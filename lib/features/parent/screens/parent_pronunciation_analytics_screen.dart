import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/local_storage.dart';
import 'package:smart_reading_buddy/features/parent/services/cross_language_analyzer.dart';
import 'package:smart_reading_buddy/features/parent/services/pdf_report_service.dart';
import 'package:smart_reading_buddy/core/services/practice_suggestion_service.dart';
import 'package:smart_reading_buddy/core/services/session_logger.dart';
import 'package:smart_reading_buddy/features/parent/services/wav_waveform.dart';

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
  List<Map<String, dynamic>> _wordConfusions = [];
  List<PracticeSuggestion> _practiceSuggestions = [];
  List<Map<String, dynamic>> _assignedPracticeHistory = [];
  List<Map<String, dynamic>> _wrongAttemptsWithAudio = [];
  Map<String, dynamic>? _lastSession; // null = no session within the last 3 days
  List<Map<String, dynamic>> _lastSessionAttempts = [];
  double? _trendDelta; // positive = improving, negative = declining, null = not enough data
  // Single-slot "active assignment" flag (LocalStorage.AssignedPractice —
  // see local_storage.dart, at most one per profile). Non-null suppresses
  // the PEPA-Driven Auto-Recommendation banner below, so the parent isn't
  // nagged about assigning practice when one is already pending.
  AssignedPractice? _activeAssignedPractice;

  /// Phonemes meeting PEPA's already-established "enough data to matter"
  /// bar — the exact same `total >= 2` filter _TroubleSoundsCard applies
  /// before ranking (see its `ranked` local), just not capped to its
  /// top-5 display limit. Deliberately not a new threshold: reusing this
  /// one is what requirement 1 asked for.
  List<Map<String, dynamic>> get _needsAttentionPhonemes =>
      _phonemeStats.where((r) => (r['total'] as int) >= 2).toList();

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
    final wordConfusions =
        await SessionLogger.getTopWordConfusions(profileName: profileName);
    final lastSession = await SessionLogger.getLastSessionWithinDays(profileName: profileName);
    final lastSessionAttempts = lastSession == null
        ? <Map<String, dynamic>>[]
        : await SessionLogger.getWordAttemptsForSession(lastSession['session_id'] as int);
    final practiceSuggestions =
        await PracticeSuggestionService.getSuggestions(profileName: profileName);
    // Fetched generously (not just the 3 shown by default) so "View all"
    // can reuse the same in-memory list rather than a second query.
    final assignedPracticeHistory =
        await SessionLogger.getAssignedPracticeHistory(profileName: profileName, limit: 100);
    final wrongAttemptsWithAudio =
        await SessionLogger.getWrongAttemptsWithAudio(profileName: profileName);
    final activeAssignedPractice = await LocalStorage.getAssignedPractice(profileName);

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
      _wordConfusions = wordConfusions;
      _lastSession = lastSession;
      _lastSessionAttempts = lastSessionAttempts;
      _assignedPracticeHistory = assignedPracticeHistory;
      _wrongAttemptsWithAudio = wrongAttemptsWithAudio;
      _activeAssignedPractice = activeAssignedPractice;
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
                    if (_needsAttentionPhonemes.isNotEmpty && _activeAssignedPractice == null) ...[
                      const SizedBox(height: 16),
                      _AutoRecommendationBanner(
                        count: _needsAttentionPhonemes.length,
                        onTap: () => _showAutoRecommendationSheet(context),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _StatsRow(
                      accuracy: _wordAccuracy.totalWords == 0
                          ? 0
                          : _wordAccuracy.correctWords / _wordAccuracy.totalWords,
                      wordsPracticed: _wordAccuracy.totalWords,
                      streak: _streak,
                    ),
                    const SizedBox(height: 12),
                    _CompactFeatureButton(
                      emoji: '📄',
                      label: 'Export Report',
                      onTap: () => _exportReport(context),
                    ),
                    if (_trendDelta != null) ...[
                      const SizedBox(height: 16),
                      _TrendCard(delta: _trendDelta!),
                    ],
                    if (_crossPatterns.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _CrossLanguagePatternCard(patterns: _crossPatterns),
                    ],
                    if (_wrongAttemptsWithAudio.isNotEmpty || _substitutionPatterns.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (_wrongAttemptsWithAudio.isNotEmpty)
                            Expanded(
                              child: _CompactFeatureButton(
                                emoji: '🎵',
                                label: 'Sound Waves',
                                onTap: () => _showSoundWaveList(context),
                              ),
                            ),
                          if (_wrongAttemptsWithAudio.isNotEmpty && _substitutionPatterns.isNotEmpty)
                            const SizedBox(width: 12),
                          if (_substitutionPatterns.isNotEmpty)
                            Expanded(
                              child: _CompactFeatureButton(
                                emoji: '🔊',
                                label: 'Sound Patterns',
                                onTap: () => _showSoundPatternsSheet(context),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (_wordConfusions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _CompactFeatureButton(
                        emoji: '🔤',
                        label: 'Word Confusion Patterns',
                        onTap: () => _showWordConfusionSheet(context),
                      ),
                    ],
                    if (_lastSession != null) ...[
                      const SizedBox(height: 12),
                      _CompactFeatureButton(
                        emoji: '📋',
                        label: 'Last Session Review',
                        onTap: () => _showLastSessionReview(context),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _TroubleSoundsCard(stats: _phonemeStats, onAssign: _assignPractice),
                    if (_practiceSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _PracticeSuggestionsCard(suggestions: _practiceSuggestions),
                    ],
                    if (_assignedPracticeHistory.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _AssignedPracticeHistoryCard(
                        history: _assignedPracticeHistory,
                        onDelete: (sessionId) => _dismissHistoryEntry(context, sessionId),
                        onViewAll: () => _showAllAssignedPracticeHistory(context),
                      ),
                    ],
                  ],
                ),
    );
  }

  /// Confirms, then removes one entry from the Assigned Practice History
  /// view only — see SessionLogger.dismissAssignedPracticeHistory's doc
  /// comment: the underlying session/word_attempts/phoneme_attempts data
  /// is untouched, this just stops that entry from showing up here.
  /// Returns whether it was actually confirmed+deleted, so callers that
  /// keep their own local copy of the list (see
  /// _AllAssignedPracticeHistorySheet) don't remove a row the parent
  /// then cancelled out of.
  Future<bool> _dismissHistoryEntry(BuildContext context, int sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this practice record?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    await SessionLogger.dismissAssignedPracticeHistory(
      profileName: widget.profileName,
      sessionId: sessionId,
    );
    if (!mounted) return true;
    setState(() {
      _assignedPracticeHistory = _assignedPracticeHistory.where((r) => r['sessionId'] != sessionId).toList();
    });
    return true;
  }

  /// Entry point for the Assigned Practice History card's "View all" —
  /// same content already loaded in _assignedPracticeHistory (fetched
  /// with a generous limit — see _load), just the full list instead of
  /// the top-3 the card shows by default.
  void _showAllAssignedPracticeHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AllAssignedPracticeHistorySheet(
        history: _assignedPracticeHistory,
        onDelete: (sessionId) => _dismissHistoryEntry(context, sessionId),
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
    // Refresh the single-slot flag so the auto-recommendation banner
    // (and any future load) reflects the new pending assignment right
    // away, without needing a full screen reload.
    final activeAssignedPractice = await LocalStorage.getAssignedPractice(widget.profileName);
    if (mounted) setState(() => _activeAssignedPractice = activeAssignedPractice);
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

  /// Entry point for the "Export Report" button — asks which language the
  /// PDF should be written in (the parent may be sharing it with an
  /// English- or Sinhala-speaking professional, independent of the app's
  /// own UI language), generates it, then hands off to the OS share sheet.
  Future<void> _exportReport(BuildContext context) async {
    final sinhala = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Report Language', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          'Which language should the exported report use?',
          style: GoogleFonts.nunito(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('English', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('සිංහල', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (sinhala == null || !mounted) return; // dialog dismissed

    final grade = _profile?.grade == 'grade3'
        ? 'Grade 3'
        : _profile?.grade == 'grade4'
            ? 'Grade 4'
            : null;

    final bytes = await PdfReportService.generate(
      childName: _profile?.name ?? widget.profileName,
      grade: grade,
      sinhala: sinhala,
      sessionCount: _sessionCount,
      accuracy: _wordAccuracy.totalWords == 0 ? 0 : _wordAccuracy.correctWords / _wordAccuracy.totalWords,
      wordsPracticed: _wordAccuracy.totalWords,
      phonemeStats: _phonemeStats,
      crossPatterns: _crossPatterns,
      substitutionPatterns: _substitutionPatterns,
    );

    await Printing.sharePdf(bytes: bytes, filename: 'speech_progress_report.pdf');
  }

  /// Opens the sheet listing every phoneme currently meeting PEPA's
  /// "needs attention" bar (see _needsAttentionPhonemes) — the banner's
  /// tap target. Each row reuses _PhonemeBar (same widget Top Struggling
  /// Phonemes uses) and _assignPractice (same write path), so there's no
  /// separate assign-practice logic to keep in sync.
  void _showAutoRecommendationSheet(BuildContext context) {
    final qualifying = _needsAttentionPhonemes;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AutoRecommendationSheet(
        phonemes: qualifying,
        onAssign: _assignPractice,
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

  /// Opens the "Sound Wave Comparison" view for one WRONG attempt —
  /// reference pronunciation vs the child's own saved recording.
  void _showWaveformComparison(BuildContext context, Map<String, dynamic> attempt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SoundWaveComparisonSheet(attempt: attempt),
    );
  }

  /// Entry point for the "🎵 Sound Waves" compact button — the list of
  /// recent WRONG attempts with saved audio, tapping one opens
  /// _showWaveformComparison exactly as before. Same data/content as the
  /// old always-visible _SoundWaveReviewCard, just behind a tap now.
  void _showSoundWaveList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _SoundWaveListSheet(
        attempts: _wrongAttemptsWithAudio,
        onTapAttempt: (a) => _showWaveformComparison(sheetContext, a),
      ),
    );
  }

  /// Entry point for the "🔊 Sound Patterns" compact button — same
  /// top-5 confirmed-pattern content as the old always-visible
  /// _SoundPatternsCard, just behind a tap now. "View all sound
  /// patterns" (unfiltered, including still-developing patterns) now
  /// lives inside this sheet rather than floating on the main dashboard.
  void _showSoundPatternsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SoundPatternsCard(
                    patterns: _substitutionPatterns,
                    onAssign: _assignPractice,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => _showAllSoundPatterns(sheetContext),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('View all sound patterns'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.pronunciation,
                    textStyle: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Entry point for the "🔤 Word Confusion Patterns" compact button.
  /// Distinct from Sound Patterns: a full valid-word swap (e.g. "cat"
  /// said instead of "sun"), not a phoneme-level mispronunciation.
  void _showWordConfusionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _WordConfusionCard(confusions: _wordConfusions),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Entry point for the "📋 Last Session Review" compact button.
  /// [_lastSession] is guaranteed non-null here (the button itself is
  /// only rendered when it is — see the button row in build() above).
  void _showLastSessionReview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _LastSessionReviewSheet(
        session: _lastSession!,
        attempts: _lastSessionAttempts,
        onListen: (attempt) => _showWaveformComparison(sheetContext, attempt),
      ),
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

/// Compact, collapsed-by-default entry point for a feature that used to
/// be an always-visible full card (Sound Wave Comparison / Sound
/// Patterns) — tap opens the same underlying sheet/content as before.
/// Only ever built when its data is non-empty (see the guarded Row in
/// build() above) — there's no disabled/greyed-out state, the caller
/// simply omits the button entirely when there's nothing to show.
class _CompactFeatureButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _CompactFeatureButton({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider, width: 0.5),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
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

// ── PEPA-Driven Auto-Recommendation ──────────────────────────────────────
// Proactive entry point sitting on top of the existing Top Struggling
// Phonemes/Sound Patterns/Assign Practice machinery — doesn't change any
// of it, just surfaces "you might want to look at this" before the parent
// has to notice the pattern themselves in the cards below.

class _AutoRecommendationBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _AutoRecommendationBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.30), width: 1),
          ),
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count sound${count == 1 ? '' : 's'} could use extra practice',
                      style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Based on recent pronunciation attempts',
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Review & Assign',
                  style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoRecommendationSheet extends StatelessWidget {
  final List<Map<String, dynamic>> phonemes;
  final void Function(String phoneme, String language) onAssign;

  const _AutoRecommendationSheet({required this.phonemes, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sounds that could use extra practice',
              style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick one to assign — it\'ll be waiting next time they open Pronunciation.',
              style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: phonemes.length,
                itemBuilder: (_, i) {
                  final row = phonemes[i];
                  final total = row['total'] as int;
                  final incorrect = row['incorrect'] as int;
                  final rate = total == 0 ? 0.0 : incorrect / total;
                  return _PhonemeBar(
                    rank: i + 1,
                    phoneme: row['phoneme'] as String,
                    language: row['language'] as String,
                    errorRate: rate,
                    onAssign: onAssign,
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

// ── Word Confusion Patterns ──────────────────────────────────────────────
//
// Distinct from Sound Patterns: a full valid-word swap (e.g. "cat" said
// instead of "sun"), not a phoneme-level mispronunciation. Rows here
// already come pre-filtered to confirmed patterns (occurrences >= 2 —
// see SessionLogger.getTopWordConfusions), so every row shown is a real
// pattern, not a one-off mishearing.

class _WordConfusionCard extends StatelessWidget {
  final List<Map<String, dynamic>> confusions;
  const _WordConfusionCard({required this.confusions});

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
            'Word Confusion Patterns',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Your child may not be reading the word carefully before speaking, '
            'or may be confusing similar-looking words.',
            style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...confusions.indexed.map((entry) {
            final i = entry.$1;
            final row = entry.$2;
            return _WordConfusionRow(
              expected: row['expected_word'] as String,
              confused: row['confused_word'] as String,
              occurrences: row['occurrences'] as int,
            ).animate(delay: (i * 70).ms).fadeIn().slideX(begin: 0.1);
          }),
        ],
      ),
    );
  }
}

class _WordConfusionRow extends StatelessWidget {
  final String expected;
  final String confused;
  final int occurrences;

  const _WordConfusionRow({
    required this.expected,
    required this.confused,
    required this.occurrences,
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
            child: Text(
              'Said "$confused" instead of "$expected"',
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$occurrences times',
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Last Session Review ──────────────────────────────────────────────────
//
// "What did my child actually say" for the most recent completed session
// (within the last 3 days — see SessionLogger.getLastSessionWithinDays's
// doc comment: a read-side query filter, no data is ever deleted). No
// transcript text is ever available (English STT's recognized text is
// never persisted, by design — see hybrid_pronunciation_scorer.dart);
// WRONG attempts that still have a saved WAV (audio_path) get a "Listen"
// tap into the existing Sound Wave Comparison view instead.

class _LastSessionReviewSheet extends StatelessWidget {
  final Map<String, dynamic> session;
  final List<Map<String, dynamic>> attempts;
  final void Function(Map<String, dynamic> attempt) onListen;

  const _LastSessionReviewSheet({
    required this.session,
    required this.attempts,
    required this.onListen,
  });

  String _formatDate(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final grade =
        (session['grade'] as String?) == 'grade4' ? 'Grade 4' : 'Grade 3';
    final dateLabel = _formatDate(session['date'] as String?);
    final levelName = session['level_name'] as String?;

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.90,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
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
                'Last Session Review',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  dateLabel,
                  grade,
                  if (levelName != null) levelName,
                ].where((s) => s.isNotEmpty).join(' · '),
                style: GoogleFonts.nunito(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: attempts.isEmpty
                    ? Center(
                        child: Text(
                          'No word attempts recorded for this session.',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: attempts.length,
                        itemBuilder: (context, index) {
                          final attempt = attempts[index];

                          return _LastSessionAttemptRow(
                            attempt: attempt,
                            grade: session['grade'] as String?,
                            onListen: onListen,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LastSessionAttemptRow extends StatelessWidget {
  final Map<String, dynamic> attempt;
  final String? grade;
  final void Function(Map<String, dynamic> attempt) onListen;

  const _LastSessionAttemptRow({required this.attempt, required this.grade, required this.onListen});

  @override
  Widget build(BuildContext context) {
    final word = attempt['word'] as String;
    final result = attempt['result'] as String;
    final audioPath = attempt['audio_path'] as String?;
    final hasAudio = result == 'WRONG' && audioPath != null;
    // Only shown for a genuine mismatch — an OK attempt matched the target,
    // so "what they said" would just repeat the word already shown.
    final recognizedText = attempt['recognized_text'] as String?;
    final showSaid = (result == 'WRONG' || result == 'ALMOST') &&
        recognizedText != null && recognizedText.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  word,
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              if (hasAudio) ...[
                InkWell(
                  onTap: () => onListen({'word': word, 'grade': grade, 'audio_path': audioPath}),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.pronunciation.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.graphic_eq_rounded, size: 14, color: AppColors.pronunciation),
                        const SizedBox(width: 4),
                        Text(
                          'Listen',
                          style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.pronunciation),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              _VerdictBadge(verdict: result),
            ],
          ),
          if (showSaid) ...[
            const SizedBox(height: 6),
            Text(
              'Said: "$recognizedText"',
              style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

/// Verdict badge reused by Last Session Review — matches the app's
/// existing verdict palette exactly (AppColors.success/almost/danger),
/// so OK/ALMOST/WRONG read consistently with every other verdict shown
/// elsewhere in the app. NO_SPEECH gets a new neutral grey badge (no
/// prior styling existed for it) labeled in plain language.
class _VerdictBadge extends StatelessWidget {
  final String verdict;
  const _VerdictBadge({required this.verdict});

  ({String label, Color color}) get _display {
    switch (verdict) {
      case 'OK':
        return (label: 'OK', color: AppColors.success);
      case 'ALMOST':
        return (label: 'Almost', color: AppColors.almost);
      case 'WRONG':
        return (label: 'Wrong', color: AppColors.danger);
      case 'NO_SPEECH':
        return (label: 'No sound detected', color: AppColors.textHint);
      default:
        return (label: verdict, color: AppColors.textHint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _display;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: d.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        d.label,
        style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w800, color: d.color),
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
  final Future<bool> Function(int sessionId) onDelete;
  final VoidCallback onViewAll;

  static const int _defaultVisibleCount = 3;

  const _AssignedPracticeHistoryCard({
    required this.history,
    required this.onDelete,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final visible = history.take(_defaultVisibleCount).toList();
    final hasMore = history.length > _defaultVisibleCount;

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
          ...visible.indexed.map((entry) {
            final i = entry.$1;
            final row = entry.$2;
            return _AssignedPracticeHistoryTile(row: row, onDelete: onDelete)
                .animate(delay: (i * 70).ms)
                .fadeIn()
                .slideY(begin: 0.1);
          }),
          if (hasMore)
            Center(
              child: TextButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: Text('View all (${history.length})'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.pronunciation,
                  textStyle: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssignedPracticeHistoryTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final Future<bool> Function(int sessionId) onDelete;

  const _AssignedPracticeHistoryTile({required this.row, required this.onDelete});

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
          Tooltip(
            message: 'Remove this record',
            child: InkWell(
              onTap: () => onDelete(row['sessionId'] as int),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full Assigned Practice History — behind the card's "View all" link.
/// Manages its own local copy of [history] so a delete inside the sheet
/// removes the row immediately (no waiting for the sheet to close and the
/// dashboard behind it to rebuild) — [onDelete] still persists it via
/// SessionLogger and syncs the dashboard's own list for when the sheet
/// closes.
class _AllAssignedPracticeHistorySheet extends StatefulWidget {
  final List<Map<String, dynamic>> history;
  final Future<bool> Function(int sessionId) onDelete;

  const _AllAssignedPracticeHistorySheet({required this.history, required this.onDelete});

  @override
  State<_AllAssignedPracticeHistorySheet> createState() => _AllAssignedPracticeHistorySheetState();
}

class _AllAssignedPracticeHistorySheetState extends State<_AllAssignedPracticeHistorySheet> {
  late List<Map<String, dynamic>> _history;

  @override
  void initState() {
    super.initState();
    _history = List.of(widget.history);
  }

  Future<bool> _handleDelete(int sessionId) async {
    final deleted = await widget.onDelete(sessionId);
    if (deleted && mounted) {
      setState(() => _history.removeWhere((r) => r['sessionId'] == sessionId));
    }
    return deleted;
  }

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
              'All Assigned Practice History',
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Results from every sound you assigned for extra practice.',
              style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (_history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No history left.',
                    style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final row in _history)
                        _AssignedPracticeHistoryTile(row: row, onDelete: _handleDelete),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Sound Wave Comparison — entry point ─────────────────────────────────

/// Modal-sheet content behind the "🎵 Sound Waves" compact button — lists
/// recent WRONG-verdict attempts that still have a saved audio_path
/// (English only, per hybrid_pronunciation_scorer.dart's keep-only-WRONG
/// policy); tapping one opens _SoundWaveComparisonSheet for that specific
/// attempt. Same content as the old always-visible _SoundWaveReviewCard
/// card, just shown on tap now instead of permanently on the dashboard —
/// the compact button itself is only rendered when this list is
/// non-empty (see the button row in build() above), so there's no
/// broken/empty entry point to begin with.
class _SoundWaveListSheet extends StatelessWidget {
  final List<Map<String, dynamic>> attempts;
  final void Function(Map<String, dynamic> attempt) onTapAttempt;

  const _SoundWaveListSheet({required this.attempts, required this.onTapAttempt});

  String _formatDate(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final shown = attempts.take(5).toList();
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
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.pronunciation.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: AppColors.pronunciation, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sound Wave Comparison',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Hear the difference — compare the reference pronunciation against your child\'s own recording.',
              style: GoogleFonts.nunito(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            ...shown.indexed.map((entry) {
            final i = entry.$1;
            final a = entry.$2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTapAttempt(a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a['word'] as String,
                                style: GoogleFonts.nunito(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(a['date'] as String?),
                                style: GoogleFonts.nunito(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'WRONG',
                            style: GoogleFonts.nunito(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.danger),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate(delay: (i * 60).ms).fadeIn().slideX(begin: 0.1);
          }),
          ],
        ),
      ),
    );
  }
}

// ── Sound Wave Comparison — detail sheet ────────────────────────────────

/// Reference pronunciation vs the child's saved WRONG-attempt recording,
/// each rendered as a simple amplitude-over-time bar row (not a
/// spectrogram — deliberately simple for a non-technical parent). Purely
/// a display aid: reads real bytes from the bundled reference .wav asset
/// and the real saved WAV at word_attempts.audio_path — no placeholder
/// or synthetic data anywhere in this widget.
class _SoundWaveComparisonSheet extends StatefulWidget {
  final Map<String, dynamic> attempt;

  const _SoundWaveComparisonSheet({required this.attempt});

  @override
  State<_SoundWaveComparisonSheet> createState() => _SoundWaveComparisonSheetState();
}

class _SoundWaveComparisonSheetState extends State<_SoundWaveComparisonSheet> {
  bool _loading = true;
  WavWaveformResult? _reference;
  WavWaveformResult? _child;
  String? _referenceError;
  String? _childError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final word = widget.attempt['word'] as String;
    final grade = (widget.attempt['grade'] as String?) == 'grade4' ? 'grade4' : 'grade3';
    final childPath = widget.attempt['audio_path'] as String?;

    WavWaveformResult? reference;
    String? refError;
    try {
      // English only — this feature only ever saves audio for English
      // attempts (see hybrid_pronunciation_scorer.dart), same asset path
      // pattern pronunciation_session_screen.dart's own _playReference
      // uses for the "Listen to reference" button.
      final data = await rootBundle.load('assets/audio/words/en/$grade/$word.wav');
      reference = WavWaveform.extractBarsFromBytes(data.buffer.asUint8List());
      if (reference == null) refError = 'Reference audio could not be read.';
    } catch (_) {
      refError = 'No reference recording found for this word.';
    }

    WavWaveformResult? child;
    String? childError;
    if (childPath == null) {
      childError = 'No recording was saved for this attempt.';
    } else {
      child = await WavWaveform.extractBarsFromFile(childPath);
      if (child == null) {
        childError = 'This recording is no longer available (it may have been cleaned up).';
      }
    }

    if (!mounted) return;
    setState(() {
      _reference = reference;
      _referenceError = refError;
      _child = child;
      _childError = childError;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.attempt['word'] as String;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    word,
                    style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'WRONG',
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.pronunciation)),
              )
            else ...[
              _WaveformSection(
                label: 'Reference pronunciation',
                color: AppColors.success,
                result: _reference,
                error: _referenceError,
              ),
              const SizedBox(height: 20),
              _WaveformSection(
                label: 'Your child\'s attempt',
                color: AppColors.accentOrange,
                result: _child,
                error: _childError,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WaveformSection extends StatelessWidget {
  final String label;
  final Color color;
  final WavWaveformResult? result;
  final String? error;

  const _WaveformSection({required this.label, required this.color, this.result, this.error});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.nunito(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            if (result?.isQuiet == true) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'quiet recording',
                  style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (result != null)
          _WaveformBars(bars: result!.bars, color: color)
        else
          Container(
            width: double.infinity,
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              error ?? 'Not available',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// Simple amplitude-over-time bar row — deliberately not a spectrogram,
/// just relative peak amplitude per time bucket. [bars] values are
/// 0.0-1.0; a small floor is applied so a near-silent bucket still shows
/// a thin sliver rather than fully disappearing (makes silence-vs-word
/// boundaries visually obvious instead of just empty space).
class _WaveformBars extends StatelessWidget {
  final List<double> bars;
  final Color color;

  const _WaveformBars({required this.bars, required this.color});

  static const double _height = 70;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final b in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.75),
                child: Container(
                  height: (b.clamp(0.04, 1.0)) * _height,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
