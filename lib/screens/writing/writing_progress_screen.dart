import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/writing_data.dart';
import '../../models/app_colors.dart';
import '../../services/writing_session_logger.dart';

class WritingProgressScreen extends StatefulWidget {
  final WritingArgs args;
  const WritingProgressScreen({super.key, required this.args});

  @override
  State<WritingProgressScreen> createState() => _WritingProgressScreenState();
}

class _WritingProgressScreenState extends State<WritingProgressScreen> {
  List<LetterAccuracy> _accuracies = [];
  List<LetterAccuracy> _hardest = [];
  List<SessionTrend> _trend = [];
  int _totalXp = 0;
  bool _loading = true;

  bool get _isSi => widget.args.isSinhala;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pid = widget.args.profileId;
    final lang = widget.args.language;
    final results = await Future.wait([
      WritingSessionLogger.getLetterAccuracies(pid, lang),
      WritingSessionLogger.getHardestLetters(pid, lang, limit: 5),
      WritingSessionLogger.getRecentTrend(pid),
      WritingSessionLogger.getTotalXp(pid),
    ]);
    if (mounted) {
      setState(() {
        _accuracies = results[0] as List<LetterAccuracy>;
        _hardest    = results[1] as List<LetterAccuracy>;
        _trend      = results[2] as List<SessionTrend>;
        _totalXp    = results[3] as int;
        _loading    = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.writing,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isSi ? 'ලිවීම් ප්‍රගතිය' : 'Writing Progress',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.writing))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.writing,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary row
                    _SummaryRow(totalXp: _totalXp, sessionsCount: _accuracies.fold(0, (s, a) => s + a.sessionCount), isSi: _isSi)
                        .animate().fadeIn().slideY(begin: -0.2),

                    const SizedBox(height: 20),

                    // Trend chart
                    if (_trend.isNotEmpty) ...[
                      _sectionLabel(_isSi ? '📈 ප්‍රගති ප්‍රස්තාරය' : '📈 Accuracy Trend'),
                      const SizedBox(height: 10),
                      _TrendChart(trend: _trend).animate().fadeIn(delay: 100.ms),
                      const SizedBox(height: 20),
                    ],

                    // Hardest letters
                    if (_hardest.isNotEmpty) ...[
                      _sectionLabel(_isSi ? '💪 දුෂ්කරම අකුරු' : '💪 Needs Most Practice'),
                      const SizedBox(height: 10),
                      _HardestLetters(letters: _hardest).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: 20),
                    ],

                    // Letter grid
                    _sectionLabel(_isSi ? '🔤 අකුරු නිරවද්‍යතාව' : '🔤 Letter Accuracy Grid'),
                    const SizedBox(height: 10),
                    _accuracies.isEmpty
                        ? _EmptyState(isSi: _isSi).animate().fadeIn(delay: 200.ms)
                        : _LetterGrid(accuracies: _accuracies).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 20),

                    // Buddy encouragement
                    _BuddyEncouragement(
                      totalSessions: _accuracies.fold(0, (s, a) => s + a.sessionCount),
                      isSi: _isSi,
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
  );
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int totalXp;
  final int sessionsCount;
  final bool isSi;
  const _SummaryRow({required this.totalXp, required this.sessionsCount, required this.isSi});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(icon: '⚡', label: '$totalXp XP', color: AppColors.wordBuilding),
        const SizedBox(width: 12),
        _StatChip(icon: '✏️', label: '$sessionsCount ${isSi ? "වාර" : "sessions"}', color: AppColors.writing),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Trend chart ───────────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<SessionTrend> trend;
  const _TrendChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    final spots = trend.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.accuracy)).toList();

    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 25,
                getTitlesWidget: (v, _) => Text('${v.round()}%',
                    style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textHint)),
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
    );
  }
}

// ── Hardest letters ───────────────────────────────────────────────────────────

class _HardestLetters extends StatelessWidget {
  final List<LetterAccuracy> letters;
  const _HardestLetters({required this.letters});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: letters.map((la) {
          final color = _colorFor(la.averageAccuracy);
          return Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(la.letter,
                    style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: color))),
              ),
              const SizedBox(height: 4),
              Text('${la.averageAccuracy.round()}%',
                  style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
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

// ── Letter grid ───────────────────────────────────────────────────────────────

class _LetterGrid extends StatelessWidget {
  final List<LetterAccuracy> accuracies;
  const _LetterGrid({required this.accuracies});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: accuracies.map((la) {
          final color = _colorFor(la.averageAccuracy);
          return Tooltip(
            message: '${la.averageAccuracy.round()}% (${la.sessionCount}x)',
            child: Container(
              width: 48, height: 52,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(la.letter,
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                  Text('${la.averageAccuracy.round()}%',
                      style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSi;
  const _EmptyState({required this.isSi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Text('✏️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(isSi ? 'තවම ලිවීම් ආරම්භ කර නැත' : 'No writing sessions yet',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Buddy encouragement ───────────────────────────────────────────────────────

class _BuddyEncouragement extends StatelessWidget {
  final int totalSessions;
  final bool isSi;
  const _BuddyEncouragement({required this.totalSessions, required this.isSi});

  String get _message {
    if (totalSessions == 0) return isSi ? 'ලිවීම ආරම්භ කරන්න! ✏️' : "Let's start writing practice! ✏️";
    if (totalSessions < 5) return isSi ? 'හොඳ ආරම්භයක්! දිගටම ලියන්න! 🌟' : 'Great start! Keep practicing! 🌟';
    if (totalSessions < 20) return isSi ? 'ඔබ දියුණු වෙමින් සිටී! ⭐' : "You're improving every day! ⭐";
    return isSi ? 'ඔබ ලිවීමේ ශූරයෙකු! 🏆' : "You're a writing champion! 🏆";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.writing, const Color(0xFF6C3483)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.writing.withOpacity(0.38), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Center(child: Text('🦉', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(_message,
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
