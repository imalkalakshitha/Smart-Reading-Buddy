import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/app_colors.dart';
import 'learning_widgets.dart';

const _objectEmoji = {'star': '⭐', 'apple': '🍎', 'fish': '🐟'};

String objectEmoji(String object) => _objectEmoji[object] ?? '🔵';

/// [count] objects in rows of 5 (ten-frame style), so they're easy to
/// count in groups.
class ObjectGrid extends StatelessWidget {
  final int count;
  final String object;
  final double size;

  /// The last [crossedOut] objects are faded and crossed (subtraction).
  final int crossedOut;

  const ObjectGrid({
    super.key,
    required this.count,
    required this.object,
    this.size = 34,
    this.crossedOut = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Container(
        width: size * 5,
        height: size * 1.6,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text('empty', style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary)),
      );
    }
    final rows = <Widget>[];
    for (var start = 0; start < count; start += 5) {
      final end = start + 5 > count ? count : start + 5;
      rows.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = start; i < end; i++)
            Padding(
              padding: EdgeInsets.all(size * 0.08),
              child: _item(i >= count - crossedOut),
            ),
        ],
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _item(bool crossed) {
    final glyph = Text(objectEmoji(object), style: TextStyle(fontSize: size * 0.8));
    if (!crossed) return SizedBox(width: size, height: size, child: Center(child: glyph));
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0.3, child: glyph),
          Icon(Icons.close_rounded, size: size, color: LearningColors.tryAgain),
        ],
      ),
    );
  }
}

/// Base-ten blocks: hundred flats, ten sticks, ones balls. With [chart],
/// each kind sits in a labelled Hundreds / Tens / Ones column.
class BaseTenBlocks extends StatelessWidget {
  final int hundreds;
  final int tens;
  final int ones;
  final bool chart;

  const BaseTenBlocks({
    super.key,
    required this.hundreds,
    required this.tens,
    required this.ones,
    this.chart = false,
  });

  static const flatColor = Color(0xFFF39C12);
  static const stickColor = Color(0xFF27AE60);
  static const ballColor = Color(0xFF3498DB);

  @override
  Widget build(BuildContext context) {
    final groups = <(String, Widget)>[
      if (hundreds > 0 || chart) ('Hundreds', _wrap([for (var i = 0; i < hundreds; i++) const _Flat()])),
      ('Tens', _wrap([for (var i = 0; i < tens; i++) const _Stick()])),
      ('Ones', _wrap([for (var i = 0; i < ones; i++) const _Ball()], spacing: 6)),
    ];
    if (!chart) {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 24,
        runSpacing: 16,
        children: [for (final g in groups) g.$2],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider, width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    groups[i].$1,
                    style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  groups[i].$2,
                ],
              ),
            ),
          ),
          if (i < groups.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _wrap(List<Widget> children, {double spacing = 4}) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: spacing,
        runSpacing: 6,
        children: children,
      );
}

/// 10 × 10 square = one hundred.
class _Flat extends StatelessWidget {
  const _Flat();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: CustomPaint(painter: _GridPainter(10, 10, BaseTenBlocks.flatColor)),
      );
}

/// 1 × 10 stick = one ten.
class _Stick extends StatelessWidget {
  const _Stick();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 10,
        height: 60,
        child: CustomPaint(painter: _GridPainter(1, 10, BaseTenBlocks.stickColor)),
      );
}

/// A ball = one.
class _Ball extends StatelessWidget {
  const _Ball();

  @override
  Widget build(BuildContext context) => Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(color: BaseTenBlocks.ballColor, shape: BoxShape.circle),
      );
}

class _GridPainter extends CustomPainter {
  final int cols;
  final int rows;
  final Color color;

  _GridPainter(this.cols, this.rows, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas.drawRRect(r, fill);
    for (var c = 1; c < cols; c++) {
      final x = size.width * c / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var rr = 1; rr < rows; rr++) {
      final y = size.height * rr / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.cols != cols || old.rows != rows || old.color != color;
}

/// [groups] bordered boxes, each holding [perGroup] dots (× and ÷).
class DotGroups extends StatelessWidget {
  final int groups;
  final int perGroup;

  const DotGroups({super.key, required this.groups, required this.perGroup});

  @override
  Widget build(BuildContext context) {
    final dot = perGroup > 12 ? 10.0 : 14.0;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var g = 0; g < groups; g++)
          Container(
            constraints: BoxConstraints(maxWidth: (dot + 4) * 5 + 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: LearningColors.tryAgainSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LearningColors.accent.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var i = 0; i < perGroup; i++)
                  Container(
                    width: dot,
                    height: dot,
                    decoration: const BoxDecoration(color: BaseTenBlocks.ballColor, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
