import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/pronunciation_result.dart';
import '../data/sinhala_syllables.dart';
import 'simple_pronunciation_scorer.dart';

/// Hybrid pronunciation scorer — STT word verification + quality stars.
///
/// English  → English STT + 5-strategy matching (exact, phonetic variants,
///            edit-distance, similarity ratio, Soundex).
/// Sinhala  → English STT + phonetic-variant matching (si_LK models are
///            rarely installed on Sri Lankan devices, so we recognise the
///            romanised sound using the en_US model).
///
/// When STT is completely unavailable the energy-envelope scorer
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

  // ── Sinhala phonetic variants ─────────────────────────────────────────────
  //
  // When a Sinhala word is spoken by a child, the en_US STT engine hears a
  // romanised approximation.  Each entry lists the likely recognitions so that
  // a correct pronunciation still scores OK.

  static const Map<String, List<String>> _sinhalaPhonetics = {
    // ── Grade 3 Basic ───────────────────────────────────────────────────────
    'asa':        ['asa', 'assa', 'usa', 'esa'],
    'eka':        ['eka', 'ekka', 'eca', 'ika'],
    'gama':       ['gama', 'gamma', 'guma', 'gammer'],
    'ura':        ['ura', 'oora', 'hora', 'urah'],
    'oya':        ['oya', 'ohya', 'oia'],
    'kesel':      ['kesel', 'kessel', 'casel', 'kassel', 'kesal'],
    'gehaniya':   ['gehaniya', 'gahaniya', 'gehaneeya', 'gehanya'],
    'niyara':     ['niyara', 'niyaara', 'niara'],
    'thaaraawa':  ['tharawa', 'tarawa', 'taaraawa'],
    'cheenaya':   ['chenaya', 'cheenaya', 'china', 'chinaya', 'cheena'],
    'baegaya':    ['bagaya', 'baegaya', 'begaya', 'baiga'],
    'theentha':   ['thenta', 'theentha', 'tinta', 'tenta', 'theenta'],
    'poojaawa':   ['poojawa', 'pujawa', 'poojaawa', 'pooja'],
    'muhuda':     ['muhuda', 'moohuda', 'muhoodah', 'muhooda'],
    'wewela':     ['wewela', 'vevela', 'wayweyla', 'wevela'],
    // ── Grade 3 Advanced ────────────────────────────────────────────────────
    'athsana':    ['atsana', 'athsana', 'asana'],
    'kemaththa':  ['kematha', 'kemaththa', 'kemattha'],
    'sinhaya':    ['sinhaya', 'singaya', 'sinhaia', 'sinha'],
    'guruthuma':  ['guruthuma', 'guru thuma', 'gurutooma', 'gooro tooma'],
    'thowilaya':  ['towilaya', 'thowilaya', 'tovilaya'],
    'sigiriya':   ['sigiriya', 'sigi ria', 'sigeeriya', 'sigiria'],
    'waralasa':   ['waralasa', 'varalasa'],
    'eethalaya':  ['ethalaya', 'eethalaya', 'etalaya', 'arrow'],
    'udalla':     ['udalla', 'udala', 'oodalla', 'udela'],
    'kiribath':   ['kiribath', 'kiri bath', 'kiri buth', 'kiribat'],
    'wichaaraya': ['wicharaya', 'vicharaya', 'wichara', 'wichaaraya'],
    'rupakaya':   ['rupakaya', 'roopakaya', 'roopa kaya', 'roopakai'],
    'janathaawa': ['janathawa', 'janathaawa', 'janatha', 'janatawa'],
    'pohosath':   ['pohosath', 'poho sath', 'poho sat', 'pohosut'],
    'gaayanaya':  ['gayanaya', 'gaayanaya', 'gayan', 'gayana'],
    // ── Grade 4 Level 2 ─────────────────────────────────────────────────────
    'sampoorna':       ['sampoorna', 'sam poorna', 'sampurna', 'sampoornas'],
    'pilihuduwa':      ['pilihuduwa', 'pili huduwa', 'pili hooduwa'],
    'sanwaadaya':      ['sanwadaya', 'sanwaadaya', 'sanvadaya', 'sanwadaia'],
    'awabodhaya':      ['awabodhaya', 'avabodhaya', 'awa bodhaya'],
    'sankalpa':        ['sankalpa', 'sankalpaya', 'san kalpa', 'sankalpu'],
    'nirmaanasheelee': ['nirmana sheelee', 'nirmanasheelee', 'nirmana sheeli', 'nirmana shili'],
    'saukhya':         ['saukhya', 'soukhya', 'sukhaya', 'sowkia'],
    'sanvidhaanaya':   ['sanvidhanaya', 'sanvidhaanaya', 'san vidhanaya'],
    'gaurawaya':       ['gaurawaya', 'gowrawaya', 'gowrawa', 'gourawaya'],
    'wistharaya':      ['wistharaya', 'vistharaya', 'wis tharaya'],
    'nigamanaya':      ['nigamanaya', 'niga manaya', 'nigama', 'nigamanaia'],
    'aarakshaawa':     ['araksawa', 'aarakshaawa', 'arakshaawa'],
    'prayathnaya':     ['prayathnaya', 'prayatnaya', 'prayathna', 'prayatna'],
    'awadhaanaya':     ['awadanaya', 'awadhaanaya', 'awa dhanaya', 'awadana'],
    'praayoogika':     ['prayogika', 'praayoogika', 'prayoogika'],
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
    await _ensureInit();
    _recognized    = '';
    _confidence    = 0.0;
    _peakAmplitude = 0.0;
    await _fallbackSub?.cancel();
    _fallbackSub = null;

    if (_sttAvailable) {
      // Always use en_US — for Sinhala we match phonetic variants.
      // Sinhala needs a longer pause since each word has more syllables.
      await _stt.listen(
        onResult: _onResult,
        onSoundLevelChange: (level) {
          final norm = ((level + 5) / 15).clamp(0.0, 1.0);
          if (norm > _peakAmplitude) _peakAmplitude = norm;
          _safeAdd(norm);
        },
        localeId: 'en_US',
        pauseFor: lang == 'si'
            ? const Duration(seconds: 4)
            : const Duration(seconds: 3),
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
  }) async {
    await _fallbackSub?.cancel();
    _fallbackSub = null;

    // STT completely unavailable → energy scorer
    if (!_sttAvailable) {
      final verdict = await SimplePronunciationScorer.stopAndScore(
          word: word, lang: lang, gradeNum: gradeNum);
      return _verdictToFallbackResult(verdict);
    }

    await _stt.stop();
    // Give the engine a moment to deliver the final result.
    // Sinhala needs a bit more time.
    await Future.delayed(lang == 'si'
        ? const Duration(milliseconds: 700)
        : const Duration(milliseconds: 500));

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
      // For Sinhala the en_US engine often returns nothing even when the child
      // did speak (it can't map Sinhala phonemes to English words).  Use the
      // peak amplitude we tracked as a voice-activity signal.
      // Longer words need more audio, so we scale the threshold down slightly
      // — a 5-syllable word takes longer to say and produces more amplitude
      // variance, but we still want to be fair to 2-syllable words.
      if (lang == 'si') {
        final syllableCount =
            SinhalaSyllables.getSyllables(expected)?.length ?? 2;
        // 2-syllable: 0.25, 3+ syllables: 0.20 (more forgiving for long words)
        final vadThreshold = syllableCount >= 3 ? 0.20 : 0.25;
        if (_peakAmplitude >= vadThreshold) {
          // ignore: avoid_print
          print('Result: ALMOST (VAD, peak=$_peakAmplitude '
              'syl=$syllableCount thr=$vadThreshold)\n════════════════');
          return const PronunciationResult(
              verdict: 'ALMOST', stars: 1, xpEarned: 3);
        }
      }
      // ignore: avoid_print
      print('Result: NO_SPEECH  peak=$_peakAmplitude\n════════════════');
      return const PronunciationResult(
          verdict: 'NO_SPEECH', stars: 0, xpEarned: 0);
    }

    // ── Word match ────────────────────────────────────────────────────────
    final matched = lang == 'si'
        ? _matchesSinhala(recognized, expected)
        : _matchesEnglish(recognized, expected);

    if (matched) {
      final stars = _starsFromConfidence(confidence);
      final xp    = _xpForStars(stars);
      // ignore: avoid_print
      print('Result: OK  stars=$stars  xp=$xp\n════════════════');
      return PronunciationResult(
          verdict: 'OK', stars: stars, xpEarned: xp, confidence: confidence);
    }

    // ── English-only ALMOST check (Soundex + similarity ratio) ───────────
    if (lang == 'en') {
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

  /// Sinhala: check the word itself, phonetic variants, then syllable subsets.
  static bool _matchesSinhala(String recognized, String expected) {
    final tokens = recognized.split(RegExp(r'\s+'));

    // Strategy 1 — direct match
    if (recognized == expected || tokens.contains(expected)) {
      // ignore: avoid_print
      print('   ✅ S1: direct match');
      return true;
    }

    // Strategy 2 — phonetic variant table
    final variants = _sinhalaPhonetics[expected] ?? [];
    for (final variant in variants) {
      if (recognized == variant || tokens.contains(variant)) {
        // ignore: avoid_print
        print('   ✅ S2: variant "$variant"');
        return true;
      }
      if (_editDistance(recognized, variant) <= 1 ||
          tokens.any((t) => _editDistance(t, variant) <= 1)) {
        // ignore: avoid_print
        print('   ✅ S2: variant edit "$variant"');
        return true;
      }
      if (recognized.contains(variant) && variant.length >= 4) {
        // ignore: avoid_print
        print('   ✅ S2: variant substring "$variant"');
        return true;
      }
    }

    // Strategy 3 — syllable-subset matching.
    // When en_US STT hears only part of a Sinhala word (e.g. it hears "guru"
    // from "guruthuma"), check whether enough syllables are present in the
    // recognised text.  Require ceiling(n/2) of n syllables to match — so a
    // 4-syllable word passes if at least 2 syllables are heard.
    final syllables = SinhalaSyllables.getSyllables(expected);
    if (syllables != null && syllables.length >= 2) {
      int matchedCount = 0;
      for (final syl in syllables) {
        if (syl.length < 2) continue; // skip single-character syllables
        if (recognized.contains(syl) ||
            tokens.any((t) => t == syl || _editDistance(t, syl) <= 1)) {
          matchedCount++;
        }
      }
      final needed = (syllables.length / 2).ceil();
      if (matchedCount >= needed) {
        // ignore: avoid_print
        print('   ✅ S3: syllable subset $matchedCount/${syllables.length}'
            ' (need $needed)');
        return true;
      }
      // ignore: avoid_print
      print('   ✗  S3: syllable subset $matchedCount/${syllables.length}'
          ' (need $needed)');
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
