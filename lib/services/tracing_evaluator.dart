import 'package:flutter/material.dart';

// ── Result types ──────────────────────────────────────────────────────────────

class StrokeResult {
  final double accuracy;        // 0–100
  final List<bool> pointFlags;  // true = correct per drawn point

  const StrokeResult({required this.accuracy, required this.pointFlags});
}

// ── Evaluator ─────────────────────────────────────────────────────────────────

class TracingEvaluator {
  final double tolerance; // pixels
  TracingEvaluator({this.tolerance = 25.0});

  /// Expand normalized waypoints to dense pixel points (stepPx apart).
  List<Offset> expandPath(List<Offset> normalized, Size size, {double stepPx = 4.0}) {
    if (normalized.isEmpty) return [];
    final result = <Offset>[];
    for (int i = 0; i < normalized.length - 1; i++) {
      final p0 = Offset(normalized[i].dx * size.width, normalized[i].dy * size.height);
      final p1 = Offset(normalized[i + 1].dx * size.width, normalized[i + 1].dy * size.height);
      final d = (p1 - p0).distance;
      final steps = (d / stepPx).ceil().clamp(1, 200);
      for (int j = 0; j <= steps; j++) {
        result.add(Offset.lerp(p0, p1, j / steps)!);
      }
    }
    return result;
  }

  /// Expand all strokes of a letter template into one flat list of pixel points.
  List<Offset> expandAllStrokes(List<List<Offset>> strokes, Size size) {
    final all = <Offset>[];
    for (final stroke in strokes) {
      all.addAll(expandPath(stroke, size));
    }
    return all;
  }

  /// Evaluate a single drawn path against the template pixel points.
  StrokeResult evaluate(List<Offset> drawnPoints, List<Offset> templatePoints) {
    if (drawnPoints.isEmpty || templatePoints.isEmpty) {
      return const StrokeResult(accuracy: 0, pointFlags: []);
    }
    final flags = drawnPoints.map((p) => _nearest(p, templatePoints) < tolerance).toList();
    final correct = flags.where((f) => f).length;
    final accuracy = (correct / flags.length) * 100.0;
    return StrokeResult(accuracy: accuracy, pointFlags: flags);
  }

  /// Check a single point against template — used for real-time feedback.
  bool isCorrect(Offset point, List<Offset> templatePoints) =>
      _nearest(point, templatePoints) < tolerance;

  double _nearest(Offset point, List<Offset> templatePoints) {
    var minDist = double.infinity;
    for (final tp in templatePoints) {
      final d = (tp - point).distance;
      if (d < minDist) minDist = d;
      if (minDist < tolerance) break; // early exit
    }
    return minDist;
  }
}
