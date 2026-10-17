import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/app_colors.dart';
import '../../../../services/numbers/number_question.dart';
import '../choice_options.dart';
import '../learning_widgets.dart';
import '../number_visuals.dart';

/// Place value — the number, its stick & ball blocks in a Hundreds / Tens /
/// Ones chart, and "How many tens?" (347 → 3, 4, 7).
class PlaceValueActivity extends StatelessWidget {
  final PlaceValueQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;

  const PlaceValueActivity({
    super.key,
    required this.question,
    required this.onSubmit,
    required this.enabled,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final digits = '${q.number}';
    final placeIndex = switch (q.place) {
      Place.hundreds => digits.length - 3,
      Place.tens => digits.length - 2,
      Place.ones => digits.length - 1,
    };
    return Column(
      children: [
        // The number, with the asked-about digit underlined once revealed.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < digits.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: revealed && i == placeIndex ? LearningColors.correct : Colors.transparent,
                      width: 5,
                    ),
                  ),
                ),
                child: Text(
                  digits[i],
                  style: GoogleFonts.nunito(fontSize: 64, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        BaseTenBlocks(
          hundreds: (q.number ~/ 100) % 10,
          tens: (q.number ~/ 10) % 10,
          ones: q.number % 10,
          chart: q.number >= 100,
        ),
        const SizedBox(height: 24),
        ChoiceOptions(
          options: q.options,
          answer: q.answer,
          onSubmit: onSubmit,
          enabled: enabled,
          revealed: revealed,
          fontSize: 40,
        ),
      ],
    );
  }
}

/// Comparison — "Bigger or smaller?": tap the bigger (or smaller) number.
class ComparisonActivity extends StatelessWidget {
  final ComparisonQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;

  const ComparisonActivity({
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
        Text(question.askBigger ? '🐘' : '🐭', style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 24),
        ChoiceOptions(
          options: question.options,
          answer: question.answer,
          onSubmit: onSubmit,
          enabled: enabled,
          revealed: revealed,
          fontSize: 40,
        ),
      ],
    );
  }
}
