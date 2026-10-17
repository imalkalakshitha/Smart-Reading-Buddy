import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Result of preprocessing one canvas capture. [hasInk] gates whether
/// inference should run at all (see FreeDrawingRecognizer) — a blank
/// canvas has no "nothing here" class in the model, so it must never
/// reach the interpreter.
class PreprocessResult {
  final Float32List input; // flattened 128*128, row-major, 0.0-1.0
  final bool hasInk;
  // Dark-pixel count / bounding-box area, both from the pre-crop grayscale
  // image (see step 3-4 below) — 0.0 whenever hasInk is false. Resolution-
  // independent (it's a ratio, not a raw pixel count), unlike stroke path
  // length which depends on the canvas's on-screen size — see
  // ScribbleGuard's doc comment for why ink ratio + stroke count are used
  // for scribble rejection instead of a raw path-length threshold.
  final double inkRatio;
  const PreprocessResult({required this.input, required this.hasInk, this.inkRatio = 0.0});
}

/// Turns a raw PNG capture of the drawing canvas into the exact
/// [1,128,128,1] float32 tensor the model was trained on. Every step here
/// mirrors the training-time pipeline — do not simplify to a plain resize,
/// the model will not recognise anything reliably without it.
class DrawingPreprocessor {
  static const int targetSize = 128;
  static const int totalMargin = 20; // total empty margin left around the character on the final canvas
  static const double paddingFraction = 0.10; // bbox padding, relative to the larger bbox dimension
  static const int darkThreshold = 128; // grayscale value below which a pixel counts as "ink" after normalisation
  static const int minInkPixels = 40; // pixel-fallback guard: minimum ink pixel count to consider the canvas non-blank
  static const int minBoundingBoxArea = 30; // pixel-fallback guard: minimum bbox area (width*height) to consider the canvas non-blank
  static const int minContrastRange = 20; // below this raw min/max spread the canvas is uniform (blank) — normalising it would divide by ~1 and stretch noise/background to solid black

  static PreprocessResult process(Uint8List pngBytes) {
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      return PreprocessResult(input: Float32List(targetSize * targetSize), hasInk: false);
    }

    // 1. RGB/RGBA -> grayscale
    final gray = img.grayscale(decoded);

    // 2. min-max contrast normalisation
    int minV = 255, maxV = 0;
    for (final p in gray) {
      final l = p.r.toInt();
      if (l < minV) minV = l;
      if (l > maxV) maxV = l;
    }

    // A blank (or near-uniform) canvas has ~zero raw contrast: minV≈maxV.
    // Normalising that degenerate range used to stretch every pixel to
    // (l-minV)*255/1 == 0 — i.e. solid black — which then registered as
    // "ink" everywhere. Bail out here, before normalising, instead.
    if (maxV - minV < minContrastRange) {
      return PreprocessResult(input: Float32List(targetSize * targetSize), hasInk: false);
    }

    final range = (maxV - minV).clamp(1, 255);
    for (final p in gray) {
      final l = p.r.toInt();
      final nv = (((l - minV) * 255) / range).round().clamp(0, 255);
      p
        ..r = nv
        ..g = nv
        ..b = nv;
    }

    // 3-4. detect dark (ink) pixels and their bounding box
    int minX = gray.width, minY = gray.height, maxX = -1, maxY = -1;
    int inkCount = 0;
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final v = gray.getPixel(x, y).r.toInt();
        if (v < darkThreshold) {
          inkCount++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    final bboxArea = (maxX >= minX && maxY >= minY) ? (maxX - minX + 1) * (maxY - minY + 1) : 0;
    final hasInk = maxX >= minX && maxY >= minY && inkCount >= minInkPixels && bboxArea >= minBoundingBoxArea;
    if (!hasInk) {
      return PreprocessResult(input: Float32List(targetSize * targetSize), hasInk: false);
    }
    final inkRatio = bboxArea > 0 ? inkCount / bboxArea : 0.0;

    // 5. padding, ~10% of the larger bbox dimension
    final bw = maxX - minX + 1;
    final bh = maxY - minY + 1;
    final pad = (paddingFraction * (bw > bh ? bw : bh)).round();
    final cx0 = (minX - pad).clamp(0, gray.width - 1);
    final cy0 = (minY - pad).clamp(0, gray.height - 1);
    final cx1 = (maxX + pad).clamp(0, gray.width - 1);
    final cy1 = (maxY + pad).clamp(0, gray.height - 1);

    // 6. crop
    final cropped = img.copyCrop(gray, x: cx0, y: cy0, width: cx1 - cx0 + 1, height: cy1 - cy0 + 1);

    // 7. resize preserving aspect ratio so the character fits within
    // (targetSize - totalMargin), leaving ~20px total margin once centred
    final maxDim = targetSize - totalMargin;
    final cw = cropped.width, ch = cropped.height;
    final scale = cw > ch ? maxDim / cw : maxDim / ch;
    final rw = (cw * scale).round().clamp(1, maxDim);
    final rh = (ch * scale).round().clamp(1, maxDim);
    final resized = img.copyResize(cropped, width: rw, height: rh, interpolation: img.Interpolation.average);

    // 8. centre on a white 128x128 canvas
    final canvas = img.Image(width: targetSize, height: targetSize);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    final offsetX = ((targetSize - rw) / 2).round();
    final offsetY = ((targetSize - rh) / 2).round();
    img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);

    // 9-11. invert (white bg -> 0, ink -> high), normalise to 0.0-1.0, flatten
    final input = Float32List(targetSize * targetSize);
    int i = 0;
    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        final v = canvas.getPixel(x, y).r.toInt();
        input[i++] = (255 - v) / 255.0;
      }
    }

    return PreprocessResult(input: input, hasInk: true, inkRatio: inkRatio);
  }
}
