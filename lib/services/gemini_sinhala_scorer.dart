import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/api_keys.dart';

/// Thrown internally when Gemini responds 429 (rate limited). Carries the
/// server-suggested wait time so the caller can back off before retrying.
class _GeminiRateLimitException implements Exception {
  final int retryAfterSeconds;
  _GeminiRateLimitException(this.retryAfterSeconds);
}

/// Sinhala pronunciation scorer — Gemini multimodal transcription.
///
/// Isolated experiment (replaces an earlier on-device Whisper attempt):
/// records the child's audio, sends it to Gemini asking for a bare
/// Sinhala-script transcription of the single spoken word, then compares
/// that transcription against the expected word text.
///
/// On a 429 (rate limit) response, waits for the server-suggested delay
/// (parsed from the error body, default 20s if not present) and retries
/// once. If still rate-limited after that, fails gracefully — no crash,
/// caller gets the usual WRONG-style verdict instead of an exception.
///
/// Fully self-contained — does not touch PronunciationScorer (DTW) or
/// HybridPronunciationScorer's English STT path. Requires internet; see
/// [stopAndScore]'s NO_INTERNET result.
class GeminiSinhalaScorer {
  GeminiSinhalaScorer._();

  static final _recorder = AudioRecorder();

  /// True while waiting out a 429 backoff before the automatic retry.
  /// The UI can listen to this to show "please wait, retrying..." instead
  /// of the normal "checking..." indicator during that specific wait.
  static final ValueNotifier<bool> isRetrying = ValueNotifier<bool>(false);

  static const int _defaultRetryDelaySeconds = 20;

  // Pinned to a specific lighter model rather than the "-latest" alias —
  // gemini-flash-latest currently resolves to gemini-3.6-flash, which has
  // a much lower free-tier rate limit and was hitting 429s quickly.
  // gemini-2.5-flash-lite has a higher free-tier quota. Revisit if this
  // model is deprecated (see git history for the -latest alias approach).
  static const String _model = 'gemini-2.5-flash-lite';
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
      final recognized = await _transcribeWithRetry(bytes);
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

  // ── Gemini REST call, with one automatic retry on 429 ────────────────────

  /// Calls Gemini once; on a 429 it waits out the suggested backoff and
  /// tries exactly one more time. If it's still rate-limited (or fails for
  /// any other reason) after that, this rethrows a plain Exception, which
  /// [stopAndScore]'s catch block turns into a graceful WRONG result rather
  /// than crashing the app.
  static Future<String> _transcribeWithRetry(Uint8List wavBytes) async {
    try {
      return await _transcribe(wavBytes);
    } on _GeminiRateLimitException catch (e) {
      // ignore: avoid_print
      print('═══ GEMINI (si) ═══');
      // ignore: avoid_print
      print('429 rate limited — waiting ${e.retryAfterSeconds}s, retrying once');
      // ignore: avoid_print
      print('════════════════');

      isRetrying.value = true;
      try {
        await Future.delayed(Duration(seconds: e.retryAfterSeconds));
      } finally {
        isRetrying.value = false;
      }

      try {
        return await _transcribe(wavBytes);
      } on _GeminiRateLimitException {
        throw Exception(
            'Gemini still rate-limited after one retry (waited '
            '${e.retryAfterSeconds}s)');
      }
    }
  }

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

    if (response.statusCode == 429) {
      throw _GeminiRateLimitException(_parseRetryDelaySeconds(response.body));
    }

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

  /// Extracts the server-suggested retry delay from a 429 error body.
  /// Handles the structured `"retryDelay":"20s"` field Gemini normally
  /// sends, and falls back to free-text like "retry in 20.5 seconds" or
  /// "Please retry in 20s". Defaults to 20s if neither pattern is found.
  static int _parseRetryDelaySeconds(String body) {
    final structured = RegExp(r'"retryDelay"\s*:\s*"(\d+(?:\.\d+)?)s"')
        .firstMatch(body);
    if (structured != null) {
      return double.tryParse(structured.group(1)!)?.ceil() ??
          _defaultRetryDelaySeconds;
    }

    final freeText = RegExp(
      r'retry in\s*(\d+(?:\.\d+)?)\s*s',
      caseSensitive: false,
    ).firstMatch(body);
    if (freeText != null) {
      return double.tryParse(freeText.group(1)!)?.ceil() ??
          _defaultRetryDelaySeconds;
    }

    return _defaultRetryDelaySeconds;
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
