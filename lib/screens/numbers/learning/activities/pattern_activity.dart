import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/app_colors.dart';
import '../../../../services/numbers/number_question.dart';
import '../choice_options.dart' show WrongPickReset;
import '../learning_widgets.dart';

/// Patterns — find the missing number in a rule-based sequence.
class PatternActivity extends StatefulWidget {
  final PatternQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;

  const PatternActivity({
    super.key,
    required this.question,
    required this.onSubmit,
    required this.enabled,
    required this.revealed,
  });

  @override
  State<PatternActivity> createState() => _PatternActivityState();
}

class _PatternActivityState extends State<PatternActivity>
    with WrongPickReset<PatternActivity> {
  int? _correct;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final filled = _correct != null || widget.revealed;

    final row = Row(
      children: [
        for (var i = 0; i < q.sequence.length; i++) ...[
          Expanded(child: _bubble(i, filled)),
          if (i < q.sequence.length - 1) const SizedBox(width: 6),
        ],
      ],
    );

    return Column(
      children: [
        q.road ? _road(row) : row,
        const SizedBox(height: 36),
        OptionGrid(
          children: [
            for (final o in q.options)
              BigNumberButton(
                label: '$o',
                fontSize: 40,
                look: o == _correct || (widget.revealed && o == q.answer)
                    ? OptionLook.correct
                    : (isMarkedWrong(o) ? OptionLook.wrong : OptionLook.normal),
                onTap: widget.enabled && _correct == null && !isMarkedWrong(o)
                    ? () {
                        final ok = widget.onSubmit(o);
                        ok ? setState(() => _correct = o) : markWrong(o);
                      }
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  /// "Number road": the sequence as stepping stones on a road, with a car
  /// driving along it.
  Widget _road(Widget stones) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('🚗', style: TextStyle(fontSize: 36)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF6B7280),
            borderRadius: BorderRadius.circular(18),
            border: const Border.symmetric(
              horizontal: BorderSide(color: Color(0xFFFDE68A), width: 4),
            ),
          ),
          child: stones,
        ),
      ],
    );
  }

  Widget _bubble(int i, bool filled) {
    final q = widget.question;
    final isGap = i == q.missingIndex;
    final text = isGap && !filled ? '?' : '${q.sequence[i]}';
    final color = isGap
        ? (filled ? LearningColors.correctSurface : LearningColors.tryAgainSurface)
        : Colors.white;
    final border = isGap
        ? (filled ? LearningColors.correct : LearningColors.accent)
        : AppColors.divider;
    return AspectRatio(
      aspectRatio: 0.85,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: isGap ? 3 : 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
