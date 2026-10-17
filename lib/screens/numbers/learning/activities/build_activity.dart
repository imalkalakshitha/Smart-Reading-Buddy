import 'package:flutter/material.dart';
import '../../../../services/numbers/number_question.dart';
import '../digit_tile_board.dart';
import '../learning_widgets.dart';

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
        const Text('🧱', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 20),
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
