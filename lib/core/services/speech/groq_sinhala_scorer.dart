import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:smart_reading_buddy/config/api_keys.dart';

/// Sinhala pronunciation scorer — Groq-hosted Whisper large-v3 transcription.
///
/// Isolated experiment (replaces the Gemini experiment as the active path):
/// records the child's audio, sends it to Groq's OpenAI-compatible audio
/// transcription endpoint (whisper-large-v3, language=si), then compares
/// the returned transcript against the expected word text.
///
/// Fully self-contained — does not touch PronunciationScorer (DTW),
/// GeminiSinhalaScorer, or HybridPronunciationScorer's English STT path.
/// Requires internet; see [stopAndScore]'s NO_INTERNET result.
class GroqSinhalaScorer {
  GroqSinhalaScorer._();

  static final _recorder = AudioRecorder();

  static const String _model = 'whisper-large-v3';
  static const int _sr         = 16000;
  static const int _minSamples = 3200; // 200 ms minimum recording

  // ── Recording ─────────────────────────────────────────────────────────────

  static Future<void> startRecording() async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/pron_groq.wav';
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

  // ── Connectivity ─────────────────────────────────────────────────────────

  static Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('api.groq.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Scoring ────────────────────────────────────────────────────────────────

  /// [word] must be the expected word in Sinhala script (NOT the romanised
  /// asset key used elsewhere for filenames).
  /// Returns 'OK' | 'WRONG' | 'NO_SPEECH' | 'NO_INTERNET'.
  static Future<String> stopAndScore({
    required String word,
    required int    gradeNum,
  }) async {
    final path = await _recorder.stop();
    if (path == null) return 'WRONG';

    final Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      return 'WRONG';
    }

    if (!_hasSpeech(bytes)) return 'NO_SPEECH';

    if (!await _hasInternet()) {
      // ignore: avoid_print
      print('═══ GROQ (si) ═══');
      // ignore: avoid_print
      print('No internet connection — Groq unreachable');
      // ignore: avoid_print
      print('════════════════');
      return 'NO_INTERNET';
    }

    try {
      final recognized = await _transcribe(bytes);
      final matched    = _matches(recognized, word);

      // ignore: avoid_print
      print('═══ GROQ (si) ═══');
      // ignore: avoid_print
      print('Expected  : "$word"');
      // ignore: avoid_print
      print('Groq raw  : "$recognized"');
      // ignore: avoid_print
      print('Result    : ${matched ? "OK (matched)" : "WRONG (unmatched)"}');
      // ignore: avoid_print
      print('════════════════');

      return matched ? 'OK' : 'WRONG';
    } catch (e) {
      // ignore: avoid_print
      print('═══ GROQ (si) ═══');
      // ignore: avoid_print
      print('Expected  : "$word"');
      // ignore: avoid_print
      print('Error     : $e');
      // ignore: avoid_print
      print('════════════════');
      return 'WRONG';
    }
  }

  // ── Groq REST call (OpenAI-compatible transcription endpoint) ────────────

  static Future<String> _transcribe(Uint8List wavBytes) async {
    final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${ApiKeys.groqApiKey}'
      ..fields['model']    = _model
      ..fields['language'] = 'si'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        wavBytes,
        filename: 'audio.wav',
      ));

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Groq HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final text = decoded['text'] as String?;
    return (text ?? '').trim();
  }

  // ── Matching ───────────────────────────────────────────────────────────────

  static bool _matches(String recognized, String expected) {
    if (recognized.isEmpty) return false;
    if (recognized == expected) return true;
    // Whisper sometimes wraps the answer in stray whitespace/newlines or
    // trailing punctuation — tolerate that without loosening the match
    // beyond exact-word comparison.
    final rClean = recognized.replaceAll(RegExp(r'[\s.!,?"‍]'), '');
    final eClean = expected.replaceAll(RegExp(r'[\s.!,?"‍]'), '');
    return rClean == eClean;
  }

  // ── Crude speech-presence check (RMS on raw PCM) ────────────────────────────

  static bool _hasSpeech(Uint8List wavBytes) {
    if (wavBytes.length < 44 + _minSamples * 2) return false;
    final bd = wavBytes.buffer.asByteData();

    int dataStart = 44;
    for (int i = 12; i < wavBytes.length - 8; i++) {
      if (wavBytes[i]   == 0x64 && wavBytes[i + 1] == 0x61 &&
          wavBytes[i + 2] == 0x74 && wavBytes[i + 3] == 0x61) {
        dataStart = i + 8;
        break;
      }
    }

    final n = (wavBytes.length - dataStart) ~/ 2;
    if (n < _minSamples) return false;

    double sumSq = 0;
    for (int i = 0; i < n; i++) {
      final s = bd.getInt16(dataStart + i * 2, Endian.little) / 32768.0;
      sumSq += s * s;
    }
    final rms = sqrt(sumSq / n);
    return rms >= 0.018;
  }
}
