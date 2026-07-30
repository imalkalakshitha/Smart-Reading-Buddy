import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../eduplay_theme.dart';
import '../eduplay_data.dart';
import '../eduplay_lesson_unlock_screen.dart';

class SentenceMeaningQuizScreen extends StatefulWidget {
  final ValueChanged<int> onLessonComplete;

  const SentenceMeaningQuizScreen(
      {super.key, required this.onLessonComplete});

  @override
  State<SentenceMeaningQuizScreen> createState() =>
      _SentenceMeaningQuizScreenState();
}

class _SentenceMeaningQuizScreenState
    extends State<SentenceMeaningQuizScreen> {
  static const _accentColor = EP.l5;

  final _tts = FlutterTts();
  late final ConfettiController _confetti;
  int _questionIndex = 0;
  String? _selectedAnswer;
  bool _showSuccess = false;
  bool _showWrong = false;
  int _totalStars = 0;

  MeaningQuestion get _current => lesson5Questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.40);
    _confetti =
        ConfettiController(duration: const Duration(seconds: 2));
    Future.delayed(const Duration(milliseconds: 600), _speak);
  }

  @override
  void dispose() {
    _tts.stop();
    _confetti.dispose();
    super.dispose();
  }

  void _speak() => _tts.speak(_current.sentence);

  void _done() {
    if (_selectedAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Choose an answer first! 😊',
              style: EP.body(14, color: Colors.white)),
          backgroundColor: EP.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedAnswer == _current.correctAnswer) {
      HapticFeedback.heavyImpact();
      _confetti.play();
      _tts.speak('Correct! ${_current.correctAnswer}');
      setState(() {
        _showSuccess = true;
        _totalStars += 3;
        _showWrong = false;
      });
    } else {
      HapticFeedback.vibrate();
      setState(() => _showWrong = true);
    }
  }

  void _tryAgain() {
    setState(() {
      _selectedAnswer = null;
      _showWrong = false;
    });
  }

  void _nextQuestion() {
    if (_questionIndex + 1 >= lesson5Questions.length) {
      _goToLessonUnlock();
    } else {
      setState(() {
        _questionIndex++;
        _selectedAnswer = null;
        _showSuccess = false;
        _showWrong = false;
      });
      Future.delayed(const Duration(milliseconds: 400), _speak);
    }
  }

  void _goToLessonUnlock() {
    widget.onLessonComplete(_totalStars);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => EduPlayLessonUnlockScreen(
          completedLessonIndex: 4,
          totalStarsEarned: _totalStars,
          onStartNext: () => Navigator.pop(context),
          onBackToJourney: () => Navigator.pop(context),
        ),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EP.bg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBody(),

          // Confetti when correct
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 20,
              colors: const [
                EP.primary, EP.orange, EP.yellow, EP.teal, EP.l5
              ],
            ),
          ),

          if (_showSuccess)
            WordSuccessOverlay(
              wordNumber: _questionIndex + 1,
              total: lesson5Questions.length,
              completedWord: _current.correctAnswer,
              emoji: _current.emoji,
              stars: 3,
              accentColor: _accentColor,
              onNextWord: _nextQuestion,
              onBackToJourney: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _accentColor,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text('Sentence Meaning Quiz',
          style: EP.head(18, color: Colors.white)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              '${_questionIndex + 1} / ${lesson5Questions.length}',
              style: EP.head(15, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          EduProgressBar(
            current: _questionIndex + 1,
            total: lesson5Questions.length,
            color: _accentColor,
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          BuddyBar(
            message: 'Buddy is listening...',
            active: false,
          ).animate(delay: 80.ms).fadeIn(),

          const SizedBox(height: 20),

          // Sentence card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: _accentColor.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Text(_current.emoji,
                    style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '"${_current.sentence}"',
                    style: EP.head(17, color: EP.textDark),
                  ),
                ),
              ],
            ),
          ).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 16),

          // Audio buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AudioButton(onTap: _speak, color: _accentColor),
              const SizedBox(width: 16),
              ListenAgainButton(onTap: _speak, color: _accentColor),
            ],
          ).animate(delay: 140.ms).fadeIn(),

          const SizedBox(height: 24),

          // Question
          Text(
            _current.question,
            style: EP.head(22, color: EP.textDark),
            textAlign: TextAlign.center,
          ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.1),

          const SizedBox(height: 8),

          // Hint
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: EP.yellowLt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EP.yellow.withOpacity(0.5)),
            ),
            child: Text(
              '💡 Listen carefully and choose the correct meaning!',
              style: EP.body(13, color: EP.textDark),
              textAlign: TextAlign.center,
            ),
          ).animate(delay: 220.ms).fadeIn(),

          const SizedBox(height: 24),

          // Answer options
          ...List.generate(_current.options.length, (i) {
            final option = _current.options[i];
            final isSelected = _selectedAnswer == option;
            final isCorrect = option == _current.correctAnswer;
            final showCorrect = _showWrong && isCorrect;
            final showIncorrect =
                _showWrong && isSelected && !isCorrect;

            Color bg;
            Color border;
            Color fg;
            IconData? trailingIcon;

            if (showCorrect) {
              bg = EP.successLt;
              border = EP.success;
              fg = EP.success;
              trailingIcon = Icons.check_circle_rounded;
            } else if (showIncorrect) {
              bg = EP.dangerLt;
              border = EP.danger;
              fg = EP.danger;
              trailingIcon = Icons.cancel_rounded;
            } else if (isSelected) {
              bg = _accentColor.withOpacity(0.10);
              border = _accentColor;
              fg = _accentColor;
              trailingIcon = Icons.radio_button_checked_rounded;
            } else {
              bg = EP.card;
              border = EP.divider;
              fg = EP.textDark;
              trailingIcon = Icons.radio_button_off_rounded;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: _showWrong
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedAnswer = option);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border, width: 2),
                    boxShadow: EP.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Icon(trailingIcon, color: fg, size: 24),
                      const SizedBox(width: 14),
                      Text(option, style: EP.head(18, color: fg)),
                    ],
                  ),
                ),
              ).animate(delay: Duration(milliseconds: 240 + i * 50)).fadeIn().slideX(begin: 0.1),
            );
          }),

          const SizedBox(height: 8),

          // Wrong feedback
          if (_showWrong)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: EP.dangerLt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '❌ Not right! The answer is "${_current.correctAnswer}"',
                style: EP.body(14, color: EP.danger, w: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ).animate().fadeIn(),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: EduButton(
                  label: 'Try Again',
                  onTap: _tryAgain,
                  color: EP.danger,
                  outline: true,
                  icon: Icons.replay_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: EduButton(
                  label: 'Done',
                  onTap: _done,
                  color: _accentColor,
                  icon: Icons.check_rounded,
                ),
              ),
            ],
          ).animate(delay: 350.ms).fadeIn(),

          const SizedBox(height: 12),

          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              '← Back to Journey',
              style: EP.body(14, color: EP.textLight),
            ),
          ),
        ],
      ),
    );
  }
}
