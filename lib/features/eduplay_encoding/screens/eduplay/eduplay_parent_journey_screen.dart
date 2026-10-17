import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/widgets/coming_soon_placeholder.dart';
import 'package:smart_reading_buddy/core/dao/eduplay_database.dart';
import 'package:smart_reading_buddy/features/eduplay_encoding/services/eduplay_engine_holder.dart';
import 'package:smart_reading_buddy/features/eduplay_encoding/screens/eduplay/parent_recommendation_screen.dart';

const Color _kGreen = Color(0xFF2ECC71);
const Color _kAmber = Color(0xFFF59E0B);
const Color _kRed = Color(0xFFEF4444);
const Color _kBlue = Color(0xFF3B82F6);
const Color _kTextPrimary = Color(0xFF1A1A1A);
const Color _kTextSecondary = Color(0xFF6B7280);

// Exact skill_area -> display-name mapping, per the feature-builder's
// skill_area convention (see feature_builder.dart / task JSON). Kept here
// rather than reusing kActivityDisplayNames (keyed by activity_type, a
// different field) since Lesson Mastery groups by skill_area.
const Map<String, String> _kSkillDisplayNames = {
  'letter_order': 'Letter Drag & Drop',
  'sound_recognition': 'Word Recognition',
  'spelling_gap': 'Fill in the Blanks',
  'sentence_order': 'Sentence Drag & Drop',
  'meaning_understanding': 'Sentence Quiz',
};

const List<String> _kSkillOrder = [
  'letter_order',
  'sound_recognition',
  'spelling_gap',
  'sentence_order',
  'meaning_understanding',
];

/// EduPlay's parent-facing "Learning Journey" hub — 5-tab bottom nav.
/// Dashboard is the only tab built rich; Picks/Assigned reuse the
/// existing ParentRecommendationScreen (navigated to, not modified);
/// Progress is a placeholder; Profile is a minimal real read-only screen.
/// Reads exclusively from EduPlayDatabase — nothing here touches
/// reading_buddy.db, and ParentRecommendationScreen's own approve/
/// override/dismiss logic is untouched.
class EduPlayParentJourneyScreen extends StatefulWidget {
  final String childId;
  const EduPlayParentJourneyScreen({super.key, required this.childId});

  @override
  State<EduPlayParentJourneyScreen> createState() => _EduPlayParentJourneyScreenState();
}

class _EduPlayParentJourneyScreenState extends State<EduPlayParentJourneyScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: Text(
          'Learning Journey',
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: _kTextPrimary),
        ),
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _DashboardTab(childId: widget.childId),
          const ComingSoonPlaceholder(
            title: 'Detailed Progress',
            emoji: '📈',
            accent: _kGreen,
            message: 'More detailed charts are coming soon.',
          ),
          _PicksTab(childId: widget.childId),
          _AssignedTab(childId: widget.childId),
          _ProfileTab(childId: widget.childId),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        selectedItemColor: _kGreen,
        unselectedItemColor: _kTextSecondary,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_rounded), label: 'Picks'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_rounded), label: 'Assigned'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ── Tab 1: Dashboard ────────────────────────────────────────────────────

class _DashboardTab extends StatefulWidget {
  final String childId;
  const _DashboardTab({required this.childId});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  Map<String, String> _skillMap = {};
  double _overallAccuracy = 0;
  int _exercisesDone = 0;
  int _totalXp = 0;
  int _sessionsThisWeek = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await EduPlayDatabase.getChildProfile(widget.childId);
    final skillMap = await EduPlayDatabase.getSkillAccuracyMap(widget.childId);
    final overallAccuracy = await EduPlayDatabase.getOverallAccuracy(widget.childId);
    final exercisesDone = await EduPlayDatabase.countCompletedActivities(widget.childId);
    final totalXp = await EduPlayDatabase.getTotalXp(widget.childId);
    final sessionsThisWeek = await EduPlayDatabase.getSessionCountThisWeek(widget.childId);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _skillMap = skillMap;
      _overallAccuracy = overallAccuracy;
      _exercisesDone = exercisesDone;
      _totalXp = totalXp;
      _sessionsThisWeek = sessionsThisWeek;
      _loading = false;
    });
  }

  /// Lowest-scoring skill, or null if there's no data or every skill is
  /// already at/above 65% — the needs-practice alert's gate.
  MapEntry<String, double>? _weakestSkillBelowThreshold() {
    if (_skillMap.isEmpty) return null;
    final parsed = _skillMap.map((k, v) => MapEntry(k, double.tryParse(v.replaceAll('%', '')) ?? 0));
    final weakest = parsed.entries.reduce((a, b) => a.value <= b.value ? a : b);
    return weakest.value < 65 ? weakest : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGreen));

    final weakest = _weakestSkillBelowThreshold();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ChildHeaderCard(childId: widget.childId, profile: _profile),
        if (weakest != null) ...[
          const SizedBox(height: 16),
          _NeedsPracticeAlert(skillKey: weakest.key, percentage: weakest.value),
        ],
        const SizedBox(height: 16),
        _RecommendedLessonsButton(childId: widget.childId),
        const SizedBox(height: 20),
        _ProgressOverviewGrid(
          overallAccuracy: _overallAccuracy,
          exercisesDone: _exercisesDone,
          totalXp: _totalXp,
          sessionsThisWeek: _sessionsThisWeek,
        ),
        const SizedBox(height: 24),
        Text('Lesson Mastery', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: _kTextPrimary)),
        const SizedBox(height: 10),
        for (final skill in _kSkillOrder) _LessonMasteryRow(skillKey: skill, rawValue: _skillMap[skill]),
      ],
    );
  }
}

class _ChildHeaderCard extends StatelessWidget {
  final String childId;
  final Map<String, dynamic>? profile;
  const _ChildHeaderCard({required this.childId, required this.profile});

  @override
  Widget build(BuildContext context) {
    final grade = profile?['grade'] as String?;
    final level = profile?['starting_level'] as String?;
    final language = profile?['language'] as String?;
    final gradeLevelLine = [if (grade != null) grade, if (level != null) level].join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Center(
              child: Text('🦉', style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(childId, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                if (gradeLevelLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(gradeLevelLine, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                ],
                if (language != null) ...[
                  const SizedBox(height: 2),
                  Text(language, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedsPracticeAlert extends StatelessWidget {
  final String skillKey;
  final double percentage;
  const _NeedsPracticeAlert({required this.skillKey, required this.percentage});

  @override
  Widget build(BuildContext context) {
    final displayName = _kSkillDisplayNames[skillKey] ?? skillKey;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(14),
        border: const Border(left: BorderSide(color: _kRed, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, color: _kRed),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Needs Practice: $displayName', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: _kRed)),
                const SizedBox(height: 2),
                Text('Most common area: $displayName', style: GoogleFonts.nunito(fontSize: 13, color: _kTextSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(20)),
            child: Text('Needs Practice', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _RecommendedLessonsButton extends StatelessWidget {
  final String childId;
  const _RecommendedLessonsButton({required this.childId});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kGreen,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParentRecommendationScreen(childId: childId, engine: EduPlayEngineHolder.instance),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'View Recommended Lessons',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressOverviewGrid extends StatelessWidget {
  final double overallAccuracy;
  final int exercisesDone;
  final int totalXp;
  final int sessionsThisWeek;

  const _ProgressOverviewGrid({
    required this.overallAccuracy,
    required this.exercisesDone,
    required this.totalXp,
    required this.sessionsThisWeek,
  });

  static Color _accuracyColor(double v) => v >= 75 ? _kGreen : (v >= 50 ? _kAmber : _kRed);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.6,
        children: [
          _GridCell(icon: Icons.bar_chart_rounded, iconColor: _accuracyColor(overallAccuracy), value: '${overallAccuracy.round()}%', label: 'Overall Accuracy'),
          _GridCell(icon: Icons.check_circle_rounded, iconColor: _kGreen, value: '$exercisesDone', label: 'Exercises Done'),
          _GridCell(icon: Icons.bolt_rounded, iconColor: _kAmber, value: '$totalXp ⚡', label: 'Total XP'),
          _GridCell(icon: Icons.calendar_today_rounded, iconColor: _kBlue, value: '$sessionsThisWeek', label: 'Sessions This Week'),
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  const _GridCell({required this.icon, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: _kTextPrimary)),
        Text(label, style: GoogleFonts.nunito(fontSize: 12, color: _kTextSecondary)),
      ],
    );
  }
}

class _LessonMasteryRow extends StatelessWidget {
  final String skillKey;
  final String? rawValue; // e.g. "78%", null = not started

  const _LessonMasteryRow({required this.skillKey, required this.rawValue});

  @override
  Widget build(BuildContext context) {
    final displayName = _kSkillDisplayNames[skillKey] ?? skillKey;
    final percentage = rawValue == null ? null : double.tryParse(rawValue!.replaceAll('%', ''));
    final color = percentage == null ? const Color(0xFFE5E7EB) : (percentage >= 75 ? _kGreen : (percentage >= 50 ? _kAmber : _kRed));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(displayName, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: _kTextPrimary)),
              if (percentage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text('${percentage.round()}%', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
                )
              else
                Text('Not started yet', style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: _kTextSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percentage ?? 0) / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 3: Picks / Tab 4: Assigned ──────────────────────────────────────
//
// ParentRecommendationScreen owns its own Scaffold+AppBar+internal TabBar
// (Current Recommendation / Assignment History) — embedding it directly
// as a tab body would nest a second AppBar/TabBar inside this screen's
// own bottom-nav tab, and would still let the parent swipe to the OTHER
// internal tab, defeating the point of Picks/Assigned being separate. The
// less invasive option (per the brief) is used instead: each tab is a
// simple card that navigates to ParentRecommendationScreen with
// initialTabIndex set to the matching internal tab — no duplication of
// its list/approve/override/dismiss UI code.

class _PicksTab extends StatelessWidget {
  final String childId;
  const _PicksTab({required this.childId});

  @override
  Widget build(BuildContext context) {
    return _RecommendationEntryCard(
      childId: childId,
      initialTabIndex: 0,
      emoji: '✨',
      title: 'Today\'s Pick',
      subtitle: 'See the lesson recommended for $childId right now.',
      buttonLabel: 'View Recommendation',
    );
  }
}

class _AssignedTab extends StatelessWidget {
  final String childId;
  const _AssignedTab({required this.childId});

  @override
  Widget build(BuildContext context) {
    return _RecommendationEntryCard(
      childId: childId,
      initialTabIndex: 1,
      emoji: '📋',
      title: 'Assignment History',
      subtitle: 'See every lesson assigned to $childId so far, and how they did.',
      buttonLabel: 'View Assignment History',
    );
  }
}

class _RecommendationEntryCard extends StatelessWidget {
  final String childId;
  final int initialTabIndex;
  final String emoji;
  final String title;
  final String subtitle;
  final String buttonLabel;

  const _RecommendationEntryCard({
    required this.childId,
    required this.initialTabIndex,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: _kTextPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 14, color: _kTextSecondary)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ParentRecommendationScreen(
                      childId: childId,
                      engine: EduPlayEngineHolder.instance,
                      initialTabIndex: initialTabIndex,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(buttonLabel, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 5: Profile ──────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final String childId;
  const _ProfileTab({required this.childId});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _loading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await EduPlayDatabase.getChildProfile(widget.childId);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  String _formatCreatedAt(String? raw) {
    if (raw == null) return 'Unknown';
    final d = DateTime.tryParse(raw);
    if (d == null) return 'Unknown';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _kGreen));

    final profile = _profile;
    if (profile == null) {
      return Center(
        child: Text('No profile data yet.', style: GoogleFonts.nunito(fontSize: 15, color: _kTextSecondary)),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Center(child: Text('🦉', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(height: 14),
              Text(widget.childId, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: _kTextPrimary)),
              const SizedBox(height: 18),
              _ProfileRow(label: 'Grade', value: profile['grade'] as String? ?? '—'),
              _ProfileRow(label: 'Level', value: profile['starting_level'] as String? ?? '—'),
              _ProfileRow(label: 'Language', value: profile['language'] as String? ?? '—'),
              _ProfileRow(label: 'Member since', value: _formatCreatedAt(profile['created_at'] as String?)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 14, color: _kTextSecondary)),
          Text(value, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: _kTextPrimary)),
        ],
      ),
    );
  }
}
