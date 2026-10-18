import 'package:flutter/material.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';

/// Flat, 2-3-colour vector illustrations for Pronunciation's level cards —
/// replaces the old star-count/trophy/crown EMOJI (word_data.dart's
/// _levelEmojis, still present there but no longer read by _LevelCard) with
/// custom-painted icons that read as a clear growth progression:
/// seedling → growing plant → small tree → trophy → crown.
///
/// Same flat-shape-with-thin-outline style as vmg_mouth_widget.dart's
/// _MouthPainter (fill Paint + separate stroke Paint per shape), just a
/// much simpler shape count per icon. Palette is AppColors only, plus one
/// warm soil/wood brown not currently in AppColors (levels 1-3 are
/// literally soil/plant illustrations — a green-only or blue-only palette
/// can't represent that), and one darker gold for the trophy/crown outline
/// (a shade of AppColors.accentYellow, not a new hue).
class LevelProgressIcon extends StatelessWidget {
  /// 0-based level index (0 = Level 1 seedling ... 4 = Level 5 crown).
  final int levelIndex;
  final double size;

  const LevelProgressIcon({super.key, required this.levelIndex, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _LevelProgressPainter(levelIndex: levelIndex.clamp(0, 4)),
      ),
    );
  }
}

class _LevelProgressPainter extends CustomPainter {
  final int levelIndex;

  _LevelProgressPainter({required this.levelIndex});

  // Soil/wood brown — not in AppColors (nothing there represents earth/
  // wood), needed for levels 1-3's ground/trunk. Kept to one shade, reused
  // across all three rather than inventing a second brown.
  static const _soil = Color(0xFF9C6B3E);
  static const _soilDark = Color(0xFF7A5230);
  // Darker gold for trophy/crown outlines — a shade of AppColors
  // .accentYellow (F9CA24), not an unrelated hue.
  static const _goldDark = Color(0xFFC98A0F);

  @override
  void paint(Canvas canvas, Size size) {
    switch (levelIndex) {
      case 0:
        _paintSeedling(canvas, size);
        break;
      case 1:
        _paintGrowingPlant(canvas, size);
        break;
      case 2:
        _paintTree(canvas, size);
        break;
      case 3:
        _paintTrophy(canvas, size);
        break;
      case 4:
        _paintCrown(canvas, size);
        break;
    }
  }

  // ── Level 1: seedling ────────────────────────────────────────────────

  void _paintSeedling(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final groundY = h * 0.78;

    _drawSoilMound(canvas, size, groundY);

    final stemPaint = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, groundY), Offset(cx, h * 0.40), stemPaint);

    final leafFill = Paint()..color = AppColors.primary;
    final leafStroke = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025;

    // Two small teardrop leaves splayed from the stem tip.
    for (final side in [-1.0, 1.0]) {
      final tipX = cx + side * w * 0.22;
      final tipY = h * 0.30;
      final path = Path()
        ..moveTo(cx, h * 0.40)
        ..quadraticBezierTo(cx + side * w * 0.24, h * 0.42, tipX, tipY)
        ..quadraticBezierTo(cx + side * w * 0.10, h * 0.36, cx, h * 0.40)
        ..close();
      canvas.drawPath(path, leafFill);
      canvas.drawPath(path, leafStroke);
    }
  }

  // ── Level 2: growing plant (a few leaves) ───────────────────────────

  void _paintGrowingPlant(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final groundY = h * 0.82;
    final topY = h * 0.20;

    _drawSoilMound(canvas, size, groundY);

    final stemPaint = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    final stemPath = Path()
      ..moveTo(cx, groundY)
      ..quadraticBezierTo(cx - w * 0.04, h * 0.5, cx, topY);
    canvas.drawPath(stemPath, stemPaint);

    final leafFill = Paint()..color = AppColors.primary;
    final leafStroke = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022;

    void leaf(double atY, double side, double length) {
      final baseX = cx - w * 0.015;
      final tipX = baseX + side * length;
      final tipY = atY - length * 0.35;
      final path = Path()
        ..moveTo(baseX, atY)
        ..quadraticBezierTo(baseX + side * length * 0.7, atY - length * 0.1, tipX, tipY)
        ..quadraticBezierTo(baseX + side * length * 0.35, atY + length * 0.18, baseX, atY)
        ..close();
      canvas.drawPath(path, leafFill);
      canvas.drawPath(path, leafStroke);
    }

    leaf(h * 0.62, -1, w * 0.26);
    leaf(h * 0.48, 1, w * 0.28);
    leaf(h * 0.34, -1, w * 0.20);
  }

  // ── Level 3: small tree ──────────────────────────────────────────────

  void _paintTree(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;

    // Trunk.
    final trunkFill = Paint()..color = _soil;
    final trunkStroke = Paint()
      ..color = _soilDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02;
    final trunkRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, h * 0.80), width: w * 0.16, height: h * 0.30),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(trunkRect, trunkFill);
    canvas.drawRRect(trunkRect, trunkStroke);

    // Canopy — three overlapping circles read as a soft, flat treetop.
    final canopyFill = Paint()..color = AppColors.primary;
    final canopyStroke = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025;

    final canopyCenters = [
      Offset(cx - w * 0.18, h * 0.46),
      Offset(cx + w * 0.18, h * 0.46),
      Offset(cx, h * 0.30),
    ];
    final path = Path();
    for (final c in canopyCenters) {
      path.addOval(Rect.fromCircle(center: c, radius: w * 0.24));
    }
    canvas.drawPath(path, canopyFill);
    for (final c in canopyCenters) {
      canvas.drawCircle(c, w * 0.24, canopyStroke);
    }
  }

  // ── Level 4: trophy ──────────────────────────────────────────────────

  void _paintTrophy(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;

    final gold = Paint()..color = AppColors.accentYellow;
    final goldStroke = Paint()
      ..color = _goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025;

    // Base (two-tier).
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, h * 0.86), width: w * 0.30, height: h * 0.08),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(baseRect, gold);
    canvas.drawRRect(baseRect, goldStroke);

    // Stem.
    final stemRect = Rect.fromCenter(center: Offset(cx, h * 0.72), width: w * 0.10, height: h * 0.14);
    canvas.drawRect(stemRect, gold);
    canvas.drawRect(stemRect, goldStroke);

    // Cup body — tapered path from a wide rim to a narrow base.
    final rimY = h * 0.24;
    final cupBottomY = h * 0.62;
    final rimHalfW = w * 0.26;
    final bottomHalfW = w * 0.10;
    final cupPath = Path()
      ..moveTo(cx - rimHalfW, rimY)
      ..lineTo(cx + rimHalfW, rimY)
      ..quadraticBezierTo(cx + rimHalfW, cupBottomY - h * 0.06, cx + bottomHalfW, cupBottomY)
      ..lineTo(cx - bottomHalfW, cupBottomY)
      ..quadraticBezierTo(cx - rimHalfW, cupBottomY - h * 0.06, cx - rimHalfW, rimY)
      ..close();
    canvas.drawPath(cupPath, gold);
    canvas.drawPath(cupPath, goldStroke);

    // Handles.
    final handleStroke = Paint()
      ..color = _goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;
    final handleY = (rimY + cupBottomY) / 2 - h * 0.02;
    canvas.drawArc(
        Rect.fromCenter(center: Offset(cx - rimHalfW - w * 0.02, handleY), width: w * 0.16, height: h * 0.22),
        1.0, 3.2, false, handleStroke);
    canvas.drawArc(
        Rect.fromCenter(center: Offset(cx + rimHalfW + w * 0.02, handleY), width: w * 0.16, height: h * 0.22),
        -1.0 - 3.2, 3.2, false, handleStroke);

    // Shine streak — a thin white arc on the cup, single extra highlight.
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(cx - rimHalfW * 0.45, rimY + h * 0.06), Offset(cx - rimHalfW * 0.30, cupBottomY - h * 0.10), shine);
  }

  // ── Level 5: crown ───────────────────────────────────────────────────

  void _paintCrown(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;

    final gold = Paint()..color = AppColors.accentYellow;
    final goldStroke = Paint()
      ..color = _goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03;

    final baseY = h * 0.72;
    final topY = h * 0.24;
    final bandBottomY = h * 0.84;
    final leftX = cx - w * 0.30;
    final rightX = cx + w * 0.30;

    // Zigzag crown silhouette: 3 points, alternating with valleys.
    final path = Path()
      ..moveTo(leftX, baseY)
      ..lineTo(leftX, h * 0.46)
      ..lineTo(cx - w * 0.17, h * 0.34)
      ..lineTo(cx, topY)
      ..lineTo(cx + w * 0.17, h * 0.34)
      ..lineTo(rightX, h * 0.46)
      ..lineTo(rightX, baseY)
      ..close();
    canvas.drawPath(path, gold);
    canvas.drawPath(path, goldStroke);

    // Base band.
    final bandRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(leftX, baseY - h * 0.02, rightX, bandBottomY),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(bandRect, gold);
    canvas.drawRRect(bandRect, goldStroke);

    // Small gem dots — the one non-gold accent, tying back to the app's
    // primary green rather than an unrelated jewel colour.
    final gem = Paint()..color = AppColors.primary;
    for (final gx in [cx - w * 0.17, cx, cx + w * 0.17]) {
      canvas.drawCircle(Offset(gx, h * 0.42), w * 0.035, gem);
    }
  }

  // ── Shared ────────────────────────────────────────────────────────────

  void _drawSoilMound(Canvas canvas, Size size, double groundY) {
    final w = size.width;
    final fill = Paint()..color = _soil;
    final stroke = Paint()
      ..color = _soilDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02;
    final rect = Rect.fromCenter(center: Offset(w / 2, groundY), width: w * 0.56, height: size.height * 0.14);
    canvas.drawOval(rect, fill);
    canvas.drawOval(rect, stroke);
  }

  @override
  bool shouldRepaint(_LevelProgressPainter old) => old.levelIndex != levelIndex;
}
