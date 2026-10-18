import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/services/numbers/level_progress.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';

/// End-of-session summary shared by every Numbers practice session:
/// score / total, stars, pass message, Play again and Back.
class SessionSummaryView extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onPlayAgain;
  final VoidCallback onBack;

  const SessionSummaryView({
    super.key,
    required this.score,
    required this.total,
    required this.onPlayAgain,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final passed = score >= LevelProgressRules.passScore;
    final stars = passed ? 3 : (score >= 5 ? 2 : 1);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(passed ? '🏆' : '🌟', style: const TextStyle(fontSize: 84))
              .animate()
              .scale(begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack),
          const SizedBox(height: 8),
          Text(
            passed ? 'Level passed!' : 'Well done!',
            style: GoogleFonts.nunito(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Icon(
                i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                color: i < stars ? Colors.amber : Colors.grey.shade300,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$score / $total',
            style: GoogleFonts.nunito(fontSize: 48, fontWeight: FontWeight.w900, color: LearningColors.accent),
          ),
          const SizedBox(height: 8),
          Text(
            passed
                ? 'The next level is open! ✓'
                : 'Get ${LevelProgressRules.passScore} or more to open the next level. You can do it!',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          PillButton(label: 'Play again 🔁', color: LearningColors.accent, onTap: onPlayAgain),
          const SizedBox(height: 12),
          PillButton(label: 'Back to levels', color: AppColors.reading, onTap: onBack),
        ],
      ),
    );
  }
}
