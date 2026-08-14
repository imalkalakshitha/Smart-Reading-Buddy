import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dao/timed_reading_dao.dart';
import '../../data/timed_reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../router/app_router.dart';

/// Optional post-attempt screen: tap any word that was misread.
/// Skippable — if skipped, accuracyMarked stays false and ResultsScreen
/// shows WPM only, no WCPM/accuracy. Auto-pre-filled from STT/Gemini
/// diff when available; if the session fell back to manual (Sinhala
/// offline, or English STT unavailable), this is the original fully
/// blank manual state, no caption — matching pre-STT behavior exactly.
class MiscueMarkingScreen extends StatefulWidget {
  final MiscueMarkingArgs args;

  const MiscueMarkingScreen({super.key, required this.args});

  @override
  State<MiscueMarkingScreen> createState() => _MiscueMarkingScreenState();
}

class _MiscueMarkingScreenState extends State<MiscueMarkingScreen> {
  bool _hasAutoDetected = false;
  // Counts consecutive persistence failures across instances of this
  // screen (i.e. across sessions) so a repeatedly-failing DB write is
  // visible in logs rather than silently swallowed every time — resets
  // on any successful save.
  static int _consecutiveSaveFailures = 0;

  @override
  void initState() {
    super.initState();
    _prefillAutoDetected();
  }

  void _prefillAutoDetected() {
    if (widget.args.session.manualFallback) return;

    final sentences = widget.args.sentences;
    final session = widget.args.session;

    var runningIndex = 0;
    final baseIndexByUnit = <int, int>{};
    for (var i = 0; i < sentences.length; i++) {
      baseIndexByUnit[i] = runningIndex;
      runningIndex += splitWords(sentences[i].text).length;
    }

    for (final timing in session.unitTimings) {
      final auto = timing.autoDetectedMisreadIndexes;
      if (auto == null) continue;
      _hasAutoDetected = true;
      final base = baseIndexByUnit[timing.unitIndex];
      if (base == null) continue;
      for (final localIdx in auto) {
        session.misreadWordIndexes.add(base + localIdx);
      }
    }
  }

  void _toggle(int globalWordIndex) {
    setState(() {
      final set = widget.args.session.misreadWordIndexes;
      if (!set.add(globalWordIndex)) set.remove(globalWordIndex);
    });
  }

  /// Saves the finished session (+ its unit timings) to SQLite via
  /// TimedReadingDao, on BOTH the DONE and SKIP paths — accuracyMarked
  /// (already set on widget.args.session before this is called) records
  /// which path was taken so wcpm is only ever computed when marking
  /// actually happened. Never throws: any failure is caught, logged with
  /// a [TR] tag, and returns null — the in-memory session/results always
  /// proceed regardless of whether the write succeeded.
  Future<int?> _saveSession({required bool marked}) async {
    final sentences = widget.args.sentences;
    final session = widget.args.session;
    if (sentences.isEmpty) return null;

    final totalWords = sentences.fold<int>(0, (sum, s) => sum + s.wordCount);
    final totalMs = session.totalElapsedMs;
    final wpm = totalMs > 0 ? totalWords / (totalMs / 60000) : null;
    final correct = (totalWords - session.errorCount).clamp(0, totalWords);
    final wcpm = (marked && totalMs > 0) ? correct / (totalMs / 60000) : null;

    final grade = sentences.first.grade;
    final language = sentences.first.language;
    final level = sentences.first.level;
    final contentSetId = timedReadingContentSetId(grade: grade, language: language, level: level);

    try {
      final sessionId = await TimedReadingDao.insertSession(
        profileName: AppState.name,
        grade: grade,
        language: language,
        level: level,
        contentSetId: contentSetId,
        challengeAttemptNumber: widget.args.attemptNumber,
        startedAt: session.startedAt ?? DateTime.now(),
        completedAt: session.endedAt,
        interrupted: session.interrupted,
        accuracyMarked: marked,
        wpm: wpm,
        wcpm: wcpm,
      );

      final rows = <TimedReadingUnitTimingRow>[];
      for (final t in session.unitTimings) {
        if (t.unitIndex < 0 || t.unitIndex >= sentences.length) continue;
        final s = sentences[t.unitIndex];
        var base = 0;
        for (var i = 0; i < t.unitIndex; i++) {
          base += splitWords(sentences[i].text).length;
        }
        final wordCountThisUnit = splitWords(s.text).length;
        // misreadWordIndexes is flat across the whole session — slice
        // back down to this unit's own local (0-based-per-sentence)
        // indexes for the snapshot. Only meaningful if marking happened.
        final finalLocal = marked
            ? session.misreadWordIndexes
                .where((g) => g >= base && g < base + wordCountThisUnit)
                .map((g) => g - base)
                .toList()
            : null;
        rows.add(TimedReadingUnitTimingRow(
          unitIndex: t.unitIndex,
          sentenceId: s.id,
          sentenceTextSnapshot: s.text,
          expectedMsSnapshot: (s.expectedTimeSec * 1000).round(),
          elapsedMs: t.elapsedMs,
          stalled: t.stalled,
          noSpeechDetected: t.noSpeechDetected,
          autoMisreadIndexes: t.autoDetectedMisreadIndexes,
          finalMisreadIndexes: finalLocal,
        ));
      }
      await TimedReadingDao.insertUnitTimings(sessionId: sessionId, rows: rows);

      _consecutiveSaveFailures = 0;
      // ignore: avoid_print
      print('[TR] session saved  id=$sessionId  contentSetId=$contentSetId  units=${rows.length}');
      return sessionId;
    } catch (e) {
      _consecutiveSaveFailures++;
      // ignore: avoid_print
      print('[TR] session save FAILED (attempt #$_consecutiveSaveFailures consecutive) — results still shown in-memory, persistence silently skipped: $e');
      if (_consecutiveSaveFailures >= 3) {
        // ignore: avoid_print
        print('[TR][WARNING] $_consecutiveSaveFailures consecutive Timed Reading save failures — persistence looks broken, check DB/schema.');
      }
      return null;
    }
  }

  Future<void> _finish({required bool marked}) async {
    widget.args.session.accuracyMarked = marked;
    // ignore: avoid_print
    print('[TR] miscue marking  marked=$marked  errors=${widget.args.session.errorCount}');

    final sessionId = await _saveSession(marked: marked);
    if (!mounted) return;

    if (widget.args.attemptNumber != null) {
      Navigator.pop(context, widget.args.session);
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRouter.timedReadingResults,
      arguments: ResultsScreenArgs(
        sentences: widget.args.sentences,
        session: widget.args.session,
        previousWpm: widget.args.previousWpm,
        sessionId: sessionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sentences = widget.args.sentences;
    final session = widget.args.session;
    final isSinhala = AppState.language == 'sinhala';

    var runningIndex = 0;
    final rows = <List<(int, String)>>[];
    for (final unit in sentences) {
      final words = splitWords(unit.text);
      final row = <(int, String)>[];
      for (final w in words) {
        row.add((runningIndex, w));
        runningIndex++;
      }
      rows.add(row);
    }

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.timedReading,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          isSinhala ? 'නිවැරදිතාවය පරීක්ෂා කරන්න' : 'Check Accuracy',
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSinhala ? 'ඔවුන් සෑම වචනයක්ම නිවැරදිව කියෙව්වාද?' : 'Did they read every word correctly?',
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ).animate().fadeIn(),
              const SizedBox(height: 6),
              Text(
                isSinhala
                    ? 'වැරදි ලෙස කියවූ වචන ස්පර්ශ කරන්න. අවශ්‍ය නම් මෙය මඟ හැරිය හැක.'
                    : 'Tap any word that was misread. This step can be skipped.',
                style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
              ).animate(delay: 60.ms).fadeIn(),
              if (_hasAutoDetected) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.timedReading.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.timedReading),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isSinhala ? 'ස්වයංක්‍රීයව අනාවරණය කරන ලදී — කරුණාකර සමාලෝචනය කරන්න' : 'Auto-detected — please review',
                          style: GoogleFonts.nunito(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.timedReading),
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 90.ms).fadeIn(),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int r = 0; r < rows.length; r++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final (idx, word) in rows[r])
                                  _WordChip(
                                    word: word,
                                    misread: session.misreadWordIndexes.contains(idx),
                                    onTap: () => _toggle(idx),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _finish(marked: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.divider, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        isSinhala ? 'මඟ හරින්න' : 'SKIP',
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _finish(marked: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.timedReading,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        isSinhala ? 'අවසන්' : 'DONE',
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  final bool misread;
  final VoidCallback onTap;

  const _WordChip({required this.word, required this.misread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: misread ? AppColors.dangerLight : AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: misread ? AppColors.danger : AppColors.divider, width: misread ? 2 : 1),
        ),
        child: Text(
          word,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: misread ? AppColors.danger : AppColors.textPrimary,
            decoration: misread ? TextDecoration.lineThrough : TextDecoration.none,
            decorationThickness: 2,
          ),
        ),
      ),
    );
  }
}
