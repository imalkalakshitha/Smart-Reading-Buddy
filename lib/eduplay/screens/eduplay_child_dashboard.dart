import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../eduplay_constants.dart';
import '../eduplay_database.dart';
import 'activity_level_select.dart';

// ── Palette — matches Pronunciation/Home screen exactly (see spec) ──────
const _kPrimary = Color(0xFF2ECC71);
const _kPrimaryLightBg = Color(0xFFE8F8F0);
const _kBg = Color(0xFFFAFAF7);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kAmberBg = Color(0xFFFEF3C7);
const _kAmberText = Color(0xFFD97706);
const _kOrangeBg = Color(0xFFFEE2E2);
const _kOrangeText = Color(0xFFDC2626);
const _kBannerBg = Color(0xFFFFF7ED);
const _kBannerBorder = Color(0xFFF59E0B);

TextStyle _title24(Color color) =>
    GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: color);
TextStyle _title20(Color color) =>
    GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: color);
TextStyle _title18(Color color) =>
    GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: color);
TextStyle _small13(Color color, {FontWeight weight = FontWeight.w500}) =>
    GoogleFonts.nunito(fontSize: 13, fontWeight: weight, letterSpacing: 0.3, color: color);

/// Route: '/eduplay/dashboard'. Required arg: String childId.
///
/// Child-facing — no progress analysis (parent-only, see
/// ParentRecommendationScreen) and no language switch. Language is locked
/// at account creation; this screen never shows or offers a language
/// choice, and every task lookup is filtered by the child's own locked
/// profile language, never a UI-selectable one.
class EduPlayChildDashboard extends StatefulWidget {
  final String childId;

  const EduPlayChildDashboard({super.key, required this.childId});

  @override
  State<EduPlayChildDashboard> createState() => _EduPlayChildDashboardState();
}

class _EduPlayChildDashboardState extends State<EduPlayChildDashboard> {
  bool _loading = true;
  int _totalXp = 0;
  Map<String, dynamic>? _activeAssignment;
  int _streakDays = 0;
  Map<String, String> _skillAccuracy = {};

  // Locked profile grade/language — read once from the child's own
  // EduPlay profile row, never offered as a UI choice.
  String _grade = 'Grade 3';
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await EduPlayDatabase.getChildProfile(widget.childId);
    final totalXp = await EduPlayDatabase.getTotalXp(widget.childId);
    final activeAssignment = await EduPlayDatabase.getActiveAssignment(widget.childId);
    final recentSessions = await EduPlayDatabase.getRecentSessions(widget.childId, limit: 20);
    final skillAccuracy = await EduPlayDatabase.getSkillAccuracyMap(widget.childId);

    if (!mounted) return;
    setState(() {
      if (profile != null) {
        _grade = profile['grade'] as String? ?? _grade;
        _language = profile['language'] as String? ?? _language;
      }
      _totalXp = totalXp;
      _activeAssignment = activeAssignment;
      _streakDays = _computeStreak(recentSessions);
      _skillAccuracy = skillAccuracy;
      _loading = false;
    });
  }

  int _computeStreak(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return 0;
    final days = <DateTime>{};
    for (final s in sessions) {
      final dt = DateTime.tryParse(s['completed_at'] as String? ?? '');
      if (dt != null) days.add(DateTime(dt.year, dt.month, dt.day));
    }
    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kPrimary))
            : RefreshIndicator(
                onRefresh: _load,
                color: _kPrimary,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: _kTextPrimary, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _HeaderCard(childId: widget.childId, totalXp: _totalXp, streakDays: _streakDays),
                    ),
                    if (_activeAssignment != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _AssignedLessonBanner(
                          assignment: _activeAssignment!,
                          onStart: () => _startActivity(_activeAssignment!['activity_type'] as String),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('My Activities', style: _title20(_kTextPrimary)),
                    ),
                    const SizedBox(height: 8),
                    for (final activity in kActivityTypes)
                      _ActivityCard(
                        activityType: activity,
                        accuracyLabel: _skillAccuracy[activity],
                        onStart: () => _startActivity(activity),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  void _startActivity(String activityType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityLevelSelectScreen(
          childId: widget.childId,
          activityType: activityType,
          // Locked profile grade/language, read once above — never a UI
          // choice, just threaded down so level-select doesn't need its
          // own redundant profile fetch.
          grade: _grade,
          language: _language,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String childId;
  final int totalXp;
  final int streakDays;

  const _HeaderCard({required this.childId, required this.totalXp, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hello, $childId!', style: _title24(_kTextPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip(bg: _kAmberBg, textColor: _kAmberText, emoji: '⭐', label: '$totalXp XP'),
              const SizedBox(width: 10),
              _Chip(bg: _kOrangeBg, textColor: _kOrangeText, emoji: '🔥', label: '$streakDays days'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final Color bg;
  final Color textColor;
  final String emoji;
  final String label;

  const _Chip({required this.bg, required this.textColor, required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: textColor)),
        ],
      ),
    );
  }
}

class _AssignedLessonBanner extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final VoidCallback onStart;

  const _AssignedLessonBanner({required this.assignment, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final activityType = assignment['activity_type'] as String;
    final level = assignment['level'] as String;
    return Container(
      decoration: const BoxDecoration(
        color: _kBannerBg,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        border: Border(left: BorderSide(color: _kBannerBorder, width: 4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Special task for you!', style: _title18(_kTextPrimary)),
                const SizedBox(height: 4),
                Text('${kActivityDisplayNames[activityType] ?? activityType} — $level', style: _small13(_kTextSecondary)),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 44,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text('Start', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

const Map<String, IconData> _kActivityIcons = {
  'letter_drag_drop': Icons.drag_indicator,
  'word_recognition': Icons.record_voice_over,
  'fill_blanks_word': Icons.edit_note,
  'sentence_drag_drop': Icons.reorder,
  'sentence_quiz': Icons.quiz,
};

class _ActivityCard extends StatelessWidget {
  final String activityType;
  final String? accuracyLabel; // null = "New"
  final VoidCallback onStart;

  const _ActivityCard({
    required this.activityType,
    required this.accuracyLabel,
    required this.onStart,
  });

  Color _accuracyColor() {
    if (accuracyLabel == null) return _kTextSecondary;
    final pct = double.tryParse(accuracyLabel!.replaceAll('%', '')) ?? 0;
    if (pct >= 70) return _kPrimary;
    if (pct >= 50) return _kAmberText;
    return const Color(0xFFEA580C);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: _kPrimaryLightBg, borderRadius: BorderRadius.circular(14)),
            child: Icon(_kActivityIcons[activityType] ?? Icons.games_rounded, color: _kPrimary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(kActivityDisplayNames[activityType] ?? activityType, style: _title18(_kTextPrimary)),
                const SizedBox(height: 4),
                Text(accuracyLabel ?? 'New', style: _small13(_accuracyColor(), weight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            height: 44,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text('Start', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}
