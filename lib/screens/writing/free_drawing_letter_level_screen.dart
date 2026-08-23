import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dao/free_drawing_dao.dart';
import '../../data/free_drawing_cues.dart';
import '../../data/free_drawing_stroke_paths.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../services/character_model_service.dart';
import '../../services/free_drawing_debug_config.dart';
import '../../services/free_drawing_recognizer.dart';
import '../../widgets/free_drawing_canvas.dart';
import '../../widgets/mascot_reaction.dart';
import '../../widgets/stroke_order_animation.dart';

const Color _kWarmBg = Color(0xFFFFF9F0);
const List<Color> _kLetterColors = [
  Color(0xFFFF6B6B),
  Color(0xFFFFA94D),
  Color(0xFFFFD43B),
  Color(0xFF69DB7C),
  Color(0xFF4DD4C0),
  Color(0xFF4DABF7),
  Color(0xFF9775FA),
  Color(0xFFF783AC),
];

/// Letter Level: one target character at a time, picked by the child from
/// the Letter Picker. Three steps: intro (character/cue/stroke
/// animation/audio), draw (blank canvas + ghost hint), result
/// (accept/retry, never revealing the model's guess).
class FreeDrawingLetterLevelScreen extends StatefulWidget {
  final String initialTarget;
  const FreeDrawingLetterLevelScreen({super.key, required this.initialTarget});

  @override
  State<FreeDrawingLetterLevelScreen> createState() => _FreeDrawingLetterLevelScreenState();
}

enum _LetterStep { loading, intro, draw, result }

const int _kMaxAttemptsBeforeOffer = 3;

class _FreeDrawingLetterLevelScreenState extends State<FreeDrawingLetterLevelScreen> {
  _LetterStep _step = _LetterStep.loading;
  List<String> _targets = [];
  int _targetIndex = 0;
  int _failedAttempts = 0;
  bool _isChecking = false;
  String? _drawHint; // "Let's draw something first!" — inline, cleared on next attempt

  TargetEvaluation? _lastEvaluation;

  final GlobalKey<StrokeOrderAnimationState> _animationKey = GlobalKey();
  final GlobalKey<FreeDrawingCanvasState> _canvasKey = GlobalKey();
  late final FlutterTts _tts;
  bool _ttsReady = false;

  bool get _isSinhala => AppState.language == 'sinhala';
  String get _currentTarget => _targets[_targetIndex];
  Color get _currentColor => _kLetterColors[_targetIndex % _kLetterColors.length];

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _initTts();
    _loadTargets();
  }

  Future<void> _initTts() async {
    await _tts.setVolume(1.0);
    if (_isSinhala) {
      await _tts.setLanguage('si-LK');
      await _tts.setSpeechRate(0.3);
      await _tts.setPitch(0.9);
    } else {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.38);
      await _tts.setPitch(1.0);
    }
    _ttsReady = true;
  }

  Future<void> _loadTargets() async {
    await CharacterModelService.instance.load();
    final classNames = CharacterModelService.instance.classNames;
    final start = _isSinhala ? FreeDrawingRecognizer.siStart : FreeDrawingRecognizer.enStart;
    final end = _isSinhala ? FreeDrawingRecognizer.siEnd : FreeDrawingRecognizer.enEnd;
    final targets = [for (int i = start; i <= end; i++) classNames[i]];
    if (!mounted) return;
    final initialIndex = targets.indexOf(widget.initialTarget);
    setState(() {
      _targets = targets;
      _targetIndex = initialIndex >= 0 ? initialIndex : 0;
      _step = _LetterStep.intro;
    });
    _playSound();
  }

  Future<void> _playSound() async {
    if (!_ttsReady) return;
    await _tts.speak(_currentTarget);
  }

  void _replay() {
    _animationKey.currentState?.replay();
    _playSound();
  }

  void _myTurn() {
    setState(() {
      _step = _LetterStep.draw;
      _drawHint = null;
    });
  }

  Future<void> _check() async {
    final canvas = _canvasKey.currentState;
    if (canvas == null) return;

    if (!canvas.hasInk) {
      setState(() => _drawHint = "Let's draw something first!");
      return;
    }

    setState(() {
      _isChecking = true;
      _drawHint = null;
    });

    try {
      final pngBytes = await canvas.capturePng();
      final evaluation = await FreeDrawingRecognizer.evaluateAgainstTarget(
        pngBytes: pngBytes,
        isSinhala: _isSinhala,
        strokePoints: canvas.strokePoints,
        target: _currentTarget,
      );

      if (!mounted) return;

      if (evaluation == null) {
        setState(() {
          _isChecking = false;
          _drawHint = "Let's draw something first!";
        });
        return;
      }

      final language = _isSinhala ? 'si' : 'en';
      final attemptNumber = await FreeDrawingDao.nextAttemptNumber(
        profileName: AppState.name,
        levelType: 'letter',
        targetCharacter: _currentTarget,
      );
      await FreeDrawingDao.saveAttempt(
        profileName: AppState.name,
        levelType: 'letter',
        language: language,
        targetCharacter: _currentTarget,
        top1Prediction: evaluation.rawTop1Character,
        top1Confidence: evaluation.rawTop1Confidence,
        pTarget: evaluation.pTarget,
        targetRank: evaluation.targetRank,
        accepted: evaluation.accepted,
        attemptNumber: attemptNumber,
      );

      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _lastEvaluation = evaluation;
        _failedAttempts = evaluation.accepted ? 0 : _failedAttempts + 1;
        _step = _LetterStep.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _drawHint = "Let's try again!";
      });
    }
  }

  void _tryAgain() {
    _canvasKey.currentState?.clear();
    setState(() => _step = _LetterStep.draw);
  }

  void _replayFromResult() {
    setState(() => _step = _LetterStep.intro);
    _animationKey.currentState?.replay();
    _playSound();
  }

  void _nextCharacter() {
    setState(() {
      _targetIndex = (_targetIndex + 1) % _targets.length;
      _failedAttempts = 0;
      _lastEvaluation = null;
      _step = _LetterStep.intro;
    });
    _playSound();
  }

  void _backToLetters() => Navigator.of(context).pop();

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kWarmBg,
      appBar: AppBar(
        backgroundColor: _step == _LetterStep.loading ? AppColors.writing : _currentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Letter Time!'),
      ),
      body: SafeArea(
        child: switch (_step) {
          _LetterStep.loading => const Center(child: CircularProgressIndicator()),
          _LetterStep.intro => _buildIntro(context),
          _LetterStep.draw => _buildDraw(context),
          _LetterStep.result => _buildResult(context),
        },
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final cue = cueFor(_currentTarget);
    final strokes = getFreeDrawingStrokes(_currentTarget, isSinhala: _isSinhala);
    final color = _currentColor;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                Text(
                  _currentTarget,
                  style: GoogleFonts.nunito(fontSize: 88, fontWeight: FontWeight.w900, color: Colors.white),
                ).animate(key: ValueKey(_currentTarget)).scale(duration: 400.ms, curve: Curves.elasticOut).fadeIn(),
                if (cue != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${cue.emoji}  ${cue.word}',
                    style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (strokes != null && strokes.isNotEmpty)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 3),
                ),
                child: StrokeOrderAnimation(key: _animationKey, strokes: strokes, color: color),
              ),
            )
          else
            const Spacer(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _replay,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Replay'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _myTurn,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('My Turn!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    textStyle: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDraw(BuildContext context) {
    final color = _currentColor;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Draw the letter $_currentTarget',
            style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: color.withValues(alpha: 0.35), width: 3),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: FreeDrawingCanvas(key: _canvasKey),
              ),
            ),
          ),
          if (_drawHint != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _drawHint!,
                style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ).animate().shake(hz: 4, duration: 400.ms),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isChecking ? null : () => _canvasKey.currentState?.clear(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _check,
                  icon: _isChecking
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_rounded),
                  label: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Check'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    textStyle: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final accepted = _lastEvaluation?.accepted ?? false;
    final offerHelp = !accepted && _failedAttempts >= _kMaxAttemptsBeforeOffer;
    final color = _currentColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MascotReaction(color: color, happy: accepted, size: 120),
            const SizedBox(height: 18),
            Text(
              accepted ? 'Great job!' : "Let's try again!",
              style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ).animate().fadeIn(delay: 150.ms),
            if (kShowFreeDrawingDebugInfo && _lastEvaluation != null) ...[
              const SizedBox(height: 20),
              _DebugInfoPanel(evaluation: _lastEvaluation!, target: _currentTarget),
            ],
            const SizedBox(height: 30),
            if (accepted) ...[
              ElevatedButton.icon(
                onPressed: _nextCharacter,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Next Letter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  textStyle: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _backToLetters,
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Back to Letters'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _tryAgain,
                icon: const Icon(Icons.brush_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  textStyle: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (offerHelp) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _replayFromResult,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Watch it again'),
                  style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color, width: 2)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _nextCharacter,
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.nunito(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Dev-only — see kShowFreeDrawingDebugInfo. Never shown to the child in
/// a real build.
class _DebugInfoPanel extends StatelessWidget {
  final TargetEvaluation evaluation;
  final String target;
  const _DebugInfoPanel({required this.evaluation, required this.target});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEBUG (dev-only overlay)', style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w700)),
          Text('target: $target', style: GoogleFonts.robotoMono(fontSize: 12)),
          Text('p_target: ${(evaluation.pTarget * 100).toStringAsFixed(1)}%', style: GoogleFonts.robotoMono(fontSize: 12)),
          Text('target rank: ${evaluation.targetRank}', style: GoogleFonts.robotoMono(fontSize: 12)),
          Text('raw top-1: ${evaluation.rawTop1Character} (${(evaluation.rawTop1Confidence * 100).toStringAsFixed(1)}%)',
              style: GoogleFonts.robotoMono(fontSize: 12)),
          Text('accepted: ${evaluation.accepted}', style: GoogleFonts.robotoMono(fontSize: 12)),
        ],
      ),
    );
  }
}
