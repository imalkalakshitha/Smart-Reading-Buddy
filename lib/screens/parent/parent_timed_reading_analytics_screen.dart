import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dao/timed_reading_dao.dart';
import '../../data/timed_reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../widgets/sentence_report_card.dart';

/// One session's date + its avg(actual/expected) pace ratio, for the
/// "Actual vs Expected" trend chart. 1.0 = exactly on the expected pace;
/// above 1.0 = slower than expected (elapsed_ms > expected_ms_snapshot).
class _PaceRatioPoint {
  final DateTime date;
  final double ratio;
  const _PaceRatioPoint({required this.date, required this.ratio});
}

/// One session's date + its wpm, for the WPM trend chart. Sourced
/// straight from timed_reading_sessions.wpm (already computed and
/// stored at session-save time) — no extra query needed beyond the
/// getRecentSessions call the rest of this screen already makes.
class _WpmPoint {
  final DateTime date;
  final double wpm;
  const _WpmPoint({required this.date, required this.wpm});
}

/// Timed Reading summary for parents — real data from TimedReadingDao
/// (reading_buddy.db's timed_reading_sessions / timed_reading_unit_timings,
/// schema v7). Sentence-level breakdown rows are built from the DB row's
/// OWN sentence_text_snapshot/expected_ms_snapshot (not re-derived from
/// the live content bank) — that snapshot is exactly why those columns
/// were denormalized onto timed_reading_unit_timings in the first place,
/// so a later content-bank edit can never retroactively change what a
/// past report shows.
///
/// GRADE: filtered to AppState.grade — the same locked-at-login field
/// every other module reads for the active child.
class ParentTimedReadingAnalyticsScreen extends StatefulWidget {
  const ParentTimedReadingAnalyticsScreen({super.key});

  @override
  State<ParentTimedReadingAnalyticsScreen> createState() => _ParentTimedReadingAnalyticsScreenState();
}

class _ParentTimedReadingAnalyticsScreenState extends State<ParentTimedReadingAnalyticsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];
  int? _lastSessionWpm;
  int _sessionsThisWeek = 0;
  List<_PaceRatioPoint> _paceTrend = [];
  List<_WpmPoint> _wpmTrend = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final grade = AppState.grade == 'grade4' ? 'grade4' : 'grade3';
    try {
      final rows = await TimedReadingDao.getRecentSessions(
        profileName: AppState.name,
        grade: grade,
        limit: 10,
      );
      final now = DateTime.now();
      var thisWeek = 0;
      for (final r in rows) {
        final startedAt = DateTime.tryParse(r['started_at'] as String? ?? '');
        if (startedAt != null && now.difference(startedAt).inDays < 7) thisWeek++;
      }
      final lastWpm = rows.isNotEmpty && rows.first['wpm'] != null ? (rows.first['wpm'] as num).round() : null;

      // Actual-vs-expected pace trend: for each session, avg(elapsed_ms /
      // expected_ms_snapshot) across its own unit_timings rows — one ratio
      // per session, in chronological (oldest-first) order for the chart.
      // Reuses getUnitTimingsForSession (same DAO already in place), no
      // new tracking/columns.
      final trend = <_PaceRatioPoint>[];
      for (final r in rows) {
        final startedAt = DateTime.tryParse(r['started_at'] as String? ?? '');
        if (startedAt == null) continue;
        final sessionId = r['id'] as int;
        final unitRows = await TimedReadingDao.getUnitTimingsForSession(sessionId);
        final ratios = <double>[];
        for (final u in unitRows) {
          final expectedMs = u['expected_ms_snapshot'] as int?;
          final elapsedMs = u['elapsed_ms'] as int?;
          if (expectedMs == null || expectedMs <= 0 || elapsedMs == null) continue;
          ratios.add(elapsedMs / expectedMs);
        }
        if (ratios.isEmpty) continue; // e.g. interrupted before any sentence
        final avgRatio = ratios.reduce((a, b) => a + b) / ratios.length;
        trend.add(_PaceRatioPoint(date: startedAt, ratio: avgRatio));
      }
      trend.sort((a, b) => a.date.compareTo(b.date));

      // WPM trend — sessions with a non-null wpm, chronological order.
      // wpm is already a column on timed_reading_sessions (computed once
      // at save time in MiscueMarkingScreen), so this reuses the same
      // getRecentSessions rows fetched above — no second query needed.
      //
      // Grouping decision: a single combined line, not split per
      // language+level. getRecentSessions is already capped at 10 rows
      // (and further filtered to grade), so splitting that further by
      // language+level would typically leave 1-3 points per line —
      // too sparse to read as a meaningful trend. Revisit if/when this
      // screen ever shows a larger session history.
      final wpmPoints = <_WpmPoint>[
        for (final r in rows)
          if (r['wpm'] != null && DateTime.tryParse(r['started_at'] as String? ?? '') != null)
            _WpmPoint(
              date: DateTime.parse(r['started_at'] as String),
              wpm: (r['wpm'] as num).toDouble(),
            ),
      ]..sort((a, b) => a.date.compareTo(b.date));

      if (!mounted) return;
      setState(() {
        _sessions = rows;
        _lastSessionWpm = lastWpm;
        _sessionsThisWeek = thisWeek;
        _paceTrend = trend;
        _wpmTrend = wpmPoints;
        _loading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('[TR] parent dashboard session query failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
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
          'Timed Reading',
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.timedReading))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Last Session',
                          value: _lastSessionWpm != null ? '$_lastSessionWpm WPM' : '—',
                          icon: Icons.speed_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          label: 'Sessions This Week',
                          value: '$_sessionsThisWeek',
                          icon: Icons.calendar_today_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _TrendCard(paceTrend: _paceTrend, wpmTrend: _wpmTrend),
                  const SizedBox(height: 24),
                  Text(
                    'Recent Sessions',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  if (_sessions.isEmpty)
                    Text(
                      'No Timed Reading sessions yet.',
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    )
                  else
                    for (final session in _sessions) _SessionExpansionCard(sessionRow: session),
                ],
              ),
      ),
    );
  }
}

class _SessionExpansionCard extends StatefulWidget {
  final Map<String, dynamic> sessionRow;

  const _SessionExpansionCard({required this.sessionRow});

  @override
  State<_SessionExpansionCard> createState() => _SessionExpansionCardState();
}

class _SessionExpansionCardState extends State<_SessionExpansionCard> {
  bool _loaded = false;
  bool _loading = false;
  List<SentenceReportCardData> _rows = [];

  Future<void> _loadUnitTimings() async {
    if (_loaded || _loading) return;
    setState(() => _loading = true);
    try {
      final sessionId = widget.sessionRow['id'] as int;
      final unitRows = await TimedReadingDao.getUnitTimingsForSession(sessionId);
      final rows = <SentenceReportCardData>[];
      for (final u in unitRows) {
        final text = u['sentence_text_snapshot'] as String;
        final expectedSec = (u['expected_ms_snapshot'] as int) / 1000.0;
        final actualMs = u['elapsed_ms'] as int;
        final finalRaw = u['final_misread_indexes'] as String?;
        final autoRaw = u['auto_misread_indexes'] as String?;
        final indexesJson = finalRaw ?? autoRaw;
        final words = splitWords(text);
        var practiceWords = <String>[];
        if (indexesJson != null) {
          try {
            final indexes = (jsonDecode(indexesJson) as List).cast<int>();
            practiceWords = [for (final i in indexes) if (i >= 0 && i < words.length) words[i]];
          } catch (_) {
            practiceWords = [];
          }
        }
        rows.add(SentenceReportCardData(
          text: text,
          expectedTimeSec: expectedSec,
          // upperThresholdSec isn't stored per-row (only expected_ms was
          // denormalized); SentenceReportCard doesn't actually read this
          // field today, so the same placeholder band used at content-
          // authoring time (1.8x expected) is reused here for consistency.
          upperThresholdSec: expectedSec * 1.8,
          actualMs: actualMs,
          practiceWords: practiceWords,
        ));
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loaded = true;
        _loading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('[TR] parent dashboard unit-timing query failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.sessionRow;
    final grade = r['grade'] as String;
    final language = r['language'] as String;
    final level = r['level'] as String;
    final gradeLabel = grade == 'grade4' ? 'Grade 4' : 'Grade 3';
    final languageLabel = language == 'sinhala' ? 'Sinhala' : 'English';
    final levelLabel = timedReadingLevelTitle(level, false);
    final startedAt = DateTime.tryParse(r['started_at'] as String? ?? '');
    final dateLabel = startedAt != null ? _formatDate(startedAt) : '';

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
            if (expanded) _loadUnitTimings();
          },
          title: Text(
            '$gradeLabel · $languageLabel · $levelLabel',
            style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          subtitle: Text(
            dateLabel,
            style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
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
                        for (final row in _rows) SentenceReportCard(data: row),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour12:${dt.minute.toString().padLeft(2, '0')} $ampm';
    if (isToday) return 'Today, $timeStr';
    if (isYesterday) return 'Yesterday, $timeStr';
    return '${dt.month}/${dt.day}/${dt.year}, $timeStr';
  }
}

/// "Actual vs Expected" pace trend — one line, X = session date, Y = avg
/// ratio of elapsed_ms/expected_ms_snapshot for that session's sentences.
/// 1.0 (the dashed reference line) is exactly on the expected pace;
/// points above it read as slower than expected. Framed as "getting
/// closer to target pace" rather than "behind"/"slow" — same supportive-
/// tone rule as the rest of this module (see SentenceReportCard).
class _PaceTrendCard extends StatelessWidget {
  final List<_PaceRatioPoint> trend;

  const _PaceTrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    final isSinhala = AppState.language == 'sinhala';

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
          Text(
            isSinhala ? 'ඉලක්කගත වේගයට ළං වීම' : 'Getting Closer to Target Pace',
            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            isSinhala
                ? 'සෑම සැසියකම සාමාන්‍ය කියවීමේ වේගය, අපේක්ෂිත වේගයට සාපේක්ෂව'
                : 'Average reading pace per session, relative to the expected pace',
            style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (trend.length < 3)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  isSinhala
                      ? 'ප්‍රගතිය බැලීමට තවත් සැසි කිහිපයක් සම්පූර්ණ කරන්න'
                      : 'Complete a few more sessions to see progress',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textHint),
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: _buildChart(isSinhala),
            ),
        ],
      ),
    );
  }

  Widget _buildChart(bool isSinhala) {
    final spots = [
      for (var i = 0; i < trend.length; i++) FlSpot(i.toDouble(), trend[i].ratio),
    ];
    final ratios = trend.map((p) => p.ratio).toList();
    final dataMin = ratios.reduce((a, b) => a < b ? a : b);
    final dataMax = ratios.reduce((a, b) => a > b ? a : b);
    // Always keep the 1.0 reference line comfortably inside the visible
    // range, with a bit of padding above/below the data itself.
    final minY = (dataMin < 1.0 ? dataMin : 1.0) - 0.15;
    final maxY = (dataMax > 1.0 ? dataMax : 1.0) + 0.15;

    return LineChart(
      LineChartData(
        minY: minY < 0 ? 0 : minY,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 1.0,
              color: AppColors.textHint.withValues(alpha: 0.5),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textHint),
                labelResolver: (_) => isSinhala ? 'නියමිත වේගය' : 'On pace',
              ),
            ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 0.5,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
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
                if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                final d = trend[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${d.month}/${d.day}',
                    style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textHint),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.timedReading,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppColors.timedReading.withValues(alpha: 0.08)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.timedReading, size: 26),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
