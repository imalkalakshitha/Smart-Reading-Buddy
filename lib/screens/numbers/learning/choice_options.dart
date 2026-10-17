import 'package:flutter/material.dart';
import 'learning_widgets.dart';

/// Up to 4 big number options. A wrong pick turns soft orange and can't be
/// picked again; the right pick (or the revealed answer) turns green.
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

class _ChoiceOptionsState extends State<ChoiceOptions> {
  final Set<int> _wrong = {};
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
                : (_wrong.contains(o) ? OptionLook.wrong : OptionLook.normal),
            onTap: widget.enabled && _correct == null && !_wrong.contains(o)
                ? () {
                    final ok = widget.onSubmit(o);
                    setState(() => ok ? _correct = o : _wrong.add(o));
                  }
                : null,
          ),
      ],
    );
  }
}
