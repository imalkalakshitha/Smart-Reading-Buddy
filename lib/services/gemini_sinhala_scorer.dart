import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/api_keys.dart';
import 'audio_preprocessor.dart';

/// Thrown internally when Gemini responds 429 (rate limited). Carries the
/// server-suggested wait time so the caller can back off before retrying.
class _GeminiRateLimitException implements Exception {
  final int retryAfterSeconds;
  _GeminiRateLimitException(this.retryAfterSeconds);
}

/// Thrown internally when Gemini responds 404 for a given model — this
/// account doesn't actually have access to it, regardless of whether it
/// shows up in ListModels.
class _GeminiModelNotFoundException implements Exception {
  final String model;
  _GeminiModelNotFoundException(this.model);
}

/// Sinhala pronunciation scorer — Gemini multimodal transcription.
///
/// Isolated experiment (replaces an earlier on-device Whisper attempt):
/// records the child's audio, sends it to Gemini asking for a bare
/// Sinhala-script transcription of the single spoken word, then compares
/// that transcription against the expected word text.
///
/// Model selection tries a fixed priority list (see [_candidateModels])
/// rather than trusting ListModels, since that endpoint lists models this
/// account doesn't actually have access to. A 404 on the current model
/// clears the cache and moves to the next candidate automatically; a 429
/// waits out the server-suggested delay and retries the same model once.
/// If nothing works, fails gracefully — no crash, caller gets the usual
/// WRONG-style verdict instead of an exception.
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

  // ListModels lists models this account doesn't actually have access to
  // (2.x entries 404 with "no longer available to new users" despite
  // appearing there), so model selection no longer trusts it. Instead we
  // try this fixed priority list in order, using the real transcription
  // call itself as the availability test — the first one that doesn't
  // 404 is cached in [_cachedModel] and reused for the rest of the app
  // run. On a 404 for the cached model mid-session, the cache is cleared
  // and [_candidateIndex] advances so the next call picks up the next
  // candidate automatically — see _transcribeWithRetry.
  static const List<String> _candidateModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.6-flash',
  ];
  static int _candidateIndex = 0;
  static String? _cachedModel;

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
  /// verdict: 'OK' | 'WRONG' | 'NO_SPEECH' | 'NO_INTERNET'.
  /// transcript: Gemini's raw transcription, only set when a transcription
  /// actually happened (null for NO_SPEECH/NO_INTERNET/error cases) — used
  /// for phonological substitution analysis, see
  /// phoneme_substitution_analyzer.dart.
  /// audioPath: only ever set for NO_INTERNET — the raw (unpreprocessed)
  /// recording, kept specifically so HybridPronunciationScorer can hand it
  /// straight to the offline DTW scorer as a fallback without a second
  /// recording. Null for every other verdict — nothing else needs it.
  static Future<({String verdict, String? transcript, String? audioPath})> stopAndScore({
    required String word,
    required int    gradeNum,
    // Optional per-call override — defaults to Pronunciation's own key so
    // every existing call site is unaffected. Timed Reading's speech
    // bridge passes ApiKeys.timedReadingGeminiApiKey explicitly here.
    String? apiKey,
    // Optional, default-preserving — defaults to false so every existing
    // Pronunciation call site keeps running AudioPreprocessor exactly as
    // before. Timed Reading's speech bridge passes true: confirmed via
    // live device testing that AudioPreprocessor's RMS-threshold trim
    // (tuned for Pronunciation's short single-word clips) was cutting
    // Timed Reading's full-sentence recordings down to just the first
    // word, even on short, cleanly-bounded (manual "Done" button)
    // recordings — later words fell below the trim's RMS floor and were
    // discarded as "trailing silence". Timed Reading now has its own
    // reliable start/stop boundary (tap-to-record / manual Done tap), so
    // it doesn't need AudioPreprocessor's trim/gate/normalize protection
    // the way Pronunciation's less-bounded single-word capture does.
    bool skipPreprocessing = false,
  }) async {
    final path = await _recorder.stop();
    if (path == null) return (verdict: 'WRONG', transcript: null, audioPath: null);

    // Speech-presence and connectivity are both checked on the RAW file,
    // before any preprocessing — deliberately, so that if there's no
    // internet, the untouched recording is still available at [path] for
    // a DTW fallback (see HybridPronunciationScorer.stopAndScore). Only
    // once we know we're actually about to call Gemini does preprocessing
    // run, exactly as before.
    final Uint8List rawBytes;
    try {
      rawBytes = await File(path).readAsBytes();
    } catch (_) {
      return (verdict: 'WRONG', transcript: null, audioPath: null);
    }

    if (!_hasSpeech(rawBytes)) return (verdict: 'NO_SPEECH', transcript: null, audioPath: null);

    if (!await _hasInternet()) {
      return (verdict: 'NO_INTERNET', transcript: null, audioPath: path);
    }

    final Uint8List bytes;
    try {
      if (!skipPreprocessing) {
        await AudioPreprocessor.process(path);
      }
      bytes = await File(path).readAsBytes();
    } catch (_) {
      return (verdict: 'WRONG', transcript: null, audioPath: null);
    }

    try {
      final recognized = await _transcribeWithRetry(bytes, apiKey: apiKey);
      final matched    = _matches(recognized, word);
      return (verdict: matched ? 'OK' : 'WRONG', transcript: recognized, audioPath: null);
    } on TimeoutException {
      // A slow/unstable connection, not a mispronunciation — the pre-flight
      // _hasInternet() DNS check above can pass yet the actual request still
      // stall out. Treat the same as NO_INTERNET rather than silently
      // scoring the child WRONG for a network hiccup. The raw file was
      // already overwritten by preprocessing above in this branch, so no
      // audioPath to offer here — DTW fallback only applies to the
      // pre-flight NO_INTERNET case.
      return (verdict: 'NO_INTERNET', transcript: null, audioPath: null);
    } catch (_) {
      return (verdict: 'WRONG', transcript: null, audioPath: null);
    }
  }

  // ── Model selection — fixed priority list, verified by real use ──────────

  static bool _isSkippable(String name) =>
      name.contains('preview') || name.contains('image') || name.contains('tts');

  /// Returns the model to try next: the cached one if we already have a
  /// confirmed-working model, otherwise the next untried candidate from
  /// [_candidateModels] (skipping any preview/image/tts entries). Returns
  /// null once every candidate has been tried and 404'd.
  static String? _pickModel() {
    if (_cachedModel != null) return _cachedModel;
    while (_candidateIndex < _candidateModels.length) {
      final candidate = _candidateModels[_candidateIndex];
      if (_isSkippable(candidate)) {
        _candidateIndex++;
        continue;
      }
      return candidate; // confirmed/cached by _transcribeOnce on success
    }
    return null;
  }

  /// Called after a confirmed 404 for the current candidate — moves past
  /// it so the next [_pickModel] call advances to the following one.
  /// Returns false once there's nothing left to try.
  static bool _advanceCandidate() {
    _candidateIndex++;
    return _candidateIndex < _candidateModels.length;
  }

  // ── Gemini REST call, with model fallback on 404 and one retry on 429 ────

  /// Tries [_transcribeOnce] with the current model. On a 404 (this
  /// account doesn't actually have access to that model, whatever
  /// ListModels says), clears the cache and automatically moves on to the
  /// next candidate in [_candidateModels] — repeating until one works or
  /// every candidate has been exhausted. On a 429 for whichever model is
  /// currently active, waits out the suggested backoff and retries that
  /// same model exactly once. If nothing works, throws a plain Exception,
  /// which [stopAndScore]'s catch block turns into a graceful WRONG result
  /// rather than crashing the app.
  static Future<String> _transcribeWithRetry(Uint8List wavBytes, {String? apiKey}) async {
    Object? lastError;
    for (int attempt = 0; attempt < _candidateModels.length; attempt++) {
      try {
        return await _transcribeWithRateLimitRetry(wavBytes, apiKey: apiKey);
      } on _GeminiModelNotFoundException catch (e) {
        _cachedModel = null;
        lastError = e;
        if (!_advanceCandidate()) break;
      }
    }
    throw Exception('All Gemini model candidates exhausted: $lastError');
  }

  /// Handles the "one retry after a 429 backoff" behaviour for whichever
  /// single model is currently selected. Does not change models itself —
  /// model fallback on 404 is handled by the caller, [_transcribeWithRetry].
  static Future<String> _transcribeWithRateLimitRetry(Uint8List wavBytes, {String? apiKey}) async {
    try {
      return await _transcribeOnce(wavBytes, apiKey: apiKey);
    } on _GeminiRateLimitException catch (e) {
      isRetrying.value = true;
      try {
        await Future.delayed(Duration(seconds: e.retryAfterSeconds));
      } finally {
        isRetrying.value = false;
      }

      try {
        return await _transcribeOnce(wavBytes, apiKey: apiKey);
      } on _GeminiRateLimitException {
        throw Exception(
            'Gemini still rate-limited after one retry (waited '
            '${e.retryAfterSeconds}s)');
      }
    }
  }

  /// Makes exactly one Gemini request with the current candidate model.
  /// This call itself is the "does this model actually work" test — no
  /// separate ping request is made, since the free-tier quota is tight
  /// enough that spending it on test calls isn't worth it.
  static Future<String> _transcribeOnce(Uint8List wavBytes, {String? apiKey}) async {
    final model = _pickModel();
    if (model == null) {
      throw Exception('No remaining Gemini model candidates to try');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'
      '?key=${apiKey ?? ApiKeys.geminiApiKey}',
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
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 404) {
      throw _GeminiModelNotFoundException(model);
    }

    if (response.statusCode == 429) {
      throw _GeminiRateLimitException(_parseRetryDelaySeconds(response.body));
    }

    if (response.statusCode != 200) {
      throw Exception('Gemini HTTP ${response.statusCode}: ${response.body}');
    }

    // Confirmed working — cache it so every later call skips straight to
    // this model instead of re-walking the candidate list.
    _cachedModel = model;

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
