import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'simple_pronunciation_scorer.dart';

/// Pronunciation scorer that uses the device's built-in speech recognition
/// (works offline on Android/iOS with pre-installed language models).
///
/// English → real word comparison via STT (accurate, language-model-backed).
/// Sinhala → energy-envelope fallback via SimplePronunciationScorer.
///
/// Drop-in replacement: same static API as SimplePronunciationScorer.
class SttPronunciationScorer {
  SttPronunciationScorer._();

  static final _stt = SpeechToText();
  static bool _initAttempted = false;
  static bool _sttAvailable  = false;

  static String _recognized = '';
  static StreamSubscription<double>? _fallbackSub;

  static final _ampCtrl = StreamController<double>.broadcast();

  /// Normalised amplitude 0.0–1.0 — works for both STT and energy-fallback modes.
  static Stream<double> get amplitudeStream => _ampCtrl.stream;

  // ── Initialisation ────────────────────────────────────────────────────────

  static Future<void> _ensureInit() async {
    if (_initAttempted) return;
    _initAttempted = true;
    _sttAvailable = await _stt.initialize(
      onError:  (e) => debugPrint('STT error: ${e.errorMsg}'),
      onStatus: (s) => debugPrint('STT status: $s'),
    );
    debugPrint(_sttAvailable
        ? '✅ STT ready'
        : '⚠️  STT unavailable — using energy fallback');
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  /// [lang] is 'en' or 'si'.
  static Future<void> startRecording({String lang = 'en'}) async {
    await _ensureInit();
    _recognized  = '';
    await _fallbackSub?.cancel();
    _fallbackSub = null;

    // Sinhala always uses the energy fallback — si_LK offline models are
    // rarely installed on Sri Lankan devices.
    if (_sttAvailable && lang == 'en') {
      await _stt.listen(
        onResult: _onResult,
        onSoundLevelChange: (level) {
          // level ranges roughly -2 to 10 dB during speech
          final norm = ((level + 5) / 15).clamp(0.0, 1.0);
          _safeAdd(norm);
        },
        localeId: 'en_US',
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          listenMode:    ListenMode.dictation,
          cancelOnError: false,
        ),
      );
    } else {
      // Energy fallback (Sinhala, or STT not available)
      await SimplePronunciationScorer.startRecording();
      _fallbackSub =
          SimplePronunciationScorer.amplitudeStream.listen(_safeAdd);
    }
  }

  static void _onResult(SpeechRecognitionResult result) {
    if (result.recognizedWords.isNotEmpty) {
      _recognized = result.recognizedWords;
    }
    debugPrint('STT ▶ "${result.recognizedWords}" '
        '(final=${result.finalResult})');
  }

  static void _safeAdd(double v) {
    if (!_ampCtrl.isClosed) { _ampCtrl.add(v); }
  }

  // ── Scoring ───────────────────────────────────────────────────────────────

  /// Returns 'OK' | 'ALMOST' | 'WRONG' | 'NO_SPEECH'.
  static Future<String> stopAndScore({
    required String word,
    required String lang,
    required int    gradeNum,
  }) async {
    await _fallbackSub?.cancel();
    _fallbackSub = null;

    // Sinhala / STT-unavailable → energy scorer
    if (!_sttAvailable || lang == 'si') {
      return SimplePronunciationScorer.stopAndScore(
          word: word, lang: lang, gradeNum: gradeNum);
    }

    // English STT path
    await _stt.stop();
    // Give the recognition engine a moment to deliver the final result.
    await Future.delayed(const Duration(milliseconds: 500));

    final recognized = _recognized.toLowerCase().trim();
    final expected   = word.toLowerCase().trim();

    // ignore: avoid_print
    print('═══ STT SCORE ═══');
    // ignore: avoid_print
    print('Expected  : "$expected"');
    // ignore: avoid_print
    print('Recognized: "$recognized"');

    if (recognized.isEmpty) {
      // ignore: avoid_print
      print('Result: NO_SPEECH\n════════════════');
      return 'NO_SPEECH';
    }

    // Exact match or the word appears as one token in the phrase
    // (e.g. child says "the cat" → tokens = ["the","cat"] → contains "cat")
    final tokens = recognized.split(RegExp(r'\s+'));
    if (recognized == expected || tokens.contains(expected)) {
      // ignore: avoid_print
      print('Result: OK\n════════════════');
      return 'OK';
    }

    // Fuzzy: edit distance ≤ 1 handles minor mishearings ("cot"→"cat", etc.)
    if (_editDistance(recognized, expected) <= 1 ||
        tokens.any((t) => _editDistance(t, expected) <= 1)) {
      // ignore: avoid_print
      print('Result: ALMOST\n════════════════');
      return 'ALMOST';
    }

    // ignore: avoid_print
    print('Result: WRONG\n════════════════');
    return 'WRONG';
  }

  /// Returns raw calibration data, or null if no speech detected.
  static Future<({double dtw, double rawThreshold})?> stopAndGetCalibrationScore({
    required String word,
    required String lang,
    required int    gradeNum,
  }) async {
    final result = await stopAndScore(word: word, lang: lang, gradeNum: gradeNum);
    if (result == 'NO_SPEECH' || result == 'WRONG') return null;
    // Dummy values — STT-based scoring doesn't use DTW thresholds.
    return (dtw: 0.5, rawThreshold: 1.0);
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
}
