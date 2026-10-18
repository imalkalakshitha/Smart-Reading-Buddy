import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_question.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/digit_tile_board.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';

/// Spell Number Words — see the digit, build its English word from letter
/// tiles (the word's letters plus look-alike distractors).
class SpellWordActivity extends StatelessWidget {
  final SpellWordQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;

  const SpellWordActivity({
    super.key,
    required this.question,
    required this.onSubmit,
    required this.enabled,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 140,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primaryLight, width: 1.5),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 5)),
            ],
          ),
          child: Text(
            '${question.value}',
            style: GoogleFonts.nunito(fontSize: 72, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 28),
        TileBoard(
          tiles: question.tiles,
          slotCount: question.letters.length,
          gapsAfter: question.gapsAfter,
          onSubmit: onSubmit,
          enabled: enabled,
          reveal: revealed ? question.letters : null,
        ),
      ],
    );
  }
}
