import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../eduplay_theme.dart';
import '../eduplay_data.dart';
import '../eduplay_lesson_unlock_screen.dart';

class SentenceDragDropScreen extends StatefulWidget {
  final ValueChanged<int> onLessonComplete;

  const SentenceDragDropScreen({super.key, required this.onLessonComplete});

  @override
  State<SentenceDragDropScreen> createState() =>
      _SentenceDragDropScreenState();
}

class _SentenceDragDropScreenState extends State<SentenceDragDropScreen> {
  static const _accentColor = EP.l4;

  final _tts = FlutterTts();
  int _sentenceIndex = 0;
  bool _showSuccess = false;
  bool _showWrong = false;
  int _totalStars = 0;

  // Slots for the built sentence
  List<String?> _slots = [];
  // Word pool (available word cards)
  List<String> _pool = [];

  SentenceItem get _current => lesson4Sentences[_sentenceIndex];

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.40);
    _resetSentence();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _resetSentence() {
    setState(() {
      _slots = List.filled(_current.correctOrder.length, null);
      _pool = List.from(_current.wordChoices);
      _showSuccess = false;
      _showWrong = false;
    });
  }

  void _speak() => _tts.speak(_current.sentence);

  void _dropOnSlot(int slotIndex, String word) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_slots[slotIndex] != null) {
        _pool.add(_slots[slotIndex]!);
      }
      _pool.remove(word);
      _slots[slotIndex] = word;
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
    _resetSentence();
  }

  void _done() {
    if (_slots.any((s) => s == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fill all the word slots first! 😊',
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

    final built = _slots.whereType<String>().toList();
    final correct = _current.correctOrder;

    if (built.length == correct.length &&
        List.generate(built.length, (i) => built[i] == correct[i])
            .every((b) => b)) {
      HapticFeedback.heavyImpact();
      _tts.speak('Well done! ${_current.sentence}');
      setState(() {
        _showSuccess = true;
        _totalStars += 3;
        _showWrong = false;
      });
    } else {
      HapticFeedback.vibrate();
      setState(() => _showWrong = true);
      Future.delayed(const Duration(milliseconds: 1500),
          () => setState(() => _showWrong = false));
    }
  }

  void _nextSentence() {
    if (_sentenceIndex + 1 >= lesson4Sentences.length) {
      _goToLessonUnlock();
    } else {
      setState(() {
        _sentenceIndex++;
        _showSuccess = false;
      });
      _resetSentence();
    }
  }

  void _goToLessonUnlock() {
    widget.onLessonComplete(_totalStars);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => EduPlayLessonUnlockScreen(
          completedLessonIndex: 3,
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
              wordNumber: _sentenceIndex + 1,
              total: lesson4Sentences.length,
              completedWord: _current.correctOrder.join(' '),
              emoji: _current.emoji,
              stars: 3,
              accentColor: _accentColor,
              onNextWord: _nextSentence,
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
      title: Text('Sentence Drag and Drop',
          style: EP.head(18, color: Colors.white)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              '${_sentenceIndex + 1} / ${lesson4Sentences.length}',
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
            current: _sentenceIndex + 1,
            total: lesson4Sentences.length,
            color: _accentColor,
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          BuddyBar(
            message: 'Buddy is listening... Repeat the sentence!',
            active: true,
          ).animate(delay: 80.ms).fadeIn(),

          const SizedBox(height: 20),

          // Scene image
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 110,
                decoration: BoxDecoration(
                  color: EP.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: _accentColor.withOpacity(0.35), width: 2),
                  boxShadow: EP.cardShadow,
                ),
                child: Center(
                  child: Text(
                    _current.emoji,
                    style: const TextStyle(fontSize: 52),
                  ),
                ),
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

          // Sentence slots
          Text(
            'Build the sentence:',
            style: EP.body(15, color: EP.textMid, w: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: List.generate(_slots.length, (i) {
              final word = _slots[i];
              return DragTarget<String>(
                onWillAcceptWithDetails: (d) => true,
                onAcceptWithDetails: (d) => _dropOnSlot(i, d.data),
                builder: (_, candidates, __) {
                  final isHovering = candidates.isNotEmpty;
                  return GestureDetector(
                    onTap: () => _returnToPool(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      constraints: const BoxConstraints(minWidth: 70),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: _showWrong
                            ? EP.dangerLt
                            : word != null
                                ? _accentColor.withOpacity(0.12)
                                : isHovering
                                    ? EP.successLt
                                    : EP.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _showWrong
                              ? EP.danger
                              : word != null
                                  ? _accentColor
                                  : isHovering
                                      ? EP.success
                                      : EP.divider,
                          width: 2,
                        ),
                        boxShadow: EP.cardShadow,
                      ),
                      child: Center(
                        child: word != null
                            ? Text(word,
                                style: EP.head(16, color: _accentColor))
                            : Text('_ _ _',
                                style: EP.body(14, color: EP.divider)),
                      ),
                    ),
                  );
                },
              );
            }),
          ).animate(delay: 160.ms).fadeIn(),

          const SizedBox(height: 20),

          if (_showWrong)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: EP.dangerLt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '❌ Wrong order! Try again.',
                style: EP.body(14, color: EP.danger, w: FontWeight.w700),
              ),
            ).animate().fadeIn(),

          const SizedBox(height: 24),

          // Word pool
          Text(
            'Drag words to the slots above:',
            style: EP.body(13, color: EP.textLight),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _pool.map((word) {
              return LongPressDraggable<String>(
                data: word,
                delay: const Duration(milliseconds: 80),
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: EP.colorShadow(_accentColor),
                    ),
                    child: Text(word,
                        style: EP.head(16, color: Colors.white)),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _wordCard(word),
                ),
                child: _wordCard(word),
              );
            }).toList(),
          ).animate(delay: 200.ms).fadeIn(),

          const SizedBox(height: 32),

          // Buttons
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

  Widget _wordCard(String word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: EP.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentColor.withOpacity(0.4), width: 2),
        boxShadow: EP.cardShadow,
      ),
      child: Text(word, style: EP.head(16, color: _accentColor)),
    );
  }
}
