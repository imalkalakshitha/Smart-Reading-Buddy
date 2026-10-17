import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/app_colors.dart';
import '../../../../services/numbers/number_question.dart';
import '../learning_widgets.dart';

/// Ordering — a number train. Tap numbers to load them into the cars in
/// order; tap a car to unload it.
class OrderingActivity extends StatefulWidget {
  final OrderingQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;

  const OrderingActivity({
    super.key,
    required this.question,
    required this.onSubmit,
    required this.enabled,
    required this.revealed,
  });

  @override
  State<OrderingActivity> createState() => _OrderingActivityState();
}

class _OrderingActivityState extends State<OrderingActivity> with WrongCheckReset<OrderingActivity> {
  /// Item index loaded into each car, or null.
  late final List<int?> _cars = List.filled(widget.question.items.length, null);

  bool get _full => _cars.every((c) => c != null);

  void _load(int itemIndex) {
    final empty = _cars.indexOf(null);
    if (empty < 0) return;
    setState(() {
      _cars[empty] = itemIndex;
      changed();
    });
  }

  void _unload(int car) {
    if (_cars[car] == null) return;
    setState(() {
      _cars[car] = null;
      changed();
    });
  }

  void _check() {
    final order = [for (final c in _cars) widget.question.items[c!]];
    final ok = widget.onSubmit(order);
    ok ? setState(() => checkedCorrect = true) : showWrong();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final loaded = _cars.whereType<int>().toSet();
    final highlight = checkHighlight;
    final editable = widget.enabled && !checkedCorrect;
    final answer = q.answer;
    final small = Text('smallest',
        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary));
    final big = Text('biggest',
        style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary));

    return Column(
      children: [
        wrongMarked(wrong: wrongShown && !widget.revealed, Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('🚂', style: TextStyle(fontSize: 44)),
            const SizedBox(width: 6),
            for (var i = 0; i < q.items.length; i++) ...[
              Expanded(
                child: AnswerSlot(
                  width: double.infinity,
                  value: widget.revealed
                      ? '${answer[i]}'
                      : (_cars[i] == null ? null : '${q.items[_cars[i]!]}'),
                  highlight: widget.revealed ? LearningColors.correct : highlight,
                  wrong: wrongShown && !widget.revealed,
                  onTap: editable ? () => _unload(i) : null,
                ),
              ),
              if (i < q.items.length - 1) const SizedBox(width: 6),
            ],
          ],
        )),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 50),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: q.descending ? [big, const Text('→'), small] : [small, const Text('→'), big],
          ),
        ),
        const SizedBox(height: 32),
        OptionGrid(
          children: [
            for (var i = 0; i < q.items.length; i++)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: loaded.contains(i) ? 0.2 : 1,
                child: BigNumberButton(
                  label: '${q.items[i]}',
                  fontSize: 38,
                  onTap: editable && !loaded.contains(i) ? () => _load(i) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        if (!widget.revealed)
          PillButton(
            label: 'Check ✓',
            color: AppColors.pronunciation,
            onTap: editable && _full && canCheck ? _check : null,
          ),
      ],
    );
  }
}
