import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/features/numbers/dao/number_learning_dao.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/features/numbers/services/learner_grade.dart';
import 'package:smart_reading_buddy/features/numbers/services/level_config.dart';
import 'package:smart_reading_buddy/features/numbers/services/level_progress.dart';
import 'package:smart_reading_buddy/features/numbers/screens/numbers_hub_screen.dart' show EnglishOnlyNote;
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/number_level_list_screen.dart';

/// Number Learning entry: Basic / Advanced for the child's own grade (from
/// their profile — there is no grade picker). Advanced opens once every
/// playable Basic level is passed.
class NumberLearningScreen extends StatefulWidget {
  const NumberLearningScreen({super.key});

  @override
  State<NumberLearningScreen> createState() => _NumberLearningScreenState();
}

class _NumberLearningScreenState extends State<NumberLearningScreen> {
  final LearnerGrade _grade = LearnerGrade.fromProfile(AppState.grade);
  List<LevelConfig>? _basic;
  List<LevelConfig>? _advanced;
  Map<String, int> _best = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await LevelRepository.load();
    final best = await NumberLearningDao.bestScores(AppState.name);
    if (!mounted) return;
    setState(() {
      _basic = LevelRepository.forTrack(all, _grade.grade, Track.basic);
      _advanced = LevelRepository.forTrack(all, _grade.grade, Track.advanced);
      _best = best;
    });
  }

  Future<void> _open(String track, List<LevelConfig> levels, bool trackUnlocked) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NumberLevelListScreen(
        grade: _grade.grade,
        track: track,
        levels: levels,
        trackUnlocked: trackUnlocked,
      ),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final basic = _basic;
    final advanced = _advanced;
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
          'Number Learning',
          style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: basic == null || advanced == null
            ? const Center(child: CircularProgressIndicator(color: LearningColors.accent))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (AppState.language == 'sinhala') ...[
                    const EnglishOnlyNote(),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'Grade ${_grade.grade}',
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_grade.defaulted) ...[
                    const SizedBox(height: 4),
                    Text(
                      'No grade on this profile yet — showing Grade 3.',
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _TrackCard(
                    emoji: '🌱',
                    title: 'Basic',
                    levels: basic,
                    best: _best,
                    unlocked: true,
                    onTap: () => _open(Track.basic, basic, true),
                  ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.3),
                  const SizedBox(height: 16),
                  Builder(builder: (context) {
                    final open = LevelProgressRules.trackComplete(basic, _best);
                    return _TrackCard(
                      emoji: '🚀',
                      title: 'Advanced',
                      levels: advanced,
                      best: _best,
                      unlocked: open,
                      lockedHint: 'Finish all Basic levels to open',
                      onTap: open ? () => _open(Track.advanced, advanced, true) : null,
                    ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.3);
                  }),
                ],
              ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final String emoji;
  final String title;
  final List<LevelConfig> levels;
  final Map<String, int> best;
  final bool unlocked;
  final String? lockedHint;
  final VoidCallback? onTap;

  const _TrackCard({
    required this.emoji,
    required this.title,
    required this.levels,
    required this.best,
    required this.unlocked,
    this.lockedHint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final playable = levels.where(LevelProgressRules.isPlayable).toList();
    final passed = playable.where((l) => (best[l.id] ?? 0) >= LevelProgressRules.passScore).length;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: unlocked ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.divider),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Text(unlocked ? emoji : '🔒', style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unlocked
                          ? '$passed of ${playable.length} levels passed'
                          : (lockedHint ?? 'Locked'),
                      style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (unlocked)
                const Icon(Icons.arrow_forward_ios_rounded, color: LearningColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
