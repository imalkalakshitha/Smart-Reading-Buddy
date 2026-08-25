import 'dart:math';
import 'package:flutter/material.dart';

/// Face-free success celebration — small colourful sparkle/star shapes
/// bursting outward from the center and fading, drawn entirely with
/// CustomPainter (no new package, no image assets). Replaces MascotReaction
/// on Free Drawing Letter Level's result screen (see
/// free_drawing_letter_level_screen.dart's _buildResult) — only ever built
/// on an accepted attempt; a retry shows no celebration widget at all.
class SparkleBurst extends StatefulWidget {
  final double size;
  const SparkleBurst({super.key, this.size = 120});

  @override
  State<SparkleBurst> createState() => _SparkleBurstState();
}

class _SparkleBurstState extends State<SparkleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Sparkle> _sparkles;

  static const List<Color> _kSparkleColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFA94D),
    Color(0xFFFFD43B),
    Color(0xFF69DB7C),
    Color(0xFF4DD4C0),
    Color(0xFF4DABF7),
    Color(0xFF9775FA),
    Color(0xFFF783AC),
  ];
  static const int _kParticleCount = 14;

  @override
  void initState() {
    super.initState();
    // Fixed seed — same pleasant, evenly-spread burst every time rather
    // than a different random layout (some ugly, some nice) per attempt.
    final rnd = Random(42);
    _sparkles = List.generate(_kParticleCount, (i) {
      final angle = (2 * pi / _kParticleCount) * i + rnd.nextDouble() * 0.4;
      return _Sparkle(
        angle: angle,
        distanceFraction: 0.55 + rnd.nextDouble() * 0.45,
        size: 5.0 + rnd.nextDouble() * 6.0,
        color: _kSparkleColors[i % _kSparkleColors.length],
        isStar: i.isEven,
      );
    });
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _SparkleBurstPainter(sparkles: _sparkles, t: Curves.easeOut.transform(_ctrl.value)),
      ),
    );
  }
}

class _Sparkle {
  final double angle;
  final double distanceFraction; // 0.0-1.0, fraction of the burst radius
  final double size;
  final Color color;
  final bool isStar; // alternates star/circle shapes for visual variety
  const _Sparkle({
    required this.angle,
    required this.distanceFraction,
    required this.size,
    required this.color,
    required this.isStar,
  });
}

class _SparkleBurstPainter extends CustomPainter {
  final List<_Sparkle> sparkles;
  final double t; // 0.0-1.0, eased animation progress
  const _SparkleBurstPainter({required this.sparkles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    // Quick fade in, brief hold, fade out over the back 40% of the burst.
    final opacity = t < 0.6 ? (t / 0.6).clamp(0.0, 1.0) : (1.0 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    for (final s in sparkles) {
      final dist = radius * s.distanceFraction * (0.2 + 0.8 * t);
      final pos = center + Offset(cos(s.angle), sin(s.angle)) * dist;
      final paint = Paint()..color = s.color.withValues(alpha: opacity);
      if (s.isStar) {
        _drawStar(canvas, pos, s.size, paint);
      } else {
        canvas.drawCircle(pos, s.size * 0.6, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    const points = 4;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? size : size * 0.4;
      final a = (pi / points) * i - pi / 2;
      final p = center + Offset(cos(a), sin(a)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkleBurstPainter oldDelegate) => oldDelegate.t != t;
}
