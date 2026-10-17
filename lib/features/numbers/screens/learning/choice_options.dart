import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';

/// Up to 4 big number options. A wrong pick is marked softly (peach fill,
/// darker orange border, 🔄, a gentle shake) and resets after
/// [kWrongResetDelay] so the child can try again; the right pick (or the
/// revealed answer) turns green.
class ChoiceOptions extends StatefulWidget {
  final List<int> options;
  final int answer;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;
  final double fontSize;

  const ChoiceOptions({
    super.key,
    required this.options,
    required this.answer,
    required this.onSubmit,
    required this.enabled,
    required this.revealed,
    this.fontSize = 44,
  });

  @override
  State<ChoiceOptions> createState() => _ChoiceOptionsState();
}

class _ChoiceOptionsState extends State<ChoiceOptions> with WrongPickReset<ChoiceOptions> {
  int? _correct;

  @override
  Widget build(BuildContext context) {
    return OptionGrid(
      children: [
        for (final o in widget.options)
          BigNumberButton(
            label: '$o',
            fontSize: widget.fontSize,
            look: o == _correct || (widget.revealed && o == widget.answer)
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
    );
  }
}

/// Marks a wrong option for [kWrongResetDelay], then clears it so it looks
/// (and taps) like a normal option again.
mixin WrongPickReset<T extends StatefulWidget> on State<T> {
  final Set<int> _wrong = {};
  final List<Timer> _wrongTimers = [];

  bool isMarkedWrong(int option) => _wrong.contains(option);

  void markWrong(int option) {
    setState(() => _wrong.add(option));
    _wrongTimers.add(Timer(kWrongResetDelay, () {
      if (mounted) setState(() => _wrong.remove(option));
    }));
  }

  @override
  void dispose() {
    for (final t in _wrongTimers) {
      t.cancel();
    }
    super.dispose();
  }
}
