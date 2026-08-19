import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

// ignore: constant_identifier_names
const String RESULT_NO_SPEECH = 'NO_SPEECH';

class _Ref {
  final List<List<double>> mfcc; // [frames][_nMfcc]
  final double threshold;
  const _Ref(this.mfcc, this.threshold);
}

/// Records the child's voice, extracts MFCC features, and compares them to
/// the pre-built reference templates via DTW.  Returns 'OK' | 'ALMOST' | 'WRONG'.
class PronunciationScorer {
  PronunciationScorer._();

  static final _recorder = AudioRecorder();

  // ── MFCC parameters — must stay in sync with 4_build_references.py ──────────
  static const int _sr        = 16000;
  static const int _nFft      = 512;   // next power-of-2 ≥ win_length=400
  static const int _winLen    = 400;   // 25 ms
  static const int _hopLen    = 160;   // 10 ms
  static const int _nMels     = 128;
  static const int _nMfcc     = 13;
  static const int _maxFrames = 250;   // cap very long recordings
  static const int _minSamples = 3200; // 200 ms minimum recording

  // OK gate  = rawThreshold × _thresholdScale
  // ALMOST gate = OK gate × 1.20
  // Raise _thresholdScale if correct words are wrongly rejected.
  // Lower _thresholdScale if wrong words still pass.
  static const double _thresholdScale = 0.65;

  // ── Recording ─────────────────────────────────────────────────────────────────

  static Future<void> startRecording() async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/pron_tmp.wav';
    await _recorder.start(
      const RecordConfig(
        encoder:      AudioEncoder.wav,
        sampleRate:   _sr,
        numChannels:  1,
        autoGain:     true,   // normalize quiet voices automatically
        echoCancel:   true,   // remove speaker echo
        noiseSuppress: true,  // suppress fans, traffic, classroom hum
      ),
      path: path,
    );
  }

  /// Normalized amplitude 0.0–1.0, sampled every 100 ms.
  /// Only meaningful while recording; returns an empty stream otherwise.
  static Stream<double> get amplitudeStream => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => ((a.current + 160) / 160).clamp(0.0, 1.0));

  /// Stops recording, scores the utterance and returns 'OK' | 'ALMOST' | 'WRONG'.
  /// [word] must match the JSON filename (lowercase, romanised for Sinhala).
  /// [lang] is 'en' or 'si'.  [gradeNum] is 3 or 4.
  static Future<String> stopAndScore({
    required String word,
    required String lang,
    required int    gradeNum,
  }) async {
    final path = await _recorder.stop();
    if (path == null) return 'WRONG';
    return _scoreFile(path: path, word: word, lang: lang, gradeNum: gradeNum);
  }

  /// Scores an already-recorded WAV at [path] instead of stopping this
  /// scorer's own recorder — used by HybridPronunciationScorer's Sinhala
  /// NO_INTERNET fallback, which hands over the raw file GeminiSinhalaScorer
  /// already captured rather than making the child record a second time.
  /// [path] must be a raw (unpreprocessed) 16kHz/mono/PCM WAV, same as
  /// what this scorer's own [startRecording] produces — GeminiSinhalaScorer
  /// uses an identical RecordConfig, so the MFCC pipeline below sees the
  /// same input shape it was calibrated against either way.
  static Future<String> scoreFromFile({
    required String path,
    required String word,
    required String lang,
    required int    gradeNum,
  }) =>
      _scoreFile(path: path, word: word, lang: lang, gradeNum: gradeNum);

  static Future<String> _scoreFile({
    required String path,
    required String word,
    required String lang,
    required int    gradeNum,
  }) async {
    try {
      final ref = await _loadRef(lang, 'grade$gradeNum', word);
      if (ref == null) return 'WRONG';

      final samples = _readWav(path);
      if (samples.length < _minSamples) return 'NO_SPEECH';
      if (!_hasSpeech(samples))         return 'NO_SPEECH';

      final query = _computeMfcc(samples);
      if (query.isEmpty) return 'WRONG';

      final dist = _dtwNorm(query, ref.mfcc);
      final thr  = ref.threshold * _thresholdScale;

      // ignore: avoid_print
      print('═══ DTW DEBUG ═══');
      // ignore: avoid_print
      print('Word: $word  lang=$lang  grade=$gradeNum');
      // ignore: avoid_print
      print('Query frames : ${query.length}');
      // ignore: avoid_print
      print('Ref frames   : ${ref.mfcc.length}');
      // ignore: avoid_print
      print('DTW distance : ${dist.toStringAsFixed(4)}');
      // ignore: avoid_print
      print('Raw threshold: ${ref.threshold.toStringAsFixed(4)}');
      // ignore: avoid_print
      print('OK  threshold: ${thr.toStringAsFixed(4)}');
      // ignore: avoid_print
      print('ALM threshold: ${(thr * 1.20).toStringAsFixed(4)}');

      if (dist <= thr)        { print('Result: OK\n════════════════'); return 'OK'; }
      if (dist <= thr * 1.20) { print('Result: ALMOST\n════════════════'); return 'ALMOST'; }
      print('Result: WRONG\n════════════════');
      return 'WRONG';
    } catch (_) {
      return 'WRONG';
    }
  }

  // ── Speech detection ──────────────────────────────────────────────────────────

  static bool _hasSpeech(List<double> samples) {
    // 1. RMS energy — silence / mic-off recordings are near zero
    double sumSq = 0;
    for (final s in samples) sumSq += s * s;
    final rms = sqrt(sumSq / samples.length);
    if (rms < 0.018) {
      // ignore: avoid_print
      print('⚠️  Speech detection FAILED  RMS=${rms.toStringAsFixed(4)} (too quiet)');
      return false;
    }

    // 2. Zero-crossing rate — pure background hum has very low ZCR,
    //    speech has moderate ZCR (0.01–0.25).
    int zc = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i - 1] >= 0) != (samples[i] >= 0)) zc++;
    }
    final zcr = zc / samples.length;
    if (zcr < 0.01 || zcr > 0.30) {
      // ignore: avoid_print
      print('⚠️  Speech detection FAILED  ZCR=${zcr.toStringAsFixed(4)} (unusual)');
      return false;
    }

    // ignore: avoid_print
    print('✓  Speech detected  RMS=${rms.toStringAsFixed(4)}  ZCR=${zcr.toStringAsFixed(4)}');
    return true;
  }

  // ── WAV decoding ──────────────────────────────────────────────────────────────

  static List<double> _readWav(String path) {
    final bytes = File(path).readAsBytesSync();
    final bd    = bytes.buffer.asByteData();

    // Read audio format and bit-depth from the fmt chunk (offsets 20, 34).
    final audioFmt     = bd.getUint16(20, Endian.little); // 1=PCM, 3=float
    final bitsPerSample = bd.getUint16(34, Endian.little);

    // Locate the 'data' sub-chunk (robustly handles non-standard headers).
    int dataStart = 44;
    for (int i = 12; i < bytes.length - 8; i++) {
      if (bytes[i]   == 0x64 && bytes[i+1] == 0x61 &&
          bytes[i+2] == 0x74 && bytes[i+3] == 0x61) {
        dataStart = i + 8;
        break;
      }
    }

    if (audioFmt == 3 && bitsPerSample == 32) {
      // 32-bit IEEE float (iOS may produce this)
      final n = (bytes.length - dataStart) ~/ 4;
      return List.generate(
          n, (i) => bd.getFloat32(dataStart + i * 4, Endian.little));
    }
    // 16-bit PCM (standard on Android and most platforms)
    final n = (bytes.length - dataStart) ~/ 2;
    return List.generate(
        n, (i) => bd.getInt16(dataStart + i * 2, Endian.little) / 32768.0);
  }

  // ── MFCC computation ──────────────────────────────────────────────────────────

  static List<List<double>> _computeMfcc(List<double> y) {
    final win = _hann(_winLen);
    final fb  = _melFilterbank();
    final out = <List<double>>[];

    for (int s = 0;
        s + _winLen <= y.length && out.length < _maxFrames;
        s += _hopLen) {
      // Frame → Hann window → zero-pad to _nFft
      final re = List<double>.filled(_nFft, 0.0);
      final im = List<double>.filled(_nFft, 0.0);
      for (int i = 0; i < _winLen; i++) re[i] = y[s + i] * win[i];
      _fftInPlace(re, im);

      // One-sided power spectrum
      final ps = List<double>.generate(
          _nFft ~/ 2 + 1, (k) => re[k] * re[k] + im[k] * im[k]);

      // Mel filterbank → log energy
      final mel = List<double>.generate(_nMels, (m) {
        double e = 0;
        for (int k = 0; k < ps.length; k++) e += fb[m][k] * ps[k];
        return log(e + 1e-10);
      });

      // DCT-II (ortho) → first _nMfcc coefficients
      out.add(_dct2(mel, _nMfcc));
    }

    if (out.isEmpty) return out;

    // Z-score normalise per coefficient across all frames
    final nF = out.length;
    for (int c = 0; c < _nMfcc; c++) {
      double sum = 0;
      for (int f = 0; f < nF; f++) sum += out[f][c];
      final mean = sum / nF;
      double sq = 0;
      for (int f = 0; f < nF; f++) {
        sq += (out[f][c] - mean) * (out[f][c] - mean);
      }
      final std = sqrt(sq / nF) + 1e-8;
      for (int f = 0; f < nF; f++) {
        out[f][c] = (out[f][c] - mean) / std;
      }
    }
    return out;
  }

  // Hann window of length n
  static List<double> _hann(int n) =>
      List.generate(n, (i) => 0.5 * (1.0 - cos(2 * pi * i / (n - 1))));

  // Radix-2 Cooley-Tukey FFT (in-place, length must be a power of 2)
  static void _fftInPlace(List<double> re, List<double> im) {
    final n = re.length;
    // Bit-reversal permutation
    for (int i = 1, j = 0; i < n; i++) {
      int bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) j ^= bit;
      j ^= bit;
      if (i < j) {
        double t = re[i]; re[i] = re[j]; re[j] = t;
               t = im[i]; im[i] = im[j]; im[j] = t;
      }
    }
    // Butterfly stages
    for (int len = 2; len <= n; len <<= 1) {
      final ang = -2.0 * pi / len;
      final wRe = cos(ang), wIm = sin(ang);
      for (int i = 0; i < n; i += len) {
        double cRe = 1.0, cIm = 0.0;
        for (int j = 0; j < len >> 1; j++) {
          final uRe = re[i + j], uIm = im[i + j];
          final h   = i + j + (len >> 1);
          final vRe = re[h] * cRe - im[h] * cIm;
          final vIm = re[h] * cIm + im[h] * cRe;
          re[i + j] = uRe + vRe;  im[i + j] = uIm + vIm;
          re[h]     = uRe - vRe;  im[h]     = uIm - vIm;
          final ncRe = cRe * wRe - cIm * wIm;
          cIm = cRe * wIm + cIm * wRe;
          cRe = ncRe;
        }
      }
    }
  }

  // Mel triangular filterbank [_nMels × (_nFft/2 + 1)] — computed once & cached
  static List<List<double>>? _cachedFb;
  static List<List<double>> _melFilterbank() {
    if (_cachedFb != null) return _cachedFb!;

    const fMin = 0.0;
    const fMax = _sr / 2.0;
    final melMin = _hz2mel(fMin), melMax = _hz2mel(fMax);
    final pts = List.generate(
        _nMels + 2,
        (i) => _mel2hz(melMin + i * (melMax - melMin) / (_nMels + 1)));

    final binN = _nFft ~/ 2 + 1;
    final bins = pts
        .map((f) => min((f * _nFft / _sr).round(), binN - 1))
        .toList();

    _cachedFb = List.generate(_nMels, (m) {
      final row = List<double>.filled(binN, 0.0);
      final dLeft  = max(1, bins[m + 1] - bins[m]);
      final dRight = max(1, bins[m + 2] - bins[m + 1]);
      for (int k = bins[m]; k < bins[m + 1]; k++) {
        if (k < binN) row[k] = (k - bins[m]) / dLeft;
      }
      for (int k = bins[m + 1]; k < bins[m + 2]; k++) {
        if (k < binN) row[k] = (bins[m + 2] - k) / dRight;
      }
      return row;
    });
    return _cachedFb!;
  }

  static double _hz2mel(double f) => 2595.0 * log(1.0 + f / 700.0) / ln10;
  static double _mel2hz(double m)  => 700.0 * (pow(10.0, m / 2595.0) - 1.0);

  // DCT-II with orthonormal scaling — first [nOut] coefficients
  static List<double> _dct2(List<double> x, int nOut) {
    final n = x.length;
    return List.generate(nOut, (k) {
      double s = 0;
      for (int i = 0; i < n; i++) s += x[i] * cos(pi * k * (i + 0.5) / n);
      return s * (k == 0 ? sqrt(1.0 / n) : sqrt(2.0 / n));
    });
  }

  // ── Classic DTW — O(n·m) — normalised by traceback path length ───────────────

  static double _dtwNorm(List<List<double>> a, List<List<double>> b) {
    final n = a.length, m = b.length;
    const inf = double.maxFinite;

    // Allocate (n+1)×(m+1) DP table
    final dp = List.generate(n + 1, (_) => List<double>.filled(m + 1, inf));
    dp[0][0] = 0.0;

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final cost = _euclidean(a[i - 1], b[j - 1]);
        dp[i][j] = cost + _min3(dp[i-1][j-1], dp[i-1][j], dp[i][j-1]);
      }
    }

    // Greedy traceback to count path length
    int pathLen = 0, i = n, j = m;
    while (i > 0 || j > 0) {
      pathLen++;
      if (i == 0) {
        j--;
      } else if (j == 0) {
        i--;
      } else {
        final d3 = dp[i-1][j-1], d1 = dp[i-1][j], d2 = dp[i][j-1];
        if (d3 <= d1 && d3 <= d2) { i--; j--; }
        else if (d1 <= d2)        { i--; }
        else                       { j--; }
      }
    }
    return dp[n][m] / max(pathLen, 1);
  }

  static double _euclidean(List<double> a, List<double> b) {
    double s = 0;
    for (int i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      s += d * d;
    }
    return sqrt(s);
  }

  static double _min3(double a, double b, double c) =>
      a < b ? (a < c ? a : c) : (b < c ? b : c);

  // ── Reference JSON loading — in-memory cache ──────────────────────────────────

  static final _cache = <String, _Ref>{};

  static Future<_Ref?> _loadRef(String lang, String grade, String word) async {
    final key = '$lang/$grade/$word';
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final raw = await rootBundle
          .loadString('assets/audio/reference/$lang/$grade/$word.json');
      final d = json.decode(raw) as Map<String, dynamic>;
      final mfcc = (d['mfcc'] as List)
          .map((r) =>
              (r as List).map((v) => (v as num).toDouble()).toList())
          .toList();
      final ref = _Ref(mfcc, (d['threshold'] as num).toDouble());
      _cache[key] = ref;
      return ref;
    } catch (_) {
      return null;
    }
  }
}
