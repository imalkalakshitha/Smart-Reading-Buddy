import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../eduplay_theme.dart';
import '../eduplay_data.dart';
import '../eduplay_lesson_unlock_screen.dart';

class MissingSpellingScreen extends StatefulWidget {
  final ValueChanged<int> onLessonComplete;

  const MissingSpellingScreen({super.key, required this.onLessonComplete});

  @override
  State<MissingSpellingScreen> createState() =>
      _MissingSpellingScreenState();
}

class _MissingSpellingScreenState extends State<MissingSpellingScreen> {
  static const _accentColor = EP.l3;

  final _tts = FlutterTts();
  int _wordIndex = 0;
  String? _selectedLetter;
  bool _showSuccess = false;
  bool _showWrong = false;
  int _totalStars = 0;

  SpellingWord get _current => lesson3Words[_wordIndex];

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.40);
    Future.delayed(const Duration(milliseconds: 600), _speak);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _speak() => _tts.speak(_current.fullWord);

  void _done() {
    if (_selectedLetter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Choose the missing letter! 😊',
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

    if (_selectedLetter == _current.correctLetter) {
      HapticFeedback.heavyImpact();
      _tts.speak('Correct! ${_current.fullWord}');
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
      _selectedLetter = null;
      _showWrong = false;
    });
  }

  void _nextWord() {
    if (_wordIndex + 1 >= lesson3Words.length) {
      _goToLessonUnlock();
    } else {
      setState(() {
        _wordIndex++;
        _selectedLetter = null;
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
          completedLessonIndex: 2,
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
              total: lesson3Words.length,
              completedWord: _current.fullWord,
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
      title: Text('Missing Spelling Practice',
          style: EP.head(18, color: Colors.white)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              '${_wordIndex + 1} / ${lesson3Words.length}',
              style: EP.head(15, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final chars = _current.fullWord.split('');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          EduProgressBar(
            current: _wordIndex + 1,
            total: lesson3Words.length,
            color: _accentColor,
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          BuddyBar(
            message: 'Buddy is here to help! 🦉',
            active: false,
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

          const SizedBox(height: 24),

          // Word display with blank
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(chars.length, (i) {
              final isBlank = i == _current.blankIndex;
              final filledLetter =
                  isBlank ? (_selectedLetter ?? '') : chars[i];
              final isFilled = isBlank && _selectedLetter != null;

              Color boxColor;
              Color borderCol;
              Color textCol;

              if (isBlank && _showWrong) {
                boxColor = EP.dangerLt;
                borderCol = EP.danger;
                textCol = EP.danger;
              } else if (isBlank && _showSuccess) {
                boxColor = EP.successLt;
                borderCol = EP.success;
                textCol = EP.success;
              } else if (isBlank) {
                boxColor = isFilled
                    ? _accentColor.withOpacity(0.12)
                    : EP.card;
                borderCol = isFilled ? _accentColor : EP.divider;
                textCol = _accentColor;
              } else {
                boxColor = EP.primaryLt;
                borderCol = EP.primary.withOpacity(0.3);
                textCol = EP.textDark;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 62,
                  height: 72,
                  decoration: BoxDecoration(
                    color: boxColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol, width: 2.5),
                    boxShadow: EP.cardShadow,
                  ),
                  child: Center(
                    child: Text(
                      filledLetter,
                      style: EP.head(28, color: textCol),
                    ),
                  ),
                ),
              );
            }),
          ).animate(delay: 160.ms).fadeIn().scale(),

          const SizedBox(height: 12),

          Text(
            _current.displayWord,
            style: EP.body(16, color: EP.textLight),
          ),

          const SizedBox(height: 28),

          // Letter choices
          Text(
            'Choose the missing letter:',
            style: EP.body(15, color: EP.textMid, w: FontWeight.w700),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _current.options.map((letter) {
              final isSelected = _selectedLetter == letter;
              final isCorrect = letter == _current.correctLetter;
              final showCorrect = _showWrong && isCorrect;
              final showIncorrect =
                  _showWrong && isSelected && !isCorrect;

              Color bg;
              Color border;
              Color fg;

              if (showCorrect) {
                bg = EP.successLt;
                border = EP.success;
                fg = EP.success;
              } else if (showIncorrect) {
                bg = EP.dangerLt;
                border = EP.danger;
                fg = EP.danger;
              } else if (isSelected) {
                bg = _accentColor.withOpacity(0.15);
                border = _accentColor;
                fg = _accentColor;
              } else {
                bg = EP.card;
                border = EP.divider;
                fg = EP.textDark;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: GestureDetector(
                  onTap: _showWrong
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedLetter = letter);
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    height: 80,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border, width: 2.5),
                      boxShadow: EP.cardShadow,
                    ),
                    child: Center(
                      child: Text(letter, style: EP.head(30, color: fg)),
                    ),
                  ),
                ),
              );
            }).toList(),
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
                '❌ Not right! The correct letter is "${_current.correctLetter}"',
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
