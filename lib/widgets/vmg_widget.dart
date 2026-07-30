import 'package:flutter/material.dart';
import '../models/app_colors.dart';

/// Animated mouth guide for pronunciation feedback (Visual Mouth Guide).
class VmgWidget extends StatefulWidget {
  final String vmgType;
  final bool animate;

  const VmgWidget({super.key, required this.vmgType, this.animate = true});

  @override
  State<VmgWidget> createState() => _VmgWidgetState();
}

class _VmgWidgetState extends State<VmgWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(VmgWidget old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    if (!widget.animate) _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => CustomPaint(
        size: const Size(160, 130),
        painter: _MouthPainter(
          vmgType: widget.vmgType,
          pulseValue: _pulse.value,
        ),
      ),
    );
  }
}

class _MouthPainter extends CustomPainter {
  final String vmgType;
  final double pulseValue;

  _MouthPainter({required this.vmgType, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 10;

    // Face outline
    final facePaint = Paint()
      ..color = const Color(0xFFFDE9D5)
      ..style = PaintingStyle.fill;
    final faceStroke = Paint()
      ..color = const Color(0xFFE8B89A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 8), width: 140, height: 120),
      facePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 8), width: 140, height: 120),
      faceStroke,
    );

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF4A3728);
    canvas.drawCircle(Offset(cx - 28, cy - 38), 6.0, eyePaint);
    canvas.drawCircle(Offset(cx + 28, cy - 38), 6.0, eyePaint);

    // Eyebrow lines
    final browPaint = Paint()
      ..color = const Color(0xFF6B4F3A)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 36, cy - 50), Offset(cx - 18, cy - 48), browPaint);
    canvas.drawLine(Offset(cx + 18, cy - 48), Offset(cx + 36, cy - 50), browPaint);

    // Draw mouth based on type
    _drawMouth(canvas, cx, cy, size);
  }

  void _drawMouth(Canvas canvas, double cx, double cy, Size size) {
    final lipColor = Color.lerp(
      const Color(0xFFE07070),
      AppColors.primary,
      pulseValue * 0.3,
    )!;

    final lipPaint = Paint()
      ..color = lipColor
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = const Color(0xFFC05050)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final teethPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final tonguePaint = Paint()
      ..color = const Color(0xFFFF8A80)
      ..style = PaintingStyle.fill;

    switch (vmgType) {
      case 'mouth_open_wide':
        _drawOpenWide(canvas, cx, cy, lipPaint, outlinePaint, teethPaint, tonguePaint);
        break;
      case 'lips_together':
        _drawLipsTogether(canvas, cx, cy, lipPaint, outlinePaint);
        break;
      case 'teeth_close':
        _drawTeethClose(canvas, cx, cy, lipPaint, outlinePaint, teethPaint);
        break;
      case 'lips_rounded':
        _drawLipsRounded(canvas, cx, cy, lipPaint, outlinePaint);
        break;
      case 'tongue_teeth':
        _drawTongueBetweenTeeth(canvas, cx, cy, lipPaint, outlinePaint, teethPaint, tonguePaint);
        break;
      case 'tongue_back':
        _drawTongueBack(canvas, cx, cy, lipPaint, outlinePaint, teethPaint, tonguePaint);
        break;
      case 'tongue_up':
        _drawTongueUp(canvas, cx, cy, lipPaint, outlinePaint, teethPaint, tonguePaint);
        break;
      case 'teeth_lip':
        _drawTeethOnLip(canvas, cx, cy, lipPaint, outlinePaint, teethPaint);
        break;
      default: // mouth_open
        _drawMouthOpen(canvas, cx, cy, lipPaint, outlinePaint, teethPaint);
        break;
    }
  }

  void _drawOpenWide(Canvas canvas, double cx, double cy,
      Paint lip, Paint outline, Paint teeth, Paint tongue) {
    final h = 28.0 + pulseValue * 6;
    final rect = Rect.fromCenter(center: Offset(cx, cy + 10), width: 64, height: h);
    canvas.drawOval(rect, lip);
    // teeth strip
    canvas.drawRect(Rect.fromLTWH(cx - 28, cy + 10 - h / 2 + 2, 56, 8), teeth);
    canvas.drawRect(Rect.fromLTWH(cx - 28, cy + 10 + h / 2 - 10, 56, 8), teeth);
    // tongue
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 14 + h / 4), width: 32, height: 14),
      tongue,
    );
    canvas.drawOval(rect, outline);
  }

  void _drawLipsTogether(Canvas canvas, double cx, double cy,
      Paint lip, Paint outline) {
    final path = Path();
    path.moveTo(cx - 32, cy + 12);
    path.quadraticBezierTo(cx, cy + 6, cx + 32, cy + 12);
    path.quadraticBezierTo(cx, cy + 18, cx - 32, cy + 12);
    path.close();
    canvas.drawPath(path, lip);
    // center line (lips pressed)
    canvas.drawLine(
      Offset(cx - 32, cy + 12),
      Offset(cx + 32, cy + 12),
      Paint()
        ..color = const Color(0xFFC05050)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawTeethClose(Canvas canvas, double cx, double cy,
      Paint lip, Paint outline, Paint teeth) {
    final outer = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 12), width: 66, height: 22),
      const Radius.circular(11),
    );
    canvas.drawRRect(outer, lip);
    // thin teeth gap line
    canvas.drawLine(
      Offset(cx - 28, cy + 12),
      Offset(cx + 28, cy + 12),
      Paint()
        ..color = const Color(0xFFDDDDDD)
        ..strokeWidth = 1.5,
    );
    canvas.drawRRect(outer, outline);
  }

  void _drawLipsRounded(Canvas canvas, double cx, double cy,
      Paint lip, Paint outline) {
    final r = 18.0 + pulseValue * 4;
    canvas.drawCircle(Offset(cx, cy + 12), r, lip);
    canvas.drawCircle(Offset(cx, cy + 12), r, outline);
    // inner darker circle to show depth
    canvas.drawCircle(
      Offset(cx, cy + 12),
      r - 8,
      Paint()..color = const Color(0x55C05050),
    );
  }

  void _drawTongueBetweenTeeth(Canvas canvas, double cx, double cy,
      Paint lip, Paint outline, Paint teeth, Paint tongue) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 12), width: 60, height: 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, lip);
    // teeth showing
    canvas.drawRect(Rect.fromLTWH(cx - 25, cy + 3, 50, 8), teeth);
    // tongue tip peeking between teeth
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 17), width: 28, height: 10),
      tongue,
    );
    canvas.drawRRect(rect, outline);
  }

  void _drawTongueBack(Canvas canvas, double cx, double cy,
      Paint lip, Paint outline, Paint teeth, Paint tongue) {
    final h = 22.0 + pulseValue * 4;
    final rect = Rect.fromCenter(center: Offset(cx, cy + 12), width: 58, height: h);
    canvas.drawOval(rect, lip);
    canvas.drawRect(Rect.fromLTWH(cx - 25, cy + 4, 50, 8), teeth);
    // tongue humped at back
    final tp = Path();
    tp.moveTo(cx - 20, cy + 20);
    tp.quadraticBezierTo(cx, cy + 10, cx + 20, cy + 20);
    tp.close();
    canvas.drawPath(tp, tongue);
    canvas.drawOval(rect, outline);
  }

  void _drawTongueUp(Canvas canvas, double cx, double cy,
      Paint lip, Paint outline, Paint teeth, Paint tongue) {
    final h = 20.0 + pulseValue * 4;
    final rect = Rect.fromCenter(center: Offset(cx, cy + 12), width: 56, height: h);
    canvas.drawOval(rect, lip);
    canvas.drawRect(Rect.fromLTWH(cx - 24, cy + 4, 48, 7), teeth);
    // tongue tip touching upper area
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 7), width: 20, height: 8),
      tongue,
    );
    canvas.drawOval(rect, outline);
  }

  void _drawTeethOnLip(Canvas canvas, double cx, double cy,
      Paint lip, Paint outline, Paint teeth) {
    // Upper teeth resting on lower lip
    final outerPath = Path();
    outerPath.moveTo(cx - 30, cy + 8);
    outerPath.quadraticBezierTo(cx, cy + 2, cx + 30, cy + 8);
    outerPath.quadraticBezierTo(cx, cy + 22, cx - 30, cy + 8);
    outerPath.close();
    canvas.drawPath(outerPath, lip);
    // upper teeth strip
    canvas.drawRect(Rect.fromLTWH(cx - 25, cy + 3, 50, 8), teeth);
  }

  void _drawMouthOpen(Canvas canvas, double cx, double cy,
      Paint lip, Paint outline, Paint teeth) {
    final h = 20.0 + pulseValue * 6;
    final rect = Rect.fromCenter(center: Offset(cx, cy + 12), width: 58, height: h);
    canvas.drawOval(rect, lip);
    canvas.drawRect(Rect.fromLTWH(cx - 25, cy + 4, 50, 7), teeth);
    canvas.drawRect(Rect.fromLTWH(cx - 25, cy + 12 + h / 2 - 9, 50, 7), teeth);
    canvas.drawOval(rect, outline);
  }

  @override
  bool shouldRepaint(_MouthPainter old) =>
      old.pulseValue != pulseValue || old.vmgType != vmgType;
}
