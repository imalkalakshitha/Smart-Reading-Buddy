import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../eduplay/eduplay_database.dart';
import '../../models/app_colors.dart';

/// Real EduPlay progress for "Word Building" — i.e. the letter_drag_drop
/// activity (see kActivityDisplayNames in eduplay_constants.dart: 'Letter
/// Drag & Drop'). Data comes from eduplay.db via EduPlayDatabase, not
/// reading_buddy.db — a completely separate database from every other
/// parent analytics screen in this file's sibling files, but styled to
/// match them (same card/typography pattern as
/// parent_pronunciation_analytics_screen.dart /
/// parent_timed_reading_analytics_screen.dart).
class ParentWordBuildingAnalyticsScreen extends StatefulWidget {
  final String childId;

  const ParentWordBuildingAnalyticsScreen({super.key, required this.childId});

  @override
  State<ParentWordBuildingAnalyticsScreen> createState() => _ParentWordBuildingAnalyticsScreenState();
}

class _ParentWordBuildingAnalyticsScreenState extends State<ParentWordBuildingAnalyticsScreen> {
  static const _activityType = 'letter_drag_drop';

  bool _loading = true;
  String? _accuracyLabel; // e.g. "78%", null = no data yet
  List<Map<String, dynamic>> _sessions = [];
  String _trend = 'not_enough_data'; // 'improving' | 'steady' | 'needs_practice' | 'not_enough_data'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final skillMap = await EduPlayDatabase.getSkillAccuracyMap(widget.childId);

    // getRecentSessions isn't activity-filtered at the DAO level (see
    // eduplay_database.dart) — pull a wider window and filter/trim to
    // letter_drag_drop here rather than adding a new DAO method.
    final allRecent = await EduPlayDatabase.getRecentSessions(widget.childId, limit: 50);
    final letterSessions = allRecent.where((s) => s['activity_type'] == _activityType).take(10).toList();

    if (!mounted) return;
    setState(() {
      _accuracyLabel = skillMap['letter_order'];
      _sessions = letterSessions;
      _trend = _computeTrend(letterSessions);
      _loading = false;
    });
  }

  /// letterSessions is newest-first (see getRecentSessions' ORDER BY).
  /// Compares the older half's average accuracy against the newer half's.
  String _computeTrend(List<Map<String, dynamic>> letterSessions) {
    if (letterSessions.length < 4) return 'not_enough_data';
    final oldestFirst = letterSessions.reversed.toList();
    final mid = oldestFirst.length ~/ 2;
    final firstHalf = oldestFirst.sublist(0, mid);
    final secondHalf = oldestFirst.sublist(mid);

    double avg(List<Map<String, dynamic>> rows) =>
        rows.fold<double>(0, (sum, r) => sum + (r['accuracy_percentage'] as num).toDouble()) / rows.length;

    final firstAvg = avg(firstHalf);
    final secondAvg = avg(secondHalf);
    final delta = secondAvg - firstAvg;

    if (delta >= 5) return 'improving';
    if (delta <= -5) return 'needs_practice';
    return 'steady';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.wordBuilding,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Word Building Progress'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.wordBuilding))
          : _sessions.isEmpty && _accuracyLabel == null
              ? _EmptyState()
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _AccuracyCard(accuracyLabel: _accuracyLabel),
                    const SizedBox(height: 16),
                    _TrendCard(trend: _trend),
                    const SizedBox(height: 20),
                    Text(
                      'Recent Sessions',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    if (_sessions.isEmpty)
                      Text(
                        'No Letter Drag & Drop sessions yet.',
                        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                      )
                    else
                      for (final session in _sessions) _SessionRow(session: session),
                  ],
                ),
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  final String? accuracyLabel;

  const _AccuracyCard({required this.accuracyLabel});

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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.wordBuilding.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('🔤', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Letter Order Accuracy',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  accuracyLabel ?? 'Not enough data yet',
                  style: GoogleFonts.nunito(
                    fontSize: accuracyLabel != null ? 26 : 15,
                    fontWeight: FontWeight.w900,
                    color: accuracyLabel != null ? AppColors.textPrimary : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String trend;

  const _TrendCard({required this.trend});

  ({String emoji, String label, Color color}) get _display {
    switch (trend) {
      case 'improving':
        return (emoji: '📈', label: 'Improving', color: AppColors.success);
      case 'needs_practice':
        return (emoji: '📉', label: 'Needs practice', color: AppColors.danger);
      case 'steady':
        return (emoji: '➡️', label: 'Steady', color: AppColors.textSecondary);
      default:
        return (emoji: '🌱', label: 'Not enough sessions yet to show a trend', color: AppColors.textHint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _display;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Text(d.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(d.label, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: d.color)),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> session;

  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final completedAt = DateTime.tryParse(session['completed_at'] as String? ?? '');
    final accuracy = (session['accuracy_percentage'] as num).round();
    final timeSec = (session['time_spent_seconds'] as num).round();
    final minutes = timeSec ~/ 60;
    final seconds = timeSec % 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              completedAt != null
                  ? '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}'
                  : 'Unknown date',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          Text('$accuracy%',
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.wordBuilding)),
          const SizedBox(width: 14),
          Text('${minutes}m ${seconds}s',
              style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No Word Building sessions recorded yet — this screen will fill in once your child completes some Letter Drag & Drop activities.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textHint),
        ),
      ),
    );
  }
}
