import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Amplitude stats for a WAV, used to verify preprocessing before/after —
/// not consumed by scoring itself.
class AudioStats {
  final double peakAmplitude; // 0.0–1.0
  final double rmsAmplitude;  // 0.0–1.0
  final int    sampleCount;

  const AudioStats({
    required this.peakAmplitude,
    required this.rmsAmplitude,
    required this.sampleCount,
  });

  @override
  String toString() =>
      'peak=${peakAmplitude.toStringAsFixed(4)} '
      'rms=${rmsAmplitude.toStringAsFixed(4)} '
      'samples=$sampleCount';
}

/// App-level preprocessing pass applied to a recorded WAV before it's
/// handed to a scorer. Runs on top of Android's OS-level AGC/AEC/
/// NoiseSuppression (already enabled on the AudioRecord config in each
/// scorer's RecordConfig) — an additional pass, not a replacement.
///
/// Three steps, in order, over the raw PCM samples:
///  1. Trim leading/trailing silence (RMS-threshold based), so dead air
///     before/after the child speaks isn't sent to the scorer.
///  2. Soft noise gate: frames below a low-amplitude threshold (room hum,
///     not the child's voice) are attenuated, not zeroed — a hard cut
///     risks clipping quiet word-onset/offset consonants. Not spectral
///     noise removal, which would need a DSP library this project doesn't
///     have.
///  3. Peak-gain normalisation: if the trimmed/gated recording is still
///     quiet (child spoke softly), gain is applied so it isn't unfairly
///     penalised by a weak signal-to-noise ratio versus the reference WAV.
///
/// Pure integer/float math over 16-bit PCM samples — no external DSP
/// dependency, and fast (tens of ms for a 1–2s word recording).
///
/// Only handles 16-bit PCM WAV, which is what every recorder in this app
/// produces (RecordConfig(encoder: AudioEncoder.wav, ...) — see
/// SimplePronunciationScorer/GeminiSinhalaScorer). If a file doesn't match
/// that shape, [process] leaves it untouched and returns null.
class AudioPreprocessor {
  AudioPreprocessor._();

  // 20ms frames at 16kHz — matches the RecordConfig sample rate used by
  // every scorer in this app.
  static const int _frameSize = 320;

  // Frames below this RMS are silence, trimmed from the start/end.
  static const double _silenceThreshold = 0.02;

  // Frames below this RMS (but above the trim threshold) are background
  // noise between/around speech — attenuated, not removed.
  static const double _gateThreshold = 0.035;
  static const double _gateAttenuation = 0.25;

  // Target peak after normalisation. Deliberately below 1.0 so gain on a
  // very quiet clip doesn't blow up quantisation noise into clipping.
  static const double _targetPeak = 0.7;

  // Recordings at/above this peak are already loud enough — skip gain.
  static const double _normalizeBelow = 0.5;

  /// Reads the WAV at [path], applies trim -> gate -> normalise, and
  /// overwrites the same file with the processed audio. Returns
  /// (before, after) stats for logging/verification, or null if the file
  /// isn't a 16-bit PCM WAV it can parse.
  static Future<(AudioStats before, AudioStats after)?> process(
      String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    if (bytes.length < 44) return null;

    final bd = bytes.buffer.asByteData();
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
    final samples = Int16List(n);
    for (int i = 0; i < n; i++) {
      samples[i] = bd.getInt16(dataStart + i * 2, Endian.little);
    }

    final before = _stats(samples);

    var processed = _trimSilence(samples);
    processed = _noiseGate(processed);
    processed = _normalize(processed);

    final after = _stats(processed);

    final header = bytes.sublist(0, dataStart);
    final outBytes = _buildWav(header, processed);
    await file.writeAsBytes(outBytes);

    return (before, after);
  }

  static AudioStats _stats(Int16List samples) {
    if (samples.isEmpty) {
      return const AudioStats(peakAmplitude: 0, rmsAmplitude: 0, sampleCount: 0);
    }
    double sumSq = 0;
    int peak = 0;
    for (final s in samples) {
      final norm = s / 32768.0;
      sumSq += norm * norm;
      final abs = s.abs();
      if (abs > peak) peak = abs;
    }
    return AudioStats(
      peakAmplitude: peak / 32768.0,
      rmsAmplitude: sqrt(sumSq / samples.length),
      sampleCount: samples.length,
    );
  }

  /// Cuts leading/trailing frames whose RMS is below [_silenceThreshold],
  /// keeping one frame of padding on each side so speech onset/offset
  /// isn't clipped. If the whole clip is silent, returns it unchanged —
  /// the downstream _hasSpeech() check rejects it as NO_SPEECH anyway.
  static Int16List _trimSilence(Int16List samples) {
    if (samples.isEmpty) return samples;
    final frameCount = (samples.length / _frameSize).ceil();

    int firstVoiced = -1;
    int lastVoiced = -1;
    for (int f = 0; f < frameCount; f++) {
      final start = f * _frameSize;
      final end = min(start + _frameSize, samples.length);
      if (_frameRms(samples, start, end) >= _silenceThreshold) {
        firstVoiced == -1 ? firstVoiced = f : null;
        lastVoiced = f;
      }
    }
    if (firstVoiced == -1) return samples;

    final startFrame = max(0, firstVoiced - 1);
    final endFrame = min(frameCount - 1, lastVoiced + 1);
    final start = startFrame * _frameSize;
    final end = min((endFrame + 1) * _frameSize, samples.length);
    return Int16List.sublistView(samples, start, end);
  }

  /// Attenuates (doesn't zero) low-RMS frames — background hum between or
  /// around speech gets quieter without risking cutting real signal.
  static Int16List _noiseGate(Int16List samples) {
    if (samples.isEmpty) return samples;
    final out = Int16List.fromList(samples);
    final frameCount = (samples.length / _frameSize).ceil();
    for (int f = 0; f < frameCount; f++) {
      final start = f * _frameSize;
      final end = min(start + _frameSize, samples.length);
      if (_frameRms(samples, start, end) < _gateThreshold) {
        for (int i = start; i < end; i++) {
          out[i] = (out[i] * _gateAttenuation).round();
        }
      }
    }
    return out;
  }

  /// Applies gain to a quiet recording so its peak reaches [_targetPeak].
  /// Leaves already-adequate or fully-silent recordings untouched.
  static Int16List _normalize(Int16List samples) {
    if (samples.isEmpty) return samples;
    int peak = 0;
    for (final s in samples) {
      final abs = s.abs();
      if (abs > peak) peak = abs;
    }
    final peakNorm = peak / 32768.0;
    if (peakNorm < 0.001 || peakNorm >= _normalizeBelow) return samples;

    // Capped so a near-silent clip's noise floor isn't blown into clipping.
    final gain = (_targetPeak / peakNorm).clamp(1.0, 6.0);
    final out = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      out[i] = (samples[i] * gain).round().clamp(-32768, 32767);
    }
    return out;
  }

  static double _frameRms(Int16List samples, int start, int end) {
    double sumSq = 0;
    for (int i = start; i < end; i++) {
      final v = samples[i] / 32768.0;
      sumSq += v * v;
    }
    return sqrt(sumSq / (end - start));
  }

  /// Rebuilds a WAV file from [headerPrefix] (everything up to and
  /// including the "data" chunk's size field) and [samples], fixing the
  /// RIFF chunk size and data chunk size for the new (post-trim) length.
  static Uint8List _buildWav(List<int> headerPrefix, Int16List samples) {
    final dataLen = samples.length * 2;
    final header = Uint8List.fromList(headerPrefix);
    final hd = header.buffer.asByteData();
    hd.setUint32(4, header.length - 8 + dataLen, Endian.little);   // RIFF chunk size
    hd.setUint32(header.length - 4, dataLen, Endian.little);       // data chunk size

    final out = BytesBuilder();
    out.add(header);
    final sampleBytes = Uint8List(dataLen);
    final sbd = sampleBytes.buffer.asByteData();
    for (int i = 0; i < samples.length; i++) {
      sbd.setInt16(i * 2, samples[i], Endian.little);
    }
    out.add(sampleBytes);
    return out.toBytes();
  }
}
