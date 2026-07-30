import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'eduplay_theme.dart';
import 'eduplay_data.dart';
import 'activities/drag_drop_letters_screen.dart';
import 'activities/word_sound_recognition_screen.dart';
import 'activities/missing_spelling_screen.dart';
import 'activities/sentence_drag_drop_screen.dart';
import 'activities/sentence_meaning_quiz_screen.dart';

class EduPlayJourneyScreen extends StatefulWidget {
  const EduPlayJourneyScreen({super.key});

  @override
  State<EduPlayJourneyScreen> createState() => _EduPlayJourneyScreenState();
}

class _EduPlayJourneyScreenState extends State<EduPlayJourneyScreen> {
  int _navIndex = 0;

  // Track which lessons are unlocked and completed
  // Starts with only lesson 0 unlocked
  final List<bool> _unlocked   = [true,  false, false, false, false];
  final List<bool> _completed  = [false, false, false, false, false];
  int _completedLessons = 0;
  int _totalStars = 0;

  void _onLessonUnlock(int lessonIndex, int starsEarned) {
    setState(() {
      _completed[lessonIndex] = true;
      _totalStars += starsEarned;
      _completedLessons = _completed.where((c) => c).length;
      if (lessonIndex + 1 < _unlocked.length) {
        _unlocked[lessonIndex + 1] = true;
      }
    });
  }

  void _startLesson(int index) {
    if (!_unlocked[index]) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🔒 Complete Lesson ${index} first to unlock this!',
              style: EP.body(14, color: Colors.white)),
          backgroundColor: EP.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    Widget screen;
    switch (index) {
      case 0:
        screen = DragDropLettersScreen(
          onLessonComplete: (stars) => _onLessonUnlock(0, stars),
        );
        break;
      case 1:
        screen = WordSoundRecognitionScreen(
          onLessonComplete: (stars) => _onLessonUnlock(1, stars),
        );
        break;
      case 2:
        screen = MissingSpellingScreen(
          onLessonComplete: (stars) => _onLessonUnlock(2, stars),
        );
        break;
      case 3:
        screen = SentenceDragDropScreen(
          onLessonComplete: (stars) => _onLessonUnlock(3, stars),
        );
        break;
      case 4:
      default:
        screen = SentenceMeaningQuizScreen(
          onLessonComplete: (stars) => _onLessonUnlock(4, stars),
        );
        break;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => screen,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeInOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EP.bg,
      appBar: _buildAppBar(),
      body: _navIndex == 0 ? _buildJourney() : _buildComingSoon(),
      bottomNavigationBar: EduBottomNav(
        selected: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: EP.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('😊', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Buddy',
                  style: EP.head(16, color: Colors.white)),
              Text('Grade 3 Basic',
                  style: EP.body(12,
                      color: Colors.white.withOpacity(0.8),
                      w: FontWeight.w600)),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text('$_totalStars',
                  style: EP.head(15, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJourney() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        // Welcome banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [EP.primary, EP.primaryDk],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: EP.colorShadow(EP.primary),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hi Buddy! 👋',
                        style: EP.head(22, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text("Let's learn!",
                        style: EP.body(16,
                            color: Colors.white.withOpacity(0.9))),
                  ],
                ),
              ),
              const Text('🦉', style: TextStyle(fontSize: 52)),
            ],
          ),
        ).animate().fadeIn().slideY(begin: -0.15),

        const SizedBox(height: 20),

        // Today's progress
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: EP.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: EP.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Today's Practice",
                      style: EP.head(15, color: EP.textDark)),
                  Text(
                    '$_completedLessons / 5 Lessons',
                    style: EP.body(13, color: EP.primary, w: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween:
                      Tween(begin: 0, end: _completedLessons / 5),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 12,
                    backgroundColor: EP.divider,
                    valueColor:
                        const AlwaysStoppedAnimation(EP.primary),
                  ),
                ),
              ),
            ],
          ),
        ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1),

        const SizedBox(height: 20),

        Text('Your Lessons', style: EP.head(18, color: EP.textDark))
            .animate(delay: 150.ms)
            .fadeIn(),

        const SizedBox(height: 12),

        // Lesson cards
        ...List.generate(allLessons.length, (i) {
          final lesson = allLessons[i];
          final unlocked = _unlocked[i];
          final done = _completed[i];
          final color = EP.lessonColor(i);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _LessonCard(
              lesson: lesson,
              color: color,
              unlocked: unlocked,
              completed: done,
              onStart: () => _startLesson(i),
            )
                .animate(delay: Duration(milliseconds: 180 + i * 60))
                .fadeIn()
                .slideX(begin: 0.15),
          );
        }),
      ],
    );
  }

  Widget _buildComingSoon() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🚧', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Coming Soon!', style: EP.head(24, color: EP.textDark)),
          const SizedBox(height: 8),
          Text('This section is under construction.',
              style: EP.body(15, color: EP.textLight)),
        ],
      ),
    );
  }
}

// ── Lesson Card ───────────────────────────────────────────────────────────────

class _LessonCard extends StatelessWidget {
  final LessonInfo lesson;
  final Color color;
  final bool unlocked;
  final bool completed;
  final VoidCallback onStart;

  const _LessonCard({
    required this.lesson,
    required this.color,
    required this.unlocked,
    required this.completed,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EP.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: completed
              ? EP.success.withOpacity(0.5)
              : color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: EP.cardShadow,
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: unlocked
                  ? color.withOpacity(0.12)
                  : EP.divider,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                unlocked ? lesson.icon : '🔒',
                style: TextStyle(
                    fontSize: unlocked ? 28 : 22),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Lesson ${lesson.number}',
                      style: EP.body(12,
                          color: color, w: FontWeight.w800),
                    ),
                    if (completed) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: EP.successLt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Done ✓',
                            style: EP.body(11,
                                color: EP.success,
                                w: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  lesson.title,
                  style: EP.head(15,
                      color: unlocked ? EP.textDark : EP.textLight),
                ),
                const SizedBox(height: 3),
                Text(
                  lesson.description,
                  style: EP.body(12, color: EP.textLight),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Start button
          GestureDetector(
            onTap: onStart,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: unlocked ? color : EP.divider,
                borderRadius: BorderRadius.circular(14),
                boxShadow: unlocked ? EP.colorShadow(color) : null,
              ),
              child: Text(
                completed ? 'Again' : 'Start',
                style: EP.head(14,
                    color: unlocked ? Colors.white : EP.textLight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
