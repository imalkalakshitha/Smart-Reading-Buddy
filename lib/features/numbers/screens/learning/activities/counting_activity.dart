import 'package:flutter/material.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_question.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/choice_options.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/number_visuals.dart';

/// Counting — count the objects (or base-ten blocks) and tap how many.
class CountingActivity extends StatelessWidget {
  final CountingQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;

  const CountingActivity({
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: q.grouped
                ? BaseTenBlocks(
                    hundreds: q.hundreds,
                    tens: q.tens,
                    ones: q.ones,
                    chart: q.placeValueChart,
                  )
                : ObjectGrid(count: q.answer, object: q.object, size: 44),
          ),
        ),
        const SizedBox(height: 28),
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
