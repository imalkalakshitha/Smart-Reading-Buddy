import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'audio_preprocessor.dart';

// ignore: constant_identifier_names
const String RESULT_NO_SPEECH = 'NO_SPEECH';

/// Energy-envelope pronunciation scorer.
///
/// Compares the child's voice to the reference WAV in assets using
/// frame-level RMS energy + normalised cross-correlation.  Much more
/// robust than MFCC-DTW when child recordings are short or noisy.
///
/// Drop-in replacement for PronunciationScorer: same static API.
class SimplePronunciationScorer {
  SimplePronunciationScorer._();

  static final _recorder = AudioRecorder();

  static const int _sr         = 16000;
  static const int _minSamples = 3200; // 200 ms minimum
  static const int _frameSize  = 800;  // 50 ms frames

  // ── Recording ─────────────────────────────────────────────────────────────

  static Future<void> startRecording() async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/pron_simple.wav';
    await _recorder.start(
      const RecordConfig(
        encoder:       AudioEncoder.wav,
        sampleRate:    _sr,
        numChannels:   1,
        autoGain:      true,
        echoCancel:    true,
        noiseSuppress: true,
      ),
      path: path,
    );
  }

  /// Normalised amplitude 0.0–1.0, sampled every 100 ms.
  static Stream<double> get amplitudeStream => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => ((a.current + 160) / 160).clamp(0.0, 1.0));

  /// Stops recording and returns raw calibration data, or null if no speech.
  /// Used by CalibrationScreen to collect the child's personal voice profile.
  static Future<({double dtw, double rawThreshold})?> stopAndGetCalibrationScore({
    required String word,
    required String lang,
    required int    gradeNum,
  }) async {
    final path = await _recorder.stop();
    if (path == null) return null;

    try {
      final stats = await AudioPreprocessor.process(path);
      if (stats != null) {
        // ignore: avoid_print
        print('🎚️  Preprocess (calibration)  before: ${stats.$1}  after: ${stats.$2}');
      }
      final childBytes   = await File(path).readAsBytes();
      final childSamples = _readWav(childBytes);

      if (childSamples.length < _minSamples) return null;
      if (!_hasSpeech(childSamples))         return null;

      final refSamples = await _loadReference(word, lang, gradeNum);
      if (refSamples == null) return null;

      final score     = _compareEnergy(childSamples, refSamples);
      final threshold = _threshold(word);

      // ignore: avoid_print
      print('🎯 Calibration  word=$word  score=${score.toStringAsFixed(4)}'
            '  threshold=${threshold.toStringAsFixed(4)}');

      return (dtw: score, rawThreshold: threshold);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Calibration scorer error: $e');
      return null;
    }
  }

  /// Stops recording and returns 'OK' | 'ALMOST' | 'WRONG' | 'NO_SPEECH'.
  /// [word] must match the WAV filename in assets (lowercase, romanised for Sinhala).
  /// [lang] is 'en' or 'si'.  [gradeNum] is 3 or 4.
  static Future<String> stopAndScore({
    required String word,
    required String lang,
    required int    gradeNum,
  }) async {
    final path = await _recorder.stop();
    if (path == null) return 'WRONG';

    try {
      final stats = await AudioPreprocessor.process(path);
      if (stats != null) {
        // ignore: avoid_print
        print('🎚️  Preprocess  before: ${stats.$1}  after: ${stats.$2}');
      }
      final childBytes   = await File(path).readAsBytes();
      final childSamples = _readWav(childBytes);

      if (childSamples.length < _minSamples) return 'NO_SPEECH';
      if (!_hasSpeech(childSamples))         return 'NO_SPEECH';

      final refSamples = await _loadReference(word, lang, gradeNum);
      if (refSamples == null) {
        // No reference WAV — fall back to speech-detected → OK so the
        // child is not unfairly blocked when assets are missing.
        // ignore: avoid_print
        print('⚠️  No reference for $word — defaulting OK (no-asset fallback)');
        return 'OK';
      }

      final score     = _compareEnergy(childSamples, refSamples);
      final threshold = _threshold(word);

      // ignore: avoid_print
      print('═══ ENERGY SCORE ═══');
      // ignore: avoid_print
      print('Word  : $word  lang=$lang  grade=$gradeNum');
      // ignore: avoid_print
      print('Score : ${score.toStringAsFixed(4)}');
      // ignore: avoid_print
      print('OK    : ${threshold.toStringAsFixed(4)}');
      // ignore: avoid_print
      print('ALMOST: ${(threshold * 1.40).toStringAsFixed(4)}');

      if (score < threshold) {
        // ignore: avoid_print
        print('Result: OK\n════════════════════');
        return 'OK';
      }
      if (score < threshold * 1.40) {
        // ignore: avoid_print
        print('Result: ALMOST\n════════════════════');
        return 'ALMOST';
      }
      // ignore: avoid_print
      print('Result: WRONG\n════════════════════');
      return 'WRONG';
    } catch (e) {
      // ignore: avoid_print
      print('❌ Simple scorer error: $e');
      return 'WRONG';
    }
  }

  // ── Threshold — shorter words need tighter gate ───────────────────────────

  static double _threshold(String word) {
    final len = word.length;
    if (len <= 3) return 0.38;
    if (len <= 5) return 0.45;
    return 0.50;
  }

  // ── Reference loading ─────────────────────────────────────────────────────

  static Future<List<double>?> _loadReference(
      String word, String lang, int gradeNum) async {
    try {
      final assetPath =
          'assets/audio/words/$lang/grade$gradeNum/${word.toLowerCase()}.wav';
      final data = await rootBundle.load(assetPath);
      return _readWav(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  // ── WAV decoding (handles both 16-bit PCM and 32-bit float) ──────────────

  static List<double> _readWav(Uint8List bytes) {
    final bd = bytes.buffer.asByteData();

    final audioFmt      = bd.getUint16(20, Endian.little);
    final bitsPerSample = bd.getUint16(34, Endian.little);

    int dataStart = 44;
    for (int i = 12; i < bytes.length - 8; i++) {
      if (bytes[i]   == 0x64 && bytes[i + 1] == 0x61 &&
          bytes[i + 2] == 0x74 && bytes[i + 3] == 0x61) {
        dataStart = i + 8;
        break;
      }
    }

    if (audioFmt == 3 && bitsPerSample == 32) {
      final n = (bytes.length - dataStart) ~/ 4;
      return List.generate(
          n, (i) => bd.getFloat32(dataStart + i * 4, Endian.little));
    }
    final n = (bytes.length - dataStart) ~/ 2;
    return List.generate(
        n, (i) => bd.getInt16(dataStart + i * 2, Endian.little) / 32768.0);
  }

  // ── Speech detection ──────────────────────────────────────────────────────

  static bool _hasSpeech(List<double> samples) {
    double sumSq = 0;
    for (final s in samples) { sumSq += s * s; }
    final rms = sqrt(sumSq / samples.length);
    if (rms < 0.018) {
      // ignore: avoid_print
      print('⚠️  No speech  RMS=${rms.toStringAsFixed(4)}');
      return false;
    }
    // ignore: avoid_print
    print('✓  Speech  RMS=${rms.toStringAsFixed(4)}');
    return true;
  }

  // ── Energy comparison ─────────────────────────────────────────────────────

  static double _compareEnergy(List<double> child, List<double> reference) {
    final cEnv = _energyEnvelope(child);
    final rEnv = _energyEnvelope(reference);

    final cNorm = _normalise(cEnv);
    final rNorm = _normalise(rEnv);

    final similarity = _crossCorrelate(cNorm, rNorm);
    return (1.0 - similarity).clamp(0.0, 1.0);
  }

  static List<double> _energyEnvelope(List<double> samples) {
    final env = <double>[];
    final hop = _frameSize ~/ 2;
    for (int i = 0; i + _frameSize <= samples.length; i += hop) {
      double sumSq = 0;
      for (int j = i; j < i + _frameSize; j++) { sumSq += samples[j] * samples[j]; }
      env.add(sqrt(sumSq / _frameSize));
    }
    return env;
  }

  static List<double> _normalise(List<double> env) {
    if (env.isEmpty) return env;
    final maxVal = env.reduce(max);
    if (maxVal < 0.001) return env;
    return env.map((v) => v / maxVal).toList();
  }

  static double _crossCorrelate(List<double> a, List<double> b) {
    final minLen = min(a.length, b.length);
    if (minLen == 0) return 0.0;
    double sum = 0;
    for (int i = 0; i < minLen; i++) { sum += a[i] * b[i]; }
    return (sum / minLen).clamp(0.0, 1.0);
  }
}
