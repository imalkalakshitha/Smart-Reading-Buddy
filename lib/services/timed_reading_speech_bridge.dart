import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../config/api_keys.dart';
import '../services/gemini_sinhala_scorer.dart';
import '../services/hybrid_pronunciation_scorer.dart';

/// ENGLISH ONLY as of the Sinhala Gemini-removal redesign (see
/// TimedReadingAudioRecorder below for Sinhala's own independent path).
/// Thin wrapper around the Pronunciation module's proven STT calling
/// pattern — reused directly, not reinvented. Every call here goes
/// through HybridPronunciationScorer's existing public static API, the
/// same one pronunciation_session_screen.dart itself calls.
///
/// HybridPronunciationScorer.stopAndScore() is built for single-word
/// matching (verdict/stars/xp against one expected word) — not meaningful
/// for a full sentence. Timed Reading only takes back the raw transcript
/// ([TimedReadingSttResult.transcript]) and runs its own sentence-level
/// word diff (see word_diff.dart) on it; the verdict/stars/xp fields are
/// deliberately ignored.
class TimedReadingSttResult {
  final String? transcript;
  final bool noSpeech; // engine returned empty/no-match — don't count as a valid attempt
  final bool noInternet; // Sinhala/Gemini only
  // Total time spent waiting out a Gemini 429 backoff during this call
  // (0 if no retry happened, always 0 for English). Logged separately so
  // retry frequency stays visible for debugging without being folded
  // into elapsedMs — see ReadingScreen._stopAndCapture.
  final int geminiRetryWaitMs;

  const TimedReadingSttResult({
    required this.transcript,
    required this.noSpeech,
    required this.noInternet,
    this.geminiRetryWaitMs = 0,
  });
}

class TimedReadingSpeechBridge {
  // English only — subscription to HybridPronunciationScorer's additive
  // onPartialResult hook (see that file's doc comment). Held here so
  // stopAndGetTranscript can cancel it once a unit's recording ends,
  // same lifecycle as everything else scoped to one recording attempt.
  static StreamSubscription<void>? _partialResultSub;

  /// [lang] is 'en' or 'si' — same convention HybridPronunciationScorer
  /// already uses. [onFirstPartialResult], English only, fires once — the
  /// first time the STT engine delivers a genuine (non-final) partial
  /// recognition — so ReadingScreen can time speech onset from actual STT
  /// recognition instead of amplitude-threshold VAD. Ignored for Sinhala
  /// (no on-device STT session exists there to observe).
  static Future<void> startRecording({
    required String lang,
    void Function()? onFirstPartialResult,
  }) async {
    await _partialResultSub?.cancel();
    _partialResultSub = null;
    if (lang == 'en' && onFirstPartialResult != null) {
      var fired = false;
      _partialResultSub = HybridPronunciationScorer.onPartialResult.listen((_) {
        if (fired) return;
        fired = true;
        onFirstPartialResult();
      });
    }
    return HybridPronunciationScorer.startRecording(lang: lang);
  }

  /// Stops recording and returns the raw transcript. [sentenceText] is
  /// passed through as the required `word`/`sinhalaScript` params
  /// stopAndScore needs for its own (here-unused) verdict computation —
  /// there's no single target "word" for a sentence, so the sentence
  /// text itself fills that slot.
  ///
  /// [onRecordingStopped], if given, fires synchronously at the very top
  /// of this method — before the network call to Gemini (or the
  /// English STT flush) begins — marking the instant recording actually
  /// stopped. The caller is invoked with no intervening await, so this
  /// timestamp reflects the moment its own VAD/silence-grace decided to
  /// stop, NOT however long the subsequent transcription (including any
  /// Gemini 429 retry backoff) ends up taking. ReadingScreen uses this
  /// (Sinhala only) instead of a post-await timestamp so a retry delay
  /// can no longer inflate elapsedMs.
  static Future<TimedReadingSttResult> stopAndGetTranscript({
    required String sentenceText,
    required String lang,
    required int gradeNum,
    void Function()? onRecordingStopped,
  }) async {
    onRecordingStopped?.call();
    await _partialResultSub?.cancel();
    _partialResultSub = null;

    // Sinhala-only: GeminiSinhalaScorer.isRetrying is a public
    // ValueNotifier<bool> already exposed for UI ("please wait,
    // retrying..."). Observed here read-only to measure actual 429-retry
    // backoff duration for logging — gemini_sinhala_scorer.dart itself
    // is untouched, this only listens to a field it already exposes.
    var retryWaitMs = 0;
    DateTime? retryStartedAt;
    void onRetryChanged() {
      if (GeminiSinhalaScorer.isRetrying.value) {
        retryStartedAt = DateTime.now();
      } else if (retryStartedAt != null) {
        retryWaitMs += DateTime.now().difference(retryStartedAt!).inMilliseconds;
        retryStartedAt = null;
      }
    }
    if (lang == 'si') GeminiSinhalaScorer.isRetrying.addListener(onRetryChanged);

    try {
      final result = await HybridPronunciationScorer.stopAndScore(
        word: sentenceText,
        lang: lang,
        gradeNum: gradeNum,
        sinhalaScript: lang == 'si' ? sentenceText : null,
        geminiApiKey: ApiKeys.timedReadingGeminiApiKey,
        // Timed Reading has its own reliable start/stop boundary (manual
        // "Done" button) and doesn't need AudioPreprocessor's RMS-trim —
        // confirmed via live testing that trim was cutting full-sentence
        // recordings down to just the first word. See
        // GeminiSinhalaScorer.stopAndScore's doc for full detail.
        skipPreprocessing: true,
      );
      final transcript = result.rawTranscript;
      final noSpeech = result.verdict == 'NO_SPEECH' ||
          transcript == null ||
          transcript.trim().isEmpty;
      final noInternet = result.verdict == 'NO_INTERNET';
      return TimedReadingSttResult(
        transcript: transcript,
        noSpeech: noSpeech,
        noInternet: noInternet,
        geminiRetryWaitMs: retryWaitMs,
      );
    } finally {
      if (lang == 'si') GeminiSinhalaScorer.isRetrying.removeListener(onRetryChanged);
    }
  }

  // ── English-only STT availability pre-check ──────────────────────────
  // HybridPronunciationScorer's own STT-availability flag (_sttAvailable)
  // is private with no public getter, and that file is off-limits to
  // modify — so this uses a standalone SpeechToText().initialize() call
  // (same technique/pattern Pronunciation itself uses) purely to decide
  // UI mode upfront. Actual recording during the session still always
  // goes through HybridPronunciationScorer, never this instance — if its
  // own internal check disagrees and silently falls back to the energy
  // scorer, stopAndGetTranscript's noSpeech flag catches that per-unit
  // anyway (no crash either way).
  static Future<bool> checkEnglishSttAvailability() async {
    try {
      final probe = SpeechToText();
      return await probe.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      return false;
    }
  }

}

/// Sinhala Timed Reading's own independent audio recorder — deliberately
/// separate from GeminiSinhalaScorer/HybridPronunciationScorer (both
/// off-limits pronunciation-module files, and both now unused for
/// Sinhala Timed Reading entirely). Gemini transcription/scoring is no
/// longer part of the Sinhala Timed Reading flow at all: recording is
/// kept as a temp WAV per unit purely so a parent/teacher can play it
/// back in MiscueMarkingScreen and mark misreads manually — fully
/// offline, no network dependency anywhere in this path.
///
/// Same `record` package, same RecordConfig shape as the pronunciation
/// scorers use (confirmed via reading those files that this is the
/// project's standard pattern) — but its own AudioRecorder instance, so
/// it never shares state with, or has to coordinate with, any
/// pronunciation-module recorder.
class TimedReadingAudioRecorder {
  TimedReadingAudioRecorder._();

  static final _recorder = AudioRecorder();

  static Future<void> start({required String path}) => _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );

  /// Returns the recorded file's path, or null if recording never
  /// started / produced no file.
  static Future<String?> stop() => _recorder.stop();

  // Every temp file lives under <tempDir>/tr_audio/, named by session
  // token + unit index — keeps Timed Reading's audio fully separate from
  // any pronunciation-module temp files (which use their own fixed
  // filenames directly in the temp root) and makes the whole subfolder
  // trivial to sweep on cleanup.
  static Future<String> pathFor({
    required String sessionToken,
    required int unitIndex,
  }) async {
    final dir = await getTemporaryDirectory();
    final audioDir = Directory('${dir.path}/tr_audio');
    await audioDir.create(recursive: true);
    return '${audioDir.path}/${sessionToken}_unit$unitIndex.wav';
  }

  /// Deletes the given files if they exist. Best-effort — a failure to
  /// delete one file (e.g. already gone) doesn't stop the rest, and never
  /// throws back to the caller.
  static Future<void> deleteFiles(Iterable<String?> paths) async {
    for (final p in paths) {
      if (p == null) continue;
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Defensive startup sweep — deletes any tr_audio/ (temp, in-progress
  /// recording) file older than [maxAge] (default 1 hour), catching
  /// orphans left behind by a crash or force-close before a recording
  /// ever reached _moveToReviewStorage. Safe to call on every app
  /// launch: a session actively in progress is always far younger than
  /// [maxAge], so it's never at risk of being swept mid-use.
  static Future<void> cleanupStaleFiles({Duration maxAge = const Duration(hours: 1)}) async {
    try {
      final dir = await getTemporaryDirectory();
      final audioDir = Directory('${dir.path}/tr_audio');
      if (!await audioDir.exists()) return;
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in audioDir.list()) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  // ── Longer-lived Parent Dashboard review storage ─────────────────────
  // Separate from tr_audio/ (temp, session-scoped) above — files here
  // deliberately outlive the Timed Reading session and Miscue Marking,
  // surviving until a parent listens in Parent Dashboard (which deletes
  // + nulls the DB row) or the 14-day safety-net sweep below. Uses
  // getApplicationDocumentsDirectory (not temp) for the same reason
  // hybrid_pronunciation_scorer.dart's WRONG-attempt audio does — OS temp
  // cleanup can purge getTemporaryDirectory() contents at any time, which
  // would be wrong for something meant to persist for potentially days.

  /// Moves a just-recorded temp WAV (from [pathFor]) into permanent
  /// review storage once the real SQLite session id is known — see
  /// MiscueMarkingScreen._saveSession, the only caller. Returns the new
  /// path, or null if the move failed (e.g. source file already gone) —
  /// callers should treat that unit as having no audio rather than throw.
  static Future<String?> moveToReviewStorage({
    required String tempPath,
    required int sessionId,
    required int unitIndex,
  }) async {
    try {
      final srcFile = File(tempPath);
      if (!await srcFile.exists()) {
        // ignore: avoid_print
        print('[TR-DEBUG] moveToReviewStorage: source missing at move time: $tempPath');
        return null;
      }
      final dir = await getApplicationDocumentsDirectory();
      final reviewDir = Directory('${dir.path}/tr_audio_review');
      await reviewDir.create(recursive: true);
      final destPath = '${reviewDir.path}/${sessionId}_unit$unitIndex.wav';
      try {
        await srcFile.rename(destPath);
      } catch (_) {
        // rename() can fail across filesystem boundaries on some
        // platforms — fall back to copy+delete.
        await srcFile.copy(destPath);
        await srcFile.delete();
      }
      return destPath;
    } catch (e) {
      // ignore: avoid_print
      print('[TR-DEBUG] moveToReviewStorage failed: $e');
      return null;
    }
  }

  /// Safety-net sweep for tr_audio_review/ — deletes anything older than
  /// [maxAge] (default 14 days) regardless of what the DB's
  /// audio_file_path column says, in case a delete-on-listen ever failed
  /// to also clear that column, or a parent never opens Parent Dashboard
  /// at all. Run at app startup alongside [cleanupStaleFiles]. Does NOT
  /// touch the database — a file deleted here whose row still points at
  /// it will simply fail to play next time (DeviceFileSource on a
  /// missing file), not crash; acceptable for a 14-day-stale recording.
  static Future<void> cleanupStaleReviewFiles({Duration maxAge = const Duration(days: 14)}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final reviewDir = Directory('${dir.path}/tr_audio_review');
      if (!await reviewDir.exists()) return;
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in reviewDir.list()) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}

/// Voice-activity auto-stop — English ONLY as of the Sinhala manual-Done
/// redesign (see ReadingScreen._startRecording/_onDoneTap). Three
/// amplitude-threshold tuning attempts for Sinhala (900ms silence-grace,
/// 2500ms silence-grace, 2-consecutive-sample debounce) each failed
/// against a different real noise profile on the same test device —
/// confirmed via live logging that this device's ambient noise bursts
/// overlap in both amplitude range and duration with genuine inter-word
/// pauses, so no amplitude threshold reliably separates them. Rather than
/// keep tuning, Sinhala now stops recording via an explicit "Done
/// reading" button tap instead of this class. This class is kept
/// unchanged for English, which has never shown the bug (speech_to_text's
/// own engine decides when recognition is final; this monitor's
/// onAutoStop is a secondary catch-all for English, not its primary stop
/// signal).
class TimedReadingVadMonitor {
  static const double speechThreshold = 0.12;
  static const double silenceThreshold = 0.06;

  // Pronunciation's single-word-drill value is 900ms — too short for a
  // full sentence's natural inter-word pauses. 2500ms is a deliberately
  // more generous starting point for connected speech.
  static const Duration defaultSilenceGrace = Duration(milliseconds: 2500);

  // English-only concern: HybridPronunciationScorer's amplitudeStream
  // only carries samples while speech_to_text is actively listening —
  // once its own internal pauseFor (hardcoded 3s, see the unresolved
  // risk noted separately) auto-stops the engine, onSoundLevelChange
  // simply stops firing and the stream goes silent. This monitor's own
  // silence-grace logic only evaluates samples it RECEIVES, so it can
  // never detect "the stream stopped sending anything at all" — that gap
  // was exactly why English fell through to the 25s ceiling even though
  // speech_to_text had already delivered a correct final transcript
  // seconds earlier: nothing was watching for the stream going idle.
  static const Duration _streamIdleTimeout = Duration(milliseconds: 900);

  final Duration silenceGrace;
  StreamSubscription<double>? _sub;
  Timer? _idleWatchdog;
  bool _hasSpokenOnce = false;
  DateTime? _silenceStartedAt;

  TimedReadingVadMonitor({this.silenceGrace = defaultSilenceGrace});

  /// [onSpeechStart] fires exactly once, the first time amplitude crosses
  /// [speechThreshold] — the caller (ReadingScreen) captures its own
  /// Stopwatch reading at that moment so elapsed can be measured from
  /// actual speech onset rather than from the tap that started recording
  /// (which includes mic-init latency and the child's pre-speech
  /// thinking time).
  ///
  /// [onAutoStop] fires either from the normal silence-grace path
  /// (amplitude observed dropping and staying below [silenceThreshold]
  /// for [silenceGrace]) OR from the idle watchdog below — whichever
  /// happens first. The watchdog does NOT shorten how long speech_to_text
  /// itself waits before deciding a result is final; it only reacts
  /// promptly once the stream shows that decision already happened (no
  /// new samples for [_streamIdleTimeout]).
  void start(void Function() onSpeechStart, void Function() onAutoStop) {
    _hasSpokenOnce = false;
    _silenceStartedAt = null;
    _sub?.cancel();
    _idleWatchdog?.cancel();

    // Armed only once the FIRST sample arrives (inside the listener
    // below), not before _sub even starts — an idle window before mic
    // warm-up delivers its first sample is normal, not a "stream went
    // dead" signal, and must not trigger a false auto-stop.
    void resetIdleWatchdog() {
      _idleWatchdog?.cancel();
      _idleWatchdog = Timer(_streamIdleTimeout, onAutoStop);
    }

    _sub = HybridPronunciationScorer.amplitudeStream.listen((amplitude) {
      resetIdleWatchdog();
      if (amplitude >= speechThreshold) {
        if (!_hasSpokenOnce) onSpeechStart();
        _hasSpokenOnce = true;
        _silenceStartedAt = null;
        return;
      }
      if (!_hasSpokenOnce) return;
      if (amplitude < silenceThreshold) {
        _silenceStartedAt ??= DateTime.now();
        if (DateTime.now().difference(_silenceStartedAt!) >= silenceGrace) {
          onAutoStop();
        }
      } else {
        _silenceStartedAt = null;
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _idleWatchdog?.cancel();
    _idleWatchdog = null;
  }
}
