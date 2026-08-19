import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/pronunciation_result.dart';
import 'gemini_sinhala_scorer.dart';
// ignore: unused_import
import 'groq_sinhala_scorer.dart'; // FALLBACK — see stopAndScore/startRecording below
import 'pronunciation_scorer.dart'; // Sinhala NO_INTERNET fallback — see stopAndScore below
import 'simple_pronunciation_scorer.dart';

/// Hybrid pronunciation scorer — word verification + quality stars.
///
/// English  → on-device STT (en_US) + 5-strategy text matching (exact,
///            phonetic variants, edit-distance, similarity ratio, Soundex).
///            Unchanged — si_LK STT is not reliably available offline, but
///            en_US is standard on virtually every Android device.
/// Sinhala  → GeminiSinhalaScorer (cloud multimodal transcription via
///            REST — see gemini_sinhala_scorer.dart). Retries once with
///            backoff on Gemini 429 rate-limit responses (see
///            GeminiSinhalaScorer.stopAndScore). When there's no internet,
///            falls back to PronunciationScorer (offline MFCC/DTW),
///            reusing the same raw recording Gemini already captured — no
///            second attempt needed, no child-facing "no internet"
///            message. GroqSinhalaScorer (Whisper large-v3 via Groq) is
///            the other experiment — commented directly above its call
///            site below, uncomment to switch to it.
///
/// When English STT is completely unavailable the energy-envelope scorer
/// (SimplePronunciationScorer) is used as a last resort.
///
/// English attempt audio: on-device STT never produces a WAV file (it's
/// in-memory recognition, not file-based), so there's nothing to save
/// from the actual scored utterance. A first attempt at solving this ran
/// a second, independent `record`-package capture CONCURRENTLY with
/// _stt.listen()/.stop() — confirmed on a real device to starve STT of
/// mic input (NO_SPEECH/error_speech_timeout on clearly-spoken words),
/// a platform-level mic-arbitration conflict (SpeechRecognizer runs in a
/// separate OS process; a second AudioRecord session in ours isn't
/// reliably supported alongside it). Reverted.
///
/// Current approach: SEQUENTIAL, not parallel. STT runs completely alone,
/// exactly as before this feature existed — no capture during
/// listen()/stop() at all. Only once the verdict comes back WRONG does a
/// brief (~1.5s) `record`-package capture start, by which point _stt.stop()
/// has already fully released the mic, so there's no concurrent-session
/// conflict. Trade-off, stated plainly: this cannot literally replay the
/// audio STT already scored (that's gone — never saved anywhere); it's a
/// fresh short recording taken immediately after the result is shown.
/// Kept on disk only for WRONG verdicts and capped to the last 5
/// sessions — see session_logger.dart's cleanupOldAttemptAudio. Never
/// feeds into or blocks STT/scoring in any way.
class HybridPronunciationScorer {
  HybridPronunciationScorer._();

  static final _stt = SpeechToText();
  static bool _initAttempted = false;
  static bool _sttAvailable  = false;

  static String _recognized   = '';
  static double _confidence   = 0.0;
  static double _peakAmplitude = 0.0;   // VAD: highest level seen during recording
  static StreamSubscription<double>? _fallbackSub;

  static final _ampCtrl = StreamController<double>.broadcast();

  /// Normalised amplitude 0.0–1.0.
  static Stream<double> get amplitudeStream => _ampCtrl.stream;

  // ── English-only: brief WRONG-attempt WAV capture, AFTER STT stops ─────
  static final _attemptRecorder = AudioRecorder();

  // How long to record after a WRONG verdict. Fixed/short rather than
  // VAD-driven — this already only fires on a minority of attempts, and
  // keeping it simple avoids a second silence-detection state machine
  // for a supplementary, non-scoring recording.
  static const Duration _wrongAttemptRecordingDuration = Duration(milliseconds: 1500);

  // Per-process counter, purely to keep filenames unique even if two
  // attempts somehow land on the same millisecond — the real DB
  // session_id doesn't exist yet at record time (SessionLogger.saveSession
  // only runs once, at the END of a session, after every word has been
  // attempted), so it can't be embedded in the filename directly. The
  // link back to a real session_id happens later, in the DB row itself
  // (word_attempts.audio_path, written once the session is saved).
  static int _attemptCounter = 0;

  /// Records a brief supplementary WAV — only ever called after a WRONG
  /// verdict, and only after _stt.stop() has already fully completed (the
  /// mic is free by then, no concurrent-session conflict with STT).
  /// Best-effort: any failure is swallowed and returns null rather than
  /// throwing, since a missing waveform is not worth disrupting the
  /// child's session over.
  static Future<String?> _recordWrongAttemptAudio() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final attemptsDir = Directory('${dir.path}/pronunciation_attempts');
      await attemptsDir.create(recursive: true);
      final n = ++_attemptCounter;
      final path = '${attemptsDir.path}/wrong_${DateTime.now().millisecondsSinceEpoch}_$n.wav';
      await _attemptRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      await Future.delayed(_wrongAttemptRecordingDuration);
      return await _attemptRecorder.stop();
    } catch (e) {
      debugPrint('⚠️  Brief WRONG-attempt audio capture failed (scoring unaffected): $e');
      try { await _attemptRecorder.stop(); } catch (_) {}
      return null;
    }
  }

  // ── English phonetic variants ─────────────────────────────────────────────
  //
  // STT may hear close-sounding alternatives for short/ambiguous English words.
  // Each entry lists likely mis-recognitions so a correct pronunciation still
  // scores OK even when the engine returns a near-miss.

  static const Map<String, List<String>> _englishPhonetics = {
    // ── Grade 3 English ─────────────────────────────────────────────────────
    'cat':       ['cat', 'cats', 'kat', 'cut', 'cot'],
    'dog':       ['dog', 'dogs', 'dawg', 'doug'],
    'pig':       ['pig', 'pigs', 'pick', 'peak'],
    'sun':       ['sun', 'son', 'sung'],
    'pen':       ['pen', 'pin', 'pain'],
    'fish':      ['fish', 'fishes', 'wish'],
    'jump':      ['jump', 'jumps', 'pump'],
    'rock':      ['rock', 'rocks', 'walk'],
    'rain':      ['rain', 'rains', 'crane'],
    'ship':      ['ship', 'ships', 'sheep', 'chip'],
    'eat':       ['eat', 'eats', 'heat', 'it'],
    'ice':       ['ice', 'eyes', 'nice'],
    'open':      ['open', 'opens', 'ocean'],
    'tiger':     ['tiger', 'tigers', 'tighter'],
    'pencil':    ['pencil', 'pencils'],
    'bother':    ['bother', 'brother', 'bothers'],
    'table':     ['table', 'tables', 'cable'],
    'mother':    ['mother', 'mothers'],
    'river':     ['river', 'rivers', 'liver'],
    'weather':   ['weather', 'whether', 'feather'],
    'paper':     ['paper', 'papers', 'pepper'],
    'window':    ['window', 'windows', 'widow'],
    'green':     ['green', 'grain', 'greens'],
    'beach':     ['beach', 'beaches', 'peach'],
    'plant':     ['plant', 'plants', 'plan'],
    'bread':     ['bread', 'breads', 'bred'],
    'light':     ['light', 'lights', 'right', 'lite'],
    'computer':  ['computer', 'computers'],
    'sunshine':  ['sunshine', 'sunshines'],
    'butterfly': ['butterfly', 'butterflies'],
    // ── Grade 4 English ─────────────────────────────────────────────────────
    'apple':     ['apple', 'apples', 'chapel'],
    'tasty':     ['tasty', 'taste', 'tastes'],
    'daily':     ['daily'],
    'rings':     ['rings', 'ring', 'wings'],
    'orange':    ['orange', 'oranges'],
    'happy':     ['happy', 'happily'],
    'chair':     ['chair', 'chairs', 'cheer'],
    'water':     ['water', 'waters', 'waiter'],
    'animal':    ['animal', 'animals'],
    'kite':      ['kite', 'kites', 'kit'],
    'story':     ['story', 'stories', 'storey'],
    'large':     ['large', 'larger'],
    'morning':   ['morning', 'mornings', 'mourning'],
    'teacher':   ['teacher', 'teachers'],
    'beautiful': ['beautiful', 'beautifully'],
    'bright':    ['bright', 'brighter', 'right'],
    'everyday':  ['everyday', 'every day'],
    'picture':   ['picture', 'pictures'],
    'homework':  ['homework'],
    'classroom': ['classroom', 'classrooms'],
    'evening':   ['evening', 'evenings'],
    'market':    ['market', 'markets'],
    'rainbow':   ['rainbow', 'rainbows'],
    'village':   ['village', 'villages'],
    'student':   ['student', 'students'],
    'horse':     ['horse', 'horses', 'house'],
    'healthy':   ['healthy', 'health'],
  };

  // ── Initialisation ────────────────────────────────────────────────────────

  static Future<void> _ensureInit() async {
    if (_initAttempted) return;
    _initAttempted = true;
    _sttAvailable = await _stt.initialize(
      onError:  (e) => debugPrint('STT error: ${e.errorMsg}'),
      onStatus: (s) => debugPrint('STT status: $s'),
    );
    debugPrint(_sttAvailable
        ? '✅ STT ready (hybrid mode)'
        : '⚠️  STT unavailable — using energy fallback');
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  static Future<void> startRecording({String lang = 'en'}) async {
    _recognized    = '';
    _confidence    = 0.0;
    _peakAmplitude = 0.0;
    await _fallbackSub?.cancel();
    _fallbackSub = null;

    if (lang == 'si') {
      // FALLBACK - uncomment to revert to the offline DTW/MFCC scorer
      // await PronunciationScorer.startRecording();
      // _fallbackSub = PronunciationScorer.amplitudeStream.listen(_safeAdd);
      // return;

      // FALLBACK - uncomment to revert to Groq
      // await GroqSinhalaScorer.startRecording();
      // _fallbackSub = GroqSinhalaScorer.amplitudeStream.listen(_safeAdd);
      // return;

      await GeminiSinhalaScorer.startRecording();
      _fallbackSub = GeminiSinhalaScorer.amplitudeStream.listen(_safeAdd);
      return;
    }

    await _ensureInit();
    if (_sttAvailable) {
      // No attempt-audio capture here — STT runs completely alone, same
      // as before this feature existed. See the class doc comment: any
      // WRONG-attempt recording happens sequentially, in stopAndScore,
      // only after _stt.stop() has fully released the mic.
      await _stt.listen(
        onResult: _onResult,
        onSoundLevelChange: (level) {
          final norm = ((level + 5) / 15).clamp(0.0, 1.0);
          if (norm > _peakAmplitude) _peakAmplitude = norm;
          _safeAdd(norm);
        },
        localeId: 'en_US',
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          listenMode:     ListenMode.dictation,
          cancelOnError:  false,
          partialResults: true,
        ),
      );
    } else {
      // No STT at all — energy envelope scorer
      await SimplePronunciationScorer.startRecording();
      _fallbackSub =
          SimplePronunciationScorer.amplitudeStream.listen(_safeAdd);
    }
  }

  static void _onResult(SpeechRecognitionResult result) {
    if (result.recognizedWords.isNotEmpty) {
      _recognized  = result.recognizedWords;
      _confidence  = result.confidence;
    }
    debugPrint('STT ▶ "${result.recognizedWords}" '
        'conf=${result.confidence.toStringAsFixed(2)} '
        '(final=${result.finalResult})');
  }

  static void _safeAdd(double v) {
    if (!_ampCtrl.isClosed) _ampCtrl.add(v);
  }

  // ── Scoring ───────────────────────────────────────────────────────────────

  static Future<PronunciationResult> stopAndScore({
    required String word,
    required String lang,
    required int    gradeNum,
    // Sinhala script text of [word] (word is the romanised asset key,
    // e.g. "gama" — Gemini needs the actual script, e.g. "ගම", to compare
    // its transcription against). Unused for English.
    String? sinhalaScript,
    // Optional Gemini key override, passed straight through to
    // GeminiSinhalaScorer.stopAndScore — defaults to that method's own
    // default (Pronunciation's key) when omitted, so every existing call
    // site here is unaffected. Unused for English.
    String? geminiApiKey,
    // Optional, default-preserving pass-through to
    // GeminiSinhalaScorer.stopAndScore's skipPreprocessing — defaults to
    // false so every existing call site here is unaffected. Unused for
    // English. See GeminiSinhalaScorer.stopAndScore's doc for why Timed
    // Reading sets this true.
    bool skipPreprocessing = false,
  }) async {
    await _fallbackSub?.cancel();
    _fallbackSub = null;

    if (lang == 'si') {
      // FALLBACK - uncomment to revert to Groq
      // final verdict = await GroqSinhalaScorer.stopAndScore(
      //     word: sinhalaScript ?? word, gradeNum: gradeNum);
      // return _verdictToFallbackResult(verdict);

      final result = await GeminiSinhalaScorer.stopAndScore(
          word: sinhalaScript ?? word,
          gradeNum: gradeNum,
          apiKey: geminiApiKey,
          skipPreprocessing: skipPreprocessing);

      // No internet — rather than blocking the child with a message, fall
      // back to the offline DTW/MFCC scorer (PronunciationScorer, already
      // built/validated — this is the same fallback path that used to be
      // commented out above). Reuses the raw WAV GeminiSinhalaScorer just
      // recorded (see its audioPath doc comment) instead of asking for a
      // second recording. If that path is somehow missing (recorder
      // failed before any file existed), there's nothing to score — falls
      // through to the ordinary NO_INTERNET result below as a last resort.
      if (result.verdict == 'NO_INTERNET' && result.audioPath != null) {
        final dtwVerdict = await PronunciationScorer.scoreFromFile(
            path: result.audioPath!, word: word, lang: lang, gradeNum: gradeNum);
        return _verdictToFallbackResult(dtwVerdict);
      }

      return _verdictToFallbackResult(result.verdict, rawTranscript: result.transcript);
    }

    // ── English only from here on ───────────────────────────────────────────

    // STT completely unavailable → energy scorer
    if (!_sttAvailable) {
      final verdict = await SimplePronunciationScorer.stopAndScore(
          word: word, lang: lang, gradeNum: gradeNum);
      return _verdictToFallbackResult(verdict);
    }

    await _stt.stop();
    // Give the engine a moment to deliver the final result.
    await Future.delayed(const Duration(milliseconds: 500));

    final recognized = _recognized.toLowerCase().trim();
    final expected   = word.toLowerCase().trim();
    final confidence = _confidence;

    // ignore: avoid_print
    print('═══ HYBRID SCORE ═══');
    // ignore: avoid_print
    print('Language  : $lang');
    // ignore: avoid_print
    print('Expected  : "$expected"');
    // ignore: avoid_print
    print('Recognized: "$recognized"  conf=${confidence.toStringAsFixed(2)}');

    if (recognized.isEmpty) {
      // ignore: avoid_print
      print('Result: NO_SPEECH  peak=$_peakAmplitude\n════════════════');
      return const PronunciationResult(
          verdict: 'NO_SPEECH', stars: 0, xpEarned: 0);
    }

    // ── Word match ────────────────────────────────────────────────────────
    if (_matchesEnglish(recognized, expected)) {
      final stars = _starsFromConfidence(confidence);
      final xp    = _xpForStars(stars);
      // ignore: avoid_print
      print('Result: OK  stars=$stars  xp=$xp\n════════════════');
      return PronunciationResult(
          verdict: 'OK', stars: stars, xpEarned: xp, confidence: confidence,
          rawTranscript: recognized);
    }

    // ── ALMOST check (Soundex + similarity ratio) ─────────────────────────
    final tokens = recognized.split(RegExp(r'\s+'));
    final almostByEdit = _editDistance(recognized, expected) <= 2 ||
        tokens.any((t) => _editDistance(t, expected) <= 2);
    final almostBySoundex = _soundexMatch(recognized, expected) ||
        tokens.any((t) => _soundexMatch(t, expected));
    if (almostByEdit || almostBySoundex) {
      // ignore: avoid_print
      print('Result: ALMOST  stars=1\n════════════════');
      return PronunciationResult(
          verdict: 'ALMOST', stars: 1, xpEarned: 3, rawTranscript: recognized);
    }

    // ignore: avoid_print
    print('Result: WRONG\n════════════════');
    // Sequential, WRONG-only capture — see _recordWrongAttemptAudio's doc
    // comment. _stt.stop() (above) has already fully completed, so the
    // mic is free; this cannot conflict with STT the way the earlier
    // concurrent approach did.
    final keptAudioPath = await _recordWrongAttemptAudio();
    // ignore: avoid_print
    print(keptAudioPath != null
        ? '🎙️  Attempt audio kept for parent review: $keptAudioPath'
        : '🎙️  Attempt audio not available (capture failed)');
    return PronunciationResult(
        verdict: 'WRONG', stars: 0, xpEarned: 0, rawTranscript: recognized,
        audioPath: keptAudioPath);
  }

  // ── Matching helpers ──────────────────────────────────────────────────────

  /// English: 5 strategies — exact, phonetic variants, edit-distance ≤ 1,
  /// similarity ratio ≥ 75 %, Soundex.
  static bool _matchesEnglish(String recognized, String expected) {
    final tokens = recognized.split(RegExp(r'\s+'));

    // Strategy 1 — exact / token
    if (recognized == expected || tokens.contains(expected)) {
      // ignore: avoid_print
      print('   ✅ S1: exact/token');
      return true;
    }

    // Strategy 2 — phonetic variant table
    final variants = _englishPhonetics[expected] ?? [];
    for (final v in variants) {
      if (recognized == v || tokens.contains(v)) {
        // ignore: avoid_print
        print('   ✅ S2: phonetic variant "$v"');
        return true;
      }
      if (recognized.contains(v) && v.length >= 3) {
        // ignore: avoid_print
        print('   ✅ S2: phonetic substring "$v"');
        return true;
      }
    }

    // Strategy 3 — edit distance ≤ 1, tightened for short words.
    // On a short word a single edit distance is too permissive on its own
    // — e.g. "table" vs "sable" is edit-distance 1 but a completely
    // different word. For words ≤6 letters, also require the same first
    // letter AND same last 3 letters (both, not either — "table"/"sable"
    // share the same last 3 letters "ble", so an OR wouldn't actually
    // reject that pair).
    if (_editDistanceMatch(recognized, expected) ||
        tokens.any((t) => _editDistanceMatch(t, expected))) {
      // ignore: avoid_print
      print('   ✅ S3: edit distance ≤ 1 (tightened)');
      return true;
    }

    // Strategy 4 — similarity ratio ≥ 75 %, tightened for short words
    // (same guard as S3 — see _passesShortWordGuard).
    if (_similarityMatch(recognized, expected) ||
        tokens.any((t) => _similarityMatch(t, expected))) {
      // ignore: avoid_print
      print('   ✅ S4: similarity ≥ 75 % (tightened)');
      return true;
    }

    // Strategy 5 — Soundex
    if (_soundexMatch(recognized, expected) ||
        tokens.any((t) => _soundexMatch(t, expected))) {
      // ignore: avoid_print
      print('   ✅ S5: Soundex match');
      return true;
    }

    return false;
  }

  // ── Quality helpers ───────────────────────────────────────────────────────

  /// STT confidence → 1–3 stars.
  /// When Android doesn't report confidence (0.0) an exact match defaults to
  /// 3 stars so the child is never penalised for the OS not reporting it.
  static int _starsFromConfidence(double conf) {
    if (conf <= 0.0) return 3;
    if (conf >= 0.80) return 3;
    if (conf >= 0.55) return 2;
    return 1;
  }

  static int _xpForStars(int stars) {
    switch (stars) {
      case 3:  return 15;
      case 2:  return 10;
      case 1:  return 5;
      default: return 0;
    }
  }

  /// Verdict (from a Sinhala cloud scorer, or the energy fallback when STT
  /// is unavailable) → PronunciationResult. [rawTranscript] carries through
  /// whatever the scorer actually heard, when it has one to offer.
  static PronunciationResult _verdictToFallbackResult(
    String verdict, {
    String? rawTranscript,
  }) {
    switch (verdict) {
      case 'OK':
        return PronunciationResult(
            verdict: 'OK', stars: 2, xpEarned: 10, rawTranscript: rawTranscript);
      case 'ALMOST':
        return PronunciationResult(
            verdict: 'ALMOST', stars: 1, xpEarned: 3, rawTranscript: rawTranscript);
      case 'NO_SPEECH':
        return const PronunciationResult(
            verdict: 'NO_SPEECH', stars: 0, xpEarned: 0);
      case 'NO_INTERNET':
        return const PronunciationResult(
            verdict: 'NO_INTERNET', stars: 0, xpEarned: 0);
      default:
        return PronunciationResult(
            verdict: 'WRONG', stars: 0, xpEarned: 0, rawTranscript: rawTranscript);
    }
  }

  /// Shared secondary guard for S3 and S4 on short words (≤6 letters),
  /// where a raw edit-distance-1 / 75%-similarity signal alone is too
  /// permissive — e.g. "table" vs "sable" is both edit-distance 1 (S3) and
  /// 80% similar (S4) despite being unrelated words.
  ///
  /// Requires the same first letter. A same-last-3-letters clause was
  /// tried and rejected: it broke legitimate single-letter-drop STT noise
  /// near the end of a word (e.g. "window" heard as "windo", "mother"
  /// heard as "mothr") because a deletion shifts every character after
  /// it, so no fixed-length suffix comparison survives it — that's not a
  /// tuning problem, a same-length suffix check is structurally
  /// incompatible with insertion/deletion-type edits. First-letter-only
  /// correctly rejects the reported "table"/"sable" and "mother"/"bother"
  /// cases while recovering the trailing-letter-drop cases; the known
  /// trade-off is a same-first-letter, different-word pair like
  /// "plant"/"plait" would still pass — accepted as it's a narrower miss
  /// than what this guard was added to fix.
  ///
  /// Longer words (>6 letters) skip the guard; a single edit is far less
  /// likely to land on a coincidentally-similar different word there.
  static bool _passesShortWordGuard(String candidate, String expected) {
    if (expected.length > 6) return true;
    if (candidate.isEmpty || expected.isEmpty) return false;
    return candidate[0] == expected[0];
  }

  /// Strategy 3's actual gate — see [_passesShortWordGuard].
  static bool _editDistanceMatch(String candidate, String expected) {
    if (candidate.isEmpty || expected.isEmpty) return false;
    if (_editDistance(candidate, expected) > 1) return false;
    return _passesShortWordGuard(candidate, expected);
  }

  /// Strategy 4's actual gate — see [_passesShortWordGuard].
  static bool _similarityMatch(String candidate, String expected) {
    if (candidate.isEmpty || expected.isEmpty) return false;
    if (_similarityRatio(candidate, expected) < 0.75) return false;
    return _passesShortWordGuard(candidate, expected);
  }

  // ── Levenshtein edit distance ─────────────────────────────────────────────

  static int _editDistance(String a, String b) {
    final m = a.length, n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) { dp[i][0] = i; }
    for (int j = 0; j <= n; j++) { dp[0][j] = j; }
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce(min);
      }
    }
    return dp[m][n];
  }

  // ── Similarity ratio ──────────────────────────────────────────────────────

  /// Normalised match score 0.0–1.0 based on edit distance.
  static double _similarityRatio(String a, String b) {
    final dist = _editDistance(a, b);
    final maxLen = max(a.length, b.length);
    if (maxLen == 0) return 1.0;
    return 1.0 - dist / maxLen;
  }

  // ── Soundex ───────────────────────────────────────────────────────────────

  /// American Soundex — 4-character phonetic code.
  static String _soundex(String word) {
    if (word.isEmpty) return '';
    final w = word.toUpperCase();
    const table = {
      'B': '1', 'F': '1', 'P': '1', 'V': '1',
      'C': '2', 'G': '2', 'J': '2', 'K': '2',
      'Q': '2', 'S': '2', 'X': '2', 'Z': '2',
      'D': '3', 'T': '3',
      'L': '4',
      'M': '5', 'N': '5',
      'R': '6',
    };
    var code = w[0];
    for (int i = 1; i < w.length && code.length < 4; i++) {
      final digit = table[w[i]];
      if (digit != null && digit != table[code[code.length - 1]]) {
        code += digit;
      }
    }
    while (code.length < 4) { code += '0'; }
    return code;
  }

  static bool _soundexMatch(String a, String b) =>
      _soundex(a) == _soundex(b);
}
