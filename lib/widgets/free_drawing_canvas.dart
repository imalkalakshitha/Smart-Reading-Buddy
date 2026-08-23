import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/canvas_ink_guard.dart';

/// Reusable blank drawing canvas: white background, black ~10px rounded
/// strokes. Used by Letter Level.
class FreeDrawingCanvas extends StatefulWidget {
  const FreeDrawingCanvas({super.key});

  @override
  State<FreeDrawingCanvas> createState() => FreeDrawingCanvasState();
}

class FreeDrawingCanvasState extends State<FreeDrawingCanvas> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<Offset?> _points = [];

  bool get hasInk => CanvasInkGuard.hasInk(_points);
  List<Offset?> get strokePoints => List.unmodifiable(_points);

  void clear() => setState(() => _points.clear());

  Future<Uint8List> capturePng() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: RepaintBoundary(
        key: _boundaryKey,
        child: GestureDetector(
          onPanUpdate: (details) {
            final box = _boundaryKey.currentContext!.findRenderObject() as RenderBox;
            setState(() => _points.add(box.globalToLocal(details.globalPosition)));
          },
          onPanEnd: (_) => setState(() => _points.add(null)),
          child: Container(
            color: Colors.white,
            width: double.infinity,
            height: double.infinity,
            child: CustomPaint(
              painter: _DrawingPainter(_points),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<Offset?> points;
  _DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
