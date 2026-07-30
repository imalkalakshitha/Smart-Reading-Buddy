import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/writing_data.dart';
import '../../models/app_colors.dart';
import '../../services/writing_session_logger.dart';

// Mastery thresholds
const double _kMasteryAccuracy = 70.0;
const int _kMasteryMinSessions = 3;

class WritingProgressDashboard extends StatefulWidget {
  const WritingProgressDashboard({super.key});

  @override
  State<WritingProgressDashboard> createState() =>
      _WritingProgressDashboardState();
}

class _WritingProgressDashboardState extends State<WritingProgressDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  List<LetterMastery> _masteryEn = [];
  List<LetterMastery> _masterySi = [];
  List<SessionTrend> _trend = [];
  Map<String, int> _weeklyActivity = {};
  bool _loading = true;

  static const _profileId = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      WritingSessionLogger.getLetterMastery(_profileId, 'en'),
      WritingSessionLogger.getLetterMastery(_profileId, 'si'),
      WritingSessionLogger.getRecentTrend(_profileId),
      WritingSessionLogger.getWeeklyActivity(_profileId),
    ]);
    if (mounted) {
      setState(() {
        _masteryEn = results[0] as List<LetterMastery>;
        _masterySi = results[1] as List<LetterMastery>;
        _trend = results[2] as List<SessionTrend>;
        _weeklyActivity = results[3] as Map<String, int>;
        _loading = false;
      });
    }
  }

  // ── Unlock logic ─────────────────────────────────────────────────────────────

  Set<int> _unlockedLevels(String lang, List<LetterMastery> mastery) {
    final levels = letterLevels[lang] ?? [];
    final unlocked = <int>{0}; // Level 0 always unlocked
    for (int i = 1; i < levels.length; i++) {
      final prev = levels[i - 1];
      final allMastered = prev.every((letter) {
        final m = mastery.firstWhere(
          (m) => m.letter == letter,
          orElse: () => const LetterMastery(
            letter: '',
            averageAccuracy: 0,
            sessionCount: 0,
            avgAttemptsToPass: 1,
            avgCompletionSecs: 0,
          ),
        );
        return m.averageAccuracy >= _kMasteryAccuracy &&
            m.sessionCount >= _kMasteryMinSessions;
      });
      if (allMastered) {
        unlocked.add(i);
      } else {
        break;
      }
    }
    return unlocked;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.writing,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Writing Progress',
          style: GoogleFonts.nunito(
              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelStyle:
              GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800),
          unselectedLabelStyle:
              GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'English'),
            Tab(text: 'සිංහල'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.writing))
          : TabBarView(
              controller: _tab,
              children: [
                _LangTab(
                  language: 'en',
                  mastery: _masteryEn,
                  trend: _trend,
                  weeklyActivity: _weeklyActivity,
                  unlockedLevels: _unlockedLevels('en', _masteryEn),
                ),
                _LangTab(
                  language: 'si',
                  mastery: _masterySi,
                  trend: _trend,
                  weeklyActivity: _weeklyActivity,
                  unlockedLevels: _unlockedLevels('si', _masterySi),
                ),
              ],
            ),
    );
  }
}

// ── Per-language tab content ──────────────────────────────────────────────────

class _LangTab extends StatelessWidget {
  final String language;
  final List<LetterMastery> mastery;
  final List<SessionTrend> trend;
  final Map<String, int> weeklyActivity;
  final Set<int> unlockedLevels;

  const _LangTab({
    required this.language,
    required this.mastery,
    required this.trend,
    required this.weeklyActivity,
    required this.unlockedLevels,
  });

  bool get _isSi => language == 'si';

  int get _masteredCount =>
      mastery.where((m) => m.isMastered).length;

  int get _startedCount =>
      mastery.where((m) => m.isStarted && !m.isMastered).length;

  List<LetterMastery> get _needsPractice {
    final started = mastery.where((m) => m.isStarted).toList()
      ..sort((a, b) => a.averageAccuracy.compareTo(b.averageAccuracy));
    return started.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final levels = letterLevels[language] ?? [];
    final totalLetters = _isSi
        ? sinhalaLetters.length
        : englishLetters.length;

    if (mastery.isEmpty && trend.isEmpty) {
      return _EmptyState(isSi: _isSi);
    }

    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.writing,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // ── Overview ────────────────────────────────────────────────────────
          _OverviewRow(
            masteredCount: _masteredCount,
            inProgressCount: _startedCount,
            totalLetters: totalLetters,
            weeklyActivity: weeklyActivity,
            isSi: _isSi,
          ).animate().fadeIn().slideY(begin: -0.15),

          const SizedBox(height: 16),

          // ── Weekly activity dots ─────────────────────────────────────────
          _WeeklyActivityCard(activity: weeklyActivity, isSi: _isSi)
              .animate().fadeIn(delay: 80.ms),

          const SizedBox(height: 16),

          // ── Level progression ────────────────────────────────────────────
          _SectionLabel(
            icon: '🔓',
            label: _isSi ? 'මට්ටම් ප්‍රගතිය' : 'Level Progression',
          ),
          const SizedBox(height: 8),
          _LevelProgressionCard(
            language: language,
            levels: levels,
            mastery: mastery,
            unlockedLevels: unlockedLevels,
            isSi: _isSi,
          ).animate().fadeIn(delay: 120.ms),

          const SizedBox(height: 16),

          // ── Needs most practice ──────────────────────────────────────────
          if (_needsPractice.isNotEmpty) ...[
            _SectionLabel(
              icon: '💪',
              label: _isSi ? 'වැඩිම පුහුණුව අවශ්‍ය' : 'Needs Most Practice',
            ),
            const SizedBox(height: 8),
            _NeedsPracticeCard(letters: _needsPractice, isSi: _isSi)
                .animate().fadeIn(delay: 160.ms),
            const SizedBox(height: 16),
          ],

          // ── Accuracy trend ───────────────────────────────────────────────
          if (trend.isNotEmpty) ...[
            _SectionLabel(
              icon: '📈',
              label: _isSi ? 'නිරවද්‍යතා ප්‍රවණතාව' : 'Accuracy Trend (14 days)',
            ),
            const SizedBox(height: 8),
            _TrendChart(trend: trend).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 16),
          ],

          // ── Letter mastery grid ─────────────────────────────────────────
          _SectionLabel(
            icon: '🔤',
            label: _isSi ? 'අකුරු ප්‍රාවීණ්‍යතා' : 'Letter Mastery',
          ),
          const SizedBox(height: 4),
          _LegendRow(),
          const SizedBox(height: 8),
          _LetterMasteryGrid(
            language: language,
            mastery: mastery,
            isSi: _isSi,
          ).animate().fadeIn(delay: 240.ms),

          const SizedBox(height: 16),

          // ── Recommendations ──────────────────────────────────────────────
          _RecommendationsCard(
            mastery: mastery,
            levels: levels,
            unlockedLevels: unlockedLevels,
            isSi: _isSi,
          ).animate().fadeIn(delay: 280.ms),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      );
}

// ── Card wrapper ──────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: child,
      );
}

// ── Overview row ──────────────────────────────────────────────────────────────

class _OverviewRow extends StatelessWidget {
  final int masteredCount;
  final int inProgressCount;
  final int totalLetters;
  final Map<String, int> weeklyActivity;
  final bool isSi;

  const _OverviewRow({
    required this.masteredCount,
    required this.inProgressCount,
    required this.totalLetters,
    required this.weeklyActivity,
    required this.isSi,
  });

  int get _weeklySessions =>
      weeklyActivity.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          value: '$masteredCount/$totalLetters',
          label: isSi ? 'ප්‍රාවීණ' : 'Mastered',
          icon: '⭐',
          color: AppColors.success,
        ),
        const SizedBox(width: 10),
        _StatTile(
          value: '$inProgressCount',
          label: isSi ? 'ප්‍රගතිය' : 'In Progress',
          icon: '⚡',
          color: AppColors.almost,
        ),
        const SizedBox(width: 10),
        _StatTile(
          value: '$_weeklySessions',
          label: isSi ? 'මෙ සතිය' : 'This Week',
          icon: '📅',
          color: AppColors.writing,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  final Color color;

  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(value,
                  style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color)),
              Text(label,
                  style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

// ── Weekly activity dots ──────────────────────────────────────────────────────

class _WeeklyActivityCard extends StatelessWidget {
  final Map<String, int> activity;
  final bool isSi;
  const _WeeklyActivityCard({required this.activity, required this.isSi});

  @override
  Widget build(BuildContext context) {
    // Build last 7 days
    final days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return (d, activity[key] ?? 0);
    });

    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSi ? '📅 සතිය තුළ පුහුණුව' : '📅 Practice This Week',
            style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: days.asMap().entries.map((entry) {
              final idx = entry.key;
              final sessions = entry.value.$2;
              final active = sessions > 0;
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.writing
                          : AppColors.divider,
                      shape: BoxShape.circle,
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppColors.writing.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: active
                          ? Text(
                              '$sessions',
                              style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white),
                            )
                          : const SizedBox(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayLabels[idx],
                    style: GoogleFonts.nunito(
                        fontSize: 10, color: AppColors.textHint),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Level progression ─────────────────────────────────────────────────────────

class _LevelProgressionCard extends StatelessWidget {
  final String language;
  final List<List<String>> levels;
  final List<LetterMastery> mastery;
  final Set<int> unlockedLevels;
  final bool isSi;

  const _LevelProgressionCard({
    required this.language,
    required this.levels,
    required this.mastery,
    required this.unlockedLevels,
    required this.isSi,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: levels.asMap().entries.map((entry) {
          final idx = entry.key;
          final letters = entry.value;
          final unlocked = unlockedLevels.contains(idx);

          final masteredInLevel = letters.where((letter) {
            final m = mastery.firstWhere(
              (m) => m.letter == letter,
              orElse: () => const LetterMastery(
                letter: '',
                averageAccuracy: 0,
                sessionCount: 0,
                avgAttemptsToPass: 1,
                avgCompletionSecs: 0,
              ),
            );
            return m.isMastered;
          }).length;

          final progress = masteredInLevel / letters.length;
          final allMastered = masteredInLevel == letters.length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      allMastered
                          ? '✅'
                          : unlocked
                              ? '🔓'
                              : '🔒',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSi
                          ? 'මට්ටම ${idx + 1}'
                          : 'Level ${idx + 1}',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: unlocked
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      letters.take(4).join(' ') +
                          (letters.length > 4 ? '…' : ''),
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$masteredInLevel/${letters.length}',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: allMastered
                            ? AppColors.success
                            : AppColors.writing,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: unlocked ? progress : 0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation(
                        allMastered ? AppColors.success : AppColors.writing,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Needs practice card ───────────────────────────────────────────────────────

class _NeedsPracticeCard extends StatelessWidget {
  final List<LetterMastery> letters;
  final bool isSi;
  const _NeedsPracticeCard({required this.letters, required this.isSi});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: letters.map((m) {
          final color = _colorFor(m.averageAccuracy);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(m.letter,
                            maxLines: 1,
                            style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: color)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${m.averageAccuracy.round()}%',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                  Text(
                    '${m.avgAttemptsToPass.toStringAsFixed(1)}× tries',
                    style: GoogleFonts.nunito(
                        fontSize: 10, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _colorFor(double acc) {
    if (acc >= 70) return AppColors.success;
    if (acc >= 50) return AppColors.almost;
    return AppColors.wrong;
  }
}

// ── Accuracy trend chart ──────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<SessionTrend> trend;
  const _TrendChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    final spots = trend.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.accuracy))
        .toList();

    return _Card(
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 100,
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.divider, strokeWidth: 1),
              drawVerticalLine: false,
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 25,
                  getTitlesWidget: (v, _) => Text('${v.round()}%',
                      style: GoogleFonts.nunito(
                          fontSize: 10, color: AppColors.textHint)),
                ),
              ),
              bottomTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.writing,
                barWidth: 3,
                dotData: FlDotData(
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.writing,
                    strokeColor: Colors.white,
                    strokeWidth: 1.5,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.writing.withOpacity(0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Letter mastery grid ───────────────────────────────────────────────────────

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        children: [
          _LegendDot(color: AppColors.success, label: 'Mastered'),
          const SizedBox(width: 12),
          _LegendDot(color: AppColors.almost, label: 'Practicing'),
          const SizedBox(width: 12),
          _LegendDot(color: AppColors.divider, label: 'Not started'),
        ],
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      );
}

class _LetterMasteryGrid extends StatelessWidget {
  final String language;
  final List<LetterMastery> mastery;
  final bool isSi;

  const _LetterMasteryGrid({
    required this.language,
    required this.mastery,
    required this.isSi,
  });

  @override
  Widget build(BuildContext context) {
    final allLetters =
        language == 'si' ? sinhalaLetters : englishLetters;

    return _Card(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: allLetters.map((letter) {
          final m = mastery.firstWhere(
            (m) => m.letter == letter,
            orElse: () => const LetterMastery(
              letter: '',
              averageAccuracy: 0,
              sessionCount: 0,
              avgAttemptsToPass: 1,
              avgCompletionSecs: 0,
            ),
          );

          final Color bg;
          final Color fg;
          final String badge;

          if (!m.isStarted) {
            bg = AppColors.divider;
            fg = AppColors.textHint;
            badge = '';
          } else if (m.isMastered) {
            bg = AppColors.success.withOpacity(0.15);
            fg = AppColors.success;
            badge = '✓';
          } else {
            bg = AppColors.almost.withOpacity(0.15);
            fg = AppColors.almost;
            badge = '⚡';
          }

          return Tooltip(
            message: m.isStarted
                ? '${m.averageAccuracy.round()}% · ${m.sessionCount} sessions · '
                    '${m.avgAttemptsToPass.toStringAsFixed(1)}× tries'
                : 'Not practiced yet',
            child: Container(
              width: 52,
              height: 58,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(10)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(letter,
                        maxLines: 1,
                        style: GoogleFonts.nunito(
                            fontSize: isSi ? 14 : 16,
                            fontWeight: FontWeight.w900,
                            color: fg)),
                  ),
                  if (badge.isNotEmpty)
                    Text(badge,
                        style: TextStyle(fontSize: 10, color: fg)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Recommendations card ──────────────────────────────────────────────────────

class _RecommendationsCard extends StatelessWidget {
  final List<LetterMastery> mastery;
  final List<List<String>> levels;
  final Set<int> unlockedLevels;
  final bool isSi;

  const _RecommendationsCard({
    required this.mastery,
    required this.levels,
    required this.unlockedLevels,
    required this.isSi,
  });

  String get _nextLevelHint {
    for (int i = 0; i < levels.length; i++) {
      if (!unlockedLevels.contains(i + 1) && i + 1 < levels.length) {
        final current = levels[i];
        final remaining = current.where((letter) {
          final m = mastery.firstWhere(
            (m) => m.letter == letter,
            orElse: () => const LetterMastery(
              letter: '',
              averageAccuracy: 0,
              sessionCount: 0,
              avgAttemptsToPass: 1,
              avgCompletionSecs: 0,
            ),
          );
          return !m.isMastered;
        }).toList();
        if (remaining.isEmpty) return '';
        final count = remaining.length;
        return isSi
            ? 'මට්ටම ${i + 2} අගුළු ඇරීමට $count අකුරු ප්‍රාවීණ කරන්න'
            : 'Master $count more letter${count > 1 ? 's' : ''} to unlock Level ${i + 2}';
      }
    }
    return isSi ? 'සියලු මට්ටම් අගුළු ඇරී ඇත!' : 'All levels unlocked!';
  }

  List<String> get _focusLetters {
    final struggling = mastery
        .where((m) => m.isStarted && m.averageAccuracy < 70)
        .toList()
      ..sort((a, b) => a.averageAccuracy.compareTo(b.averageAccuracy));
    return struggling.take(3).map((m) => m.letter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final focus = _focusLetters;
    final hint = _nextLevelHint;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.writing, const Color(0xFF6C3483)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.writing.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                isSi ? 'නිර්දේශ' : 'Recommendations',
                style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (focus.isNotEmpty) ...[
            Text(
              isSi
                  ? ' අවධානය: ${focus.join(', ')} – දිනපතා 5 min'
                  : 'Focus: ${focus.join(', ')} — practice 5 min daily',
              style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.95),
                  height: 1.4),
            ),
            const SizedBox(height: 8),
          ],
          if (hint.isNotEmpty)
            Text(
              hint,
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.4),
            ),
          const SizedBox(height: 10),
          Text(
            isSi
                ? '• සෑම දිනකම ටිකක් කාලය ගන්න\n• හොඳ කාර්ය සාධනය සමරන්න'
                : '• Celebrate each mastered letter\n• Short daily sessions beat long weekly ones',
            style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.white.withOpacity(0.80),
                height: 1.7),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSi;
  const _EmptyState({required this.isSi});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✏️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              isSi ? 'දත්ත නොමැත' : 'No data yet',
              style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              isSi
                  ? 'ලිවීම් සැසියක් සම්පූර්ණ කරන්න.'
                  : 'Complete a writing session\nto see progress here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}
