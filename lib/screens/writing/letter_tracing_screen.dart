import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/writing_data.dart';
import '../../models/app_colors.dart';
import '../../services/ble_command_service.dart';
import '../../services/writing_session_logger.dart';
import '../../widgets/buddy_feedback_overlay.dart';
import '../../widgets/tracing_canvas.dart';

class LetterTracingScreen extends StatefulWidget {
  final WritingArgs args;
  const LetterTracingScreen({super.key, required this.args});

  @override
  State<LetterTracingScreen> createState() => _LetterTracingScreenState();
}

class _LetterTracingScreenState extends State<LetterTracingScreen>
    with TickerProviderStateMixin {
  // ── Letter navigation ──────────────────────────────────────────────────────
  late final List<String> _letters;
  int _letterIndex = 0;

  // ── Attempt tracking ───────────────────────────────────────────────────────
  int _attemptCount = 0;
  int _totalXp = 0;
  double _accuracy = 0.0;
  DateTime _letterStartTime = DateTime.now();

  // ── UI state ───────────────────────────────────────────────────────────────
  bool _showOverlay = false;
  bool _overlayCorrect = false;
  bool _isThirdAttempt = false;
  bool _sessionSaved = false;

  // ── Canvas ─────────────────────────────────────────────────────────────────
  final _canvasKey = GlobalKey<TracingCanvasState>();

  // ── TTS ────────────────────────────────────────────────────────────────────
  late final FlutterTts _tts;
  bool _isSpeaking = false;

  // ── Buddy message animation ────────────────────────────────────────────────
  late final AnimationController _buddyCtrl;

  // ── Getters ────────────────────────────────────────────────────────────────
  String get _currentLetter => _letters[_letterIndex];
  List<List<Offset>> get _currentStrokes =>
      getLetterStrokes(_currentLetter, widget.args.isSinhala) ?? [];
  bool get _isSi => widget.args.isSinhala;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _letters = widget.args.levelLetters?.toList() ??
        getLetterList(widget.args.language);
    _tts = FlutterTts();
    _initTts();
    _buddyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  Future<void> _initTts() async {
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(_isSi ? 0.3 : 0.45);
    await _tts.setPitch(_isSi ? 0.9 : 1.0);
    await _tts.setLanguage(_isSi ? 'si-LK' : 'en-US');
    _tts.setCompletionHandler(() { if (mounted) setState(() => _isSpeaking = false); });
    _tts.setErrorHandler((_) { if (mounted) setState(() => _isSpeaking = false); });
  }

  @override
  void dispose() {
    _tts.stop();
    _buddyCtrl.dispose();
    super.dispose();
  }

  // ── Audio ──────────────────────────────────────────────────────────────────
  Future<void> _speak() async {
    if (_isSpeaking) { await _tts.stop(); setState(() => _isSpeaking = false); return; }
    setState(() => _isSpeaking = true);
    await _tts.speak(_currentLetter);
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void _onAccuracyChanged(double acc) {
    if (mounted) setState(() => _accuracy = acc);
  }

  void _onClear() {
    _canvasKey.currentState?.clearCanvas();
    setState(() { _accuracy = 0.0; _sessionSaved = false; });
  }

  void _onHint() => _canvasKey.currentState?.showHint();

  void _onDone() {
    if (_accuracy < 1.0 && _canvasKey.currentState?.accuracy == 0.0) {
      // Nothing drawn yet
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isSi ? 'පළමුව ලිවීම ආරම්භ කරන්න!' : 'Start tracing first!',
            style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.writing,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    _attemptCount++;
    final passed = _accuracy >= 70;

    if (passed && !_sessionSaved) {
      _sessionSaved = true;
      final xp = xpForAccuracy(_accuracy);
      _totalXp += xp;
      _saveSession(xp);
      BleCommandService.instance.send('GOOD_JOB');
    } else if (_attemptCount >= 3) {
      BleCommandService.instance.send('TRY_AGAIN');
    }

    setState(() {
      _overlayCorrect = passed;
      _isThirdAttempt = !passed && _attemptCount >= 3;
      _showOverlay = true;
    });
  }

  Future<void> _saveSession(int xp) async {
    final elapsedMs =
        DateTime.now().difference(_letterStartTime).inMilliseconds;
    await WritingSessionLogger.saveSession(
      profileId: widget.args.profileId,
      letter: _currentLetter,
      language: widget.args.language,
      grade: widget.args.grade,
      accuracy: _accuracy,
      xpEarned: xp,
      completionTimeMs: elapsedMs,
      attemptsToPass: _attemptCount,
    );
  }

  void _onOverlayDismiss() {
    setState(() => _showOverlay = false);
    if (_overlayCorrect) _advanceLetter();
  }

  void _onNext() {
    setState(() => _showOverlay = false);
    _advanceLetter();
  }

  void _advanceLetter() {
    if (_letterIndex < _letters.length - 1) {
      setState(() {
        _letterIndex++;
        _attemptCount = 0;
        _accuracy = 0.0;
        _sessionSaved = false;
        _letterStartTime = DateTime.now();
      });
      _canvasKey.currentState?.clearCanvas();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevLetter() {
    if (_letterIndex > 0) {
      setState(() {
        _letterIndex--;
        _attemptCount = 0;
        _accuracy = 0.0;
        _sessionSaved = false;
      });
      _canvasKey.currentState?.clearCanvas();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final letter = _currentLetter;
    final total = _letters.length;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.writing,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isSi
              ? 'අකුර ${_letterIndex + 1} / $total'
              : 'Letter ${_letterIndex + 1} of $total',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
        ),
        actions: [
          // XP
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(child: Text('⚡ $_totalXp XP',
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
          // Speaker
          IconButton(
            icon: Icon(_isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded, color: Colors.white),
            onPressed: _speak,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress dots
              _ProgressBar(current: _letterIndex + 1, total: total),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      // Main tracing card
                      _buildTracingCard(letter),

                      const SizedBox(height: 14),

                      // Action buttons
                      _buildButtons(),

                      const SizedBox(height: 14),

                      // Buddy feedback card
                      _BuddyMessageCard(
                        accuracy: _accuracy,
                        isSi: _isSi,
                        ctrl: _buddyCtrl,
                      ).animate().fadeIn(delay: 300.ms),
                    ],
                  ),
                ),
              ),

              // Prev / Next nav
              _LetterNav(
                onPrev: _letterIndex > 0 ? _prevLetter : null,
                onNext: _letterIndex < _letters.length - 1
                    ? () { _advanceLetter(); }
                    : null,
                isSi: _isSi,
              ),
            ],
          ),

          if (_showOverlay)
            BuddyFeedbackOverlay(
              isCorrect: _overlayCorrect,
              isThirdAttempt: _isThirdAttempt,
              xpGain: xpForAccuracy(_accuracy),
              revealAnswer: _isThirdAttempt ? _currentLetter : null,
              onDismiss: _overlayCorrect ? _onNext : _onOverlayDismiss,
              onNext: _onNext,
            ),
        ],
      ),
    );
  }

  Widget _buildTracingCard(String letter) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          // Letter label + accuracy
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Text(letter,
                    style: GoogleFonts.nunito(
                        fontSize: 52, fontWeight: FontWeight.w900, color: AppColors.writing)),
                const Spacer(),
                _AccuracyBadge(accuracy: _accuracy),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Canvas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                color: const Color(0xFFFCFAFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.writing.withOpacity(0.18), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: (_currentStrokes.isEmpty && !_isSi)
                    ? Center(child: Text(letter,
                        style: GoogleFonts.nunito(fontSize: 140, fontWeight: FontWeight.w900,
                            color: AppColors.writing.withOpacity(0.08))))
                    : TracingCanvas(
                        key: _canvasKey,
                        templateStrokes: _currentStrokes,
                        tolerance: 28.0,
                        onAccuracyChanged: _onAccuracyChanged,
                        letter: _isSi ? _currentLetter : null,
                        isSinhala: _isSi,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.15, curve: Curves.easeOut);
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.delete_outline_rounded,
            label: _isSi ? 'හිස් කරන්න' : 'Clear',
            color: Colors.white,
            textColor: AppColors.textPrimary,
            borderColor: AppColors.divider,
            onTap: _onClear,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.lightbulb_outline_rounded,
            label: _isSi ? 'ඉඟිය' : 'Hint',
            color: const Color(0xFFFFF3CD),
            textColor: const Color(0xFF856404),
            onTap: _onHint,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.check_circle_outline_rounded,
            label: _isSi ? 'හරි' : 'Done',
            color: AppColors.writing,
            textColor: Colors.white,
            onTap: _onDone,
          ),
        ),
      ],
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.writing,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: current / total),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (_, v, __) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: v,
            minHeight: 6,
            backgroundColor: Colors.white.withOpacity(0.25),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ),
    );
  }
}

// ── Accuracy badge ────────────────────────────────────────────────────────────

class _AccuracyBadge extends StatelessWidget {
  final double accuracy;
  const _AccuracyBadge({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (accuracy >= 70) color = AppColors.success;
    else if (accuracy >= 50) color = AppColors.almost;
    else color = accuracy > 0 ? AppColors.wrong : AppColors.textHint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        accuracy > 0 ? '${accuracy.round()}% ✓' : '- %',
        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

// ── Buddy message card ────────────────────────────────────────────────────────

class _BuddyMessageCard extends StatelessWidget {
  final double accuracy;
  final bool isSi;
  final AnimationController ctrl;
  const _BuddyMessageCard({required this.accuracy, required this.isSi, required this.ctrl});

  String get _message {
    if (accuracy == 0) return isSi ? '✏️ ලිවීම ආරම්භ කරන්න!' : '✏️ Start tracing!';
    if (accuracy >= 90) return isSi ? '⭐⭐⭐ විශිෂ්ටයි!' : '⭐⭐⭐ Perfect!';
    if (accuracy >= 70) return isSi ? '⭐⭐ හොඳයි! තව ලිවීමෙ!' : '⭐⭐ Great job! Keep going!';
    if (accuracy >= 50) return isSi ? '⭐ දිගටම කරගෙන යන්න!' : '⭐ Keep going! Almost there!';
    return isSi ? '💪 ලප රේඛා අනුගමනය කරන්න!' : '💪 Follow the dotted guide!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.writing.withOpacity(0.2)),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: ctrl,
            builder: (_, __) => Transform.rotate(
              angle: (ctrl.value - 0.5) * 0.15,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.writing.withOpacity(0.12), shape: BoxShape.circle),
                child: const Center(child: Text('🦉', style: TextStyle(fontSize: 24))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_message,
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ── Letter navigation ─────────────────────────────────────────────────────────

class _LetterNav extends StatelessWidget {
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool isSi;
  const _LetterNav({this.onPrev, this.onNext, required this.isSi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      color: Colors.white,
      child: Row(
        children: [
          _NavBtn(icon: Icons.arrow_back_rounded, label: isSi ? 'පෙර' : 'Prev', onTap: onPrev),
          const Spacer(),
          _NavBtn(icon: Icons.arrow_forward_rounded, label: isSi ? 'ඊළඟ' : 'Next', onTap: onNext, reversed: true),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool reversed;
  const _NavBtn({required this.icon, required this.label, this.onTap, this.reversed = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? AppColors.writing : AppColors.textHint;
    final children = [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
    ];
    return GestureDetector(
      onTap: onTap,
      child: Row(children: reversed ? children.reversed.toList() : children),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon, required this.label, required this.color,
    required this.textColor, required this.onTap, this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: borderColor != null ? Border.all(color: borderColor!, width: 1.5) : null,
          boxShadow: color == Colors.white ? null : [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 5),
              Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}
