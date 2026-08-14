import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_colors.dart';
import '../../models/local_storage.dart';
import '../../services/cross_language_analyzer.dart';
import '../../services/practice_suggestion_service.dart';
import '../../services/session_logger.dart';

const _avatarMap = {
  'owl': '🦉', 'tiger': '🐯', 'frog': '🐸',
  'fox': '🦊', 'panda': '🐼', 'lion': '🦁',
};

/// Real pronunciation analytics for the parent dashboard, built entirely
/// from the existing PEPA phoneme-attempt log (phoneme_attempts table —
/// see SessionLogger.savePhonemeAttempts). No mock/sample data.
///
/// [profileName] is passed explicitly from ParentDashboardScreen rather than
/// read off AppState.name here — AppState.name is only populated once a
/// child's own PIN has been validated (see child_pin_screen.dart), but the
/// parent flow can be reached without that ever happening (profile-select
/// screen's "Parent" button skips straight to the PIN gate), so relying on
/// the global silently queried with an empty/stale profile name and showed
/// a blank screen despite real data existing in SQLite.
class ParentPronunciationAnalyticsScreen extends StatefulWidget {
  final String profileName;

  const ParentPronunciationAnalyticsScreen({
    super.key,
    required this.profileName,
  });

  @override
  State<ParentPronunciationAnalyticsScreen> createState() =>
      _ParentPronunciationAnalyticsScreenState();
}

class _ParentPronunciationAnalyticsScreenState
    extends State<ParentPronunciationAnalyticsScreen> {
  bool _loading = true;

  UserProfile? _profile;
  int _sessionCount = 0;
  int _streak = 0;
  ({int totalWords, int correctWords}) _wordAccuracy = (totalWords: 0, correctWords: 0);
  List<Map<String, dynamic>> _phonemeStats = [];
  List<CrossLanguagePattern> _crossPatterns = [];
  List<Map<String, dynamic>> _substitutionPatterns = [];
  List<PracticeSuggestion> _practiceSuggestions = [];
  List<Map<String, dynamic>> _assignedPracticeHistory = [];
  double? _trendDelta; // positive = improving, negative = declining, null = not enough data

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profileName = widget.profileName;

    final profiles = await LocalStorage.getAllProfiles();
    final profile = profiles.where((p) => p.name == profileName).firstOrNull;

    final sessionCount = await SessionLogger.getSessionCount(profileName: profileName);
    final streak = await SessionLogger.getStreakDaysForProfile(profileName);
    final wordAccuracy = await SessionLogger.getWordAccuracy(profileName: profileName);
    final phonemeStats = await SessionLogger.getPhonemeStats(profileName: profileName);
    final crossPatterns = await CrossLanguageAnalyzer.analyze(profileName: profileName);
    final timeline = await SessionLogger.getSessionAccuracyTimeline(profileName: profileName);
    final trendDelta = _computeTrend(timeline);
    final substitutionPatterns =
        await SessionLogger.getTopSubstitutionPatterns(profileName: profileName);
    final practiceSuggestions =
        await PracticeSuggestionService.getSuggestions(profileName: profileName);
    final assignedPracticeHistory =
        await SessionLogger.getAssignedPracticeHistory(profileName: profileName);

    // ── Part 1 debug output: raw PEPA data shape, empty vs populated ──────
    debugPrint('[ParentPronunciationAnalytics] profileName="$profileName"');
    debugPrint('[ParentPronunciationAnalytics] profile found in LocalStorage: ${profile != null}');
    debugPrint('[ParentPronunciationAnalytics] sessionCount=$sessionCount streak=$streak');
    debugPrint('[ParentPronunciationAnalytics] wordAccuracy total=${wordAccuracy.totalWords} '
        'correct=${wordAccuracy.correctWords}');
    debugPrint('[ParentPronunciationAnalytics] phonemeStats rows=${phonemeStats.length} '
        '(empty=${phonemeStats.isEmpty}) raw=$phonemeStats');
    debugPrint('[ParentPronunciationAnalytics] crossPatterns=${crossPatterns.length}');
    debugPrint('[ParentPronunciationAnalytics] timeline sessions=${timeline.length} trendDelta=$trendDelta');
    debugPrint('[ParentPronunciationAnalytics] substitutionPatterns (minOccurrences=3) '
        'rows=${substitutionPatterns.length} raw=$substitutionPatterns');
    debugPrint('[ParentPronunciationAnalytics] practiceSuggestions=${practiceSuggestions.length}');
    debugPrint('[ParentPronunciationAnalytics] assignedPracticeHistory=${assignedPracticeHistory.length}');

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _sessionCount = sessionCount;
      _streak = streak;
      _wordAccuracy = wordAccuracy;
      _phonemeStats = phonemeStats;
      _crossPatterns = crossPatterns;
      _practiceSuggestions = practiceSuggestions;
      _trendDelta = trendDelta;
      _substitutionPatterns = substitutionPatterns;
      _assignedPracticeHistory = assignedPracticeHistory;
      _loading = false;
    });
  }

  /// Compares average word accuracy of the most recent sessions against the
  /// sessions before that, split roughly in half (capped at 5 sessions per
  /// side so a couple of bad early attempts don't get diluted by dozens of
  /// later ones). Returns null if there isn't enough history to compare.
  double? _computeTrend(
    List<({int sessionId, int totalWords, int correctWords})> timeline,
  ) {
    if (timeline.length < 2) return null;
    final windowSize = (timeline.length / 2).floor().clamp(1, 5);
    final recent = timeline.sublist(timeline.length - windowSize);
    final earlier = timeline.sublist(0, timeline.length - windowSize);
    if (earlier.isEmpty) return null;

    double accuracyOf(List<({int sessionId, int totalWords, int correctWords})> entries) {
      final total = entries.fold<int>(0, (s, e) => s + e.totalWords);
      final correct = entries.fold<int>(0, (s, e) => s + e.correctWords);
      return total == 0 ? 0.0 : correct / total;
    }

    return accuracyOf(recent) - accuracyOf(earlier);
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _wordAccuracy.totalWords > 0;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pronunciation,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pronunciation Progress'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !hasData
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _HeaderCard(
                      profile: _profile,
                      profileNameFallback: widget.profileName,
                      sessionCount: _sessionCount,
                    ),
                    const SizedBox(height: 20),
                    _StatsRow(
                      accuracy: _wordAccuracy.totalWords == 0
                          ? 0
                          : _wordAccuracy.correctWords / _wordAccuracy.totalWords,
                      wordsPracticed: _wordAccuracy.totalWords,
                      streak: _streak,
                    ),
                    if (_trendDelta != null) ...[
                      const SizedBox(height: 16),
                      _TrendCard(delta: _trendDelta!),
                    ],
                    if (_crossPatterns.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _CrossLanguagePatternCard(patterns: _crossPatterns),
                    ],
                    const SizedBox(height: 20),
                    _TroubleSoundsCard(stats: _phonemeStats, onAssign: _assignPractice),
                    if (_substitutionPatterns.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SoundPatternsCard(patterns: _substitutionPatterns, onAssign: _assignPractice),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showAllSoundPatterns(context),
                        icon: const Icon(Icons.list_alt_rounded, size: 18),
                        label: const Text('View all sound patterns'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.pronunciation,
                          textStyle: GoogleFonts.nunito(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (_practiceSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _PracticeSuggestionsCard(suggestions: _practiceSuggestions),
                    ],
                    if (_assignedPracticeHistory.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _AssignedPracticeHistoryCard(history: _assignedPracticeHistory),
                    ],
                  ],
                ),
    );
  }

  /// Stores a local-only "assigned practice" flag for this child, picked
  /// up by pronunciation_home_screen.dart next time they open the
  /// Pronunciation module. See LocalStorage.setAssignedPractice.
  Future<void> _assignPractice(String phoneme, String language) async {
    await LocalStorage.setAssignedPractice(
      profileName: widget.profileName,
      phoneme: phoneme,
      language: language,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Practice for "$phoneme" assigned to ${widget.profileName}',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows every detected substitution pair, including ones still below
  /// the 3-occurrence "confirmed pattern" threshold — the confirmed-only
  /// card above can stay empty for a long time on a real child with only
  /// a few sessions, so this gives visibility into what's accumulating
  /// rather than showing nothing at all.
  Future<void> _showAllSoundPatterns(BuildContext context) async {
    final all = await SessionLogger.getTopSubstitutionPatterns(
      profileName: widget.profileName,
      minOccurrences: 1,
    );
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AllSoundPatternsSheet(patterns: all),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎙️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No pronunciation data yet',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete a pronunciation session to see progress here.',
              style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final UserProfile? profile;
  final String profileNameFallback;
  final int sessionCount;

  const _HeaderCard({
    required this.profile,
    required this.profileNameFallback,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = _avatarMap[profile?.avatar] ?? '🦉';
    final name = profile?.name ?? profileNameFallback;
    final grade = profile?.grade == 'grade3'
        ? 'Grade 3'
        : profile?.grade == 'grade4'
            ? 'Grade 4'
            : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 34)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (grade != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    grade,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '$sessionCount session${sessionCount == 1 ? '' : 's'} completed',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}

// ── Overview stats row ──────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final double accuracy;
  final int wordsPracticed;
  final int streak;

  const _StatsRow({
    required this.accuracy,
    required this.wordsPracticed,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        icon: Icons.check_circle_rounded,
        value: '${(accuracy * 100).round()}%',
        label: 'Accuracy',
        accent: AppColors.primary,
      ),
      _StatCard(
        icon: Icons.record_voice_over_rounded,
        value: '$wordsPracticed',
        label: 'Words Practiced',
        accent: AppColors.accentBlue,
      ),
      _StatCard(
        icon: Icons.local_fire_department_rounded,
        value: '$streak',
        label: 'Day Streak',
        accent: AppColors.accentOrange,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i].animate(delay: (i * 80).ms).fadeIn().slideY(begin: 0.15)),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trend indicator ─────────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  final double delta; // fraction, e.g. 0.12 = +12pp

  const _TrendCard({required this.delta});

  @override
  Widget build(BuildContext context) {
    final improving = delta > 0.01;
    final declining = delta < -0.01;
    final color = improving
        ? AppColors.primary
        : declining
            ? AppColors.danger
            : AppColors.textSecondary;
    final icon = improving
        ? Icons.trending_up_rounded
        : declining
            ? Icons.trending_down_rounded
            : Icons.trending_flat_rounded;
    final label = improving
        ? 'Accuracy improving — up ${(delta * 100).abs().round()} pts over recent sessions'
        : declining
            ? 'Accuracy dipped — down ${(delta * 100).abs().round()} pts over recent sessions'
            : 'Accuracy holding steady across recent sessions';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

// ── Cross-language pattern card ─────────────────────────────────────────

class _CrossLanguagePatternCard extends StatelessWidget {
  final List<CrossLanguagePattern> patterns;

  const _CrossLanguagePatternCard({required this.patterns});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.25)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentPurple.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.compare_arrows_rounded,
                    color: AppColors.accentPurple, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cross-Language Pattern',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...patterns.map((p) {
            final m = p.mapping;
            final enPct = (p.englishErrorRate * 100).round();
            final siPct = (p.sinhalaErrorRate * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                "Your child shows difficulty with the '${m.englishPhoneme.toUpperCase()}' "
                "sound in both Sinhala (${m.sinhalaScript}) and English — this may "
                "indicate a shared phonological pattern worth focused practice. "
                "(Sinhala error rate: $siPct%, English error rate: $enPct%)",
                style: GoogleFonts.nunito(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}

// ── Top struggling phonemes ─────────────────────────────────────────────

class _TroubleSoundsCard extends StatelessWidget {
  final List<Map<String, dynamic>> stats;
  final void Function(String phoneme, String language) onAssign;

  const _TroubleSoundsCard({required this.stats, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    // Ignore near-zero-sample rows so a single unlucky attempt doesn't
    // dominate the ranking.
    final ranked = stats.where((r) => (r['total'] as int) >= 2).take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Struggling Phonemes',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sounds with the highest error rate, most difficult first.',
            style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (ranked.isEmpty)
            Text(
              'Not enough attempts yet to rank trouble sounds.',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            ...ranked.indexed.map((entry) {
              final i = entry.$1;
              final row = entry.$2;
              final total = row['total'] as int;
              final incorrect = row['incorrect'] as int;
              final rate = total == 0 ? 0.0 : incorrect / total;
              return _PhonemeBar(
                rank: i + 1,
                phoneme: row['phoneme'] as String,
                language: row['language'] as String,
                errorRate: rate,
                onAssign: onAssign,
              ).animate(delay: (i * 70).ms).fadeIn().slideX(begin: 0.1);
            }),
        ],
      ),
    );
  }
}

class _PhonemeBar extends StatelessWidget {
  final int rank;
  final String phoneme;
  final String language;
  final double errorRate;
  final void Function(String phoneme, String language) onAssign;

  const _PhonemeBar({
    required this.rank,
    required this.phoneme,
    required this.language,
    required this.errorRate,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (errorRate * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              phoneme,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Container(
                          height: 10,
                          width: constraints.maxWidth,
                          color: AppColors.divider,
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 10,
                          width: constraints.maxWidth * errorRate.clamp(0.0, 1.0),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.danger, Color(0xFFF39C6B)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  language == 'si' ? 'Sinhala' : 'English',
                  style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$pct%',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
            ),
          ),
          _AssignPracticeButton(
            onTap: () => onAssign(phoneme, language),
          ),
        ],
      ),
    );
  }
}

/// Compact "Assign Practice" tap target — reused by both Top Struggling
/// Phonemes rows and Sound Patterns rows.
class _AssignPracticeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AssignPracticeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Assign Practice',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_task_rounded,
            size: 18,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

// ── Sound patterns (substitutions) ──────────────────────────────────────

class _SoundPatternsCard extends StatelessWidget {
  final List<Map<String, dynamic>> patterns;
  final void Function(String phoneme, String language) onAssign;

  const _SoundPatternsCard({required this.patterns, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    // getTopSubstitutionPatterns already orders by occurrences DESC and is
    // pre-filtered to minOccurrences:3 — just cap how many rows we show.
    final top = patterns.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sound Patterns',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sounds your child consistently says instead of the correct one.',
            style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...top.indexed.map((entry) {
            final i = entry.$1;
            final row = entry.$2;
            return _SubstitutionRow(
              expected: row['expected_phoneme'] as String,
              produced: row['produced_phoneme'] as String,
              language: row['language'] as String,
              occurrences: row['occurrences'] as int,
              onAssign: onAssign,
            ).animate(delay: (i * 70).ms).fadeIn().slideX(begin: 0.1);
          }),
        ],
      ),
    );
  }
}

class _SubstitutionRow extends StatelessWidget {
  final String expected;
  final String produced;
  final String language;
  final int occurrences;
  final void Function(String phoneme, String language) onAssign;

  const _SubstitutionRow({
    required this.expected,
    required this.produced,
    required this.language,
    required this.occurrences,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      expected,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'often said as',
                      style: GoogleFonts.nunito(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      produced,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  language == 'si' ? 'Sinhala' : 'English',
                  style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${occurrences}x',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          _AssignPracticeButton(
            onTap: () => onAssign(expected, language),
          ),
        ],
      ),
    );
  }
}

// ── All sound patterns (unfiltered — developing + confirmed) ────────────

class _AllSoundPatternsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> patterns;

  const _AllSoundPatternsSheet({required this.patterns});

  static const _confirmThreshold = 3; // matches SessionLogger's default

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'All Sound Patterns',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A pattern needs $_confirmThreshold+ repeats to become a confirmed '
              'sound pattern above — this shows everything, including ones still '
              'building up.',
              style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (patterns.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No substitution data recorded yet.',
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: patterns.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final row = patterns[i];
                    final occurrences = row['occurrences'] as int;
                    final confirmed = occurrences >= _confirmThreshold;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: confirmed
                            ? AppColors.primarySurface
                            : AppColors.pageBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                children: [
                                  TextSpan(text: '${row['expected_phoneme']}'),
                                  TextSpan(
                                    text: '  →  ',
                                    style: GoogleFonts.nunito(color: AppColors.textSecondary),
                                  ),
                                  TextSpan(
                                    text: '${row['produced_phoneme']}',
                                    style: const TextStyle(color: AppColors.danger),
                                  ),
                                  TextSpan(
                                    text: '   (${row['language'] == 'si' ? 'Sinhala' : 'English'})',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (confirmed ? AppColors.primary : AppColors.textHint)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              confirmed ? '$occurrences× confirmed' : '$occurrences× so far',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: confirmed ? AppColors.primaryDark : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Practice suggestions ─────────────────────────────────────────────────

class _PracticeSuggestionsCard extends StatelessWidget {
  final List<PracticeSuggestion> suggestions;

  const _PracticeSuggestionsCard({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    final top = suggestions.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Practice Suggestions',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'What to try at home for each confirmed sound pattern.',
            style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...top.indexed.map((entry) {
            final i = entry.$1;
            final s = entry.$2;
            return _PracticeSuggestionTile(suggestion: s)
                .animate(delay: (i * 70).ms)
                .fadeIn()
                .slideY(begin: 0.1);
          }),
        ],
      ),
    );
  }
}

class _PracticeSuggestionTile extends StatefulWidget {
  final PracticeSuggestion suggestion;

  const _PracticeSuggestionTile({required this.suggestion});

  @override
  State<_PracticeSuggestionTile> createState() => _PracticeSuggestionTileState();
}

class _PracticeSuggestionTileState extends State<_PracticeSuggestionTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: RichText(
            text: TextSpan(
              style: GoogleFonts.nunito(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(text: s.expectedSound),
                TextSpan(
                  text: '  →  ',
                  style: GoogleFonts.nunito(color: AppColors.textSecondary),
                ),
                TextSpan(text: s.producedSound, style: const TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
          subtitle: Text(
            '${s.language == 'si' ? 'Sinhala' : 'English'} · seen ${s.occurrences}x',
            style: GoogleFonts.nunito(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          children: [
            Text(
              s.tip,
              style: GoogleFonts.nunito(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            if (s.practiceWords.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Practice words',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: s.practiceWords.map((w) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      '${w.emoji} ${w.word}',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Assigned practice history ────────────────────────────────────────────

class _AssignedPracticeHistoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const _AssignedPracticeHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assigned Practice History',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Results from sounds you assigned for extra practice.',
            style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...history.indexed.map((entry) {
            final i = entry.$1;
            final row = entry.$2;
            return _AssignedPracticeHistoryTile(row: row)
                .animate(delay: (i * 70).ms)
                .fadeIn()
                .slideY(begin: 0.1);
          }),
        ],
      ),
    );
  }
}

class _AssignedPracticeHistoryTile extends StatelessWidget {
  final Map<String, dynamic> row;

  const _AssignedPracticeHistoryTile({required this.row});

  String _displaySound() {
    final phoneme = row['phoneme'] as String?;
    if (phoneme == null) return '?';
    if (row['language'] == 'si') {
      return PracticeSuggestionService.sinhalaScriptFor(phoneme) ?? phoneme;
    }
    return phoneme.toUpperCase();
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final correct = row['correct'] as int;
    final almost = row['almost'] as int;
    final wrong = row['wrong'] as int;
    final beforeRate = row['beforeErrorRate'] as double?;
    final afterRate = row['afterErrorRate'] as double?;
    final hasComparison = beforeRate != null && afterRate != null;
    final improved = hasComparison && afterRate < beforeRate;
    final worsened = hasComparison && afterRate > beforeRate;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_displaySound()} practice',
                  style: GoogleFonts.nunito(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(row['date'] as String),
                  style: GoogleFonts.nunito(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  '$correct correct · $almost almost · $wrong wrong',
                  style: GoogleFonts.nunito(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (hasComparison)
            Column(
              children: [
                Icon(
                  improved
                      ? Icons.trending_up_rounded
                      : worsened
                          ? Icons.trending_down_rounded
                          : Icons.trending_flat_rounded,
                  color: improved
                      ? AppColors.success
                      : worsened
                          ? AppColors.danger
                          : AppColors.textHint,
                  size: 22,
                ),
                Text(
                  improved ? 'Improved' : worsened ? 'Harder' : 'Same',
                  style: GoogleFonts.nunito(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: improved
                        ? AppColors.success
                        : worsened
                            ? AppColors.danger
                            : AppColors.textHint,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
