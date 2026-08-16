import 'dart:async';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart';
import '../config/api_keys.dart';
import '../services/gemini_sinhala_scorer.dart';
import '../services/hybrid_pronunciation_scorer.dart';

/// Thin wrapper around the Pronunciation module's proven STT/Gemini
/// calling patterns — reused directly, not reinvented. Every call here
/// goes through HybridPronunciationScorer's existing public static API,
/// the same one pronunciation_session_screen.dart itself calls, plus a
/// read-only observation of GeminiSinhalaScorer.isRetrying (already a
/// public ValueNotifier there, used to time 429-retry backoffs for
/// logging — no changes to that file either).
/// Two small additive-only parameters (apiKey/geminiApiKey, both
/// optional and default-preserving) were later added to
/// hybrid_pronunciation_scorer.dart and gemini_sinhala_scorer.dart so
/// this bridge could supply its own Gemini key — see
/// ApiKeys.timedReadingGeminiApiKey below — without changing any
/// existing Pronunciation call site's behavior.
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
  /// [lang] is 'en' or 'si' — same convention HybridPronunciationScorer
  /// already uses.
  static Future<void> startRecording({required String lang}) =>
      HybridPronunciationScorer.startRecording(lang: lang);

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

  // ── Sinhala-only connectivity pre-check ──────────────────────────────
  // GeminiSinhalaScorer already has an internal _hasInternet() using this
  // exact technique (DNS lookup to generativelanguage.googleapis.com,
  // 3s timeout) — but it's private, only runs AFTER the child finishes
  // speaking (inside stopAndScore), and that file is off-limits to modify
  // (pronunciation-module hard constraint). Timed Reading's spec needs a
  // PRE-flight check, before a Sinhala session even starts recording, so
  // this duplicates the same lightweight technique rather than editing
  // gemini_sinhala_scorer.dart to expose it.
  static Future<bool> hasInternetForSinhala() async {
    try {
      final result = await InternetAddress.lookup('generativelanguage.googleapis.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// Voice-activity auto-stop — same amplitude thresholds and "arm after
/// first speech, then stop after a silence grace period" logic as
/// pronunciation_session_screen.dart's _onVadSample, but with its OWN,
/// separately-tunable [silenceGrace] rather than reusing Pronunciation's
/// verbatim. That reuse was the root cause of a real bug: Pronunciation's
/// _vadSilenceGrace (900ms) is tuned for a single-word drill, where any
/// pause at all means the child is done. Timed Reading records a full
/// CONNECTED SENTENCE — a dyslexic child decoding word-by-word can easily
/// pause >900ms between words, so the 900ms value was auto-stopping
/// after just the first word (confirmed from a device log: "මම ගමට යමි"
/// captured as just "මම"). Fixed by giving Timed Reading its own,
/// meaningfully longer default here — this class is never imported by
/// anything under screens/pronunciation/, so Pronunciation's own
/// _vadSilenceGrace constant is completely untouched.
class TimedReadingVadMonitor {
  static const double speechThreshold = 0.12;
  static const double silenceThreshold = 0.06;

  // Pronunciation's single-word-drill value is 900ms — too short for a
  // full sentence's natural inter-word pauses. 2500ms is a deliberately
  // more generous starting point for connected speech; tune after
  // real-device testing with actual children.
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
  // Sinhala's `record`-package stream (GeminiSinhalaScorer.amplitudeStream)
  // polls continuously every 100ms regardless of silence, so this idle
  // watchdog is inert for Sinhala — it only ever fires once a real gap
  // in samples exists, which for Sinhala doesn't happen.
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
  /// thinking time). This is the only speech-start signal available
  /// without modifying the pronunciation module: Gemini's Sinhala path
  /// has no partial-result stream at all (single POST-based
  /// transcription, not streaming), and English's speech_to_text partial
  /// results live inside HybridPronunciationScorer's private static
  /// state with no public stream exposed — so unlike the earlier
  /// English-only STT-service version of this feature, there is no
  /// partial-result fallback path here for either language, only this
  /// amplitude-crossing signal.
  ///
  /// [onAutoStop] fires either from the normal silence-grace path
  /// (amplitude observed dropping and staying below [silenceThreshold]
  /// for [silenceGrace]) OR, for English, from the idle watchdog below —
  /// whichever happens first. The watchdog does NOT shorten how long
  /// speech_to_text itself waits before deciding a result is final; it
  /// only reacts promptly once the stream shows that decision already
  /// happened (no new samples for [_streamIdleTimeout]).
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
