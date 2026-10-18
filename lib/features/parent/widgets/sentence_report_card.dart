import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';

/// Renders one sentence's expected-vs-actual time plus its practice-word
/// list. SENTENCE-LEVEL ONLY — there is no per-word timing anywhere in
/// Timed Reading (ReadingScreen captures one Stopwatch reading per whole
/// sentence), so this widget must never imply a within-sentence
/// breakdown: no per-word progress bar, no "stuck here" pointer inside
/// the sentence text. If that's wanted later it needs a different STT
/// approach — out of scope here.
///
/// Tone: supportive, not evaluative. No "wrong"/"failed"/"mistake"
/// anywhere — misread words are "practice targets", and going over
/// [expectedTimeSec] (by any margin, small or large) gets the exact same
/// gentle note, never escalating wording for a bigger gap.
class SentenceReportCardData {
  final String text;
  final double expectedTimeSec;
  final double upperThresholdSec;
  final int actualMs;
  final List<String> practiceWords;
  // Sinhala only — this unit's own timed_reading_unit_timings row id (for
  // the delete-on-listen DB update) and its audio_file_path (null if no
  // recording exists or it's already been listened to/deleted). Both
  // null for English, and null for any Sinhala row recorded before this
  // feature existed.
  final int? unitTimingId;
  final String? audioFilePath;
  // True if this unit's elapsedMs came in under its lowerThresholdSec —
  // a plausibility/data-quality signal (e.g. a tap-through without
  // genuinely reading aloud), not a punitive judgment. Parent Dashboard
  // only — never shown on Results (removed there in an earlier round).
  final bool tooFast;
  // True if this unit's elapsedMs went over its upperThresholdSec.
  // Carried here (alongside tooFast) purely so callers like "Practice
  // These Again" can decide which sentences qualify for the queue without
  // re-deriving it from raw DB rows — not read/displayed by this widget
  // itself (the practice-note UI below already covers the same signal).
  final bool stalled;
  // Catalog id (SentenceSet.id) for this row — not shown, only used by
  // "Practice These Again" to queue the right sentence.
  final String? sentenceId;

  const SentenceReportCardData({
    required this.text,
    required this.expectedTimeSec,
    required this.upperThresholdSec,
    required this.actualMs,
    required this.practiceWords,
    this.unitTimingId,
    this.audioFilePath,
    this.tooFast = false,
    this.stalled = false,
    this.sentenceId,
  });
}

class SentenceReportCard extends StatelessWidget {
  final SentenceReportCardData data;
  // Optional Sinhala-only playback controls — all default off/null so
  // this widget's only other caller (none currently besides
  // parent_timed_reading_analytics_screen.dart, but kept additive on
  // principle) is completely unaffected. When [hasAudio] is true, a 🔊
  // button appears; actual playback state/logic lives in the parent
  // (same pattern as MiscueMarkingScreen's own Listen button) since this
  // widget has no AudioPlayer of its own.
  final bool hasAudio;
  final bool isPlaying;
  final VoidCallback? onToggleListen;

  const SentenceReportCard({
    super.key,
    required this.data,
    this.hasAudio = false,
    this.isPlaying = false,
    this.onToggleListen,
  });

  @override
  Widget build(BuildContext context) {
    final isSinhala = AppState.language == 'sinhala';
    final actualSec = data.actualMs / 1000.0;
    // Same gentle note whether actualSec is just over expectedTimeSec or
    // way past upperThresholdSec — severity is deliberately not encoded
    // in the wording, only in whether the note shows at all.
    final needsPractice = actualSec > data.expectedTimeSec;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      // Fixed visual order: 1) sentence text (most prominent) — 2)+3)
      // Expected/Actual side-by-side, same two-stat-box pattern as
      // ReadingScreen's EXPECTED/ACTUAL boxes (_StatBox there) — 4)
      // practice-words note, smallest/last.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sentence text
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  data.text,
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              if (!needsPractice) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
              ],
              if (hasAudio) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'අහන්න',
                  onPressed: onToggleListen,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                    color: AppColors.timedReading,
                    size: 24,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // 2 + 3. Expected / Actual, side-by-side
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: isSinhala ? 'අපේක්ෂිත' : 'EXPECTED',
                  value: _formatSec((data.expectedTimeSec * 1000).round()),
                  subValue: '${(data.expectedTimeSec * 1000).round()}ms',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: isSinhala ? 'සැබෑ' : 'ACTUAL',
                  value: _formatSec(data.actualMs),
                  subValue: '${data.actualMs}ms',
                ),
              ),
            ],
          ),
          // 4. Practice-words note — smallest, last
          if (needsPractice) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.favorite_rounded, size: 13, color: AppColors.timedReading),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isSinhala ? 'මෙහි වැඩිපුර පුහුණුවක් උපකාරී විය හැක' : 'Extra practice could help here',
                    style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.timedReading),
                  ),
                ),
              ],
            ),
          ],
          // "Too fast" note — same gentle tone/size as the practice note
          // above, deliberately worded as a plausibility check, not an
          // accusation (no "cheating"/"skipped"/"fake").
          if (data.tooFast) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.timedReading),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isSinhala
                        ? 'මෙම වාක්‍යයට අපේක්ෂිතයට වඩා වේගවත් වූ බව පෙනේ — ඔවුන් එය හඬ නඟා කියෙව්වාද යන්න තහවුරු කර ගැනීම වටී'
                        : 'Pace was faster than expected for this sentence — worth confirming they read it aloud',
                    style: GoogleFonts.nunito(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.timedReading),
                  ),
                ),
              ],
            ),
          ],
          if (data.practiceWords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              isSinhala ? 'පුහුණු විය යුතු වචන' : 'Words to practice',
              style: GoogleFonts.nunito(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final w in data.practiceWords)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      w,
                      style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Precise seconds (2 decimals) — replaces the old whole-second rounding,
  // which made two genuinely different actual times (e.g. 4.1s vs 4.9s)
  // both display as "5s". Raw ms shown as a smaller subValue line in
  // _StatBox below it.
  String _formatSec(int ms) => '${(ms / 1000).toStringAsFixed(2)}s';
}

/// Same visual pattern as ReadingScreen's _StatBox (label small on top,
/// big value below, white card with shadow) — recreated here rather than
/// imported since that class is private to reading_screen.dart; kept
/// pixel-identical on purpose for consistency across the module.
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  // Optional smaller line below [value] — used here for the raw-ms
  // reading (e.g. "4330ms") under the "4.33s" headline value. Null/
  // omitted preserves the original single-line layout for any other
  // caller.
  final String? subValue;

  const _StatBox({required this.label, required this.value, this.subValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.nunito(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textHint)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          if (subValue != null) ...[
            const SizedBox(height: 2),
            Text(subValue!, style: GoogleFonts.nunito(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textHint)),
          ],
        ],
      ),
    );
  }
}
