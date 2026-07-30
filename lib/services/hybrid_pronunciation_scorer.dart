import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/pronunciation_result.dart';
import 'gemini_sinhala_scorer.dart';
// ignore: unused_import
import 'groq_sinhala_scorer.dart'; // FALLBACK — see stopAndScore/startRecording below
// ignore: unused_import
import 'pronunciation_scorer.dart'; // FALLBACK — see stopAndScore/startRecording below
import 'simple_pronunciation_scorer.dart';

/// Hybrid pronunciation scorer — word verification + quality stars.
///
/// English  → on-device STT (en_US) + 5-strategy text matching (exact,
///            phonetic variants, edit-distance, similarity ratio, Soundex).
///            Unchanged — si_LK STT is not reliably available offline, but
///            en_US is standard on virtually every Android device.
/// Sinhala  → GeminiSinhalaScorer (cloud multimodal transcription via
///            REST, requires internet — see gemini_sinhala_scorer.dart).
///            Retries once with backoff on Gemini 429 rate-limit
///            responses (see GeminiSinhalaScorer.stopAndScore).
///            GroqSinhalaScorer (Whisper large-v3 via Groq) and
///            PronunciationScorer (offline MFCC/DTW, no internet needed,
///            the deepest fallback) are the other experiments — both
///            commented directly above each call site below, uncomment
///            to switch to either.
///
/// When English STT is completely unavailable the energy-envelope scorer
/// (SimplePronunciationScorer) is used as a last resort.
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
  }) async {
    await _fallbackSub?.cancel();
    _fallbackSub = null;

    if (lang == 'si') {
      // FALLBACK - uncomment to revert to the offline DTW/MFCC scorer
      // final verdict = await PronunciationScorer.stopAndScore(
      //     word: word, lang: lang, gradeNum: gradeNum);
      // return _verdictToFallbackResult(verdict);

      // FALLBACK - uncomment to revert to Groq
      // final verdict = await GroqSinhalaScorer.stopAndScore(
      //     word: sinhalaScript ?? word, gradeNum: gradeNum);
      // return _verdictToFallbackResult(verdict);

      final verdict = await GeminiSinhalaScorer.stopAndScore(
          word: sinhalaScript ?? word, gradeNum: gradeNum);
      return _verdictToFallbackResult(verdict);
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
          verdict: 'OK', stars: stars, xpEarned: xp, confidence: confidence);
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
      return const PronunciationResult(
          verdict: 'ALMOST', stars: 1, xpEarned: 3);
    }

    // ignore: avoid_print
    print('Result: WRONG\n════════════════');
    return const PronunciationResult(
        verdict: 'WRONG', stars: 0, xpEarned: 0);
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

    // Strategy 3 — edit distance ≤ 1
    if (_editDistance(recognized, expected) <= 1 ||
        tokens.any((t) => _editDistance(t, expected) <= 1)) {
      // ignore: avoid_print
      print('   ✅ S3: edit distance ≤ 1');
      return true;
    }

    // Strategy 4 — similarity ratio ≥ 75 %
    if (_similarityRatio(recognized, expected) >= 0.75 ||
        tokens.any((t) => _similarityRatio(t, expected) >= 0.75)) {
      // ignore: avoid_print
      print('   ✅ S4: similarity ≥ 75 %');
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

  /// Energy-fallback verdict → PronunciationResult (used when STT unavailable).
  static PronunciationResult _verdictToFallbackResult(String verdict) {
    switch (verdict) {
      case 'OK':
        return const PronunciationResult(
            verdict: 'OK', stars: 2, xpEarned: 10);
      case 'ALMOST':
        return const PronunciationResult(
            verdict: 'ALMOST', stars: 1, xpEarned: 3);
      case 'NO_SPEECH':
        return const PronunciationResult(
            verdict: 'NO_SPEECH', stars: 0, xpEarned: 0);
      case 'NO_INTERNET':
        return const PronunciationResult(
            verdict: 'NO_INTERNET', stars: 0, xpEarned: 0);
      default:
        return const PronunciationResult(
            verdict: 'WRONG', stars: 0, xpEarned: 0);
    }
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
