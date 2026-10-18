import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/dao/timed_reading_dao.dart';
import 'package:smart_reading_buddy/core/data/timed_reading_data.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';

/// Researcher/admin-facing screen — NOT child-facing, NOT tied to any
/// single child's Parent Dashboard. Aggregates real observed Timed
/// Reading times across ALL children/profiles and compares them against
/// the xlsx-sourced expectedTimeSec, to empirically validate/refine the
/// sentence-length-based timing model (Research Question 3: how
/// accurately does that model measure fluency progress).
///
/// Gated behind AppRouter.parentPin (see ParentPinScreen's
/// destinationBuilder) — reused, not a new PIN flow — since this is
/// still real session data from actual child users of a dyslexia-support
/// app, not something to leave reachable without any gate even though
/// it isn't per-child.
///
/// Real data only: every number here comes from TimedReadingDao's
/// getCalibrationStatsByContentSet/BySentence — no mock/placeholder
/// values. Deliberately neutral in tone/color (no green="good"/
/// red="bad" framing) since this is diagnostic data for a researcher,
/// not feedback for a parent or child.
class CalibrationInsightsScreen extends StatefulWidget {
  const CalibrationInsightsScreen({super.key});

  @override
  State<CalibrationInsightsScreen> createState() => _CalibrationInsightsScreenState();
}

class _CalibrationInsightsScreenState extends State<CalibrationInsightsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _buckets = [];
  Set<String> _inconsistentSentenceIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final buckets = await TimedReadingDao.getCalibrationStatsByContentSet();
    final inconsistent = await TimedReadingDao.getInconsistentExpectedSnapshots();
    if (!mounted) return;
    setState(() {
      _buckets = buckets;
      _inconsistentSentenceIds = inconsistent.map((r) => r['sentence_id'] as String).toSet();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.timedReading,
        elevation: 0,
        title: Text(
          'Calibration Insights',
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.timedReading))
            : _buckets.isEmpty
                ? _emptyState()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Real observed reading times vs. xlsx-sourced expected times, aggregated across all children.',
                        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      if (_inconsistentSentenceIds.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InconsistencyWarning(sentenceIds: _inconsistentSentenceIds),
                      ],
                      const SizedBox(height: 16),
                      for (final bucket in _buckets) _ContentSetCard(bucket: bucket),
                    ],
                  ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No Timed Reading sessions recorded yet — this screen will populate once children complete some sessions.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textHint),
        ),
      ),
    );
  }
}

class _InconsistencyWarning extends StatelessWidget {
  final Set<String> sentenceIds;

  const _InconsistencyWarning({required this.sentenceIds});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
              const SizedBox(width: 6),
              Text(
                '${sentenceIds.length} sentence(s) have inconsistent expected_ms_snapshot',
                style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These sentences\' recorded expected time changed between attempts — likely a content-bank edit after some sessions were already saved. Their averages below may mix two different targets: ${sentenceIds.join(", ")}',
            style: GoogleFonts.nunito(fontSize: 11.5, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _ContentSetCard extends StatefulWidget {
  final Map<String, dynamic> bucket;

  const _ContentSetCard({required this.bucket});

  @override
  State<_ContentSetCard> createState() => _ContentSetCardState();
}

class _ContentSetCardState extends State<_ContentSetCard> {
  bool _loaded = false;
  bool _loading = false;
  List<Map<String, dynamic>> _sentenceRows = [];

  Future<void> _loadSentences() async {
    if (_loaded || _loading) return;
    setState(() => _loading = true);
    final b = widget.bucket;
    final rows = await TimedReadingDao.getCalibrationStatsBySentence(
      grade: b['grade'] as String,
      language: b['language'] as String,
      level: b['level'] as String,
    );
    if (!mounted) return;
    setState(() {
      _sentenceRows = rows;
      _loaded = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bucket;
    final n = b['n'] as int;
    final gradeLabel = (b['grade'] as String) == 'grade4' ? 'Grade 4' : 'Grade 3';
    final languageLabel = (b['language'] as String) == 'sinhala' ? 'Sinhala' : 'English';
    final levelLabel = timedReadingLevelTitle(b['level'] as String, false);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
          onExpansionChanged: (expanded) {
            if (expanded) _loadSentences();
          },
          title: Text(
            '$gradeLabel · $languageLabel · $levelLabel',
            style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          subtitle: n < 3
              ? Text('Insufficient data yet ($n reading${n == 1 ? '' : 's'})',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textHint))
              : _StatsLine(
                  actualAvgMs: (b['actual_avg_ms'] as num).toDouble(),
                  expectedAvgMs: (b['expected_avg_ms'] as num).toDouble(),
                  n: n,
                  tooFastN: (b['too_fast_n'] as num).toInt(),
                  stalledN: (b['stalled_n'] as num).toInt(),
                ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator(color: AppColors.timedReading)),
                    )
                  : Column(
                      children: [
                        for (final row in _sentenceRows) _SentenceRow(row: row),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentenceRow extends StatelessWidget {
  final Map<String, dynamic> row;

  const _SentenceRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final n = row['n'] as int;
    final text = row['sentence_text_snapshot'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          n < 3
              ? Text('Insufficient data yet ($n reading${n == 1 ? '' : 's'})',
                  style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textHint))
              : _StatsLine(
                  actualAvgMs: (row['actual_avg_ms'] as num).toDouble(),
                  expectedAvgMs: (row['expected_ms_snapshot'] as num).toDouble(),
                  n: n,
                  tooFastN: (row['too_fast_n'] as num).toInt(),
                  stalledN: (row['stalled_n'] as num).toInt(),
                ),
        ],
      ),
    );
  }
}

/// Shared stats line for both the bucket header and each sentence row —
/// deliberately neutral color (AppColors.textSecondary throughout, no
/// success/danger) since this is diagnostic data, not a judgment.
class _StatsLine extends StatelessWidget {
  final double actualAvgMs;
  final double expectedAvgMs;
  final int n;
  final int tooFastN;
  final int stalledN;

  const _StatsLine({
    required this.actualAvgMs,
    required this.expectedAvgMs,
    required this.n,
    required this.tooFastN,
    required this.stalledN,
  });

  @override
  Widget build(BuildContext context) {
    final deviationPct = expectedAvgMs == 0 ? 0.0 : (actualAvgMs - expectedAvgMs) / expectedAvgMs * 100;
    final sign = deviationPct >= 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        'expected ${_fmtSec(expectedAvgMs)}  ·  actual ${_fmtSec(actualAvgMs)}  ·  $sign${deviationPct.toStringAsFixed(1)}%  ·  n=$n'
        '${tooFastN > 0 ? '  ·  $tooFastN too-fast' : ''}'
        '${stalledN > 0 ? '  ·  $stalledN stalled' : ''}',
        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }

  String _fmtSec(double ms) => '${(ms / 1000).toStringAsFixed(2)}s';
}
