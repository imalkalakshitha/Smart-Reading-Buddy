import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dao/timed_reading_dao.dart';
import '../../data/timed_reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../models/timed_reading_session.dart';
import 'reading_screen.dart';

/// Repeated Reading Challenge — same sentence set read 3 times in a row,
/// tracking WPM per attempt so the child can see themselves get faster.
/// Each attempt pushes ReadingScreen with attemptNumber set (which makes
/// MiscueMarkingScreen pop the finished session back here instead of
/// navigating on to ResultsScreen) and awaits the popped
/// TimedReadingSession.
///
/// The progression list is seeded from TimedReadingDao.getChallengeHistory
/// on load (persisted attempts for this exact grade+language+level+
/// contentSetId), so a child who abandons and restarts a challenge later
/// still sees their prior attempts — not just whatever happens within
/// this one screen instance.
class RepeatedReadingChallengeScreen extends StatefulWidget {
  final ChallengeScreenArgs args;

  const RepeatedReadingChallengeScreen({super.key, required this.args});

  @override
  State<RepeatedReadingChallengeScreen> createState() => _RepeatedReadingChallengeScreenState();
}

class _RepeatedReadingChallengeScreenState extends State<RepeatedReadingChallengeScreen> {
  static const int _totalAttempts = 3;
  final List<int> _wpmByAttempt = [];
  bool _loadingHistory = true;

  int get _totalWords => widget.args.sentences.fold(0, (sum, s) => sum + s.wordCount);

  String get _contentSetId => timedReadingContentSetId(
        grade: widget.args.grade,
        language: widget.args.language,
        level: widget.args.level,
      );

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final rows = await TimedReadingDao.getChallengeHistory(
        profileName: AppState.name,
        grade: widget.args.grade,
        language: widget.args.language,
        level: widget.args.level,
        contentSetId: _contentSetId,
      );
      final byAttempt = <int, int>{};
      for (final r in rows) {
        final attemptNum = r['challenge_attempt_number'];
        final wpm = r['wpm'];
        if (attemptNum == null || wpm == null) continue;
        byAttempt[attemptNum as int] = (wpm as num).round();
      }
      if (!mounted) return;
      setState(() {
        _wpmByAttempt.clear();
        // Attempts are strictly sequential (1, 2, 3) — stop at the first
        // gap rather than showing a sparse/out-of-order list.
        for (var i = 1; i <= _totalAttempts; i++) {
          if (!byAttempt.containsKey(i)) break;
          _wpmByAttempt.add(byAttempt[i]!);
        }
        _loadingHistory = false;
      });
      // ignore: avoid_print
      print('[TR] challenge history loaded  contentSetId=$_contentSetId  priorAttempts=${_wpmByAttempt.length}');
    } catch (e) {
      // ignore: avoid_print
      print('[TR] challenge history query failed — starting fresh in-session only: $e');
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _startAttempt() async {
    final attemptNumber = _wpmByAttempt.length + 1;
    final previousWpm = _wpmByAttempt.isNotEmpty ? _wpmByAttempt.last : null;

    final result = await Navigator.push<TimedReadingSession>(
      context,
      MaterialPageRoute(
        builder: (_) => ReadingScreen(
          args: ReadingScreenArgs(
            grade: widget.args.grade,
            language: widget.args.language,
            level: widget.args.level,
            sentences: widget.args.sentences,
            attemptNumber: attemptNumber,
            previousWpm: previousWpm,
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    final totalMs = result.totalElapsedMs;
    final wpm = totalMs > 0 ? (_totalWords / (totalMs / 60000)).round() : 0;
    setState(() => _wpmByAttempt.add(wpm));
  }

  @override
  Widget build(BuildContext context) {
    final isSinhala = AppState.language == 'sinhala';
    final done = _wpmByAttempt.length >= _totalAttempts;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.timedReading,
        elevation: 0,
        title: Text(
          isSinhala ? 'නැවත කියවීමේ අභියෝගය' : 'Repeated Reading Challenge',
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                isSinhala
                    ? 'එකම වාක්‍ය 3 වතාවක් කියවා ඔබ වේගවත් වන ආකාරය බලන්න!'
                    : 'Read the same sentences 3 times and watch yourself get faster!',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < _totalAttempts; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isSinhala ? 'උත්සාහය ${i + 1}' : 'Attempt ${i + 1}',
                          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        Text(
                          i < _wpmByAttempt.length ? '${_wpmByAttempt[i]} WPM' : '—',
                          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.timedReading),
                        ),
                      ],
                    ),
                  ),
                ).animate(delay: (i * 80).ms).fadeIn(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loadingHistory ? null : (done ? () => Navigator.pop(context) : _startAttempt),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.timedReading,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    done
                        ? (isSinhala ? 'අවසන්' : 'Done')
                        : (isSinhala ? 'උත්සාහය ${_wpmByAttempt.length + 1} ආරම්භ කරන්න' : 'Start Attempt ${_wpmByAttempt.length + 1}'),
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
