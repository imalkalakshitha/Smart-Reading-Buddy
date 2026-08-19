import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_colors.dart';
import '../eduplay_constants.dart';
import '../eduplay_database.dart';
import '../eduplay_engine.dart';
import 'eduplay_child_dashboard.dart';

const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B7280);
const _kAmber = Color(0xFFF39C12);
const _kOrange = Color(0xFFE67E22);

const Map<String, String> _kRuleTagPlain = {
  'REINFORCE_FOUNDATION': 'Needs more practice on the basics',
  'PRACTICE_SAME_SKILL': 'Ready to practice the same skill again',
  'MOVE_TO_NEXT_SKILL': 'Ready to move to the next challenge',
};

/// Route: '/eduplay/parent/recommendation'. Args: {childId, engine}.
class ParentRecommendationScreen extends StatefulWidget {
  final String childId;
  final EduPlayEngine engine;

  const ParentRecommendationScreen({super.key, required this.childId, required this.engine});

  @override
  State<ParentRecommendationScreen> createState() => _ParentRecommendationScreenState();
}

class _ParentRecommendationScreenState extends State<ParentRecommendationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  Map<String, dynamic>? _recommendation;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rec = await widget.engine.getPendingRecommendation(widget.childId);
    final history = await EduPlayDatabase.getAssignmentHistory(widget.childId);
    if (!mounted) return;
    setState(() {
      _recommendation = rec;
      _history = history;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: Text('EduPlay Recommendation',
            style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: _kTextPrimary)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: _kTextSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          tabs: const [
            Tab(text: 'Current Recommendation'),
            Tab(text: 'Assignment History'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCurrentTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  // ── Tab 1 ────────────────────────────────────────────────────────────

  Widget _buildCurrentTab() {
    final rec = _recommendation;
    if (rec == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              const Icon(Icons.hourglass_empty_rounded, size: 48, color: _kTextSecondary),
              const SizedBox(height: 12),
              Text('No new recommendations yet',
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: _kTextPrimary)),
              const SizedBox(height: 8),
              Text('Check back after ${widget.childId} completes more activities.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: _kTextSecondary)),
            ],
          ),
        ),
      );
    }

    final activity = rec['recommended_activity'] as String;
    final level = rec['recommended_level'] as String;
    final confidence = (rec['confidence'] as num).toDouble();
    final ruleTag = rec['rule_tag'] as String;
    final topFeatures = (jsonDecode(rec['top_features'] as String) as List).cast<Map<String, dynamic>>();

    final confColor = confidence >= 0.80 ? AppColors.primary : (confidence >= 0.70 ? _kAmber : _kOrange);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recommended Next Lesson',
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
                const SizedBox(height: 6),
                Text(kActivityDisplayNames[activity] ?? activity,
                    style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: _kTextPrimary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(level,
                      style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.primary)),
                ),
                const SizedBox(height: 18),
                Text('Model confidence',
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: confidence.clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: const Color(0xFFEFEFEF),
                    color: confColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${(confidence * 100).round()}%',
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: confColor)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Why this recommendation?',
                    style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: _kTextPrimary)),
                const SizedBox(height: 6),
                Text(_kRuleTagPlain[ruleTag] ?? ruleTag,
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.primary)),
                const SizedBox(height: 14),
                for (final f in topFeatures) _WhyThisRow(feature: f),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                await widget.engine.approveRecommendation(rec['rec_id'] as String, widget.childId);
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => EduPlayChildDashboard(childId: widget.childId)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Assign this lesson', style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => _showChooseDifferentSheet(rec),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: const BorderSide(color: AppColors.primary),
              ),
              child: Text('Choose a different lesson',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () async {
                await widget.engine.dismissRecommendation(rec['rec_id'] as String);
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: Text('Dismiss',
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  void _showChooseDifferentSheet(Map<String, dynamic> rec) {
    String chosenActivity = kActivityTypes.first;
    String chosenLevel = 'Basic';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose a lesson',
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: _kTextPrimary)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final activity in kActivityTypes)
                        ChoiceChip(
                          label: Text(kActivityDisplayNames[activity] ?? activity),
                          selected: chosenActivity == activity,
                          onSelected: (_) => setSheetState(() => chosenActivity = activity),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final level in ['Basic', 'Advanced'])
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(level),
                            selected: chosenLevel == level,
                            onSelected: (_) => setSheetState(() => chosenLevel = level),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        await widget.engine.overrideRecommendation(
                          rec['rec_id'] as String,
                          widget.childId,
                          chosenActivity,
                          chosenLevel,
                        );
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => EduPlayChildDashboard(childId: widget.childId)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Confirm', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Tab 2 ────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Text('No assignments yet.',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _HistoryRow(row: _history[i]),
    );
  }
}

class _WhyThisRow extends StatelessWidget {
  final Map<String, dynamic> feature;

  const _WhyThisRow({required this.feature});

  String _sentence(String name, dynamic value) {
    switch (name) {
      case 'Recent error rate':
        return 'High recent mistakes suggest reinforcing foundational skills.';
      case 'Last 5 sessions accuracy':
        return 'Recent accuracy trend across the last few activities.';
      case 'This session accuracy':
        return 'How well this specific activity went.';
      case 'Current activity':
        return 'The type of activity just completed.';
      case 'Target skill area':
        return 'The specific skill this activity targets.';
      case 'Previous session accuracy':
        return 'How the last activity went.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = feature['feature'] as String;
    final value = feature['value'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: _kTextPrimary),
                children: [
                  TextSpan(text: '$name: $value — ', style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: _sentence(name, value), style: const TextStyle(color: _kTextSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> row;

  const _HistoryRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final activity = row['activity_type'] as String;
    final level = row['level'] as String;
    final assignedAt = DateTime.tryParse(row['assigned_at'] as String? ?? '');
    final status = row['status'] as String;
    final pre = row['pre_accuracy'] as num?;
    final post = row['post_accuracy'] as num?;

    Color? postColor;
    if (pre != null && post != null) {
      postColor = post > pre ? AppColors.primary : (post == pre ? _kAmber : _kOrange);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kActivityDisplayNames[activity] ?? activity,
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: _kTextPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(level,
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            assignedAt != null ? '${assignedAt.year}-${assignedAt.month.toString().padLeft(2, '0')}-${assignedAt.day.toString().padLeft(2, '0')}' : '',
            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: _kTextSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(status,
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
              if (pre != null && post != null) ...[
                const SizedBox(width: 10),
                Text('${pre.round()}% → ${post.round()}%',
                    style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: postColor)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
