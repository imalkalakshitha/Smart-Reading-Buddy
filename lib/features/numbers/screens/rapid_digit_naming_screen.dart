import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/dao/number_practice_dao.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_answer_checker.dart';
import 'package:smart_reading_buddy/features/numbers/services/numbers_buddy.dart';
import 'package:smart_reading_buddy/features/numbers/services/ran_row_listener.dart';
import 'package:smart_reading_buddy/features/numbers/services/ran_row_tracker.dart';
import 'package:smart_reading_buddy/core/services/speech/timed_reading_speech_bridge.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart' show LearningColors;
import 'package:smart_reading_buddy/features/numbers/screens/numbers_hub_screen.dart' show EnglishOnlyNote;

class _RowResult {
  final DigitAlignment alignment;
  final int elapsedMs;
  final String transcript;

  const _RowResult(this.alignment, this.elapsedMs, this.transcript);
}

/// Rapid Digit Naming (RAN) — ENGLISH ONLY. A 5×10 grid of digits 1–9, no
/// digit next to the same digit (left/right, across the row break, or
/// above/below).
///
/// Recorded one row at a time by RanRowListener: speech_to_text in
/// dictation mode, restarted immediately (transcript appended) whenever
/// Android ends the session early. A row ends on its own — after ~2 s of
/// silence once a digit was heard, or when all 10 digits are recognised —
/// so the child doesn't need to tap Done (it's still there as a fallback).
/// Each row's time runs from the first partial result to the last
/// recognised speech (the silence wait isn't counted); the total is their
/// sum. Digits are only marked once the row has ended.
class RapidDigitNamingScreen extends StatefulWidget {
  const RapidDigitNamingScreen({super.key});

  @override
  State<RapidDigitNamingScreen> createState() => _RapidDigitNamingScreenState();
}

enum _Phase { checking, unavailable, ready, getReady, recording, scoring, finished }

class _RapidDigitNamingScreenState extends State<RapidDigitNamingScreen> {
  static const int _rows = 5;
  static const int _cols = 10;
  // Backstop only — rows normally end on silence or once all 10 digits
  // are heard.
  static const _maxRowDuration = Duration(seconds: 40);

  late List<List<int>> _grid;
  final List<_RowResult> _results = [];
  int _row = 0;
  _Phase _phase = _Phase.checking;
  String? _notice;

  // Smart Buddy: LOUDER when a row heard nothing, PRAISE when a row is
  // finished, one SESSION_END (instead of PRAISE) when all 5 rows are done.
  // Never while the mic listens; after a reaction the next row's mic waits
  // ~2 s ("Get ready…"). RAN has no app voice.
  final _buddy = NumbersBuddy.instance;
  final _micOn = ValueNotifier<bool>(false);

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer;
  Timer? _maxRowTimer;
  RanRowTracker? _tracker;
  RanRowListener? _listener;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _buddy.attach(this, mic: _micOn);
    _grid = _generateGrid();
    _checkStt();
  }

  @override
  void dispose() {
    _buddy.detach(this);
    _micOn.dispose();
    _uiTimer?.cancel();
    _maxRowTimer?.cancel();
    _listener?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _checkStt() async {
    final ok = await TimedReadingSpeechBridge.checkEnglishSttAvailability();
    if (!mounted) return;
    setState(() => _phase = ok ? _Phase.ready : _Phase.unavailable);
  }

  static List<List<int>> _generateGrid() {
    final rng = Random();
    final grid = List.generate(_rows, (_) => List.filled(_cols, 0));
    int? prev;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final above = r > 0 ? grid[r - 1][c] : null;
        final options = [
          for (var d = 1; d <= 9; d++)
            if (d != prev && d != above) d,
        ];
        final d = options[rng.nextInt(options.length)];
        grid[r][c] = d;
        prev = d;
      }
    }
    return grid;
  }

  int get _totalMs => _results.fold(0, (sum, r) => sum + r.elapsedMs);
  int get _totalCorrect => _results.fold(0, (sum, r) => sum + r.alignment.correct);
  int get _totalErrors => _results.fold(0, (sum, r) => sum + r.alignment.errors);

  /// Live clock: finished rows plus the current row since speech began.
  int get _displayMs {
    if (_phase != _Phase.recording) return _totalMs;
    final start = _tracker?.firstPartialMs;
    if (start == null) return _totalMs;
    return _totalMs + (_stopwatch.elapsedMilliseconds - start);
  }

  Future<void> _startRow() async {
    if (_phase != _Phase.ready) return;
    // A buddy reaction was sent moments ago — let its clip finish before
    // listening, so it isn't transcribed. The button says "Get ready…".
    final wait = _buddy.micClearance();
    if (wait > Duration.zero) {
      setState(() => _phase = _Phase.getReady);
      await Future.delayed(wait);
      if (!mounted || _phase != _Phase.getReady) return;
    }
    if (!_stopwatch.isRunning) _stopwatch.start();
    final tracker = RanRowTracker(expectedCount: _cols);
    final listener = RanRowListener(
      tracker: tracker,
      now: () => _stopwatch.elapsedMilliseconds,
      onChanged: () {
        if (mounted) setState(() {});
      },
      onEnded: _onRowEnded,
    );
    setState(() {
      _phase = _Phase.recording;
      _notice = null;
      _tracker = tracker;
      _listener = listener;
    });
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
    _maxRowTimer?.cancel();
    _maxRowTimer = Timer(_maxRowDuration, () => listener.stop(RanRowEnd.timeout));
    _micOn.value = true;
    await listener.start();
  }

  /// Optional Done tap — rows normally end by themselves.
  void _doneTapped() {
    if (_phase != _Phase.recording) return;
    setState(() => _phase = _Phase.scoring);
    _listener?.stop(RanRowEnd.manual);
  }

  void _onRowEnded(RanRowEnd reason) {
    // The listener has stopped the mic (incl. its final-text grace).
    _micOn.value = false;
    _maxRowTimer?.cancel();
    _uiTimer?.cancel();
    if (!mounted) return;
    final tracker = _tracker!;
    final expected = _grid[_row];
    final heard = tracker.digits;

    if (heard.isEmpty) {
      setState(() {
        _phase = _Phase.ready;
        _notice = "We couldn't hear you — let's try this row again! 🎤";
      });
      _buddy.react(BuddyReaction.louder);
      return;
    }

    final alignment = NumberAnswerChecker.alignDigits(expected, heard);
    final elapsed = tracker.elapsedMs;
    // ignore: avoid_print
    print('[RAN] row=${_row + 1} end=${reason.name} expected=${expected.join()} heard=${heard.join()} '
        'correct=${alignment.correct} errors=${alignment.errors} elapsedMs=$elapsed '
        'restarts=${_listener?.restarts} transcript="${tracker.transcript}"');

    setState(() {
      _results.add(_RowResult(alignment, elapsed, tracker.transcript));
      if (_row < _rows - 1) {
        _row++;
        _phase = _Phase.ready;
      } else {
        _phase = _Phase.finished;
        _stopwatch.stop();
      }
    });
    if (_phase == _Phase.finished) {
      _save();
      _buddy.sessionEnded(passed: true); // whole RAN done → one SESSION_END
    } else {
      _buddy.react(BuddyReaction.praise); // a row finished
    }
  }

  void _save() {
    if (_saved) return;
    _saved = true;
    NumberPracticeDao.saveRapidDigitNaming(
      profileName: AppState.name,
      grid: _grid.map((r) => r.join()).join('/'),
      recognizedText: _results.map((r) => r.transcript).join(' / '),
      score: _totalCorrect / (_rows * _cols),
      totalMs: _totalMs,
      digitsCorrect: _totalCorrect,
      errorCount: _totalErrors,
    ).catchError((Object e) => debugPrint('[RAN] save failed: $e'));
  }

  void _restart() {
    _stopwatch
      ..stop()
      ..reset();
    setState(() {
      _grid = _generateGrid();
      _results.clear();
      _row = 0;
      _saved = false;
      _notice = null;
      _phase = _Phase.ready;
    });
  }

  String _fmt(int ms) => '${(ms / 1000).toStringAsFixed(1)}s';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pronunciation,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Rapid Digit Naming',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.checking => const Center(
              child: CircularProgressIndicator(color: AppColors.pronunciation),
            ),
          _Phase.unavailable => _buildUnavailable(),
          _Phase.finished => _buildSummary(),
          _ => _buildGame(),
        },
      ),
    );
  }

  Widget _buildUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎙️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              "Speech recognition isn't available on this device.",
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    final recording = _phase == _Phase.recording;
    final scoring = _phase == _Phase.scoring;
    final gettingReady = _phase == _Phase.getReady;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (AppState.language == 'sinhala') ...[
            const EnglishOnlyNote(),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Row ${_row + 1} of $_rows',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Text(
                  '⏱ ${_fmt(_displayMs)}',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [for (var r = 0; r < _rows; r++) _buildGridRow(r)],
            ),
          ),
          const SizedBox(height: 14),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _notice != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _notice!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Text(
            recording
                ? "Read the row out loud — I'll stop listening when you finish."
                : (_row == 0 && _results.isEmpty
                    ? 'Read each number as fast as you can. Ready?'
                    : 'Great! Tap to read the next row.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: recording ? _doneTapped : (scoring || gettingReady ? null : _startRow),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: recording ? AppColors.pronunciation : AppColors.primarySurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.pronunciation, width: recording ? 0 : 3),
                boxShadow: recording
                    ? [
                        BoxShadow(
                          color: AppColors.pronunciation.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: scoring
                  ? const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.pronunciation,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          gettingReady
                              ? Icons.hourglass_top_rounded
                              : (recording ? Icons.hearing_rounded : Icons.mic_rounded),
                          size: 42,
                          color: recording ? Colors.white : AppColors.pronunciation,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gettingReady
                              ? 'Get ready…'
                              : (recording ? 'Listening…' : (_results.isEmpty ? 'Start' : 'Next row')),
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: recording ? Colors.white : AppColors.pronunciation,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGridRow(int r) {
    final isCurrent = r == _row && _phase != _Phase.finished;
    final done = r < _results.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? AppColors.pronunciation : Colors.transparent,
          width: 2,
        ),
      ),
      // One small box per digit with clear gaps, so a row doesn't read as
      // one long number. Marking (green / soft orange) only once the row
      // has ended — never while the child is still reading.
      child: Row(
        children: [
          for (var c = 0; c < _cols; c++) Expanded(child: _digitBox(r, c, isCurrent: isCurrent, done: done)),
        ],
      ),
    );
  }

  Widget _digitBox(int r, int c, {required bool isCurrent, required bool done}) {
    final correct = done && _results[r].alignment.correctAt[c];
    final (Color bg, Color border) = done
        ? (correct
            ? (LearningColors.correctSurface, LearningColors.correct)
            : (LearningColors.wrongFill, LearningColors.wrongBorder))
        : (isCurrent ? (Colors.white, AppColors.primaryLight) : (const Color(0xFFF7F8F7), AppColors.divider));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: done || isCurrent ? 1.5 : 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${_grid[r][c]}',
          style: GoogleFonts.nunito(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: (isCurrent || done) ? AppColors.textPrimary : AppColors.textSecondary.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    const total = _rows * _cols;
    final accuracy = _totalCorrect / total;
    final stars = accuracy >= 0.9 ? 3 : (accuracy >= 0.7 ? 2 : 1);
    final perSecond = _totalMs > 0 ? _totalCorrect / (_totalMs / 1000) : 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(stars == 3 ? '🚀' : '⚡', style: const TextStyle(fontSize: 80))
              .animate()
              .scale(begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack),
          const SizedBox(height: 8),
          Text(
            stars == 3 ? 'Super speedy!' : 'Well done!',
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Icon(
                i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                color: i < stars ? Colors.amber : Colors.grey.shade300,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _stat('Total time', _fmt(_totalMs)),
          _stat('Digits correct', '$_totalCorrect / $total'),
          _stat('Mistakes', '$_totalErrors'),
          _stat('Digits per second', perSecond.toStringAsFixed(1)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _restart,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.pronunciation,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Play again 🔁',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.reading,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Back to Numbers',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
