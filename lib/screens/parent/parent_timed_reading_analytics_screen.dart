import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dao/timed_reading_dao.dart';
import '../../data/timed_reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../widgets/sentence_report_card.dart';

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
      if (!mounted) return;
      setState(() {
        _sessions = rows;
        _lastSessionWpm = lastWpm;
        _sessionsThisWeek = thisWeek;
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
