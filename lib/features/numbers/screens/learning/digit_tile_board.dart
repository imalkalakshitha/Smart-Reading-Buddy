import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';

/// Digit slots + digit tiles (Build, Formation) — a [TileBoard] of digits.
class DigitTileBoard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return TileBoard(
      tiles: [for (final t in tiles) '$t'],
      slotCount: slotCount,
      onSubmit: (labels) => onSubmit([for (final l in labels) int.parse(l)]),
      enabled: enabled,
      reveal: revealDigits?.map((d) => '$d').toList(),
    );
  }
}

/// Answer slots + tiles (digits or letters). Tap a tile to place it in the
/// next empty slot; tap a slot to take its tile back; Check submits the
/// labels in slot order. A wrong answer shakes the row and marks the slots
/// (peach fill, darker orange border, 🔄) for [kWrongResetDelay], then the
/// marking clears; the tiles stay so the child can fix them, and Check stays
/// off until something changes.
///
/// Slot sizing follows the Encoding module's Word Building tray: slots
/// shrink to fit the row (up to 64 px), rounded 14 px corners. [gapsAfter]
/// adds a word gap after those slot indices ("one | hundred").
class TileBoard extends StatefulWidget {
  final List<String> tiles;
  final int slotCount;
  final bool Function(List<String> labels) onSubmit;
  final bool enabled;
  final List<String>? reveal;
  final Set<int> gapsAfter;

  const TileBoard({
    super.key,
    required this.tiles,
    required this.slotCount,
    required this.onSubmit,
    required this.enabled,
    this.reveal,
    this.gapsAfter = const {},
  });

  @override
  State<TileBoard> createState() => _TileBoardState();
}

class _TileBoardState extends State<TileBoard> {
  /// Tile index placed in each slot, or null.
  late final List<int?> _slots = List.filled(widget.slotCount, null);
  bool _correct = false;
  bool _wrongShown = false;
  bool _lockedUntilChange = false;
  Timer? _wrongTimer;

  @override
  void dispose() {
    _wrongTimer?.cancel();
    super.dispose();
  }

  void _changed() {
    _wrongTimer?.cancel();
    _wrongShown = false;
    _lockedUntilChange = false;
  }

  bool get _full => _slots.every((s) => s != null);

  void _placeTile(int tileIndex) {
    final empty = _slots.indexOf(null);
    if (empty < 0) return;
    setState(() {
      _slots[empty] = tileIndex;
      _changed();
    });
  }

  void _clearSlot(int slot) {
    if (_slots[slot] == null) return;
    setState(() {
      _slots[slot] = null;
      _changed();
    });
  }

  void _check() {
    final labels = [for (final s in _slots) widget.tiles[s!]];
    final ok = widget.onSubmit(labels);
    if (ok) {
      setState(() => _correct = true);
      return;
    }
    setState(() => _wrongShown = true);
    _wrongTimer = Timer(kWrongResetDelay, () {
      if (!mounted) return;
      setState(() {
        _wrongShown = false;
        _lockedUntilChange = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final reveal = widget.reveal;
    final used = _slots.whereType<int>().toSet();
    final slotHighlight = _correct ? LearningColors.correct : (_wrongShown ? LearningColors.wrongBorder : null);
    final editable = widget.enabled && !_correct;
    final n = widget.slotCount;

    return Column(
      children: [
        LayoutBuilder(builder: (context, constraints) {
          const spacing = 6.0;
          const gap = 18.0;
          final gaps = widget.gapsAfter.length;
          final size = ((constraints.maxWidth - (n - 1) * spacing - gaps * gap) / n).clamp(26.0, 64.0);
          final row = Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < n; i++) ...[
                _slot(i, size, reveal, slotHighlight, editable),
                if (i < n - 1) SizedBox(width: widget.gapsAfter.contains(i) ? gap : spacing),
              ],
            ],
          );
          if (!_wrongShown) return row;
          return gentleShake(Stack(
            clipBehavior: Clip.none,
            children: [row, const Positioned(top: -12, right: 0, child: RetryBadge())],
          ));
        }),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var t = 0; t < widget.tiles.length; t++)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: used.contains(t) ? 0.2 : 1,
                child: SizedBox(
                  width: 64,
                  child: BigNumberButton(
                    label: widget.tiles[t],
                    fontSize: 34,
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
            onTap: editable && _full && !_wrongShown && !_lockedUntilChange ? _check : null,
          ),
      ],
    );
  }

  Widget _slot(int i, double size, List<String>? reveal, Color? highlight, bool editable) {
    final label = reveal != null ? reveal[i] : (_slots[i] == null ? null : widget.tiles[_slots[i]!]);
    final border = reveal != null ? LearningColors.correct : highlight;
    final filled = label != null;
    final wrong = reveal == null && _wrongShown;
    return GestureDetector(
      onTap: editable ? () => _clearSlot(i) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size * 1.15,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: wrong
              ? LearningColors.wrongFill
              : (filled ? AppColors.primary.withValues(alpha: 0.10) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: border ?? (filled ? AppColors.primary : AppColors.primaryLight),
            width: border != null ? 3 : 2,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              label ?? '',
              style: GoogleFonts.nunito(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
