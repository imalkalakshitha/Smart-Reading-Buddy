import 'package:flutter/material.dart';

/// Animates stored normalized (0.0-1.0) stroke paths drawing themselves in
/// order, in their recorded direction, then loops — with a leading dot
/// riding the tip of the currently-drawing stroke and a small bounce each
/// time a loop restarts, so it reads as alive rather than a static
/// diagram. Purely illustrative — this is not a tracing surface and
/// nothing here is validated against user input.
class StrokeOrderAnimation extends StatefulWidget {
  final List<List<Offset>> strokes;
  final Color color;
  final Duration strokeDuration;
  final Duration pauseBetweenLoops;

  const StrokeOrderAnimation({
    super.key,
    required this.strokes,
    this.color = Colors.black87,
    this.strokeDuration = const Duration(milliseconds: 700),
    this.pauseBetweenLoops = const Duration(milliseconds: 900),
  });

  @override
  State<StrokeOrderAnimation> createState() => StrokeOrderAnimationState();
}

class StrokeOrderAnimationState extends State<StrokeOrderAnimation> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _bounceController;
  double _lastValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.strokeDuration * widget.strokes.length + widget.pauseBetweenLoops,
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _controller.addListener(_onTick);
    _controller.repeat();
  }

  void _onTick() {
    // repeat() wraps the value from ~1 back to 0 each loop — that wrap is
    // the signal to play a quick bounce, since AnimationController doesn't
    // re-fire AnimationStatus.completed on every lap of repeat().
    if (_lastValue > 0.9 && _controller.value < 0.1) {
      _bounceController.forward(from: 0);
    }
    _lastValue = _controller.value;
  }

  /// Restarts the animation from the beginning — used by the intro
  /// screen's "Replay" button.
  void replay() {
    _controller.forward(from: 0);
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant StrokeOrderAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.strokes != widget.strokes) {
      _controller.duration = widget.strokeDuration * widget.strokes.length + widget.pauseBetweenLoops;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.strokes.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _bounceController]),
      builder: (context, _) {
        final totalStrokeSpan = widget.strokeDuration.inMilliseconds * widget.strokes.length;
        final elapsedMs = (_controller.value * _controller.duration!.inMilliseconds).clamp(0, totalStrokeSpan);
        // Gentle overshoot-then-settle bump, biggest right after a loop
        // restarts and fading out over _bounceController's short run.
        final bounce = 1.0 + (1 - _bounceController.value) * 0.08;
        return Transform.scale(
          scale: _bounceController.isAnimating ? bounce : 1.0,
          child: CustomPaint(
            painter: _StrokeOrderPainter(
              strokes: widget.strokes,
              elapsedMs: elapsedMs.toDouble(),
              strokeDurationMs: widget.strokeDuration.inMilliseconds.toDouble(),
              color: widget.color,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _StrokeOrderPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final double elapsedMs;
  final double strokeDurationMs;
  final Color color;

  _StrokeOrderPainter({
    required this.strokes,
    required this.elapsedMs,
    required this.strokeDurationMs,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset? tip;
    bool tipIsActivelyDrawing = false;

    for (int s = 0; s < strokes.length; s++) {
      final strokeStart = s * strokeDurationMs;
      if (elapsedMs <= strokeStart) break; // this stroke and every one after hasn't started yet

      final strokeProgress = ((elapsedMs - strokeStart) / strokeDurationMs).clamp(0.0, 1.0);
      final points = strokes[s].map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
      if (points.length < 2) continue;

      // Walk the stroke's polyline up to strokeProgress fraction of its
      // total length, so the line draws itself smoothly rather than
      // jumping segment-to-segment.
      double totalLen = 0;
      final segLens = <double>[];
      for (int i = 0; i < points.length - 1; i++) {
        final len = (points[i + 1] - points[i]).distance;
        segLens.add(len);
        totalLen += len;
      }
      if (totalLen == 0) continue;

      final targetLen = totalLen * strokeProgress;
      double coveredLen = 0;
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      Offset tipHere = points[0];
      for (int i = 0; i < segLens.length; i++) {
        final segLen = segLens[i];
        if (coveredLen + segLen <= targetLen) {
          path.lineTo(points[i + 1].dx, points[i + 1].dy);
          tipHere = points[i + 1];
          coveredLen += segLen;
        } else {
          final remaining = targetLen - coveredLen;
          final t = segLen == 0 ? 0.0 : remaining / segLen;
          final partial = Offset.lerp(points[i], points[i + 1], t)!;
          path.lineTo(partial.dx, partial.dy);
          tipHere = partial;
          break;
        }
      }
      canvas.drawPath(path, paint);
      tip = tipHere;
      tipIsActivelyDrawing = strokeProgress < 1.0;
    }

    // Leading dot rides the tip of whichever stroke is actively being
    // drawn right now — gives the animation a visible "pen" to follow,
    // makes it read as alive instead of a static diagram appearing piece
    // by piece.
    if (tip != null && tipIsActivelyDrawing) {
      canvas.drawCircle(tip, 8, Paint()..color = color);
      canvas.drawCircle(tip, 8, Paint()..color = Colors.white.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokeOrderPainter oldDelegate) =>
      oldDelegate.elapsedMs != elapsedMs || oldDelegate.strokes != strokes;
}
