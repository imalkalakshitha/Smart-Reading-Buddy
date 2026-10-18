import 'package:flutter/material.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_question.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/digit_tile_board.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';

/// Build — hear the number, build it from digit tiles.
class BuildActivity extends StatelessWidget {
  final BuildQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;

  const BuildActivity({
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
        const VisualCard(child: Text('🧱', style: TextStyle(fontSize: 56))),
        const SizedBox(height: kBlockGap),
        DigitTileBoard(
          tiles: question.tiles,
          slotCount: question.digitCount,
          onSubmit: onSubmit,
          enabled: enabled,
          revealDigits: revealed ? question.answerDigits : null,
        ),
      ],
    );
  }
}
