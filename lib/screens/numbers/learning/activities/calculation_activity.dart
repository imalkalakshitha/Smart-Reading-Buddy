import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/app_colors.dart';
import '../../../../services/numbers/number_question.dart';
import '../choice_options.dart';
import '../learning_widgets.dart';
import '../number_visuals.dart';

/// Calculations — visual add / take away (objects), multiply (groups of
/// dots) and divide (dots shared into groups), then tap the answer.
class CalculationActivity extends StatelessWidget {
  final CalculationQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;

  const CalculationActivity({
    super.key,
    required this.question,
    required this.onSubmit,
    required this.enabled,
    required this.revealed,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    return Column(
      children: [
        if (q.visual)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: _visual(q),
          ),
        const SizedBox(height: 16),
        Text(
          '${q.a} ${q.symbol} ${q.b} = ${revealed ? q.answer : '?'}',
          style: GoogleFonts.nunito(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 20),
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

  Widget _visual(CalculationQuestion q) {
    switch (q.op) {
      case Operation.add:
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            ObjectGrid(count: q.a, object: 'apple', size: 30),
            Text('+', style: GoogleFonts.nunito(fontSize: 36, fontWeight: FontWeight.w900)),
            ObjectGrid(count: q.b, object: 'apple', size: 30),
          ],
        );
      case Operation.subtract:
        return Center(child: ObjectGrid(count: q.a, object: 'apple', size: 32, crossedOut: q.b));
      case Operation.multiply:
        return DotGroups(groups: q.a, perGroup: q.b);
      case Operation.divide:
        // The sharing, already done: b groups with an equal share each.
        return DotGroups(groups: q.b, perGroup: q.answer);
    }
  }
}
