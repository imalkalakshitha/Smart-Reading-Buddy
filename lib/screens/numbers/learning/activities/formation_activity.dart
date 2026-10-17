import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/app_colors.dart';
import '../../../../services/numbers/number_question.dart';
import '../digit_tile_board.dart';
import '../learning_widgets.dart';

/// Formation — use every digit tile once to make the biggest or smallest
/// number.
class FormationActivity extends StatelessWidget {
  final FormationQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;

  const FormationActivity({
    super.key,
    required this.question,
    required this.onSubmit,
    required this.enabled,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) {
    final hasZero = question.digits.contains(0);
    return Column(
      children: [
        Text(question.highest ? '🐘' : '🐭', style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 4),
        Text(
          question.highest ? 'Biggest number' : 'Smallest number',
          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
        ),
        if (!question.highest && hasZero) ...[
          const SizedBox(height: 4),
          Text(
            'Tip: a number can’t start with 0',
            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: LearningColors.accent),
          ),
        ],
        const SizedBox(height: 18),
        DigitTileBoard(
          tiles: question.digits,
          slotCount: question.digits.length,
          onSubmit: onSubmit,
          enabled: enabled,
          revealDigits: revealed ? question.answerDigits : null,
        ),
      ],
    );
  }
}
