import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/dao/timed_reading_dao.dart';
import 'package:smart_reading_buddy/core/data/timed_reading_data.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/core/router/app_router.dart';
import 'package:smart_reading_buddy/core/services/speech/timed_reading_speech_bridge.dart';

/// Optional post-attempt screen: tap any word that was misread.
/// Skippable — if skipped, accuracyMarked stays false and ResultsScreen
/// shows WPM only, no WCPM/accuracy. English: auto-pre-filled from STT
/// diff when available. Sinhala: fully manual — Gemini transcription was
/// removed from Sinhala Timed Reading entirely (offline reliability); a
/// 🔊 "Listen" button per sentence plays that unit's own recorded temp
/// WAV instead, so a parent/teacher can listen and mark manually. If the
/// session fell back to manual (English STT unavailable), this is the
/// original fully blank manual state, no caption — matching pre-STT
/// behavior exactly.
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

  // ── Sinhala-only playback of each unit's recorded temp WAV ───────────
  late final AudioPlayer _audioPlayer;
  int? _playingUnitIndex;

  @override
  void initState() {
    super.initState();
    _prefillAutoDetected();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingUnitIndex = null);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    // No temp-file cleanup here anymore: recordings now survive past
    // this screen (moved to permanent Parent Dashboard review storage in
    // _saveSession below) whether the child finishes or backs out mid-
    // marking — deleted only once a parent listens, or by the 14-day
    // safety-net sweep. See TimedReadingAudioRecorder's class docs.
    super.dispose();
  }

  Future<void> _toggleAudio(int unitIndex, String path) async {
    if (_playingUnitIndex == unitIndex) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _playingUnitIndex = null);
      return;
    }
    try {
      setState(() => _playingUnitIndex = unitIndex);
      await _audioPlayer.play(DeviceFileSource(path));
    } catch (_) {
      if (mounted) setState(() => _playingUnitIndex = null);
    }
  }

  String? _audioPathForUnit(int unitIndex) {
    for (final t in widget.args.session.unitTimings) {
      if (t.unitIndex == unitIndex) return t.audioFilePath;
    }
    return null;
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
    // Assigned-practice sessions mix sentences from several real levels,
    // so sentences.first.level would be misleading (and would wrongly
    // count towards that one level's progress bar / Calibration
    // Insights bucket) — use the synthetic marker instead. Every other
    // session type is unaffected.
    final level = widget.args.isAssignedPractice ? 'assigned_practice' : sentences.first.level;
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
        // Sinhala only — move this unit's temp recording (tr_audio/) into
        // permanent Parent Dashboard review storage (tr_audio_review/),
        // now that the real session id exists to key the new filename.
        // Only possible now, not in ReadingScreen where the file was
        // first recorded — session_id doesn't exist until this insert.
        // ignore: avoid_print
        print('[TR] unit ${t.unitIndex} pre-move tempAudioFilePath=${t.audioFilePath}');
        final movedAudioPath = t.audioFilePath == null
            ? null
            : await TimedReadingAudioRecorder.moveToReviewStorage(
                tempPath: t.audioFilePath!,
                sessionId: sessionId,
                unitIndex: t.unitIndex,
              );
        // ignore: avoid_print
        print('[TR] unit ${t.unitIndex} post-move movedAudioPath=$movedAudioPath');
        rows.add(TimedReadingUnitTimingRow(
          unitIndex: t.unitIndex,
          sentenceId: s.id,
          sentenceTextSnapshot: s.text,
          expectedMsSnapshot: (s.expectedTimeSec * 1000).round(),
          elapsedMs: t.elapsedMs,
          stalled: t.stalled,
          tooFast: t.tooFast,
          noSpeechDetected: t.noSpeechDetected,
          autoMisreadIndexes: t.autoDetectedMisreadIndexes,
          finalMisreadIndexes: finalLocal,
          audioFilePath: movedAudioPath,
        ));
      }
      await TimedReadingDao.insertUnitTimings(sessionId: sessionId, rows: rows);

      if (widget.args.isAssignedPractice) {
        // Mark exactly this session's own sentences completed — matched
        // by sentence_id against still-pending rows, since ids weren't
        // threaded all the way through ReadingScreenArgs/TimedReadingSession
        // (which don't otherwise carry any assigned-practice-specific
        // state). Dedupe-on-assign guarantees at most one pending row per
        // sentence_id per profile, so this can't mark the wrong row.
        final pending = await TimedReadingDao.getPendingPractice(
          profileName: AppState.name,
          grade: grade,
          language: language,
        );
        final sentenceIds = sentences.map((s) => s.id).toSet();
        final idsToComplete = pending
            .where((r) => sentenceIds.contains(r['sentence_id'] as String))
            .map((r) => r['id'] as int)
            .toList();
        await TimedReadingDao.markPracticeCompleted(idsToComplete);
      }

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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isSinhala && _audioPathForUnit(r) != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      tooltip: 'අහන්න',
                                      onPressed: () => _toggleAudio(r, _audioPathForUnit(r)!),
                                      icon: Icon(
                                        _playingUnitIndex == r ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                        color: AppColors.timedReading,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                Wrap(
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
