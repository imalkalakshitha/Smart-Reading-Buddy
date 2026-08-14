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
import '../../services/timed_reading_speech_bridge.dart';
import '../../utils/word_diff.dart';

/// Core Timed Reading session screen. Button gesture/visuals deliberately
/// mirror pronunciation_session_screen.dart's mic button exactly (tap to
/// start, engine auto-stops via the same VAD pattern — NOT a hold
/// gesture, see the pre-coding investigation) for BOTH languages.
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
  String? _retryNotice; // transient bilingual "no speech, try again" banner
  int? _speechStartMs; // stopwatch reading at actual speech onset (VAD-detected), not at tap

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
      if (mounted) setState(() {});
    });
    // ignore: avoid_print
    print('[TR] ═══ READING START ═══');
    // ignore: avoid_print
    print('[TR] activity=${_session.activityId}  child=${_session.childKey}  units=${_sentences.length}');

    _checkSpeechFlow();
  }

  Future<void> _checkSpeechFlow() async {
    final available = _isSinhala
        ? await TimedReadingSpeechBridge.hasInternetForSinhala()
        : await TimedReadingSpeechBridge.checkEnglishSttAvailability();
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
      TimedReadingSpeechBridge.stopAndGetTranscript(
        sentenceText: _sentences[_unitIndex].text,
        lang: _langCode,
        gradeNum: _gradeNum,
      );
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
    // await, purely as a fallback reference (see _stopAndCapture) — it is
    // NOT the elapsed source anymore. _speechStartMs (set by the VAD's
    // onSpeechStart callback, below) is the real source: it fires at the
    // first amplitude crossing, i.e. actual speech onset, excluding both
    // mic-init latency and the child's pre-speech thinking time.
    _recordStartMs = _stopwatch.elapsedMilliseconds;
    _speechStartMs = null;
    await TimedReadingSpeechBridge.startRecording(lang: _langCode);
    if (!mounted) return;
    _autoStopTimer = Timer(_maxRecordingDuration, _stopAndCapture);
    _vad.start(
      () => _speechStartMs ??= _stopwatch.elapsedMilliseconds,
      _stopAndCapture,
    );
  }

  Future<void> _stopAndCapture() async {
    if (!_recording) return;
    _autoStopTimer?.cancel();
    _vad.stop();
    setState(() {
      _recording = false;
      _scoring = true;
    });

    final unit = _sentences[_unitIndex];
    final finishedIndex = _unitIndex;
    final result = await TimedReadingSpeechBridge.stopAndGetTranscript(
      sentenceText: unit.text,
      lang: _langCode,
      gradeNum: _gradeNum,
    );
    if (!mounted) return;

    if (result.noSpeech || result.noInternet) {
      // Do NOT count this as a valid attempt — no UnitTiming appended,
      // unit doesn't advance. Child re-taps to try the same sentence.
      // ignore: avoid_print
      print('[TR] unit $finishedIndex no valid speech (noSpeech=${result.noSpeech} noInternet=${result.noInternet}) — retry');
      setState(() {
        _scoring = false;
        _retryNotice = result.noInternet
            ? (_isSinhala ? 'අන්තර්ජාල සම්බන්ධතාවයක් නැත — නැවත උත්සාහ කරන්න' : 'No internet — try again')
            : (_isSinhala ? 'හඬක් ඇසුනේ නැත — නැවත උත්සාහ කරන්න' : 'No speech heard — try again');
      });
      return;
    }

    final autoDetected = diffWords(expected: unit.text, transcribed: result.transcript!);
    // Final capture AFTER the await, so engine/network latency correctly
    // extends the recorded elapsed rather than being measured from a
    // stale pre-await timestamp.
    final finalCaptureMs = _stopwatch.elapsedMilliseconds;
    // Elapsed from actual speech onset, not from the tap — falls back to
    // _recordStartMs only in the edge case where content was transcribed
    // despite the VAD never reporting a crossing (e.g. threshold missed
    // a very quiet/fast utterance); that fallback re-introduces the old
    // bug's prep-time inflation for that one edge case, but never
    // produces a negative/nonsensical elapsed.
    final elapsed = finalCaptureMs - (_speechStartMs ?? _recordStartMs);
    _checkpointMs = finalCaptureMs;

    final stalled = elapsed > (unit.upperThresholdSec * 1000).round();

    _session.unitTimings.add(UnitTiming(
      unitIndex: finishedIndex,
      elapsedMs: elapsed,
      stalled: stalled,
      autoDetectedMisreadIndexes: autoDetected,
    ));
    // ignore: avoid_print
    print('[TR] unit $finishedIndex done  elapsedMs=$elapsed  speechStartMs=$_speechStartMs  recordStartMs=$_recordStartMs  finalCaptureMs=$finalCaptureMs  expectedMs=${(unit.expectedTimeSec * 1000).round()}  stalled=$stalled  transcript="${result.transcript}"');

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

    _session.unitTimings.add(UnitTiming(
      unitIndex: finishedIndex,
      elapsedMs: elapsed,
      stalled: stalled,
    ));
    // ignore: avoid_print
    print('[TR] unit $finishedIndex done (manual)  elapsedMs=$elapsed  stalled=$stalled');
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
    }
  }

  void _finish() {
    _stopwatch.stop();
    _uiTimer?.cancel();
    _session.endedAt = DateTime.now();
    // ignore: avoid_print
    print('[TR] ═══ READING FINISHED ═══  totalElapsedMs=${_session.totalElapsedMs}  interrupted=${_session.interrupted}  manualFallback=${_session.manualFallback}');

    Navigator.pushReplacementNamed(
      context,
      AppRouter.timedReadingMiscue,
      arguments: MiscueMarkingArgs(
        sentences: _sentences,
        session: _session,
        attemptNumber: widget.args.attemptNumber,
        previousWpm: widget.args.previousWpm,
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Top bar ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Text(
                      isSinhala
                          ? 'වාක්‍යය ${_unitIndex + 1} / ${_sentences.length}'
                          : 'Sentence ${_unitIndex + 1} / ${_sentences.length}',
                      style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    tooltip: isSinhala ? 'විරාමය' : 'Pause',
                    icon: Icon(Icons.settings_rounded, color: _paused ? AppColors.textHint : AppColors.textPrimary),
                    onPressed: _paused ? null : _onSettingsTap,
                  ),
                ],
              ),
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
              // reuse it directly, for BOTH languages.
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
                        ? (isSinhala ? 'අහගෙන ඉන්නවා...' : 'Listening...')
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
