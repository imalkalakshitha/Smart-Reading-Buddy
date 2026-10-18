import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reading_buddy/features/numbers/services/ran_row_tracker.dart';

void main() {
  group('RanTranscript.toDigits', () {
    test('the same fast digits, however the recogniser writes them', () {
      for (final t in [
        '864',
        '8 6 4',
        'eight six four',
        'eight hundred sixty-four',
        'eight hundred sixty four',
        'eight hundred and sixty four',
        'Eight, six, four.',
      ]) {
        expect(RanTranscript.toDigits(t), [8, 6, 4], reason: t);
      }
    });

    test('compound and teen forms split into digits', () {
      expect(RanTranscript.toDigits('twenty five'), [2, 5]);
      expect(RanTranscript.toDigits('fourteen'), [1, 4]);
      expect(RanTranscript.toDigits('sixty four seven'), [6, 4, 7]);
      expect(RanTranscript.toDigits('three thousand four hundred twelve'), [3, 4, 1, 2]);
      expect(RanTranscript.toDigits('4,512'), [4, 5, 1, 2]);
    });

    test('mixed digits and words, and common mishearings', () {
      expect(RanTranscript.toDigits('3 seven 91 two'), [3, 7, 9, 1, 2]);
      expect(RanTranscript.toDigits('for to ate tree won'), [4, 2, 8, 3, 1]);
      expect(RanTranscript.toDigits('five um six'), [5, 6], reason: 'unknown words are skipped');
    });

    test('a full row of ten single digits', () {
      expect(
        RanTranscript.toDigits('one two three four five six seven eight nine one'),
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 1],
      );
      expect(RanTranscript.toDigits(null), isEmpty);
      expect(RanTranscript.toDigits(''), isEmpty);
    });
  });

  group('RanRowTracker', () {
    test('text is appended across recogniser restarts, not reset', () {
      final t = RanRowTracker(expectedCount: 10);
      t.onResult('3', isFinal: false, nowMs: 100);
      t.onResult('3 7', isFinal: false, nowMs: 300);
      t.onResult('3 7 1', isFinal: false, nowMs: 500);
      t.commit(); // Android ended the session early → restart
      t.onResult('4', isFinal: false, nowMs: 900);
      t.onResult('4 9', isFinal: true, nowMs: 1100);
      t.commit(); // 'done' after the final result must not duplicate
      expect(t.transcript, '3 7 1 4 9');
      expect(t.digits, [3, 7, 1, 4, 9]);
    });

    test('partials within one session replace each other', () {
      final t = RanRowTracker(expectedCount: 10);
      t.onResult('eight', isFinal: false, nowMs: 100);
      t.onResult('eight six', isFinal: false, nowMs: 200);
      t.onResult('864', isFinal: true, nowMs: 300);
      expect(t.digits, [8, 6, 4]);
    });

    test('ends after 2 s of silence; the wait is not counted in the time', () {
      final t = RanRowTracker(expectedCount: 10);
      t.onResult('3 7', isFinal: false, nowMs: 1000);
      t.onResult('3 7 1 4', isFinal: false, nowMs: 2600);
      expect(t.check(4500), isNull, reason: 'only 1.9 s quiet');
      expect(t.check(4600), RanRowEnd.silence);
      expect(t.elapsedMs, 1600, reason: 'first partial (1000) → last speech (2600)');
    });

    test('ends as soon as every digit is recognised', () {
      final t = RanRowTracker(expectedCount: 10);
      t.onResult('1 2 3 4 5 6 7 8 9', isFinal: false, nowMs: 500);
      expect(t.check(600), isNull);
      t.onResult('1 2 3 4 5 6 7 8 9 1', isFinal: false, nowMs: 700);
      expect(t.check(700), RanRowEnd.allDigits);
    });

    test('never ends on silence before a digit was heard', () {
      final t = RanRowTracker(expectedCount: 10);
      expect(t.check(60000), isNull);
      t.onResult('um', isFinal: false, nowMs: 100);
      expect(t.check(60000), isNull);
    });

    test('loud sound keeps the row going and sets its end time', () {
      final t = RanRowTracker(expectedCount: 10);
      t.onSoundLevel(0, 0); // quiet room
      t.onSoundLevel(10, 50); // speech
      t.onResult('5 2', isFinal: false, nowMs: 1000);
      t.onSoundLevel(8, 2500); // still speaking, no new text yet
      t.onSoundLevel(1, 2600); // quiet again
      expect(t.check(4000), isNull, reason: 'speech heard at 2.5 s');
      expect(t.check(4500), RanRowEnd.silence);
      expect(t.elapsedMs, 1500, reason: 'first partial (1000) → last loud sound (2500)');
    });

    test('noisy levels can\'t keep a row open: 4 s with no new text ends it', () {
      final t = RanRowTracker(expectedCount: 10);
      t.onSoundLevel(0, 0);
      t.onResult('6', isFinal: false, nowMs: 500);
      for (var ms = 600; ms <= 4600; ms += 100) {
        t.onSoundLevel(10, ms); // constant loud noise
      }
      expect(t.check(4400), isNull);
      expect(t.check(4500), RanRowEnd.silence);
    });

    test('text arriving after the mic stops counts, but not toward the time', () {
      final t = RanRowTracker(expectedCount: 10);
      t.onResult('2 5', isFinal: false, nowMs: 1000);
      t.onResult('2 5 8', isFinal: false, nowMs: 1800);
      t.onResult('2 5 8 3', isFinal: true, nowMs: 4200, timing: false);
      expect(t.digits, [2, 5, 8, 3]);
      expect(t.elapsedMs, 800);
    });
  });
}
