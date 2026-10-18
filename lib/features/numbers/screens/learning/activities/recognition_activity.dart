import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_question.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/choice_options.dart' show WrongPickReset;
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';

/// Recognition — hear the number, tap it. The number is never shown in the
/// prompt; only the spoken instruction tells the child which one.
///
/// With [RecognitionQuestion.colourQuantity], finding the number opens a
/// second step: colour that many stars in a ten-frame, then Check.
class RecognitionActivity extends StatefulWidget {
  final RecognitionQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;

  const RecognitionActivity({
    super.key,
    required this.question,
    required this.onSubmit,
    required this.enabled,
    required this.revealed,
  });

  @override
  State<RecognitionActivity> createState() => _RecognitionActivityState();
}

class _RecognitionActivityState extends State<RecognitionActivity>
    with WrongPickReset<RecognitionActivity>, WrongCheckReset<RecognitionActivity> {
  int? _correct;

  // Colouring step.
  final Set<int> _coloured = {};

  bool get _colouring => widget.question.colourQuantity && (_correct != null || widget.revealed);

  OptionLook _lookFor(int option) {
    if (option == _correct) return OptionLook.correct;
    if (widget.revealed && option == widget.question.answer) return OptionLook.revealed;
    if (isMarkedWrong(option)) return OptionLook.wrong;
    return OptionLook.normal;
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Column(
      children: [
        // The picture card: 👂, then the colouring instruction for the
        // second step (feedback shows over it).
        VisualCard(
          minHeight: _colouring ? 64 : 96,
          padding: EdgeInsets.all(_colouring ? 12 : 16),
          child: _colouring
              ? Text(
                  q.followUpPrompt ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                )
              : const Text('👂', style: TextStyle(fontSize: 64)),
        ),
        const SizedBox(height: kBlockGap),
        OptionGrid(
          children: [
            for (final o in q.options)
              BigNumberButton(
                label: '$o',
                look: _lookFor(o),
                fontSize: _colouring ? 32 : 44,
                onTap: widget.enabled && _correct == null && !isMarkedWrong(o)
                    ? () {
                        final ok = widget.onSubmit(o);
                        ok ? setState(() => _correct = o) : markWrong(o);
                      }
                    : null,
              ),
          ],
        ),
        if (_colouring) ...[
          const SizedBox(height: kBlockGap),
          _colourBoard(),
          const SizedBox(height: kBlockGap),
          if (!widget.revealed)
            PillButton(
              label: 'Check ✓',
              color: AppColors.pronunciation,
              onTap: widget.enabled && canCheck
                  ? () {
                      final ok = widget.onSubmit(QuantityResponse(_coloured.length));
                      ok ? setState(() => checkedCorrect = true) : showWrong();
                    }
                  : null,
            ),
        ],
      ],
    );
  }

  /// A ten-frame of stars (2 rows of 5); tap to colour / un-colour.
  Widget _colourBoard() {
    final answer = widget.question.answer;
    // Locked while a wrong answer is marked (see WrongCheckReset).
    final editable = widget.enabled && !checkedCorrect && !widget.revealed && !wrongShown;
    final wrong = wrongShown && !widget.revealed;
    final border = checkHighlight ?? AppColors.divider;
    Widget cell(int i) {
      final on = widget.revealed ? i < answer : _coloured.contains(i);
      return Expanded(
        child: GestureDetector(
          onTap: editable
              ? () => setState(() {
                    on ? _coloured.remove(i) : _coloured.add(i);
                    changed();
                  })
              : null,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: on ? const Color(0xFFFFF4C2) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider, width: 1.5),
              ),
              child: Center(
                child: Icon(
                  on ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 34,
                  color: on ? Colors.amber : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ),
      );
    }

    const perRow = RecognitionQuestion.quantitySlots ~/ 2;
    final board = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: wrong ? LearningColors.wrongFill : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: checkHighlight == null ? 1.5 : 3),
      ),
      child: Column(
        children: [
          Row(children: [for (var i = 0; i < perRow; i++) cell(i)]),
          Row(children: [for (var i = perRow; i < perRow * 2; i++) cell(i)]),
        ],
      ),
    );
    if (checkedCorrect) return correctMarked(board, correct: true);
    return wrongMarked(board, wrong: wrong);
  }
}
