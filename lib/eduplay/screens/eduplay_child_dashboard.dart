import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_text.dart';
import '../../services/ble_command_service.dart';
import '../eduplay_constants.dart';
import '../eduplay_database.dart';
import '../eduplay_si_text.dart';
import 'activity_level_select.dart';

// ── Palette — app-wide green (#2ECC71) kept for brand consistency with
// Home/Pronunciation, per lesson colors come from kLessonColors ──────────
const _kPrimary = Color(0xFF2ECC71);
// Matches the EduPlay card's own gradient lead color on the Home screen
// grid (home_screen.dart's _ActivityCard gradientColors), so this screen's
// AppBar reads as the same module the child tapped into from Home — same
// pattern Pronunciation's AppBar follows against its own Home card color.
const _kHeaderAccent = Color(0xFF7B61FF);
const _kBg = Color(0xFFFAFAF7);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kAmberText = Color(0xFFD97706);

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
  Map<String, dynamic>? _activeAssignment;
  Map<String, String> _skillAccuracy = {};
  int _completedToday = 0;

  // Locked profile grade/language — read once from the child's own
  // EduPlay profile row, never offered as a UI choice.
  String _grade = 'Grade 3';
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _load();
    // Fire-and-forget — connecting to the physical buddy device is fully
    // optional. No spinner, no error UI on failure/timeout: send() already
    // no-ops safely when nothing is connected, so this screen must look
    // and behave identically whether or not a buddy is nearby.
    BleCommandService.instance.scanAndConnect();
  }

  Future<void> _load() async {
    final profile = await EduPlayDatabase.getChildProfile(widget.childId);
    final activeAssignment = await EduPlayDatabase.getActiveAssignment(widget.childId);
    // limit raised from the old default of 20 so "today" isn't clipped
    // once a child has practiced a lot historically.
    final recentSessions = await EduPlayDatabase.getRecentSessions(widget.childId, limit: 200);
    final skillAccuracy = await EduPlayDatabase.getSkillAccuracyMap(widget.childId);

    if (!mounted) return;
    setState(() {
      if (profile != null) {
        _grade = profile['grade'] as String? ?? _grade;
        _language = profile['language'] as String? ?? _language;
      }
      _activeAssignment = activeAssignment;
      _skillAccuracy = skillAccuracy;
      _completedToday = _computeCompletedToday(recentSessions);
      _loading = false;
    });
  }

  int _computeCompletedToday(List<Map<String, dynamic>> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final types = <String>{};
    for (final s in sessions) {
      final dt = DateTime.tryParse(s['completed_at'] as String? ?? '');
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day == today) {
        final type = s['activity_type'] as String?;
        if (type != null) types.add(type);
      }
    }
    return types.length > 5 ? 5 : types.length;
  }

  bool get _isSinhala => _language == 'Sinhala';

  @override
  Widget build(BuildContext context) {
    final isSinhala = _isSinhala;
    return Scaffold(
      backgroundColor: _kBg,
      // Matches Pronunciation's/Timed Reading's level-select AppBar
      // pattern (colored bg, white back arrow + title) instead of the
      // plain unstyled back-arrow Row this screen used before.
      appBar: AppBar(
        backgroundColor: _kHeaderAccent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppText.eduplay,
          style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          // Passive cue only — connected/disconnected, no tap action, no
          // text, nothing that implies the child needs to do anything.
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ValueListenableBuilder<bool>(
              valueListenable: BleCommandService.instance.connected,
              builder: (context, connected, _) => Icon(
                connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                color: Colors.white.withValues(alpha: connected ? 1.0 : 0.5),
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _kPrimary))
            : RefreshIndicator(
                onRefresh: _load,
                color: _kPrimary,
                child: ListView(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _HeroCard(childId: widget.childId, isSinhala: isSinhala),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _TodaysPracticeCard(completedToday: _completedToday, isSinhala: isSinhala),
                    ),
                    if (_activeAssignment != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _AssignedLessonBanner(
                          assignment: _activeAssignment!,
                          isSinhala: isSinhala,
                          onStart: () => _startActivity(_activeAssignment!['activity_type'] as String),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(isSinhala ? EduPlaySiText.yourLessons : 'Your Lessons', style: _title20(_kTextPrimary)),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < kActivityTypes.length; i++)
                      _LessonCard(
                        lessonNumber: i + 1,
                        activityType: kActivityTypes[i],
                        accuracyLabel: _skillAccuracy[kActivityTypes[i]],
                        isSinhala: isSinhala,
                        onStart: () => _startActivity(kActivityTypes[i]),
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

class _HeroCard extends StatelessWidget {
  final String childId;
  final bool isSinhala;

  const _HeroCard({required this.childId, required this.isSinhala});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _kPrimary, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isSinhala ? EduPlaySiText.heroTitle : 'Let\'s learn something new! 🌟', style: _title20(Colors.white)),
                const SizedBox(height: 4),
                Text(isSinhala ? EduPlaySiText.heroSubtitle : 'Pick a lesson and start your journey!',
                    style: GoogleFonts.nunito(
                        fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.3, color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Center(child: Text('🦉', style: TextStyle(fontSize: 32))),
          ),
        ],
      ),
    );
  }
}

class _TodaysPracticeCard extends StatelessWidget {
  final int completedToday;
  final bool isSinhala;

  const _TodaysPracticeCard({required this.completedToday, required this.isSinhala});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isSinhala ? EduPlaySiText.todaysPractice : "Today's Practice", style: _title18(_kTextPrimary)),
              Text(isSinhala ? EduPlaySiText.nOf5Lessons(completedToday) : '$completedToday / 5 Lessons',
                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completedToday / 5,
              minHeight: 8,
              backgroundColor: _kBorder,
              color: _kPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedLessonBanner extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final bool isSinhala;
  final VoidCallback onStart;

  const _AssignedLessonBanner({required this.assignment, required this.isSinhala, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final activityType = assignment['activity_type'] as String;
    final level = assignment['level'] as String;
    final accent = kLessonColors[activityType] ?? _kPrimary;
    final tint = kLessonBgTints[activityType] ?? const Color(0xFFFFF7ED);
    final activityName = isSinhala
        ? (EduPlaySiText.activityNames[activityType] ?? activityType)
        : (kActivityDisplayNames[activityType] ?? activityType);
    return Container(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border(left: BorderSide(color: accent, width: 4)),
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
                Text(isSinhala ? EduPlaySiText.specialTask : 'Special task for you!', style: _title18(_kTextPrimary)),
                const SizedBox(height: 4),
                Text('$activityName — $level', style: _small13(_kTextSecondary)),
              ],
            ),
          ),
          SizedBox(
            width: isSinhala ? 108 : 80,
            height: 44,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(isSinhala ? EduPlaySiText.start : 'Start',
                    maxLines: 1,
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              ),
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

class _LessonCard extends StatelessWidget {
  final int lessonNumber;
  final String activityType;
  final String? accuracyLabel; // null = "New"
  final bool isSinhala;
  final VoidCallback onStart;

  const _LessonCard({
    required this.lessonNumber,
    required this.activityType,
    required this.accuracyLabel,
    required this.isSinhala,
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
    final accent = kLessonColors[activityType] ?? _kPrimary;
    final tint = kLessonBgTints[activityType] ?? const Color(0xFFE8F8F0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isSinhala ? EduPlaySiText.lessonN(lessonNumber) : 'Lesson $lessonNumber',
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: accent)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(16)),
                child: Icon(_kActivityIcons[activityType] ?? Icons.games_rounded, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        isSinhala
                            ? (EduPlaySiText.activityNames[activityType] ?? activityType)
                            : (kActivityDisplayNames[activityType] ?? activityType),
                        style: _title18(_kTextPrimary)),
                    const SizedBox(height: 2),
                    Text(
                        isSinhala
                            ? (EduPlaySiText.activityDescriptions[activityType] ?? '')
                            : (kLessonDescriptions[activityType] ?? ''),
                        style: _small13(_kTextSecondary)),
                    const SizedBox(height: 4),
                    Text(accuracyLabel ?? (isSinhala ? EduPlaySiText.newBadge : 'New'),
                        style: _small13(_accuracyColor(), weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: isSinhala ? 108 : 84,
                height: 44,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(isSinhala ? EduPlaySiText.start : 'Start',
                        maxLines: 1,
                        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
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
