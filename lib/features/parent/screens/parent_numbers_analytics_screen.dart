import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_text.dart';
import 'package:smart_reading_buddy/features/parent/services/numbers_summary.dart';

/// Parent view of one child's Numbers work: Number Learning progress,
/// accuracy by activity, Number Words (incl. -teen/-ty confusions), Rapid
/// Digit Naming speed, and what needs practice. Labels are English (there
/// are no Sinhala strings for these yet); grade labels use AppText.
class ParentNumbersAnalyticsScreen extends StatefulWidget {
  final String profileName;

  const ParentNumbersAnalyticsScreen({super.key, required this.profileName});

  @override
  State<ParentNumbersAnalyticsScreen> createState() => _ParentNumbersAnalyticsScreenState();
}

/// Calm parent-facing accent for Numbers (amber), alongside the dashboard's
/// indigo / pink / teal module accents.
const kNumbersAccent = Color(0xFFD97706);
const kNumbersTint = Color(0xFFFEF3E2);

class _ParentNumbersAnalyticsScreenState extends State<ParentNumbersAnalyticsScreen> {
  NumbersSummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await NumbersSummaryLoader.load(widget.profileName);
      if (mounted) setState(() => _summary = s);
    } catch (e) {
      debugPrint('[ParentNumbers] load failed: $e');
      if (mounted) setState(() => _error = "Couldn't load Numbers progress.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Numbers',
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_error != null) return Center(child: Text(_error!, style: _bodyStyle));
    final s = _summary;
    if (s == null) return const Center(child: CircularProgressIndicator(color: kNumbersAccent));
    if (!s.hasData) return const _EmptyState();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _headerStats(s),
        const SizedBox(height: 16),
        _Card(title: 'Number Learning progress', child: _progress(s)),
        if (s.byActivity.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Card(title: 'Accuracy by activity', subtitle: 'Answered right on the first try', child: _activityChart(s)),
        ],
        if (s.numberWordsByLevel.isNotEmpty || s.teenTyConfusions > 0) ...[
          const SizedBox(height: 16),
          _Card(title: 'Number Words', child: _numberWords(s)),
        ],
        if (s.ran.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Card(title: 'Rapid Digit Naming', subtitle: 'Correct digits per second', child: _ran(s)),
        ],
        const SizedBox(height: 16),
        _Card(title: 'Needs practice', child: _needs(s)),
      ],
    );
  }

  // ── Header ───────────────────────────────────────────────────────────

  Widget _headerStats(NumbersSummary s) {
    final rate = s.overall.rate;
    final gradeLabel = s.grade == 4 ? AppText.grade4 : AppText.grade3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.gradeDefaulted ? '$gradeLabel (no grade on the profile)' : gradeLabel,
          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Overall accuracy', value: rate == null ? '–' : _pct(rate))),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Basic passed', value: '${s.basicPassed}/${s.basicTotal}')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Advanced passed', value: '${s.advancedPassed}/${s.advancedTotal}')),
          ],
        ),
      ],
    );
  }

  // ── Level progress ───────────────────────────────────────────────────

  Widget _progress(NumbersSummary s) {
    const practiceNames = {
      'spell_words': 'Spell Number Words',
      'number_match': 'Number Match',
      'read_answer': 'Read & Answer',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupTitle('Basic'),
        for (final r in s.basic) _LevelRowTile(row: r),
        const SizedBox(height: 10),
        _groupTitle('Advanced'),
        for (final r in s.advanced) _LevelRowTile(row: r),
        for (final entry in s.practice.entries)
          if (entry.value.any((r) => r.attempts > 0)) ...[
            const SizedBox(height: 10),
            _groupTitle(practiceNames[entry.key] ?? entry.key),
            for (final r in entry.value) _LevelRowTile(row: r),
          ],
      ],
    );
  }

  Widget _groupTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: kNumbersAccent)),
      );

  // ── Accuracy by activity (bar chart) ─────────────────────────────────

  Widget _activityChart(NumbersSummary s) {
    final entries = s.byActivity.entries.toList();
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: 100,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 50,
                getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
              ),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: 50,
                    getTitlesWidget: (v, _) => Text('${v.round()}%', style: _axisStyle),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(NumbersSummaryBuilder.activityShortLabels[entries[i].key] ?? '', style: _axisStyle),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < entries.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: (entries[i].value.rate ?? 0) * 100,
                      width: entries.length > 8 ? 12 : 18,
                      color: kNumbersAccent,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final e in entries)
          _ValueRow(
            label: NumbersSummaryBuilder.activityLabels[e.key] ?? e.key,
            detail: '${e.value.correct}/${e.value.total}',
            value: _pct(e.value.rate!),
          ),
      ],
    );
  }

  // ── Number Words ─────────────────────────────────────────────────────

  Widget _numberWords(NumbersSummary s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in s.numberWordsByLevel.entries)
          _ProgressRow(
            label: NumbersSummaryBuilder.numberWordsLevelLabel(e.key),
            rate: e.value.rate!,
            detail: '${e.value.correct}/${e.value.total}',
          ),
        const SizedBox(height: 8),
        Text(
          '-teen / -ty mix-ups: ${s.teenTyConfusions}',
          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        if (s.confusedPairs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in s.confusedPairs)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: kNumbersTint, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${p.label}  ×${p.count}',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: kNumbersAccent),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Rapid Digit Naming (line chart) ──────────────────────────────────

  Widget _ran(NumbersSummary s) {
    final latest = s.latestRan!;
    final values = s.ran.map((r) => r.digitsPerSecond).toList();
    final dataMin = values.reduce((a, b) => a < b ? a : b);
    final dataMax = values.reduce((a, b) => a > b ? a : b);
    final pad = ((dataMax - dataMin) * 0.2).clamp(0.3, double.infinity);
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              minY: (dataMin - pad).clamp(0.0, double.infinity),
              maxY: dataMax + pad,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1), style: _axisStyle),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= s.ran.length || v != i.toDouble()) return const SizedBox.shrink();
                      final d = s.ran[i].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${d.month}/${d.day}', style: _axisStyle),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
                  isCurved: values.length > 2,
                  color: kNumbersAccent,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: kNumbersAccent.withValues(alpha: 0.08)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Latest speed', value: '${latest.digitsPerSecond.toStringAsFixed(1)}/s')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Latest time', value: '${(latest.totalMs / 1000).toStringAsFixed(1)}s')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: 'Latest mistakes', value: '${latest.errors}')),
          ],
        ),
      ],
    );
  }

  // ── Needs practice ───────────────────────────────────────────────────

  Widget _needs(NumbersSummary s) {
    if (s.needsPractice.isEmpty) {
      return Text(
        'Nothing stands out yet — keep going! (Shown once an activity has at least '
        '${NumbersSummaryBuilder.minRecentAttempts} answers.)',
        style: _bodyStyle,
      );
    }
    return Column(
      children: [
        for (final n in s.needsPractice)
          _ProgressRow(label: n.label, rate: n.recent.rate!, detail: 'last ${n.recent.total}'),
      ],
    );
  }
}

String _pct(double rate) => '${(rate * 100).round()}%';

final _bodyStyle = GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600);
final _axisStyle = GoogleFonts.nunito(fontSize: 10, color: AppColors.textHint);

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _Card({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          if (subtitle != null)
            Text(subtitle!, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _LevelRowTile extends StatelessWidget {
  final NumberLevelRow row;

  const _LevelRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final (String chip, Color fg, Color bg) = switch (row.status) {
      NumberLevelStatus.passed => ('✓ Passed', AppColors.success, const Color(0xFFE8F8EF)),
      NumberLevelStatus.inProgress => ('In progress', kNumbersAccent, kNumbersTint),
      NumberLevelStatus.notStarted => ('Not started', AppColors.textSecondary, const Color(0xFFF3F4F6)),
      NumberLevelStatus.locked => ('🔒 Locked', AppColors.textHint, const Color(0xFFF3F4F6)),
      NumberLevelStatus.comingSoon => ('Coming soon', AppColors.textHint, const Color(0xFFF3F4F6)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text('${row.level.level}', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              row.level.title,
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          if (row.best != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('${row.best}/10', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Text(chip, style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String detail;
  final String value;

  const _ValueRow({required this.label, required this.detail, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          Text(detail, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(value,
                textAlign: TextAlign.right,
                style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double rate;
  final String detail;

  const _ProgressRow({required this.label, required this.rate, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              Text('$detail · ${_pct(rate)}',
                  style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation(kNumbersAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: kNumbersTint, shape: BoxShape.circle),
              child: const Icon(Icons.pin_rounded, color: kNumbersAccent, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              'No Numbers activities yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Progress will show here once your child plays Numbers on the Home screen.',
              textAlign: TextAlign.center,
              style: _bodyStyle,
            ),
          ],
        ),
      ),
    );
  }
}
