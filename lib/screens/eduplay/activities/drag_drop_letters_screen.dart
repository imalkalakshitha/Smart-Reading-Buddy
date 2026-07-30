import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../eduplay_theme.dart';
import '../eduplay_data.dart';
import '../eduplay_lesson_unlock_screen.dart';

class DragDropLettersScreen extends StatefulWidget {
  final ValueChanged<int> onLessonComplete;

  const DragDropLettersScreen({super.key, required this.onLessonComplete});

  @override
  State<DragDropLettersScreen> createState() => _DragDropLettersScreenState();
}

class _DragDropLettersScreenState extends State<DragDropLettersScreen> {
  static const _accentColor = EP.l1;

  final _tts = FlutterTts();
  int _wordIndex = 0;
  bool _showSuccess = false;
  bool _showWrong = false;
  int _totalStars = 0;

  // Slot state: each slot holds a letter or null
  List<String?> _slots = [];
  // Pool of letters available to drag
  List<String> _pool = [];

  DragDropWord get _current => lesson1Words[_wordIndex];

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _resetWord();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _resetWord() {
    setState(() {
      _slots = List.filled(_current.word.length, null);
      _pool = List.from(_current.letters);
      _showSuccess = false;
      _showWrong = false;
    });
  }

  void _speak() => _tts.speak(_current.word);

  void _dropOnSlot(int slotIndex, String letter) {
    HapticFeedback.lightImpact();
    setState(() {
      // Return displaced letter to pool
      if (_slots[slotIndex] != null) {
        _pool.add(_slots[slotIndex]!);
      }
      // Remove from pool if it came from pool
      _pool.remove(letter);
      _slots[slotIndex] = letter;
    });
  }

  void _returnToPool(int slotIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_slots[slotIndex] != null) {
        _pool.add(_slots[slotIndex]!);
        _slots[slotIndex] = null;
      }
    });
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    _resetWord();
  }

  void _done() {
    if (_slots.any((s) => s == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fill all the letter slots first! 😊',
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

    final built = _slots.join();
    if (built == _current.word) {
      HapticFeedback.heavyImpact();
      _tts.speak('Great job! ${_current.word}');
      setState(() {
        _showSuccess = true;
        _totalStars += 3;
        _showWrong = false;
      });
    } else {
      HapticFeedback.vibrate();
      setState(() => _showWrong = true);
      Future.delayed(const Duration(milliseconds: 1200),
          () => setState(() => _showWrong = false));
    }
  }

  void _nextWord() {
    if (_wordIndex + 1 >= lesson1Words.length) {
      _goToLessonUnlock();
    } else {
      setState(() {
        _wordIndex++;
        _showSuccess = false;
      });
      _resetWord();
    }
  }

  void _goToLessonUnlock() {
    widget.onLessonComplete(_totalStars);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => EduPlayLessonUnlockScreen(
          completedLessonIndex: 0,
          totalStarsEarned: _totalStars,
          onStartNext: () {
            Navigator.pop(context); // back to journey
          },
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
              total: lesson1Words.length,
              completedWord: _current.word,
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
      title: Text('Drag and Drop Letters',
          style: EP.head(18, color: Colors.white)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              '${_wordIndex + 1} / ${lesson1Words.length}',
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
          // Progress
          EduProgressBar(
            current: _wordIndex + 1,
            total: lesson1Words.length,
            color: _accentColor,
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          // Buddy bar
          BuddyBar(message: 'Buddy is listening...', active: false)
              .animate(delay: 80.ms)
              .fadeIn(),

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
          ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.1),

          const SizedBox(height: 20),

          // Instruction
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Drag the letters to build the correct word!',
              style: EP.body(15, color: _accentColor, w: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ).animate(delay: 160.ms).fadeIn(),

          const SizedBox(height: 24),

          // Letter drop slots
          _buildSlots(),

          const SizedBox(height: 24),

          // Wrong answer feedback
          AnimatedOpacity(
            opacity: _showWrong ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: EP.dangerLt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '❌ Not quite right! Try again.',
                style: EP.body(14, color: EP.danger, w: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Draggable letter pool
          Text('Available Letters',
              style: EP.body(13, color: EP.textLight)),
          const SizedBox(height: 12),
          _buildPool(),

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: EduButton(
                  label: 'Clear',
                  onTap: _clear,
                  color: EP.textLight,
                  outline: true,
                  icon: Icons.clear_rounded,
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
          ).animate(delay: 200.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _buildSlots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slots.length, (i) {
        final letter = _slots[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DragTarget<String>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) =>
                _dropOnSlot(i, details.data),
            builder: (_, candidates, __) {
              final isHovering = candidates.isNotEmpty;
              return GestureDetector(
                onTap: () => _returnToPool(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 64,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _showWrong
                        ? EP.dangerLt
                        : letter != null
                            ? _accentColor.withOpacity(0.12)
                            : isHovering
                                ? EP.successLt
                                : EP.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _showWrong
                          ? EP.danger
                          : letter != null
                              ? _accentColor
                              : isHovering
                                  ? EP.success
                                  : EP.divider,
                      width: 2.5,
                    ),
                    boxShadow: EP.cardShadow,
                  ),
                  child: Center(
                    child: letter != null
                        ? Text(
                            letter,
                            style: EP.head(28, color: _accentColor),
                          )
                        : Text(
                            '_',
                            style: EP.head(28, color: EP.divider),
                          ),
                  ),
                ),
              );
            },
          ),
        );
      }),
    ).animate(delay: 180.ms).fadeIn();
  }

  Widget _buildPool() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: _pool.map((letter) {
        return LongPressDraggable<String>(
          data: letter,
          delay: const Duration(milliseconds: 80),
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              width: 60,
              height: 68,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: EP.colorShadow(_accentColor),
              ),
              child: Center(
                child: Text(letter,
                    style: EP.head(28, color: Colors.white)),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _letterTile(letter),
          ),
          child: _letterTile(letter),
        );
      }).toList(),
    ).animate(delay: 220.ms).fadeIn();
  }

  Widget _letterTile(String letter) {
    return Container(
      width: 60,
      height: 68,
      decoration: BoxDecoration(
        color: EP.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withOpacity(0.5), width: 2),
        boxShadow: EP.cardShadow,
      ),
      child: Center(
        child: Text(letter, style: EP.head(28, color: _accentColor)),
      ),
    );
  }
}
