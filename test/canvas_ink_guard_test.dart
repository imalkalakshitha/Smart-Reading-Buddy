import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reading_buddy/services/canvas_ink_guard.dart';

void main() {
  group('CanvasInkGuard', () {
    test('empty point list has no ink', () {
      expect(CanvasInkGuard.hasInk([]), isFalse);
    });

    test('a single tap (no drag) has no ink', () {
      expect(CanvasInkGuard.hasInk([const Offset(10, 10), null]), isFalse);
    });

    test('a short jitter below the minimum path length has no ink', () {
      final points = [
        const Offset(10, 10),
        const Offset(11, 10),
        const Offset(12, 11),
        null,
      ];
      expect(CanvasInkGuard.hasInk(points), isFalse);
    });

    test('a real drawn stroke has ink', () {
      final points = <Offset?>[];
      for (int i = 0; i <= 40; i++) {
        points.add(Offset(i.toDouble(), 0));
      }
      points.add(null);
      expect(CanvasInkGuard.hasInk(points), isTrue);
    });
  });
}
