import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/timed_reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../models/timed_reading_session.dart';
import '../../router/app_router.dart';
import '../../services/timed_reading_coaching_messages.dart';
import '../../services/timed_reading_speech_bridge.dart';
import '../../utils/word_diff.dart';

/// Core Timed Reading session screen.
///
/// Tap-to-start button gesture/visuals mirror pronunciation_session_screen
/// .dart's mic button (NOT a hold gesture). Stop mechanism DIFFERS by
/// language: English still auto-stops via TimedReadingVadMonitor (its own
/// speech_to_text engine reliably decides when recognition is final).
/// Sinhala uses an explicit manual "Done reading" button tap instead —
/// three amplitude-threshold VAD tuning attempts for Sinhala each failed
/// against a different real noise profile on the same test device, so
/// amplitude-based auto-stop was abandoned entirely for that language
/// rather than continuing to tune it (see TimedReadingVadMonitor's class
/// doc and _onDoneTap). _maxRecordingDuration (25s) remains a hard safety
/// ceiling for BOTH languages, in case a child never taps Done / the
/// engine never fires its own stop.
///
/// SINHALA ACCURACY: Gemini transcription/scoring was removed from
/// Sinhala Timed Reading entirely (network dependency, rate limits, and
/// an RMS-trim step were all fighting reliable offline use) — see
/// TimedReadingAudioRecorder. Each unit is recorded to its own temp WAV
/// via that recorder (fully independent of the pronunciation module),
/// stored on that unit's UnitTiming.audioFilePath, and never touches
/// timing at all (elapsed is purely Stopwatch-based). MiscueMarkingScreen
/// offers a 🔊 Listen button per sentence so a parent/teacher can play
/// the recording back and mark misreads manually; the temp files are
/// deleted once that screen finishes or is left (see its
/// _cleanupAudioFiles), plus a defensive startup sweep in main.dart
/// catches anything orphaned by a crash. English is entirely unaffected
/// by any of this — untouched STT/HybridPronunciationScorer path.
///
/// TIMING: every recorded value comes from Stopwatch.elapsedMilliseconds,
/// captured synchronously before any await. The periodic Timer only
/// forces a UI rebuild (mm:ss/ACTUAL box live-tick).
class ReadingScreen extends StatefulWidget {
  final ReadingScreenArgs args;

  const ReadingScreen({super.key, required this.args});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> with WidgetsBindingObserver {
  late final TimedReadingSession _session;
  final Stopwatch _stopwatch = Stopwatch();
  int _checkpointMs = 0; // manual-fallback (checkpoint-to-checkpoint) elapsed source
  int _recordStartMs = 0; // speech-flow elapsed source — set at tap, not at unit start
  int _unitIndex = 0;
  bool _paused = false;
  bool _dialogShowing = false;
  Timer? _uiTimer;

  // ── Reference "Listen" playback (🔊) ─────────────────────────────────
  // Reference audio sourced from the project's children's reading
  // dataset (indeepa wav/), not independently-recorded adult speech —
  // used here as sentence playback per product decision. Same
  // AudioPlayer + AssetSource pattern as Pronunciation's word-audio
  // "Listen" button (pronunciation_session_screen.dart._playReference).
  late final AudioPlayer _audioPlayer;
  bool _listenPlaying = false;

  bool get _isSinhala => AppState.language == 'sinhala';
  String get _langCode => _isSinhala ? 'si' : 'en';
  int get _gradeNum => widget.args.grade == 'grade4' ? 4 : 3;
  List<SentenceSet> get _sentences => widget.args.sentences;

  // ── Speech (STT/Gemini via HybridPronunciationScorer reuse) ─────────
  bool _speechFlowChecked = false;
  bool _speechFlowAvailable = false; // English: STT precheck. Sinhala: connectivity precheck.
  bool _recording = false;
  bool _scoring = false;
  Timer? _autoStopTimer;
  // Pronunciation's own ceiling (7s) is tuned for a single word. Bumped
  // for Timed Reading's full-sentence recordings, which now also tolerate
  // a longer inter-word silence grace (see TimedReadingVadMonitor) — a
  // long sentence with several 2.5s decoding pauses can legitimately run
  // well past 7s. Still bounded so a stuck mic can't hang indefinitely.
  static const _maxRecordingDuration = Duration(seconds: 25);
  final _vad = TimedReadingVadMonitor();
  String? _retryNotice; // transient "no speech, try again" banner — English only now
  int? _speechStartMs; // stopwatch reading at actual speech onset (VAD-detected), not at tap
  // English only — stopwatch reading at the moment STT delivers its FIRST
  // genuine partial recognition (see TimedReadingSpeechBridge
  // .onFirstPartialResult / HybridPronunciationScorer.onPartialResult).
  // Preferred over _speechStartMs when available — see _stopAndCapture's
  // elapsed calculation for the fallback chain.
  int? _firstPartialResultMs;

  // Sinhala only: unique per-attempt token so this session's temp audio
  // filenames (see TimedReadingAudioRecorder.pathFor) never collide with
  // another session's, even if both happen to record the same unit index.
  final String _sessionAudioToken = DateTime.now().millisecondsSinceEpoch.toString();

  // ── "Buddy Voice Coaching" text banner ───────────────────────────────
  // UI/timer-triggered only — no STT/VAD/Gemini/mic involvement. See
  // timed_reading_coaching_messages.dart.
  String? _coachingMessage;
  Timer? _coachingMessageTimer;
  // Reset once per recording attempt (in _startRecording) — guards the
  // live pace-nudge check in _uiTimer's periodic callback so it fires at
  // most once per attempt, not repeatedly every 200ms once past
  // threshold.
  bool _paceNudgeShownThisUnit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _listenPlaying = false);
    });
    _session = TimedReadingSession(
      activityId: 'tr_${widget.args.grade}_${widget.args.language}_${widget.args.level}',
      childKey: AppState.name,
    );
    _session.startedAt = DateTime.now();
    _stopwatch.start();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      // Live "encourage faster pace" check — reads already-ticking
      // Stopwatch state only (same baseline the post-hoc `stalled` check
      // in _stopAndCapture/_advanceManual uses), no STT/VAD/Gemini/mic
      // involvement, no async work — this timer was already running
      // every 200ms purely for the mm:ss display, this just adds a
      // synchronous comparison to that existing tick. Guarded by
      // _paceNudgeShownThisUnit so it can only fire once per recording
      // attempt, not repeatedly once past threshold.
      if (_recording && !_paceNudgeShownThisUnit) {
        final elapsed = _stopwatch.elapsedMilliseconds - (_speechStartMs ?? _recordStartMs);
        final upperMs = (_sentences[_unitIndex].upperThresholdSec * 1000).round();
        if (elapsed > upperMs) {
          _paceNudgeShownThisUnit = true;
          _showCoachingMessage(TimedReadingCoachingMessages.encouragePace(_langCode));
        }
      }
      setState(() {});
    });
    // ignore: avoid_print
    print('[TR] ═══ READING START ═══');
    // ignore: avoid_print
    print('[TR] activity=${_session.activityId}  child=${_session.childKey}  units=${_sentences.length}');

    // Direct field assignment (not _showCoachingMessage) — this runs
    // during initState, before the first build, so calling setState here
    // would be redundant/unsafe; the initial build already picks up
    // _coachingMessage's current value. The auto-dismiss Timer itself is
    // fine to start here since its callback (which does call setState)
    // only fires later, once the widget is definitely mounted.
    final startMessage = TimedReadingCoachingMessages.start(_langCode);
    if (startMessage != null) {
      // ignore: avoid_print
      print('[TR] coaching message: "$startMessage"');
      _coachingMessage = startMessage;
      _coachingMessageTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _coachingMessage = null);
      });
    }

    _checkSpeechFlow();
  }

  Future<void> _checkSpeechFlow() async {
    // Sinhala: recording is now fully offline (own recorder, no
    // Gemini/network dependency at all — see TimedReadingAudioRecorder),
    // so there's nothing to pre-check; always available.
    final available = _isSinhala ? true : await TimedReadingSpeechBridge.checkEnglishSttAvailability();
    if (!mounted) return;
    setState(() {
      _speechFlowChecked = true;
      _speechFlowAvailable = available;
    });
    _session.manualFallback = !available;
    // ignore: avoid_print
    print('[TR] speech flow ($_langCode) ${available ? "available" : "unavailable — falling back to manual tap-advance + manual marking"}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _autoStopTimer?.cancel();
    _coachingMessageTimer?.cancel();
    _vad.stop();
    _stopwatch.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Plays (or stops) the current sentence's reference recording. Same
  /// AudioPlayer + AssetSource pattern as Pronunciation's word "Listen"
  /// button. Reference audio sourced from the project's children's
  /// reading dataset (indeepa wav/), not independently-recorded adult
  /// speech — used here as sentence playback per product decision.
  Future<void> _playReference(String assetPath) async {
    if (_listenPlaying) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _listenPlaying = false);
      return;
    }
    try {
      setState(() => _listenPlaying = true);
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (_) {
      if (mounted) setState(() => _listenPlaying = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (!_paused && _stopwatch.isRunning) {
        // ignore: avoid_print
        print('[TR] app backgrounded mid-session — auto-pausing');
        _session.interrupted = true;
        _pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_paused && _session.interrupted && !_dialogShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showResumeDialog());
      }
    }
  }

  void _pause() {
    if (_paused) return;
    _stopwatch.stop();
    if (_listenPlaying) {
      _audioPlayer.stop();
      _listenPlaying = false;
    }
    if (_recording) {
      // Discard the in-flight recording rather than let it linger while
      // backgrounded — fire-and-forget stop, result ignored.
      _autoStopTimer?.cancel();
      _vad.stop();
      if (_isSinhala) {
        // Stop + delete the orphaned temp file — this attempt is
        // discarded, never added to _session.unitTimings, so nothing
        // would otherwise clean it up.
        TimedReadingAudioRecorder.stop().then((path) {
          if (path != null) TimedReadingAudioRecorder.deleteFiles([path]);
        });
      } else {
        TimedReadingSpeechBridge.stopAndGetTranscript(
          sentenceText: _sentences[_unitIndex].text,
          lang: _langCode,
          gradeNum: _gradeNum,
        );
      }
      _recording = false;
      _scoring = false;
    }
    setState(() => _paused = true);
    // ignore: avoid_print
    print('[TR] paused  unit=$_unitIndex  elapsedMs=${_stopwatch.elapsedMilliseconds}');
  }

  void _resume() {
    if (!_paused) return;
    setState(() => _paused = false);
    _stopwatch.start();
    // ignore: avoid_print
    print('[TR] resumed  unit=$_unitIndex');
  }

  /// Shows a short encouraging banner for [autoDismissDuration] (default
  /// 3s), then clears it. No-op when [message] is null — the current
  /// Sinhala-pending state (see TimedReadingCoachingMessages) — so
  /// callers never need their own null check. Safe to call from any
  /// already-async/event-driven context (Timer callback, button tap,
  /// etc.) — NOT called during initState directly for this reason (see
  /// initState's own inline handling instead).
  void _showCoachingMessage(String? message, {Duration? autoDismissDuration}) {
    if (message == null) return;
    // ignore: avoid_print
    print('[TR] coaching message: "$message"');
    _coachingMessageTimer?.cancel();
    setState(() => _coachingMessage = message);
    _coachingMessageTimer = Timer(autoDismissDuration ?? const Duration(seconds: 3), () {
      if (mounted) setState(() => _coachingMessage = null);
    });
  }

  void _onSettingsTap() {
    _pause();
    _showResumeDialog();
  }

  void _showResumeDialog() {
    if (_dialogShowing) return;
    _dialogShowing = true;
    final isSinhala = _isSinhala;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isSinhala ? 'විරාමයක්' : 'Paused',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          isSinhala ? 'දිගටම කියවීමට සූදානම් වූ විට ඉදිරියට යන්න.' : 'Resume when you\'re ready to keep reading.',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _dialogShowing = false;
              _resume();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.timedReading,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isSinhala ? 'දිගටම කරගෙන යන්න' : 'Resume',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Button tap ────────────────────────────────────────────────────────

  void _onButtonTap() {
    if (_paused || _scoring) return;
    if (!_speechFlowAvailable) {
      _advanceManual();
      return;
    }
    if (_recording) return; // engine's own VAD/ceiling stops it, not a second tap
    _startRecording();
  }

  Future<void> _startRecording() async {
    setState(() {
      _retryNotice = null;
      _recording = true;
    });
    // _recordStartMs is captured synchronously, before the startRecording
    // await. For English it's purely a fallback reference (see
    // _stopAndCapture) — _speechStartMs (set by the VAD's onSpeechStart
    // callback, below) is the real source there, firing at the first
    // amplitude crossing. For Sinhala, VAD is no longer used at all (see
    // class doc / _onDoneTap), so _speechStartMs is never set and elapsed
    // always falls back to this tap-to-start timestamp by design.
    _recordStartMs = _stopwatch.elapsedMilliseconds;
    _speechStartMs = null;
    _firstPartialResultMs = null;
    _paceNudgeShownThisUnit = false;
    if (_isSinhala) {
      // Own independent recorder — never touches
      // GeminiSinhalaScorer/HybridPronunciationScorer at all.
      final path = await TimedReadingAudioRecorder.pathFor(
        sessionToken: _sessionAudioToken,
        unitIndex: _unitIndex,
      );
      await TimedReadingAudioRecorder.start(path: path);
    } else {
      await TimedReadingSpeechBridge.startRecording(
        lang: _langCode,
        onFirstPartialResult: () => _firstPartialResultMs ??= _stopwatch.elapsedMilliseconds,
      );
    }
    if (!mounted) return;
    // Safety ceiling only, for BOTH languages — the routine stop signal
    // is _onDoneTap (Sinhala) or the VAD (English) below.
    _autoStopTimer = Timer(_maxRecordingDuration, _stopAndCapture);
    if (_isSinhala) {
      // Sinhala: no VAD/amplitude auto-stop at all — child taps "Done
      // reading" (_onDoneTap) to stop. See TimedReadingVadMonitor's class
      // doc for why three amplitude-threshold tuning attempts were
      // abandoned in favor of this manual control.
      return;
    }
    _vad.start(
      () => _speechStartMs ??= _stopwatch.elapsedMilliseconds,
      _stopAndCapture,
    );
  }

  /// Sinhala-only manual stop — the child taps "Done reading" / "ඉවරයි"
  /// once finished. Calls the same _stopAndCapture used by English's VAD
  /// auto-stop and the safety-ceiling timer, so downstream scoring/
  /// timing/advance logic is identical; only the trigger differs.
  void _onDoneTap() {
    if (!_recording || _scoring) return;
    _stopAndCapture();
  }

  Future<void> _stopAndCapture() async {
    if (!_recording) return;
    _autoStopTimer?.cancel();
    _vad.stop();

    final unit = _sentences[_unitIndex];
    final finishedIndex = _unitIndex;

    if (_isSinhala) {
      // Sinhala: elapsed is purely Stopwatch-based (the "WAV duration" is
      // this Done-tap instant minus _recordStartMs) — no Gemini, no
      // network, nothing sits between recording-stop and this
      // calculation, so it's correct even fully offline. The recorder's
      // own .stop() (finalizing the temp WAV) happens right here too —
      // it's fast (local file I/O only, no network), so it's fine to
      // await before advancing.
      final path = await TimedReadingAudioRecorder.stop();
      if (!mounted) return;
      final finalCaptureMs = _stopwatch.elapsedMilliseconds;
      final elapsed = finalCaptureMs - _recordStartMs;
      _checkpointMs = finalCaptureMs;
      final stalled = elapsed > (unit.upperThresholdSec * 1000).round();
      final tooFast = elapsed < (unit.lowerThresholdSec * 1000).round();

      _session.unitTimings.add(UnitTiming(
        unitIndex: finishedIndex,
        elapsedMs: elapsed,
        stalled: stalled,
        tooFast: tooFast,
        audioFilePath: path,
      ));
      // ignore: avoid_print
      print('[TR] unit $finishedIndex done (sinhala)  elapsedMs=$elapsed  recordStartMs=$_recordStartMs  finalCaptureMs=$finalCaptureMs  expectedMs=${(unit.expectedTimeSec * 1000).round()}  stalled=$stalled  tooFast=$tooFast  audioFilePath=$path');

      setState(() => _recording = false);
      _advanceUnit(finishedIndex);
      return;
    }

    // ── English: UNCHANGED from before this redesign ──────────────────
    setState(() {
      _recording = false;
      _scoring = true;
    });
    int? recordingStoppedMs;
    final result = await TimedReadingSpeechBridge.stopAndGetTranscript(
      sentenceText: unit.text,
      lang: _langCode,
      gradeNum: _gradeNum,
      onRecordingStopped: () => recordingStoppedMs = _stopwatch.elapsedMilliseconds,
    );
    if (!mounted) return;

    if (result.noSpeech || result.noInternet) {
      // Do NOT count this as a valid attempt — no UnitTiming appended,
      // unit doesn't advance. Child re-taps to try the same sentence.
      // ignore: avoid_print
      print('[TR] unit $finishedIndex no valid speech (noSpeech=${result.noSpeech} noInternet=${result.noInternet}) — retry');
      setState(() {
        _scoring = false;
        _retryNotice = result.noInternet ? 'No internet — try again' : 'No speech heard — try again';
      });
      return;
    }

    final autoDetected = diffWords(expected: unit.text, transcribed: result.transcript!);
    final finalCaptureMs = _stopwatch.elapsedMilliseconds;
    // REVERTED (2026-08-27): tried preferring firstPartialResultMs (STT
    // recognition onset) here instead — live trace showed a consistent
    // ~2.2-2.8s gap between VAD onset and the STT engine's first partial
    // result, comparable to or larger than these short sentences' entire
    // elapsed time. That's the STT engine's own internal processing
    // latency, not the child's actual speech start — using it would have
    // silently swallowed a huge chunk of real reading time out of every
    // measurement instead of improving accuracy. Back to VAD onset
    // (amplitude-threshold, fires within ~100-140ms of tap in practice)
    // as the validated baseline. firstPartialResultMs is still captured
    // (see _startRecording) and available if this is revisited, just no
    // longer consulted here.
    final elapsed = finalCaptureMs - (_speechStartMs ?? _recordStartMs);
    _checkpointMs = finalCaptureMs;

    final stalled = elapsed > (unit.upperThresholdSec * 1000).round();
    final tooFast = elapsed < (unit.lowerThresholdSec * 1000).round();

    _session.unitTimings.add(UnitTiming(
      unitIndex: finishedIndex,
      elapsedMs: elapsed,
      stalled: stalled,
      tooFast: tooFast,
      autoDetectedMisreadIndexes: autoDetected,
    ));
    // ignore: avoid_print
    print('[TR] unit $finishedIndex done  elapsedMs=$elapsed  firstPartialResultMs=$_firstPartialResultMs  speechStartMs=$_speechStartMs  recordStartMs=$_recordStartMs  recordingStoppedMs=$recordingStoppedMs  finalCaptureMs=$finalCaptureMs  geminiRetryWaitMs=${result.geminiRetryWaitMs}  expectedMs=${(unit.expectedTimeSec * 1000).round()}  stalled=$stalled  tooFast=$tooFast  transcript="${result.transcript}"');

    setState(() => _scoring = false);
    _advanceUnit(finishedIndex);
  }

  void _advanceManual() {
    final unit = _sentences[_unitIndex];
    final finishedIndex = _unitIndex;
    final nowMs = _stopwatch.elapsedMilliseconds;
    final elapsed = nowMs - _checkpointMs;
    _checkpointMs = nowMs;
    final stalled = elapsed > (unit.upperThresholdSec * 1000).round();
    final tooFast = elapsed < (unit.lowerThresholdSec * 1000).round();

    _session.unitTimings.add(UnitTiming(
      unitIndex: finishedIndex,
      elapsedMs: elapsed,
      stalled: stalled,
      tooFast: tooFast,
    ));
    // ignore: avoid_print
    print('[TR] unit $finishedIndex done (manual)  elapsedMs=$elapsed  stalled=$stalled  tooFast=$tooFast');
    _advanceUnit(finishedIndex);
  }

  void _advanceUnit(int finishedIndex) {
    if (_listenPlaying) {
      // Don't let the outgoing sentence's reference audio keep playing
      // into the next unit.
      _audioPlayer.stop();
      _listenPlaying = false;
    }
    final isLastUnit = finishedIndex + 1 >= _sentences.length;
    if (isLastUnit) {
      _finish();
    } else {
      setState(() => _unitIndex++);
      _showCoachingMessage(TimedReadingCoachingMessages.nextUnit(_langCode));
    }
  }

  void _finish() {
    _stopwatch.stop();
    _uiTimer?.cancel();
    _session.endedAt = DateTime.now();
    // ignore: avoid_print
    print('[TR] ═══ READING FINISHED ═══  totalElapsedMs=${_session.totalElapsedMs}  interrupted=${_session.interrupted}  manualFallback=${_session.manualFallback}');

    // Session-complete coaching message, shown briefly BEFORE navigating
    // away (not shown at all — navigation is immediate, exactly as
    // before this feature — when the message is null, i.e. Sinhala
    // pending verified copy). _navigateToMiscueMarking's args are
    // unchanged either way; only the timing of the call differs.
    final message = TimedReadingCoachingMessages.sessionComplete(_langCode);
    if (message == null) {
      _navigateToMiscueMarking();
      return;
    }
    _showCoachingMessage(message, autoDismissDuration: const Duration(seconds: 2));
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      _navigateToMiscueMarking();
    });
  }

  void _navigateToMiscueMarking() {
    Navigator.pushReplacementNamed(
      context,
      AppRouter.timedReadingMiscue,
      arguments: MiscueMarkingArgs(
        sentences: _sentences,
        session: _session,
        attemptNumber: widget.args.attemptNumber,
        previousWpm: widget.args.previousWpm,
        isAssignedPractice: widget.args.level == 'assigned_practice',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSinhala = _isSinhala;
    final unit = _sentences[_unitIndex];
    final actualMs = _stopwatch.elapsedMilliseconds - (_recording || _scoring ? _recordStartMs : _checkpointMs);
    final listenAssetPath = sentenceAudioAssetPath(unit);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      // Flat brand-color AppBar, matching Pronunciation session screen's
      // header convention (pronunciation_session_screen.dart) instead of
      // the plain unstyled Row this screen used before. The sentence
      // counter that used to be a separate white pill is now the AppBar
      // title, same placement Pronunciation uses for its counter.
      appBar: AppBar(
        backgroundColor: AppColors.timedReading,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isSinhala
              ? 'වාක්‍යය ${_unitIndex + 1} / ${_sentences.length}'
              : 'Sentence ${_unitIndex + 1} / ${_sentences.length}',
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: isSinhala ? 'විරාමය' : 'Pause',
            icon: Icon(Icons.settings_rounded, color: _paused ? Colors.white38 : Colors.white),
            onPressed: _paused ? null : _onSettingsTap,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (!_speechFlowChecked) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2, color: AppColors.timedReading),
              ] else if (!_speechFlowAvailable) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSinhala
                        ? 'සිංහල හඬ පරීක්ෂාවට අන්තර්ජාලය අවශ්‍යයි — ඔබට තවමත් කියවා අතින් සලකුණු කළ හැක'
                        : 'Voice check unavailable — you can still read and mark manually',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.danger),
                  ),
                ),
              ],
              if (_retryNotice != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _retryNotice!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.danger),
                  ),
                ),
              ],
              // "Buddy Voice Coaching" text banner — non-blocking, reuses
              // this screen's own retryNotice Container pattern (teal
              // instead of danger tint, encouraging instead of warning).
              if (_coachingMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.timedReading.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.timedReading.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Text(
                    _coachingMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.timedReading),
                  ),
                ).animate().fadeIn(duration: 250.ms),
              ],
              const SizedBox(height: 16),

              // ── Content card ──
              Expanded(
                child: AnimatedOpacity(
                  opacity: _paused ? 0.3 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Reference "Listen" button — hidden entirely
                          // (not greyed/disabled) whenever this sentence
                          // has no matching asset, per the null-safe
                          // sentenceAudioAssetPath contract.
                          if (listenAssetPath != null) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: isSinhala ? 'අහන්න' : 'Listen',
                                onPressed: _paused ? null : () => _playReference(listenAssetPath),
                                icon: Icon(
                                  _listenPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                  color: AppColors.timedReading,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            unit.text,
                            key: ValueKey(_unitIndex),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.5),
                          ).animate(key: ValueKey('u$_unitIndex')).fadeIn().slideY(begin: 0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Tap-to-record / tap-to-advance button ──
              // Visually identical to Pronunciation's mic button
              // (120x120, green outline idle / filled+glow active,
              // mic_rounded/stop_rounded) per explicit instruction to
              // reuse it directly. EXCEPTION: Sinhala while _recording
              // swaps this circle for an explicit "Done reading" button
              // (same visual language as Miscue Marking's DONE button)
              // instead — no VAD/amplitude auto-stop, see
              // TimedReadingVadMonitor's class doc.
              if (isSinhala && _recording && !_scoring)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onDoneTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.timedReading,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'ඉවරයි',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: (_paused || _scoring) ? null : _onButtonTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _recording ? AppColors.timedReading : AppColors.primarySurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.timedReading, width: _recording ? 0 : 3),
                      boxShadow: _recording
                          ? [BoxShadow(color: AppColors.timedReading.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 4)]
                          : [],
                    ),
                    child: _scoring
                        ? const Center(child: CircularProgressIndicator(color: AppColors.timedReading))
                        : Icon(
                            _speechFlowAvailable
                                ? (_recording ? Icons.stop_rounded : Icons.mic_rounded)
                                : Icons.arrow_forward_rounded,
                            size: 42,
                            color: _recording ? Colors.white : AppColors.timedReading,
                          ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _scoring
                    ? (isSinhala ? 'පරීක්ෂා කරමින්...' : 'Checking...')
                    : (_recording
                        ? (isSinhala ? 'කියවා අවසන් වූ විට ඉවරයි ස්පර්ශ කරන්න' : 'Listening...')
                        : (_speechFlowAvailable
                            ? (isSinhala ? 'ස්පර්ශ කර හඬ නඟා කියවන්න' : 'Tap and read aloud')
                            : (isSinhala ? 'ඊළඟට යාමට ස්පර්ශ කරන්න' : 'Tap to continue'))),
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // ── EXPECTED / ACTUAL stat boxes ──
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: isSinhala ? 'අපේක්ෂිත' : 'EXPECTED',
                      value: _formatSec(unit.expectedTimeSec),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      label: isSinhala ? 'සැබෑ' : 'ACTUAL',
                      value: _formatMs(actualMs),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSec(double sec) {
    final ms = (sec * 1000).round();
    return _formatMs(ms);
  }

  String _formatMs(int ms) {
    if (ms < 0) ms = 0;
    final totalSec = ms ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textHint)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
