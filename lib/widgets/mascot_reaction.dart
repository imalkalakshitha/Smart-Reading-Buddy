import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A tiny friendly face drawn with plain shapes (no image assets, no new
/// animation package) that pops in and wiggles happily — the "mascot
/// reaction" shown on a Letter Level success. [happy] controls its
/// expression; the same shape is reused (not built) for a softer "keep
/// trying" moment too, just with a gentler animation and no wiggle.
class MascotReaction extends StatelessWidget {
  final Color color;
  final bool happy;
  final double size;

  const MascotReaction({super.key, required this.color, this.happy = true, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final face = CustomPaint(
      size: Size(size, size),
      painter: _MascotFacePainter(color: color, happy: happy),
    );
    if (!happy) {
      return face.animate().scale(duration: 300.ms, curve: Curves.easeOut).fadeIn();
    }
    return face
        .animate()
        .scale(duration: 450.ms, curve: Curves.elasticOut)
        .then(delay: 150.ms)
        .shake(hz: 3, rotation: 0.06, duration: 500.ms);
  }
}

class _MascotFacePainter extends CustomPainter {
  final Color color;
  final bool happy;
  const _MascotFacePainter({required this.color, required this.happy});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, Paint()..color = color);

    // Cheeks
    final cheekPaint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(center.dx - radius * 0.55, center.dy + radius * 0.15), radius * 0.16, cheekPaint);
    canvas.drawCircle(Offset(center.dx + radius * 0.55, center.dy + radius * 0.15), radius * 0.16, cheekPaint);

    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = Colors.black87;
    final eyeY = center.dy - radius * 0.15;
    final eyeDx = radius * 0.38;
    final eyeRadius = radius * 0.2;

    if (happy) {
      // Closed, happy "^ ^" eyes drawn as arcs.
      final arcPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.09
        ..strokeCap = StrokeCap.round;
      for (final dx in [-eyeDx, eyeDx]) {
        final rect = Rect.fromCircle(center: Offset(center.dx + dx, eyeY + eyeRadius * 0.3), radius: eyeRadius);
        canvas.drawArc(rect, 3.4, 2.6, false, arcPaint);
      }
    } else {
      for (final dx in [-eyeDx, eyeDx]) {
        final eyeCenter = Offset(center.dx + dx, eyeY);
        canvas.drawCircle(eyeCenter, eyeRadius, eyePaint);
        canvas.drawCircle(eyeCenter, eyeRadius * 0.5, pupilPaint);
      }
    }

    // Mouth
    final mouthPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.09
      ..strokeCap = StrokeCap.round;
    final mouthRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius * 0.32),
      width: radius * 0.9,
      height: radius * (happy ? 0.7 : 0.35),
    );
    if (happy) {
      canvas.drawArc(mouthRect, 0.15, 2.85, false, mouthPaint);
    } else {
      // A small, gentle flat/neutral mouth — never a frown, just calm.
      canvas.drawLine(
        Offset(mouthRect.left, mouthRect.center.dy),
        Offset(mouthRect.right, mouthRect.center.dy),
        mouthPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MascotFacePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.happy != happy;
}
