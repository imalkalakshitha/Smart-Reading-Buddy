import 'dart:ui';

/// Primary empty-canvas check, based on the recorded stroke points rather
/// than pixel analysis — cheaper (no image decode needed) and more
/// reliable, since it can't be fooled by whatever a degenerate/blank
/// image happens to contrast-stretch to (see DrawingPreprocessor's
/// pixel-level fallback for that failure mode).
///
/// [points] is the same null-separated stroke list the canvas
/// CustomPainter draws from: a null marks a break between strokes.
class CanvasInkGuard {
  static const int minStrokePoints = 6;
  static const double minPathLength = 15.0; // logical pixels

  static bool hasInk(List<Offset?> points) {
    int count = 0;
    double length = 0;
    Offset? prev;
    for (final p in points) {
      if (p == null) {
        prev = null;
        continue;
      }
      count++;
      if (prev != null) length += (p - prev).distance;
      prev = p;
    }
    return count >= minStrokePoints && length >= minPathLength;
  }
}
