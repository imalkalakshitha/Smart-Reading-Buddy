import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_colors.dart';
import '../models/app_state.dart';

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

  const SentenceReportCardData({
    required this.text,
    required this.expectedTimeSec,
    required this.upperThresholdSec,
    required this.actualMs,
    required this.practiceWords,
  });
}

class SentenceReportCard extends StatelessWidget {
  final SentenceReportCardData data;

  const SentenceReportCard({super.key, required this.data});

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
            ],
          ),
          const SizedBox(height: 12),
          // 2 + 3. Expected / Actual, side-by-side
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: isSinhala ? 'අපේක්ෂිත' : 'EXPECTED',
                  value: _formatSec(data.expectedTimeSec),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: isSinhala ? 'සැබෑ' : 'ACTUAL',
                  value: _formatSec(actualSec),
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

  String _formatSec(double sec) {
    final s = sec.round();
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}

/// Same visual pattern as ReadingScreen's _StatBox (label small on top,
/// big value below, white card with shadow) — recreated here rather than
/// imported since that class is private to reading_screen.dart; kept
/// pixel-identical on purpose for consistency across the module.
class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

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
        ],
      ),
    );
  }
}
