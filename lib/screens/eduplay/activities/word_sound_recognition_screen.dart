import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../eduplay_theme.dart';
import '../eduplay_data.dart';
import '../eduplay_lesson_unlock_screen.dart';

class WordSoundRecognitionScreen extends StatefulWidget {
  final ValueChanged<int> onLessonComplete;

  const WordSoundRecognitionScreen(
      {super.key, required this.onLessonComplete});

  @override
  State<WordSoundRecognitionScreen> createState() =>
      _WordSoundRecognitionScreenState();
}

class _WordSoundRecognitionScreenState
    extends State<WordSoundRecognitionScreen> {
  static const _accentColor = EP.l2;

  final _tts = FlutterTts();
  int _wordIndex = 0;
  String? _selectedOption;
  bool _showSuccess = false;
  bool _showWrong = false;
  int _totalStars = 0;

  SoundWord get _current => lesson2Words[_wordIndex];

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    Future.delayed(const Duration(milliseconds: 600), _speak);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _speak() => _tts.speak(_current.word);

  void _done() {
    if (_selectedOption == null) {
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

    if (_selectedOption == _current.correctAnswer) {
      HapticFeedback.heavyImpact();
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
      _selectedOption = null;
      _showWrong = false;
    });
  }

  void _nextWord() {
    if (_wordIndex + 1 >= lesson2Words.length) {
      _goToLessonUnlock();
    } else {
      setState(() {
        _wordIndex++;
        _selectedOption = null;
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
          completedLessonIndex: 1,
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
          if (_showSuccess)
            WordSuccessOverlay(
              wordNumber: _wordIndex + 1,
              total: lesson2Words.length,
              completedWord: _current.correctAnswer,
              emoji: _current.emoji,
              stars: 3,
              accentColor: _accentColor,
              onNextWord: _nextWord,
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
      title: Text('Word Sound Recognition',
          style: EP.head(18, color: Colors.white)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              '${_wordIndex + 1} / ${lesson2Words.length}',
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
            current: _wordIndex + 1,
            total: lesson2Words.length,
            color: _accentColor,
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          BuddyBar(
            message: 'Buddy is listening... Active',
            active: true,
          ).animate(delay: 80.ms).fadeIn(),

          const SizedBox(height: 20),

          // Image + audio
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ActivityImageCard(
                emoji: _current.emoji,
                borderColor: _accentColor,
              ),
              const SizedBox(width: 20),
              Column(
                children: [
                  AudioButton(onTap: _speak, color: _accentColor),
                  const SizedBox(height: 12),
                  ListenAgainButton(onTap: _speak, color: _accentColor),
                ],
              ),
            ],
          ).animate(delay: 120.ms).fadeIn(),

          const SizedBox(height: 20),

          // Instruction
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Listen to the word and choose the correct answer.',
              style: EP.body(15, color: _accentColor, w: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ).animate(delay: 160.ms).fadeIn(),

          const SizedBox(height: 24),

          // Answer options grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            itemCount: _current.options.length,
            itemBuilder: (_, i) {
              final option = _current.options[i];
              final isSelected = _selectedOption == option;
              final isCorrect = option == _current.correctAnswer;
              final showCorrect = _showWrong && isCorrect;
              final showIncorrect =
                  _showWrong && isSelected && !isCorrect;

              Color bgColor;
              Color borderColor;
              Color textColor;

              if (showCorrect) {
                bgColor = EP.successLt;
                borderColor = EP.success;
                textColor = EP.success;
              } else if (showIncorrect) {
                bgColor = EP.dangerLt;
                borderColor = EP.danger;
                textColor = EP.danger;
              } else if (isSelected) {
                bgColor = _accentColor.withOpacity(0.12);
                borderColor = _accentColor;
                textColor = _accentColor;
              } else {
                bgColor = EP.card;
                borderColor = EP.divider;
                textColor = EP.textDark;
              }

              return GestureDetector(
                onTap: _showWrong
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedOption = option);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 2),
                    boxShadow: EP.cardShadow,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showCorrect)
                          const Text('✓ ',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: EP.success,
                                  fontWeight: FontWeight.bold)),
                        if (showIncorrect)
                          const Text('✗ ',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: EP.danger,
                                  fontWeight: FontWeight.bold)),
                        Text(option,
                            style: EP.head(18, color: textColor)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ).animate(delay: 200.ms).fadeIn(),

          const SizedBox(height: 20),

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
                '❌ Not right! The correct word is "${_current.correctAnswer}"',
                style: EP.body(14, color: EP.danger, w: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ).animate().fadeIn(),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              if (_showWrong)
                Expanded(
                  child: EduButton(
                    label: 'Try Again',
                    onTap: _tryAgain,
                    color: EP.danger,
                    outline: true,
                    icon: Icons.replay_rounded,
                  ),
                ),
              if (_showWrong) const SizedBox(width: 12),
              Expanded(
                child: EduButton(
                  label: 'Done',
                  onTap: _done,
                  color: _accentColor,
                  icon: Icons.check_rounded,
                ),
              ),
            ],
          ).animate(delay: 250.ms).fadeIn(),

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
