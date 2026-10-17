import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dao/timed_reading_dao.dart';
import '../../data/timed_reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../router/app_router.dart';
import '../../services/ble_command_service.dart';

/// WPM/WCPM results, with a real "own best" comparison pulled from
/// TimedReadingDao — the best prior WPM at this exact grade+language+
/// level (excluding this just-finished session, via [ResultsScreenArgs.
/// sessionId]). Falls back to a fixed grade default only when no prior
/// session at this level exists yet (first-ever attempt) — the
/// comparison always states plainly which basis was used.
class ResultsScreen extends StatefulWidget {
  final ResultsScreenArgs args;

  const ResultsScreen({super.key, required this.args});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  // No prior spec for this fallback existed before persistence landed —
  // placeholder defaults only used when a child has literally never
  // completed a session at this grade+language+level before.
  static const int _defaultWpmGrade3 = 45;
  static const int _defaultWpmGrade4 = 60;

  bool _loadingBest = true;
  int? _bestPreviousWpm;
  bool _isFirstAttempt = false;

  ResultsScreenArgs get args => widget.args;

  int get _totalWords => args.sentences.fold(0, (sum, s) => sum + s.wordCount);

  int get _wpm {
    final totalMs = args.session.totalElapsedMs;
    if (totalMs <= 0) return 0;
    return (_totalWords / (totalMs / 60000)).round();
  }

  int get _wcpm {
    final totalMs = args.session.totalElapsedMs;
    if (totalMs <= 0) return 0;
    final correct = (_totalWords - args.session.errorCount).clamp(0, _totalWords);
    return (correct / (totalMs / 60000)).round();
  }

  @override
  void initState() {
    super.initState();
    _loadOwnBest();
  }

  Future<void> _loadOwnBest() async {
    if (args.sentences.isEmpty) {
      setState(() => _loadingBest = false);
      return;
    }
    final grade = args.sentences.first.grade;
    final language = args.sentences.first.language;
    final level = args.sentences.first.level;
    try {
      final rows = await TimedReadingDao.getRecentSessions(
        profileName: AppState.name,
        grade: grade,
        limit: 1000,
      );
      int? best;
      for (final r in rows) {
        if (r['id'] == args.sessionId) continue; // exclude the session just saved
        if (r['language'] != language || r['level'] != level) continue;
        final wpm = r['wpm'];
        if (wpm == null) continue;
        final wpmInt = (wpm as num).round();
        if (best == null || wpmInt > best) best = wpmInt;
      }
      if (!mounted) return;
      setState(() {
        _bestPreviousWpm = best;
        _isFirstAttempt = best == null;
        _loadingBest = false;
      });
      _sendSessionEndBleCommand();
    } catch (e) {
      // ignore: avoid_print
      print('[TR] own-best query failed — falling back to default baseline: $e');
      if (!mounted) return;
      setState(() {
        _bestPreviousWpm = null;
        _isFirstAttempt = true;
        _loadingBest = false;
      });
      _sendSessionEndBleCommand();
    }
  }

  /// Fire-and-forget, same as every other BleCommandService call site —
  /// no-ops safely if nothing's connected. Fired once, after the own-best
  /// comparison above has resolved, using exactly that same signal (no
  /// new threshold invented): only a confirmed improvement over a real
  /// prior best counts as "good" (SESSION_END); a first attempt (no basis
  /// to judge) or a non-improved result both fall into "poor/mixed"
  /// (ENCOURAGE) — matches build()'s own `improved`/`comparisonBasis`
  /// calculation.
  void _sendSessionEndBleCommand() {
    if (args.sentences.isEmpty) return; // no grade -> no baseline to compare against
    final grade = args.sentences.first.grade;
    final defaultWpm = grade == 'grade4' ? _defaultWpmGrade4 : _defaultWpmGrade3;
    final comparisonBasis = _bestPreviousWpm ?? defaultWpm;
    final performedWell = !_isFirstAttempt && _wpm > comparisonBasis;
    final lang = AppState.language == 'sinhala' ? 'SI' : 'EN';
    BleCommandService.instance.send(performedWell ? 'SESSION_END:$lang' : 'ENCOURAGE:$lang');
  }

  @override
  Widget build(BuildContext context) {
    final isSinhala = AppState.language == 'sinhala';
    final wpm = _wpm;
    final wcpm = _wcpm;
    final accuracyMarked = args.session.accuracyMarked;
    final grade = args.sentences.isNotEmpty ? args.sentences.first.grade : 'grade3';
    final defaultWpm = grade == 'grade4' ? _defaultWpmGrade4 : _defaultWpmGrade3;
    final comparisonBasis = _bestPreviousWpm ?? defaultWpm;
    final improved = !_loadingBest && wpm > comparisonBasis;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                isSinhala ? 'හොඳයි!' : 'Great Job!',
                style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: Column(
                  children: [
                    Text(
                      '$wpm',
                      style: GoogleFonts.nunito(fontSize: 56, fontWeight: FontWeight.w900, color: AppColors.timedReading),
                    ),
                    Text(
                      isSinhala ? 'තත්පරයට වචන (WPM)' : 'Words Per Minute',
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    if (accuracyMarked) ...[
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.divider),
                      const SizedBox(height: 16),
                      Text(
                        '$wcpm',
                        style: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      Text(
                        isSinhala ? 'නිවැරදි වචන (WCPM)' : 'Words Correct Per Minute',
                        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.15),
              if (_loadingBest) ...[
                const SizedBox(height: 16),
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textHint),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Text(
                  // Basis is always stated honestly — "first attempt" is
                  // never dressed up as a comparison against a real
                  // number, and the fixed default is only ever used to
                  // decide improved/not, never shown as if it were a
                  // real previous WPM.
                  _isFirstAttempt
                      ? (isSinhala ? 'මෙම මට්ටමේ ඔබේ පළමු උත්සාහය' : 'First attempt at this level')
                      : (improved
                          ? (isSinhala ? 'ඔබේ පෙර හොඳම ප්‍රතිඵලයට වඩා වේගවත්! 🎉' : 'Faster than your previous best! 🎉')
                          : (isSinhala
                              ? 'ඔබේ පෙර හොඳම ප්‍රතිඵලය: $_bestPreviousWpm WPM'
                              : 'Your previous best: $_bestPreviousWpm WPM')),
                  style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.timedReading,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    isSinhala ? 'මුල් පිටුවට' : 'Back to Home',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRouter.timedReadingChallenge,
                    arguments: ChallengeScreenArgs(
                      grade: args.sentences.isNotEmpty ? args.sentences.first.grade : 'grade3',
                      language: args.sentences.isNotEmpty ? args.sentences.first.language : 'english',
                      level: args.sentences.isNotEmpty ? args.sentences.first.level : 'level1',
                      sentences: args.sentences,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.timedReading,
                    side: const BorderSide(color: AppColors.timedReading, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    isSinhala ? 'නැවත කියවීමේ අභියෝගය' : 'Repeated Reading Challenge',
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
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
