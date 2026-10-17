import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_reading_buddy/core/dao/free_drawing_dao.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';

/// Free Drawing Recognition's parent dashboard — reached from the
/// existing Parent Dashboard's "Writing" card, behind the same parent PIN
/// gate as every other module card there. Reads only from FreeDrawingDao.
class ParentWritingAnalyticsScreen extends StatefulWidget {
  final String profileName;
  const ParentWritingAnalyticsScreen({super.key, required this.profileName});

  @override
  State<ParentWritingAnalyticsScreen> createState() => _ParentWritingAnalyticsScreenState();
}

class _ParentWritingAnalyticsScreenState extends State<ParentWritingAnalyticsScreen> {
  bool _loading = true;
  ({int lettersPractised, int totalAttempts, int lettersCompleted})? _glance;
  List<bool> _daysPractised = [];
  List<LetterDifficulty> _difficulty = [];
  Map<String, ({String wrote, String? rejectionReason})> _mismatches = {};
  List<({DateTime date, int total, int accepted})> _timeline = [];
  TechnicalDetails? _technical;
  bool _exporting = false;

  String get _language => AppState.language == 'sinhala' ? 'si' : 'en';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final glance = await FreeDrawingDao.getAtAGlance(profileName: widget.profileName);
    final days = await FreeDrawingDao.getDaysPractisedLast2Weeks(profileName: widget.profileName);
    final difficulty = await FreeDrawingDao.getLetterDifficulty(profileName: widget.profileName, language: _language);
    final mismatches = await FreeDrawingDao.getRecentMismatches(profileName: widget.profileName, language: _language);
    final timeline = await FreeDrawingDao.getAcceptanceTimeline(profileName: widget.profileName);
    final technical = await FreeDrawingDao.getTechnicalDetails(profileName: widget.profileName);
    if (!mounted) return;
    setState(() {
      _glance = glance;
      _daysPractised = days;
      _difficulty = difficulty;
      _mismatches = mismatches;
      _timeline = timeline;
      _technical = technical;
      _loading = false;
    });
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final rows = await FreeDrawingDao.getAllAttempts(profileName: widget.profileName);
      final buffer = StringBuffer();
      buffer.writeln('timestamp,level_type,language,target_character,top1_prediction,'
          'top1_confidence,p_target,target_rank,accepted,attempt_number');
      for (final r in rows) {
        buffer.writeln([
          r['timestamp'],
          r['level_type'],
          r['language'],
          _csvField(r['target_character'] as String),
          _csvField(r['top1_prediction'] as String),
          r['top1_confidence'],
          r['p_target'],
          r['target_rank'],
          r['accepted'],
          r['attempt_number'],
        ].join(','));
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeProfile = widget.profileName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/free_drawing_attempts_$safeProfile.csv');
      await file.writeAsString(buffer.toString());

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exported'),
          content: Text('Saved ${rows.length} rows to:\n\n${file.path}'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.writing,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Writing Progress'),
        actions: [
          IconButton(
            onPressed: _exporting ? null : _exportCsv,
            icon: _exporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.ios_share_rounded),
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_glance == null || _glance!.totalAttempts == 0)
                ? _buildEmptyState()
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _AtAGlanceCard(glance: _glance!, daysPractised: _daysPractised),
                      const SizedBox(height: 18),
                      _NeedsPracticeCard(difficulty: _difficulty, mismatches: _mismatches),
                      const SizedBox(height: 18),
                      _ProgressOverTimeCard(timeline: _timeline),
                      const SizedBox(height: 18),
                      if (_technical != null) _TechnicalDetailsCard(details: _technical!),
                    ],
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✍️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'No practice yet',
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Once your child tries the Written activity, their letter practice will show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      ),
    );
  }
}

// ── 1. At a glance ──────────────────────────────────────────────────────

class _AtAGlanceCard extends StatelessWidget {
  final ({int lettersPractised, int totalAttempts, int lettersCompleted}) glance;
  final List<bool> daysPractised;
  const _AtAGlanceCard({required this.glance, required this.daysPractised});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('At a Glance'),
          Row(
            children: [
              _StatTile(label: 'Letters practised', value: '${glance.lettersPractised}'),
              _StatTile(label: 'Total attempts', value: '${glance.totalAttempts}'),
              _StatTile(label: 'Letters completed', value: '${glance.lettersCompleted}'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Practised in the last 2 weeks',
            style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final practised in daysPractised)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: practised ? AppColors.writing : AppColors.divider,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.writing)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── 2. Letters that need practice ───────────────────────────────────────

class _NeedsPracticeCard extends StatefulWidget {
  final List<LetterDifficulty> difficulty;
  // Keyed by target character — see FreeDrawingDao.getRecentMismatches.
  // Only letters with at least one NOT-accepted attempt appear here.
  final Map<String, ({String wrote, String? rejectionReason})> mismatches;
  const _NeedsPracticeCard({required this.difficulty, required this.mismatches});

  @override
  State<_NeedsPracticeCard> createState() => _NeedsPracticeCardState();
}

class _NeedsPracticeCardState extends State<_NeedsPracticeCard> {
  static const int _collapsedCount = 4;
  bool _showAll = false;

  static ({String label, Color color}) _labelFor(LetterDifficulty d) {
    if (!d.everCompleted || d.avgAttemptsPerCompletion > 3) {
      return (label: 'needs practice', color: const Color(0xFFE8590C));
    }
    if (d.avgAttemptsPerCompletion > 1.5) {
      return (label: 'getting there', color: const Color(0xFFF5A623));
    }
    return (label: 'confident', color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final difficulty = widget.difficulty;
    final mismatches = widget.mismatches;
    final hasMore = difficulty.length > _collapsedCount;
    final visible = _showAll ? difficulty : difficulty.take(_collapsedCount).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Letters to Practise Together'),
          if (difficulty.isEmpty)
            Text('Not enough data yet.', style: GoogleFonts.nunito(color: AppColors.textSecondary))
          else
            for (final d in visible)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.writing.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(d.letter, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.writing)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${d.totalAttempts} attempt${d.totalAttempts == 1 ? '' : 's'}',
                            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ),
                        Builder(builder: (context) {
                          final l = _labelFor(d);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: l.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              l.label,
                              style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w800, color: l.color),
                            ),
                          );
                        }),
                      ],
                    ),
                    if (mismatches[d.letter] != null) ...[
                      const SizedBox(height: 6),
                      _WhatTheyWroteRow(target: d.letter, mismatch: mismatches[d.letter]!),
                    ],
                  ],
                ),
              ),
          if (hasMore) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll ? 'Show less' : 'Show all (${difficulty.length})',
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.writing),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "What they wrote instead" — the most recent NOT-accepted attempt for one
/// struggling letter, shown as a calm, factual side-by-side. Deliberately
/// neutral (no red/wrong styling) to match this card's existing tone — see
/// FreeDrawingDao.getRecentMismatches for where the data comes from.
class _WhatTheyWroteRow extends StatelessWidget {
  final String target;
  final ({String wrote, String? rejectionReason}) mismatch;
  const _WhatTheyWroteRow({required this.target, required this.mismatch});

  @override
  Widget build(BuildContext context) {
    // A scribble-rejected attempt's raw top-1 guess isn't a meaningful
    // "what they wrote" (see ScribbleGuard) — label it plainly instead of
    // showing a misleading letter.
    final wroteText = mismatch.rejectionReason != null ? 'unclear drawing' : mismatch.wrote;
    return Padding(
      padding: const EdgeInsets.only(left: 52),
      child: Text(
        'Target: $target   →   Wrote: $wroteText',
        style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }
}

// ── 3. Progress over time ───────────────────────────────────────────────

class _ProgressOverTimeCard extends StatelessWidget {
  final List<({DateTime date, int total, int accepted})> timeline;
  const _ProgressOverTimeCard({required this.timeline});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Progress Over Time'),
          if (timeline.length < 2)
            Text(
              'Complete a few more days of practice to see a trend.',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            SizedBox(height: 160, child: _buildChart(timeline)),
        ],
      ),
    );
  }

  Widget _buildChart(List<({DateTime date, int total, int accepted})> timeline) {
    final spots = [
      for (var i = 0; i < timeline.length; i++)
        FlSpot(i.toDouble(), timeline[i].total == 0 ? 0 : timeline[i].accepted / timeline[i].total),
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 1,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 0.5,
              getTitlesWidget: (value, meta) => Text(
                '${(value * 100).round()}%',
                style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textHint),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= timeline.length) return const SizedBox.shrink();
                final d = timeline[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${d.month}/${d.day}', style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textHint)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.writing,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppColors.writing.withValues(alpha: 0.08)),
          ),
        ],
      ),
    );
  }
}

// ── 4. Technical details (dev/research — collapsed by default) ─────────

class _TechnicalDetailsCard extends StatelessWidget {
  final TechnicalDetails details;
  const _TechnicalDetailsCard({required this.details});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          title: Text(
            'Technical details',
            style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          subtitle: Text(
            'Model evaluation data — not needed for everyday use',
            style: GoogleFonts.nunito(fontSize: 11.5, color: AppColors.textHint),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _techRow('Total attempts', '${details.totalAttempts}'),
                  _techRow('Avg p_target', '${(details.avgPTarget * 100).toStringAsFixed(1)}%'),
                  _techRow('Avg top-1 confidence', '${(details.avgTop1Confidence * 100).toStringAsFixed(1)}%'),
                  _techRow('Rescued by target scoring', '${details.rescuedByTargetScoringCount}'),
                  const SizedBox(height: 12),
                  Text(
                    'Scribble/nonsense rejections',
                    style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  if (details.rejectionReasonCounts.isEmpty)
                    Text('None recorded yet.', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary))
                  else
                    for (final entry in details.rejectionReasonCounts.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${entry.key}  (×${entry.value})',
                          style: GoogleFonts.robotoMono(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                  const SizedBox(height: 12),
                  Text(
                    'Most common wrong top-1 predictions',
                    style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  if (details.commonWrongPredictions.isEmpty)
                    Text('None recorded yet.', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary))
                  else
                    for (final w in details.commonWrongPredictions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${w.target} → predicted ${w.wrongPrediction}  (×${w.count})',
                          style: GoogleFonts.robotoMono(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _techRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
