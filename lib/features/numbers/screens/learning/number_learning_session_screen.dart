import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_reading_buddy/features/numbers/dao/number_learning_dao.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/features/numbers/services/answer_checker.dart';
import 'package:smart_reading_buddy/features/numbers/services/level_config.dart';
import 'package:smart_reading_buddy/features/numbers/services/learner_grade.dart';
import 'package:smart_reading_buddy/features/numbers/services/level_progress.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_question.dart';
import 'package:smart_reading_buddy/features/numbers/services/question_generator.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/build_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/calculation_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/counting_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/formation_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/ordering_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/pattern_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/place_value_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/read_answer_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/recognition_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/spell_word_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/session_summary.dart';

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
  // Bumped by the replay button for questions that read themselves aloud
  // (Read & Answer), so the activity re-reads with word highlighting.
  final _replaySignal = ValueNotifier<int>(0);

  List<NumberQuestion>? _questions;
  String? _error;
  int _index = 0;
  int _tries = 0; // all submissions this question (saved as attempts)
  int _wrongs = 0;
  int _score = 0;
  _Feedback _feedback = _Feedback.none;
  DateTime _questionStart = DateTime.now();
  Timer? _advanceTimer;

  /// Inline feedback card under the question (see FeedbackSlot).
  FeedbackMessage? _card;
  int _cardId = 0;
  Timer? _cardTimer;
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
    _cardTimer?.cancel();
    _speaker.stop();
    _replaySignal.dispose();
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

  /// Shows the inline feedback card; it hides itself after
  /// [kWrongResetDelay] unless [autoHide] is false.
  void _showCard(String emoji, String text, FeedbackTone tone, {bool autoHide = true}) {
    _cardTimer?.cancel();
    setState(() => _card = FeedbackMessage(++_cardId, emoji, text, tone));
    if (autoHide) {
      _cardTimer = Timer(kWrongResetDelay, () {
        if (mounted) setState(() => _card = null);
      });
    }
  }

  void _startQuestion() {
    _cardTimer?.cancel();
    setState(() {
      _tries = 0;
      _wrongs = 0;
      _card = null;
      _feedback = _Feedback.none;
      _questionStart = DateTime.now();
    });
    if (!_q.speaksItself) _speaker.say(_q.speech);
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
        _showCard('⭐', 'Great! ${_q.followUpPrompt ?? ''}', FeedbackTone.good);
        _speaker.say(_q.followUpSpeech ?? 'Great!');
        return true;
      case AnswerResult.correct:
        // The point needs every step right first time (no wrong answers).
        final point = _wrongs == 0 ? 1 : 0;
        _score += point;
        _save(correct: true, score: point);
        setState(() => _feedback = _Feedback.correct);
        // Stays up until the next question (1.5 s), so no auto-hide.
        _showCard('🎉', 'Great job!', FeedbackTone.good, autoHide: false);
        _speaker.say('Great job!');
        _advanceTimer = Timer(const Duration(milliseconds: 1500), _next);
        return true;
      case AnswerResult.wrong:
        _wrongs++;
        if (_wrongs < _maxTries) {
          setState(() => _feedback = _Feedback.tryAgain);
          _showCard('💪', "Let's try again!", FeedbackTone.tryAgain);
          _speaker.say("Let's try again!");
        } else {
          _save(correct: false, score: 0);
          _cardTimer?.cancel();
          setState(() {
            _card = null;
            _feedback = _Feedback.revealed;
          });
          _speaker.say('The answer is ${NumberAnswerCheck.answerText(_q)}');
        }
        return false;
    }
  }

  /// Replay: the follow-up instruction once a question is on its second step.
  void _replay() {
    if (_q.speaksItself && _feedback != _Feedback.step) {
      _replaySignal.value++;
      return;
    }
    final follow = _q.followUpSpeech;
    _speaker.say(_feedback == _Feedback.step && follow != null ? follow : _q.speech);
  }

  void _save({required bool correct, required int score}) {
    NumberLearningDao.saveAttempt(
      profileName: AppState.name,
      sessionId: _sessionId,
      level: widget.level,
      // Practice activities aren't grade-specific (grade 0) — record the
      // child's own grade instead.
      grade: widget.level.grade == 0 ? LearnerGrade.fromProfile(AppState.grade).grade : null,
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
        // Fixed top: progress, the question, and the feedback card slot.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
              FeedbackSlot(message: _card),
            ],
          ),
        ),
        // The activity, centred vertically in the space left (scrolls when
        // it's taller than that), so there's no big empty gap at the bottom.
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: (box.maxHeight - 20).clamp(0.0, double.infinity)),
                child: Center(
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: _activity(_q),
                  ).animate(key: ValueKey('a$_index')).fadeIn(duration: 250.ms),
                ),
              ),
            ),
          ),
        ),
        if (_feedback == _Feedback.revealed) _revealBar(),
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
      SpellWordQuestion() => SpellWordActivity(
          question: q, onSubmit: _onSubmit, enabled: enabled, revealed: revealed),
      ReadAnswerQuestion() => ReadAnswerActivity(
          question: q,
          onSubmit: _onSubmit,
          enabled: enabled,
          revealed: revealed,
          speaker: _speaker,
          replaySignal: _replaySignal),
    };
  }

  /// After the last try: the answer, shown gently, with Next. The only
  /// feedback left at the bottom — it needs the button.
  Widget _revealBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: LearningColors.tryAgainSurface,
        border: Border(top: BorderSide(color: LearningColors.tryAgain, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "The answer is ${NumberAnswerCheck.answerText(_q)}. Let's keep going!",
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PillButton(label: 'Next →', color: LearningColors.accent, onTap: _next),
        ],
      ),
    ).animate(key: ValueKey('r$_index')).slideY(begin: 0.4, duration: 200.ms).fadeIn();
  }

  Widget _summary() => SessionSummaryView(
        score: _score,
        total: _questions!.length,
        onPlayAgain: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => NumberLearningSessionScreen(level: widget.level),
        )),
        onBack: () => Navigator.pop(context, true),
      );
}
