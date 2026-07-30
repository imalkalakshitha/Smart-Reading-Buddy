import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Renders a Sinhala letter offscreen using NotoSerifSinhala font,
/// detects edge pixels, and returns pixel-coordinate sample points.
/// Results are cached by letter + canvas size.
class LetterPathExtractor {
  LetterPathExtractor._();

  static final Map<String, List<Offset>> _cache = {};

  static Future<List<Offset>> extract(String letter, Size size) async {
    final w = size.width.round();
    final h = size.height.round();
    if (w <= 0 || h <= 0) return [];

    final key = '${letter}_${w}_$h';
    if (_cache.containsKey(key)) return _cache[key]!;

    // 1. Render letter offscreen with NotoSerifSinhala
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );

    final fontSize = h * 0.70;
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: ui.TextDirection.ltr,
        fontFamily: 'NotoSerifSinhala',
        fontSize: fontSize,
        fontWeight: ui.FontWeight.w700,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFF000000),
        fontFamily: 'NotoSerifSinhala',
        fontSize: fontSize,
        fontWeight: ui.FontWeight.w700,
      ))
      ..addText(letter);

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: w.toDouble()));

    final dx = ((w - paragraph.longestLine) / 2).clamp(0.0, w.toDouble());
    final dy = ((h - paragraph.height) / 2).clamp(0.0, h.toDouble());
    canvas.drawParagraph(paragraph, Offset(dx, dy));

    final picture = recorder.endRecording();
    ui.Image image;
    try {
      image = await picture.toImage(w, h);
    } catch (_) {
      _cache[key] = const [];
      return const [];
    }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (byteData == null) {
      _cache[key] = const [];
      return const [];
    }

    // 2. Edge detection: opaque pixel (alpha > 100) with at least one
    //    transparent neighbor (alpha < 50) or out-of-bounds neighbor.
    final pixels = byteData.buffer.asUint8List();
    final edges = <Offset>[];

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = (y * w + x) * 4;
        if (pixels[idx + 3] <= 100) continue;

        bool isEdge = false;
        outer:
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            final ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) {
              isEdge = true;
              break outer;
            }
            final nidx = (ny * w + nx) * 4;
            if (pixels[nidx + 3] < 50) {
              isEdge = true;
              break outer;
            }
          }
        }
        if (isEdge) edges.add(Offset(x.toDouble(), y.toDouble()));
      }
    }

    // 3. Sample every 4th edge point to reduce density
    final sampled = <Offset>[];
    for (int i = 0; i < edges.length; i += 4) {
      sampled.add(edges[i]);
    }

    _cache[key] = sampled;
    return sampled;
  }

  static void clearCache() => _cache.clear();
}
