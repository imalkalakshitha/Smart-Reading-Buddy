import 'dart:io';
import 'dart:typed_data';

/// Result of parsing a WAV into waveform bars — [bars] are normalised
/// relative to THIS clip's own loudest sample (standard waveform-viewer
/// behaviour, e.g. Audacity does the same), not a fixed int16 scale.
/// Without this, a genuinely quiet recording (see [isQuiet]) renders as
/// a flat/invisible line even though its samples have real relative
/// variation — confirmed on a real saved attempt where the loudest
/// sample was only ~0.8% of full int16 scale, which produced bars in
/// the 0.0001-0.008 range under fixed 32768-scale normalisation.
class WavWaveformResult {
  final List<double> bars;
  // True when this clip's absolute peak was very low (see
  // _quietPeakThreshold) — [bars] still show real relative shape via
  // self-normalisation, but the caller may want to tell the user the
  // underlying recording itself was quiet (e.g. captured mostly silence).
  final bool isQuiet;

  const WavWaveformResult({required this.bars, required this.isQuiet});
}

/// Parses 16-bit PCM WAV bytes into a small number of amplitude buckets,
/// for a simple bar/line waveform visualisation — the Parent Dashboard's
/// "Sound Wave Comparison" view. Purely a display aid: never used for
/// scoring, never touches any scoring logic.
///
/// Parses the same way audio_preprocessor.dart does (search for the
/// "data" chunk marker rather than assuming a fixed 44-byte header,
/// since some encoders/OEMs pad the header differently) — duplicated
/// here rather than imported, since that method is private to its own
/// class and this needs to run against two different WAV sources
/// (a bundled asset and a saved recording), not just a scorer's own
/// in-flight file.
class WavWaveform {
  WavWaveform._();

  // Below this raw int16 peak (out of 32768), a clip is flagged as
  // "quiet" for the caller — chosen well above typical digital-silence
  // noise floor but well below a normally-spoken word's peak.
  static const int _quietPeakThreshold = 800;

  /// Reads the WAV file at [path] from disk. Null if the file doesn't
  /// exist or isn't a 16-bit PCM WAV this can parse.
  static Future<WavWaveformResult?> extractBarsFromFile(String path, {int barCount = 60}) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return extractBarsFromBytes(bytes, barCount: barCount);
  }

  /// Parses WAV bytes already in memory (e.g. loaded via rootBundle for
  /// a bundled reference asset). Null if unparsable.
  static WavWaveformResult? extractBarsFromBytes(Uint8List bytes, {int barCount = 60}) {
    if (bytes.length < 44) return null;
    final bd = ByteData.sublistView(bytes);
    final bitsPerSample = bd.getUint16(34, Endian.little);
    if (bitsPerSample != 16) return null;

    int dataStart = 44;
    for (int i = 12; i < bytes.length - 8; i++) {
      if (bytes[i] == 0x64 && bytes[i + 1] == 0x61 &&
          bytes[i + 2] == 0x74 && bytes[i + 3] == 0x61) {
        dataStart = i + 8;
        break;
      }
    }

    final n = (bytes.length - dataStart) ~/ 2;
    if (n <= 0) return null;

    final bucketSize = (n / barCount).ceil().clamp(1, n);
    final rawPeaks = List<int>.filled(barCount, 0);
    int overallPeak = 0;
    for (int b = 0; b < barCount; b++) {
      final start = b * bucketSize;
      if (start >= n) continue;
      final end = (start + bucketSize).clamp(0, n);
      int peak = 0;
      for (int i = start; i < end; i++) {
        final s = bd.getInt16(dataStart + i * 2, Endian.little).abs();
        if (s > peak) peak = s;
      }
      rawPeaks[b] = peak;
      if (peak > overallPeak) overallPeak = peak;
    }

    // Self-normalise to this clip's own loudest sample, not a fixed
    // int16 scale — a quiet-but-real recording still shows its actual
    // shape instead of reading as a flat/empty line. Full silence (peak
    // 0) safely stays all-zero rather than dividing by zero.
    final bars = overallPeak == 0
        ? List<double>.filled(barCount, 0.0)
        : [for (final p in rawPeaks) (p / overallPeak).clamp(0.0, 1.0)];

    return WavWaveformResult(
      bars: bars,
      isQuiet: overallPeak < _quietPeakThreshold,
    );
  }
}
