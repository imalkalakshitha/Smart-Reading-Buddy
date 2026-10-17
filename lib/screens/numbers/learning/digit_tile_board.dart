import 'package:flutter/material.dart';
import '../../../models/app_colors.dart';
import 'learning_widgets.dart';

/// Digit slots + digit tiles (Build, Formation). Tap a tile to place it in
/// the next empty slot; tap a slot to take its tile back; Check submits the
/// digits in slot order. After a wrong answer Check stays off until the
/// child changes something.
class DigitTileBoard extends StatefulWidget {
  final List<int> tiles;
  final int slotCount;
  final bool Function(List<int> digits) onSubmit;
  final bool enabled;

  /// Shown in the slots (green) once the answer is revealed.
  final List<int>? revealDigits;

  const DigitTileBoard({
    super.key,
    required this.tiles,
    required this.slotCount,
    required this.onSubmit,
    required this.enabled,
    this.revealDigits,
  });

  @override
  State<DigitTileBoard> createState() => _DigitTileBoardState();
}

class _DigitTileBoardState extends State<DigitTileBoard> {
  /// Tile index placed in each slot, or null.
  late final List<int?> _slots = List.filled(widget.slotCount, null);
  bool? _lastResult;

  bool get _full => _slots.every((s) => s != null);

  void _placeTile(int tileIndex) {
    final empty = _slots.indexOf(null);
    if (empty < 0) return;
    setState(() {
      _slots[empty] = tileIndex;
      _lastResult = null;
    });
  }

  void _clearSlot(int slot) {
    if (_slots[slot] == null) return;
    setState(() {
      _slots[slot] = null;
      _lastResult = null;
    });
  }

  void _check() {
    final digits = [for (final s in _slots) widget.tiles[s!]];
    final ok = widget.onSubmit(digits);
    setState(() => _lastResult = ok);
  }

  @override
  Widget build(BuildContext context) {
    final reveal = widget.revealDigits;
    final used = _slots.whereType<int>().toSet();
    final slotHighlight = switch (_lastResult) {
      true => LearningColors.correct,
      false => LearningColors.tryAgain,
      null => null,
    };
    final editable = widget.enabled && _lastResult != true;
    // Narrower slots/tiles for 4+ digits so they fit at phone width.
    final slotWidth = widget.slotCount >= 4 ? 56.0 : 64.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.slotCount; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: AnswerSlot(
                  width: slotWidth,
                  value: reveal != null
                      ? '${reveal[i]}'
                      : (_slots[i] == null ? null : '${widget.tiles[_slots[i]!]}'),
                  highlight: reveal != null ? LearningColors.correct : slotHighlight,
                  onTap: editable ? () => _clearSlot(i) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            for (var t = 0; t < widget.tiles.length; t++)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: used.contains(t) ? 0.2 : 1,
                child: SizedBox(
                  width: 72,
                  child: BigNumberButton(
                    label: '${widget.tiles[t]}',
                    fontSize: 36,
                    onTap: editable && !used.contains(t) ? () => _placeTile(t) : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        if (reveal == null)
          PillButton(
            label: 'Check ✓',
            color: AppColors.pronunciation,
            onTap: editable && _full && _lastResult == null ? _check : null,
          ),
      ],
    );
  }
}
