import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'eduplay_theme.dart';
import 'eduplay_data.dart';

class EduPlayLessonUnlockScreen extends StatefulWidget {
  final int completedLessonIndex; // 0-based: lesson just finished
  final int totalStarsEarned;
  final VoidCallback onStartNext;
  final VoidCallback onBackToJourney;

  const EduPlayLessonUnlockScreen({
    super.key,
    required this.completedLessonIndex,
    required this.totalStarsEarned,
    required this.onStartNext,
    required this.onBackToJourney,
  });

  @override
  State<EduPlayLessonUnlockScreen> createState() =>
      _EduPlayLessonUnlockScreenState();
}

class _EduPlayLessonUnlockScreenState
    extends State<EduPlayLessonUnlockScreen> {
  late final ConfettiController _confetti;

  bool get hasNext =>
      widget.completedLessonIndex + 1 < allLessons.length;

  LessonInfo? get nextLesson => hasNext
      ? allLessons[widget.completedLessonIndex + 1]
      : null;

  int get completedCount => widget.completedLessonIndex + 1;
  double get progressFraction => completedCount / allLessons.length;

  @override
  void initState() {
    super.initState();
    _confetti =
        ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EP.bg,
      body: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              colors: const [
                EP.primary, EP.orange, EP.yellow, EP.success, EP.teal
              ],
            ),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                children: [
                  // Completed badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: EP.successLt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: EP.success, width: 1.5),
                    ),
                    child: Text(
                      '🎉 Lesson Completed!',
                      style: EP.head(18, color: EP.success),
                    ),
                  ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),

                  const SizedBox(height: 16),

                  if (hasNext)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: EP.primaryLt,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '🔓 Next Lesson Unlocked!',
                        style: EP.head(16, color: EP.primary),
                      ),
                    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),

                  const SizedBox(height: 28),

                  // Buddy owl
                  const Text('🦉', style: TextStyle(fontSize: 90))
                      .animate(delay: 100.ms)
                      .scale(curve: Curves.elasticOut, duration: 700.ms),

                  const SizedBox(height: 8),

                  Text(
                    'Amazing work, Buddy!',
                    style: EP.head(24, color: EP.textDark),
                    textAlign: TextAlign.center,
                  ).animate(delay: 300.ms).fadeIn(),

                  const SizedBox(height: 6),

                  Text(
                    "You're doing great! Keep it up! 🌟",
                    style: EP.body(16, color: EP.textMid),
                    textAlign: TextAlign.center,
                  ).animate(delay: 400.ms).fadeIn(),

                  const SizedBox(height: 28),

                  // Stars earned
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: EP.yellowLt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: EP.yellow, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⭐⭐⭐',
                            style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Text(
                          '${widget.totalStarsEarned} Stars Earned!',
                          style: EP.head(18, color: EP.textDark),
                        ),
                      ],
                    ),
                  ).animate(delay: 450.ms).fadeIn().scale(),

                  const SizedBox(height: 28),

                  // Next lesson card
                  if (hasNext && nextLesson != null) ...[
                    _NextLessonCard(lesson: nextLesson!),
                    const SizedBox(height: 16),
                  ],

                  // Overall progress
                  _OverallProgress(
                    completed: completedCount,
                    total: allLessons.length,
                    fraction: progressFraction,
                  ).animate(delay: 500.ms).fadeIn(),

                  const SizedBox(height: 32),

                  // Action buttons
                  if (hasNext) ...[
                    EduButton(
                      label: 'Start Next Lesson',
                      onTap: widget.onStartNext,
                      color: EP.primary,
                      icon: Icons.play_arrow_rounded,
                      width: double.infinity,
                    ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.2),
                    const SizedBox(height: 12),
                  ] else ...[
                    // All lessons done
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [EP.primary, EP.teal],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: EP.colorShadow(EP.primary),
                      ),
                      child: Column(
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 8),
                          Text(
                            'All Lessons Completed!',
                            style: EP.head(20, color: Colors.white),
                          ),
                          Text(
                            'You are a champion! 🌟',
                            style: EP.body(15,
                                color: Colors.white.withOpacity(0.9)),
                          ),
                        ],
                      ),
                    ).animate(delay: 600.ms).fadeIn().scale(),
                    const SizedBox(height: 12),
                  ],

                  EduButton(
                    label: 'Back to Journey',
                    onTap: widget.onBackToJourney,
                    color: EP.primary,
                    outline: true,
                    icon: Icons.map_rounded,
                    width: double.infinity,
                  ).animate(delay: 700.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Next Lesson Preview Card ──────────────────────────────────────────────────

class _NextLessonCard extends StatelessWidget {
  final LessonInfo lesson;

  const _NextLessonCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final color = EP.lessonColor(lesson.number - 1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EP.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.35), width: 2),
        boxShadow: EP.colorShadow(color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(lesson.icon,
                    style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Lesson: Lesson ${lesson.number}',
                      style: EP.body(13, color: color, w: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lesson.title,
                      style: EP.head(17, color: EP.textDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lesson.description,
            style: EP.body(14, color: EP.textMid),
          ),
        ],
      ),
    ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.15);
  }
}

// ── Overall Progress Row ──────────────────────────────────────────────────────

class _OverallProgress extends StatelessWidget {
  final int completed;
  final int total;
  final double fraction;

  const _OverallProgress({
    required this.completed,
    required this.total,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Text('Overall Progress',
                  style: EP.head(15, color: EP.textDark)),
              Text(
                '$completed of $total lessons',
                style: EP.body(13,
                    color: EP.primary, w: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 14,
                backgroundColor: EP.divider,
                valueColor: AlwaysStoppedAnimation(EP.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(fraction * 100).round()}% complete',
            style: EP.body(13, color: EP.textLight),
          ),
        ],
      ),
    );
  }
}
