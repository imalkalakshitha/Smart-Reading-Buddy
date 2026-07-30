import 'package:flutter/material.dart';
import '../services/tracing_evaluator.dart';
import '../services/letter_path_extractor.dart';

// ── Private types ──────────────────────────────────────────────────────────────

class _DrawnSegment {
  final List<Offset> points;
  final List<bool> flags; // true = correct per point
  _DrawnSegment({required this.points, required this.flags});
}

// ── Widget ─────────────────────────────────────────────────────────────────────

class TracingCanvas extends StatefulWidget {
  /// Normalized (0–1) stroke waypoints — used for English letters.
  final List<List<Offset>> templateStrokes;

  /// Called with updated accuracy (0–100) after each pan event.
  final ValueChanged<double>? onAccuracyChanged;

  /// Distance tolerance for correct tracing (logical pixels).
  final double tolerance;

  /// When set, the canvas extracts the template path from the NotoSerifSinhala
  /// font instead of using [templateStrokes].
  final String? letter;

  /// Must be true when [letter] is a Sinhala character so font extraction runs.
  final bool isSinhala;

  const TracingCanvas({
    super.key,
    required this.templateStrokes,
    this.onAccuracyChanged,
    this.tolerance = 25.0,
    this.letter,
    this.isSinhala = false,
  });

  @override
  State<TracingCanvas> createState() => TracingCanvasState();
}

class TracingCanvasState extends State<TracingCanvas>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────

  final List<_DrawnSegment> _segments = [];
  List<Offset> _activePoints = [];
  List<bool> _activeFlags = [];

  late final TracingEvaluator _evaluator;

  /// Pixel coords from normalized [templateStrokes] (English path).
  List<Offset> _templatePixels = [];

  /// Pixel coords extracted from the Sinhala font glyph (replaces _templatePixels
  /// when isSinhala is true and extraction succeeds).
  List<Offset>? _extractedPoints;

  Size _canvasSize = Size.zero;

  /// Guards against launching multiple concurrent extractions for the same letter.
  bool _extractionRunning = false;

  double _accuracy = 0.0;
  int _totalDrawn = 0;
  int _totalCorrect = 0;

  // Hint animation
  late final AnimationController _hintCtrl;
  late final Animation<double> _hintAnim;
  bool _hintVisible = false;

  // ── Effective template ─────────────────────────────────────────────────────

  /// The point list used for isCorrect() evaluation and hint animation.
  List<Offset> get _effectiveTemplate => _extractedPoints ?? _templatePixels;

  // ── Public API ─────────────────────────────────────────────────────────────

  double get accuracy => _accuracy;

  void clearCanvas() {
    setState(() {
      _segments.clear();
      _activePoints.clear();
      _activeFlags.clear();
      _accuracy = 0.0;
      _totalDrawn = 0;
      _totalCorrect = 0;
    });
    // Do NOT call onAccuracyChanged here: clearCanvas() is called from
    // didUpdateWidget() which fires during the parent's build pass.
    // Calling the parent's setState from inside a build triggers an assertion.
    // Every caller already resets accuracy in its own setState.
  }

  void showHint() {
    _hintCtrl.forward(from: 0);
    setState(() => _hintVisible = true);
    _hintCtrl.addStatusListener(_onHintDone);
  }

  void _onHintDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _hintVisible = false);
      });
      _hintCtrl.removeStatusListener(_onHintDone);
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _evaluator = TracingEvaluator(tolerance: widget.tolerance);
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _hintAnim = CurvedAnimation(parent: _hintCtrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(TracingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final strokesChanged = oldWidget.templateStrokes != widget.templateStrokes;
    final letterChanged = oldWidget.letter != widget.letter;
    if ((strokesChanged || letterChanged) && _canvasSize != Size.zero) {
      _extractionRunning = false;
      _rebuildTemplate(_canvasSize);
      clearCanvas();
    }
  }

  @override
  void dispose() {
    _hintCtrl.dispose();
    super.dispose();
  }

  // ── Template ───────────────────────────────────────────────────────────────

  void _rebuildTemplate(Size size) {
    _canvasSize = size;
    _templatePixels = _evaluator.expandAllStrokes(widget.templateStrokes, size);
    _extractedPoints = null;
    if (widget.isSinhala && widget.letter != null && !_extractionRunning) {
      _loadSinhalaTemplate(size);
    }
  }

  Future<void> _loadSinhalaTemplate(Size size) async {
    _extractionRunning = true;
    final letter = widget.letter!;
    try {
      final pts = await LetterPathExtractor.extract(letter, size);
      if (mounted && _canvasSize == size && widget.letter == letter && pts.isNotEmpty) {
        setState(() => _extractedPoints = pts);
      }
    } finally {
      _extractionRunning = false;
    }
  }

  // ── Gesture handlers ───────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    _activePoints = [d.localPosition];
    _activeFlags = [_evaluator.isCorrect(d.localPosition, _effectiveTemplate)];
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final pt = d.localPosition;
    final correct = _evaluator.isCorrect(pt, _effectiveTemplate);
    _activePoints.add(pt);
    _activeFlags.add(correct);
    _totalDrawn++;
    if (correct) _totalCorrect++;
    final newAcc = _totalDrawn > 0 ? (_totalCorrect / _totalDrawn) * 100.0 : 0.0;
    if ((newAcc - _accuracy).abs() > 0.5) {
      _accuracy = newAcc;
      widget.onAccuracyChanged?.call(_accuracy);
    }
    setState(() {});
  }

  void _onPanEnd(DragEndDetails _) {
    if (_activePoints.isNotEmpty) {
      _segments.add(_DrawnSegment(
        points: List.from(_activePoints),
        flags: List.from(_activeFlags),
      ));
      _activePoints = [];
      _activeFlags = [];
    }
    setState(() {});
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _canvasSize && size != Size.zero) {
          // Direct mutation is safe here: _canvasSize/_templatePixels only
          // affect CustomPainter.paint(), not the widget tree, so no
          // recursive-setState / assertion issues.
          _rebuildTemplate(size);
        }
        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: AnimatedBuilder(
            animation: _hintAnim,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _TracingPainter(
                templateStrokes: widget.templateStrokes,
                extractedPoints: _extractedPoints,
                canvasSize: size,
                segments: _segments,
                activePoints: _activePoints,
                activeFlags: _activeFlags,
                hintProgress: _hintVisible ? _hintAnim.value : 0.0,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _TracingPainter extends CustomPainter {
  final List<List<Offset>> templateStrokes;
  final List<Offset>? extractedPoints;
  final Size canvasSize;
  final List<_DrawnSegment> segments;
  final List<Offset> activePoints;
  final List<bool> activeFlags;
  final double hintProgress; // 0–1

  const _TracingPainter({
    required this.templateStrokes,
    required this.extractedPoints,
    required this.canvasSize,
    required this.segments,
    required this.activePoints,
    required this.activeFlags,
    required this.hintProgress,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  Offset _toPixel(Offset n) =>
      Offset(n.dx * canvasSize.width, n.dy * canvasSize.height);

  List<Offset> _expandStroke(List<Offset> stroke, {double step = 5}) {
    final out = <Offset>[];
    for (int i = 0; i < stroke.length - 1; i++) {
      final p0 = _toPixel(stroke[i]);
      final p1 = _toPixel(stroke[i + 1]);
      final d = (p1 - p0).distance;
      final steps = (d / step).ceil().clamp(1, 200);
      for (int j = 0; j <= steps; j++) {
        out.add(Offset.lerp(p0, p1, j / steps)!);
      }
    }
    if (stroke.isNotEmpty) out.add(_toPixel(stroke.last));
    return out;
  }

  // ── Drawing ────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (canvasSize == Size.zero) return;
    _drawTemplate(canvas);
    if (extractedPoints == null) _drawStrokeNumbers(canvas);
    _drawSegments(canvas);
    _drawActive(canvas);
    if (hintProgress > 0) _drawHint(canvas);
  }

  void _drawTemplate(Canvas canvas) {
    final dotPaint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..style = PaintingStyle.fill;

    if (extractedPoints != null) {
      // Draw dots at font-extracted pixel positions
      for (final pt in extractedPoints!) {
        canvas.drawCircle(pt, 3, dotPaint);
      }
      return;
    }

    // Draw dots along normalized template strokes
    for (final stroke in templateStrokes) {
      final pts = _expandStroke(stroke);
      for (int i = 0; i < pts.length; i += 3) {
        canvas.drawCircle(pts[i], 3, dotPaint);
      }
    }
  }

  void _drawStrokeNumbers(Canvas canvas) {
    for (int s = 0; s < templateStrokes.length; s++) {
      if (templateStrokes[s].isEmpty) continue;
      final start = _toPixel(templateStrokes[s].first);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${s + 1}',
          style: const TextStyle(
            color: Color(0xFF9B59B6),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final arrowPaint = Paint()..color = const Color(0xFF9B59B6);
      final arrowPath = Path()
        ..moveTo(start.dx, start.dy - 8)
        ..lineTo(start.dx - 5, start.dy - 16)
        ..lineTo(start.dx + 5, start.dy - 16)
        ..close();
      canvas.drawPath(arrowPath, arrowPaint);

      final badge = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(start.dx, start.dy - 22),
          width: 18,
          height: 18,
        ),
        const Radius.circular(9),
      );
      canvas.drawRRect(badge, arrowPaint);
      textPainter.paint(
        canvas,
        Offset(
          start.dx - textPainter.width / 2,
          start.dy - 22 - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawSegments(Canvas canvas) {
    for (final seg in segments) {
      _drawColoredPath(canvas, seg.points, seg.flags);
    }
  }

  void _drawActive(Canvas canvas) {
    if (activePoints.isNotEmpty) {
      _drawColoredPath(canvas, activePoints, activeFlags);
    }
  }

  void _drawColoredPath(Canvas canvas, List<Offset> pts, List<bool> flags) {
    if (pts.length < 2) return;
    for (int i = 0; i < pts.length - 1; i++) {
      final correct = i < flags.length ? flags[i] : false;
      final paint = Paint()
        ..color = correct ? const Color(0xFF2ECC71) : const Color(0xFFEF476F)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(pts[i], pts[i + 1], paint);
    }
  }

  void _drawHint(Canvas canvas) {
    // Use extracted points for Sinhala; fall back to expanded normalized strokes.
    final List<Offset> allPts;
    if (extractedPoints != null && extractedPoints!.isNotEmpty) {
      allPts = extractedPoints!;
    } else {
      if (templateStrokes.isEmpty) return;
      final tmp = <Offset>[];
      for (final stroke in templateStrokes) {
        tmp.addAll(_expandStroke(stroke));
      }
      if (tmp.isEmpty) return;
      allPts = tmp;
    }

    final idx = ((hintProgress * (allPts.length - 1)).round())
        .clamp(0, allPts.length - 1);
    final pos = allPts[idx];

    // Glow
    canvas.drawCircle(
      pos,
      22,
      Paint()
        ..color = const Color(0xFF2ECC71).withOpacity(0.35)
        ..style = PaintingStyle.fill,
    );

    // Core dot
    canvas.drawCircle(
      pos,
      12,
      Paint()
        ..color = const Color(0xFF2ECC71)
        ..style = PaintingStyle.fill,
    );

    // White centre
    canvas.drawCircle(
      pos,
      5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Trail
    if (idx > 0) {
      final trailPaint = Paint()
        ..color = const Color(0xFF2ECC71).withOpacity(0.55)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = (idx - 20).clamp(0, idx); i < idx; i++) {
        final next = i + 1 < allPts.length ? i + 1 : i;
        canvas.drawLine(allPts[i], allPts[next], trailPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_TracingPainter old) => true;
}
