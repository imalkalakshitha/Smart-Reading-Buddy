import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dao/timed_reading_dao.dart';
import '../../data/timed_reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../router/app_router.dart';

/// Level Select — grade+language filtered, 5 cards (level1-5), same
/// visual pattern as Pronunciation's level-select
/// (pronunciation_home_screen.dart's _LevelCard: white card, 20px
/// radius, 0.5px divider border, accent-tinted icon tile).
///
/// Progress per level = count of completed sessions at that grade+
/// language+level (not unique dates — simpler, and multiple sessions in
/// one day are still real practice), relative to [_sessionsForFullBar].
/// No existing spec set that target, so it's a placeholder heuristic
/// (5 sessions = 100%) — easy to retune once real usage data exists.
class TimedReadingHomeScreen extends StatefulWidget {
  const TimedReadingHomeScreen({super.key});

  @override
  State<TimedReadingHomeScreen> createState() => _TimedReadingHomeScreenState();
}

class _TimedReadingHomeScreenState extends State<TimedReadingHomeScreen> {
  static const int _sessionsForFullBar = 5;
  static const _levels = ['level1', 'level2', 'level3', 'level4', 'level5'];

  bool _loading = true;
  final Map<String, double> _progressByLevel = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final isSinhala = AppState.language == 'sinhala';
    final grade = AppState.grade == 'grade4' ? 'grade4' : 'grade3';
    final language = isSinhala ? 'sinhala' : 'english';
    try {
      final rows = await TimedReadingDao.getRecentSessions(
        profileName: AppState.name,
        grade: grade,
        limit: 1000,
      );
      final counts = <String, int>{for (final l in _levels) l: 0};
      for (final r in rows) {
        if (r['language'] != language) continue;
        final level = r['level'] as String?;
        if (level != null && counts.containsKey(level)) counts[level] = counts[level]! + 1;
      }
      if (!mounted) return;
      setState(() {
        for (final l in _levels) {
          _progressByLevel[l] = ((counts[l] ?? 0) / _sessionsForFullBar * 100).clamp(0.0, 100.0);
        }
        _loading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('[TR] level progress query failed — showing all-locked-but-first until resolved: $e');
      if (!mounted) return;
      setState(() {
        for (final l in _levels) {
          _progressByLevel[l] = 0.0;
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSinhala = AppState.language == 'sinhala';
    final grade = AppState.grade == 'grade4' ? 'grade4' : 'grade3';
    final language = isSinhala ? 'sinhala' : 'english';
    const levels = _levels;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    isSinhala ? 'ඔබේ මට්ටම තෝරන්න' : 'Select Your Level',
                    style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.timedReading))
                    : ListView.separated(
                  itemCount: levels.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    final level = levels[i];
                    final progress = _progressByLevel[level] ?? 0.0;
                    final prevProgress = i == 0 ? 100.0 : (_progressByLevel[levels[i - 1]] ?? 0.0);
                    final locked = prevProgress < 80.0;
                    return _LevelSelectCard(
                      title: timedReadingLevelTitle(level, isSinhala),
                      progress: progress,
                      locked: locked,
                      isSinhala: isSinhala,
                      onTap: locked
                          ? null
                          : () {
                              final sentences = getTimedReadingSentences(
                                grade: grade,
                                language: language,
                                level: level,
                              );
                              Navigator.pushNamed(
                                context,
                                AppRouter.timedReadingSession,
                                arguments: ReadingScreenArgs(
                                  grade: grade,
                                  language: language,
                                  level: level,
                                  sentences: sentences,
                                ),
                              );
                            },
                    ).animate(delay: (i * 90).ms).fadeIn().slideY(begin: 0.15);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelSelectCard extends StatelessWidget {
  final String title;
  final double progress; // 0-100
  final bool locked;
  final bool isSinhala;
  final VoidCallback? onTap;

  const _LevelSelectCard({
    required this.title,
    required this.progress,
    required this.locked,
    required this.isSinhala,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final complete = progress >= 100.0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Opacity(
            opacity: locked ? 0.5 : 1.0,
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.timedReading.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      locked
                          ? Icons.lock_rounded
                          : (complete ? Icons.star_rounded : Icons.menu_book_rounded),
                      color: AppColors.timedReading,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      if (locked)
                        Text(
                          isSinhala ? 'අගුළු දමා ඇත' : 'Locked',
                          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textHint),
                        )
                      else ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress / 100.0,
                            minHeight: 8,
                            backgroundColor: AppColors.divider,
                            color: AppColors.timedReading,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${progress.round()}% ${isSinhala ? "සම්පූර්ණයි" : "Complete"}',
                          style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
