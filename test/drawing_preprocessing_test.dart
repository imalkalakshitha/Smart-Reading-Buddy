import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_reading_buddy/services/drawing_preprocessing.dart';

Uint8List _blankCanvas() {
  final canvas = img.Image(width: 300, height: 300);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  return Uint8List.fromList(img.encodePng(canvas));
}

Uint8List _canvasWithStroke() {
  final canvas = img.Image(width: 300, height: 300);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.drawLine(canvas, x1: 60, y1: 150, x2: 240, y2: 150, color: img.ColorRgb8(0, 0, 0), thickness: 10);
  return Uint8List.fromList(img.encodePng(canvas));
}

void main() {
  group('DrawingPreprocessor empty-canvas guard', () {
    test('a completely blank canvas reports no ink', () {
      final result = DrawingPreprocessor.process(_blankCanvas());
      expect(result.hasInk, isFalse);
    });

    test('a canvas with an actual drawn stroke reports ink', () {
      final result = DrawingPreprocessor.process(_canvasWithStroke());
      expect(result.hasInk, isTrue);
    });
  });
}
