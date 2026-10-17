import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../dao/number_learning_dao.dart';
import '../../../models/app_colors.dart';
import '../../../models/app_state.dart';
import '../../../services/numbers/answer_checker.dart';
import '../../../services/numbers/level_config.dart';
import '../../../services/numbers/level_progress.dart';
import '../../../services/numbers/number_question.dart';
import '../../../services/numbers/question_generator.dart';
import 'activities/build_activity.dart';
import 'activities/calculation_activity.dart';
import 'activities/counting_activity.dart';
import 'activities/formation_activity.dart';
import 'activities/ordering_activity.dart';
import 'activities/pattern_activity.dart';
import 'activities/place_value_activity.dart';
import 'activities/recognition_activity.dart';
import 'learning_widgets.dart';

enum _Feedback { none, correct, tryAgain, step, revealed }

/// One Number Learning session: 10 generated questions for [level].
///
/// Scoring: a question earns its point only when answered correctly on the
/// first try. A wrong answer gets a soft "Let's try again!"; after
/// [_maxTries] wrong answers the answer is shown gently and the session moves on. Each
/// question is saved when it resolves (NumberLearningDao).
class NumberLearningSessionScreen extends StatefulWidget {
  final LevelConfig level;

  const NumberLearningSessionScreen({super.key, required this.level});

  @override
  State<NumberLearningSessionScreen> createState() => _NumberLearningSessionScreenState();
}

class _NumberLearningSessionScreenState extends State<NumberLearningSessionScreen> {
  static const _maxTries = 3;

  final _speaker = NumberSpeaker();
  final _sessionId = const Uuid().v4();

  List<NumberQuestion>? _questions;
  String? _error;
  int _index = 0;
  int _tries = 0; // all submissions this question (saved as attempts)
  int _wrongs = 0;
  int _score = 0;
  _Feedback _feedback = _Feedback.none;
  DateTime _questionStart = DateTime.now();
  Timer? _advanceTimer;
  bool _finished = false;

  NumberQuestion get _q => _questions![_index];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _speaker.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final avoid = await NumberLearningDao.recentQuestionKeys(AppState.name, widget.level.id);
      final questions = QuestionGenerator().generateSession(
        widget.level,
        count: LevelProgressRules.questionsPerSession,
        avoidKeys: avoid,
      );
      if (!mounted) return;
      setState(() => _questions = questions);
      _startQuestion();
    } catch (e) {
      debugPrint('[NumberLearning] could not start ${widget.level.id}: $e');
      if (mounted) setState(() => _error = "Oops! This level couldn't start.");
    }
  }

  void _startQuestion() {
    setState(() {
      _tries = 0;
      _wrongs = 0;
      _feedback = _Feedback.none;
      _questionStart = DateTime.now();
    });
    _speaker.say(_q.speech);
  }

  bool _onSubmit(Object response) {
    if (_feedback == _Feedback.correct || _feedback == _Feedback.revealed) return false;
    final result = NumberAnswerCheck.evaluate(_q, response);
    _tries++;
    switch (result) {
      case AnswerResult.stepDone:
        // First step of a two-step question (find, then colour) — no
        // point yet, and it doesn't count against the child.
        setState(() => _feedback = _Feedback.step);
        _speaker.say(_q.followUpSpeech ?? 'Great!');
        return true;
      case AnswerResult.correct:
        // The point needs every step right first time (no wrong answers).
        final point = _wrongs == 0 ? 1 : 0;
        _score += point;
        _save(correct: true, score: point);
        setState(() => _feedback = _Feedback.correct);
        _speaker.say('Great job!');
        _advanceTimer = Timer(const Duration(milliseconds: 1500), _next);
        return true;
      case AnswerResult.wrong:
        _wrongs++;
        if (_wrongs < _maxTries) {
          setState(() => _feedback = _Feedback.tryAgain);
          _speaker.say("Let's try again!");
        } else {
          _save(correct: false, score: 0);
          setState(() => _feedback = _Feedback.revealed);
          _speaker.say('The answer is ${NumberAnswerCheck.answerText(_q)}');
        }
        return false;
    }
  }

  /// Replay: the follow-up instruction once a question is on its second step.
  void _replay() {
    final follow = _q.followUpSpeech;
    _speaker.say(_feedback == _Feedback.step && follow != null ? follow : _q.speech);
  }

  void _save({required bool correct, required int score}) {
    NumberLearningDao.saveAttempt(
      profileName: AppState.name,
      sessionId: _sessionId,
      level: widget.level,
      questionIndex: _index,
      questionKey: _q.key,
      correct: correct,
      attempts: _tries,
      timeMs: DateTime.now().difference(_questionStart).inMilliseconds,
      score: score,
    ).catchError((Object e) => debugPrint('[NumberLearning] save failed: $e'));
  }

  void _next() {
    _advanceTimer?.cancel();
    if (!mounted) return;
    if (_index >= _questions!.length - 1) {
      setState(() => _finished = true);
      _speaker.say(_score >= LevelProgressRules.passScore ? 'Well done! Level passed!' : 'Well done!');
      return;
    }
    setState(() => _index++);
    _startQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: LearningColors.accent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          widget.level.title,
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700)),
      );
    }
    if (_questions == null) {
      return const Center(child: CircularProgressIndicator(color: LearningColors.accent));
    }
    if (_finished) return _summary();

    final total = _questions!.length;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (_index + 1) / total,
                          minHeight: 10,
                          backgroundColor: AppColors.divider,
                          valueColor: const AlwaysStoppedAnimation(LearningColors.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_index + 1} / $total',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                InstructionBar(prompt: _q.prompt, onReplay: _replay),
                const SizedBox(height: 28),
                KeyedSubtree(
                  key: ValueKey(_index),
                  child: _activity(_q),
                ).animate(key: ValueKey('a$_index')).fadeIn(duration: 250.ms),
              ],
            ),
          ),
        ),
        _feedbackBar(),
      ],
    );
  }

  Widget _activity(NumberQuestion q) {
    final enabled = _feedback == _Feedback.none ||
        _feedback == _Feedback.tryAgain ||
        _feedback == _Feedback.step;
    final revealed = _feedback == _Feedback.revealed;
    return switch (q) {
      RecognitionQuestion() => RecognitionActivity(
          question: q, onSubmit: _onSubmit, enabled: enabled, revealed: revealed),
      BuildQuestion() => BuildActivity(
          question: q, onSubmit: _onSubmit, enabled: enabled, revealed: revealed),
      OrderingQuestion() => OrderingActivity(
          question: q, onSubmit: _onSubmit, enabled: enabled, revealed: revealed),
      PatternQuestion() => PatternActivity(
          question: q, onSubmit: _onSubmit, enabled: enabled, revealed: revealed),
      CountingQuestion() => CountingActivity(
          question: q, onSubmit: _onSubmit, enabled: enabled, revealed: revealed),
      FormationQuestion() => FormationActivity(
          question: q, onSubmit: _onSubmit, enabled: enabled, revealed: revealed),
      CalculationQuestion() => CalculationActivity(
          question: q, onSubmit: _onSubmit, enabled: enabled, revealed: revealed),
      PlaceValueQuestion() => PlaceValueActivity(
          question: q, onSubmit: _onSubmit, enabled: enabled, revealed: revealed),
      ComparisonQuestion() => ComparisonActivity(
          question: q, onSubmit: _onSubmit, enabled: enabled, revealed: revealed),
    };
  }

  Widget _feedbackBar() {
    if (_feedback == _Feedback.none) return const SizedBox(height: 8);
    final (bg, fg, emoji, text) = switch (_feedback) {
      _Feedback.correct => (LearningColors.correctSurface, LearningColors.correct, '🎉', 'Great job!'),
      _Feedback.tryAgain => (LearningColors.tryAgainSurface, LearningColors.tryAgain, '💪', "Let's try again!"),
      _Feedback.step => (
          LearningColors.correctSurface,
          LearningColors.correct,
          '⭐',
          'Great! ${_q.followUpPrompt ?? ''}'
        ),
      _ => (
          LearningColors.tryAgainSurface,
          LearningColors.tryAgain,
          '💡',
          'The answer is ${NumberAnswerCheck.answerText(_q)}. Let\'s keep going!'
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: fg, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (_feedback == _Feedback.revealed) ...[
            const SizedBox(height: 14),
            PillButton(label: 'Next →', color: LearningColors.accent, onTap: _next),
          ],
        ],
      ),
    ).animate(key: ValueKey('f$_index$_feedback$_tries')).slideY(begin: 0.4, duration: 200.ms).fadeIn();
  }

  Widget _summary() {
    final total = _questions!.length;
    final passed = _score >= LevelProgressRules.passScore;
    final stars = passed ? 3 : (_score >= 5 ? 2 : 1);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(passed ? '🏆' : '🌟', style: const TextStyle(fontSize: 84))
              .animate()
              .scale(begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack),
          const SizedBox(height: 8),
          Text(
            passed ? 'Level passed!' : 'Well done!',
            style: GoogleFonts.nunito(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Icon(
                i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                color: i < stars ? Colors.amber : Colors.grey.shade300,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$_score / $total',
            style: GoogleFonts.nunito(fontSize: 48, fontWeight: FontWeight.w900, color: LearningColors.accent),
          ),
          const SizedBox(height: 8),
          Text(
            passed
                ? 'The next level is open! ✓'
                : 'Get ${LevelProgressRules.passScore} or more to open the next level. You can do it!',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          PillButton(
            label: 'Play again 🔁',
            color: LearningColors.accent,
            onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => NumberLearningSessionScreen(level: widget.level),
            )),
          ),
          const SizedBox(height: 12),
          PillButton(
            label: 'Back to levels',
            color: AppColors.reading,
            onTap: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }
}
