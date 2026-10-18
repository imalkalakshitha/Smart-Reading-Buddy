import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/dao/number_learning_dao.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/core/services/numbers/level_config.dart';
import 'package:smart_reading_buddy/core/services/numbers/level_progress.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/number_learning_session_screen.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/number_match_session_screen.dart';

const _activityLabels = {
  ActivityType.recognition: 'Listen and find',
  ActivityType.build: 'Build the number',
  ActivityType.counting: 'Count',
  ActivityType.ordering: 'Number train',
  ActivityType.formation: 'Make a number',
  ActivityType.patterns: 'Patterns',
  ActivityType.calculation: 'Calculate',
  ActivityType.placeValue: 'Place value',
  ActivityType.spellWord: 'Spell the word',
  ActivityType.numberMatch: 'Memory match',
  ActivityType.readAnswer: 'Read and answer',
};

/// Levels of one track with ✓ (passed) / 🔒 (locked) / ▶ (open) states.
class NumberLevelListScreen extends StatefulWidget {
  final int grade;
  final String track;
  final List<LevelConfig> levels;
  final bool trackUnlocked;

  /// App bar title; defaults to "Grade N · Basic/Advanced".
  final String? title;

  const NumberLevelListScreen({
    super.key,
    required this.grade,
    required this.track,
    required this.levels,
    required this.trackUnlocked,
    this.title,
  });

  @override
  State<NumberLevelListScreen> createState() => _NumberLevelListScreenState();
}

class _NumberLevelListScreenState extends State<NumberLevelListScreen> {
  Map<String, int>? _best;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final best = await NumberLearningDao.bestScores(AppState.name);
    if (mounted) setState(() => _best = best);
  }

  Future<void> _play(LevelConfig level) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => level.activityType == ActivityType.numberMatch
          ? NumberMatchSessionScreen(level: level)
          : NumberLearningSessionScreen(level: level),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final best = _best;
    final title = widget.track == Track.basic ? 'Basic' : 'Advanced';
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: LearningColors.accent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title ?? 'Grade ${widget.grade} · $title',
          style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: best == null
            ? const Center(child: CircularProgressIndicator(color: LearningColors.accent))
            : Builder(builder: (context) {
                final states = LevelProgressRules.states(
                  widget.levels,
                  best,
                  trackUnlocked: widget.trackUnlocked,
                );
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: widget.levels.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final level = widget.levels[i];
                    final state = states[level.id]!;
                    return _LevelTile(
                      level: level,
                      state: state,
                      best: best[level.id],
                      onTap: state == LevelState.unlocked || state == LevelState.passed
                          ? () => _play(level)
                          : null,
                    ).animate(delay: (60 * i).ms).fadeIn().slideY(begin: 0.25);
                  },
                );
              }),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final LevelConfig level;
  final LevelState state;
  final int? best;
  final VoidCallback? onTap;

  const _LevelTile({required this.level, required this.state, required this.best, this.onTap});

  @override
  Widget build(BuildContext context) {
    final playable = state == LevelState.unlocked || state == LevelState.passed;
    final (Widget trailing, String subtitle) = switch (state) {
      LevelState.passed => (
          const Text('✓', style: TextStyle(fontSize: 30, color: LearningColors.correct, fontWeight: FontWeight.w900)),
          'Best: ${best ?? 0} / ${LevelProgressRules.questionsPerSession}',
        ),
      LevelState.unlocked => (
          const Icon(Icons.play_circle_fill_rounded, size: 38, color: LearningColors.accent),
          best == null
              ? 'Get ${LevelProgressRules.passScore} / 10 to pass'
              : 'Best: $best / 10 — get ${LevelProgressRules.passScore} to pass',
        ),
      LevelState.locked => (const Text('🔒', style: TextStyle(fontSize: 28)), 'Pass the level before'),
      LevelState.comingSoon => (const Text('🚧', style: TextStyle(fontSize: 26)), 'Coming soon'),
    };

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: playable ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: state == LevelState.passed ? LearningColors.correctSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: state == LevelState.passed ? LearningColors.correct : AppColors.divider,
              width: state == LevelState.passed ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LearningColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${level.level}',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.title,
                      style: GoogleFonts.nunito(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _activityLabels[level.activityType] ?? level.activityType,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: LearningColors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
