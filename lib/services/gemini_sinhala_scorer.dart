import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/api_keys.dart';

/// Sinhala pronunciation scorer — Gemini multimodal transcription.
///
/// Isolated experiment (replaces an earlier on-device Whisper attempt):
/// records the child's audio, sends it to Gemini asking for a bare
/// Sinhala-script transcription of the single spoken word, then compares
/// that transcription against the expected word text.
///
/// Fully self-contained — does not touch PronunciationScorer (DTW) or
/// HybridPronunciationScorer's English STT path. Requires internet; see
/// [stopAndScore]'s NO_INTERNET result.
class GeminiSinhalaScorer {
  GeminiSinhalaScorer._();

  static final _recorder = AudioRecorder();

  // Auto-updated alias — always points at the current available Flash
  // model, so this doesn't break again when a specific dated model
  // (e.g. gemini-2.5-flash) gets deprecated for new users.
  static const String _model = 'gemini-flash-latest';
  static const int _sr         = 16000;
  static const int _minSamples = 3200; // 200 ms minimum recording

  // ── Recording ─────────────────────────────────────────────────────────────

  static Future<void> startRecording() async {
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/pron_gemini.wav';
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
      final result = await InternetAddress.lookup('generativelanguage.googleapis.com')
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
      print('═══ GEMINI (si) ═══');
      // ignore: avoid_print
      print('No internet connection — Gemini unreachable');
      // ignore: avoid_print
      print('════════════════');
      return 'NO_INTERNET';
    }

    try {
      final recognized = await _transcribe(bytes);
      final matched    = _matches(recognized, word);

      // ignore: avoid_print
      print('═══ GEMINI (si) ═══');
      // ignore: avoid_print
      print('Expected  : "$word"');
      // ignore: avoid_print
      print('Gemini raw: "$recognized"');
      // ignore: avoid_print
      print('Result    : ${matched ? "OK (matched)" : "WRONG (unmatched)"}');
      // ignore: avoid_print
      print('════════════════');

      return matched ? 'OK' : 'WRONG';
    } catch (e) {
      // ignore: avoid_print
      print('═══ GEMINI (si) ═══');
      // ignore: avoid_print
      print('Expected  : "$word"');
      // ignore: avoid_print
      print('Error     : $e');
      // ignore: avoid_print
      print('════════════════');
      return 'WRONG';
    }
  }

  // ── Gemini REST call ─────────────────────────────────────────────────────

  static Future<String> _transcribe(Uint8List wavBytes) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent'
      '?key=${ApiKeys.geminiApiKey}',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
                  'Transcribe the single Sinhala word spoken in this audio '
                  'clip. Respond with ONLY the Sinhala-script transcription '
                  'of that one word — no romanisation, no punctuation, no '
                  'explanation, no extra text of any kind.'
            },
            {
              'inline_data': {
                'mime_type': 'audio/wav',
                'data': base64Encode(wavBytes),
              }
            },
          ],
        }
      ],
    });

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Gemini HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates: ${response.body}');
    }
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini returned no content parts: ${response.body}');
    }
    final text = (parts.first as Map<String, dynamic>)['text'] as String?;
    return (text ?? '').trim();
  }

  // ── Matching ───────────────────────────────────────────────────────────────

  static bool _matches(String recognized, String expected) {
    if (recognized.isEmpty) return false;
    if (recognized == expected) return true;
    // Gemini occasionally wraps the answer in stray whitespace/newlines or
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
