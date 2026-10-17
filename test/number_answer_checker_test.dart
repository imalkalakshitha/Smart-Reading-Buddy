import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reading_buddy/data/numbers_data.dart';
import 'package:smart_reading_buddy/models/pronunciation_result.dart';
import 'package:smart_reading_buddy/services/number_answer_checker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NumbersData', () {
    test('covers 0–100 with English words', () {
      expect(NumbersData.all.length, 101);
      expect(NumbersData.item(0).word, 'zero');
      expect(NumbersData.item(15).word, 'fifteen');
      expect(NumbersData.item(42).word, 'forty-two');
      expect(NumbersData.item(100).word, 'one hundred');
    });

    test('levels', () {
      expect(NumbersData.forLevel(NumbersData.levelZeroToTen).length, 11);
      expect(NumbersData.forLevel(NumbersData.levelElevenToTwenty).length, 10);
      expect(NumbersData.forLevel(NumbersData.levelTens).map((i) => i.value),
          [20, 30, 40, 50, 60, 70, 80, 90, 100]);
      expect(NumbersData.forLevel(NumbersData.levelConfusable).length, 14);
    });
  });

  group('parseNumbers', () {
    test('digits and words', () {
      expect(NumberAnswerChecker.parseNumbers('15'), [15]);
      expect(NumberAnswerChecker.parseNumbers('fifteen'), [15]);
      expect(NumberAnswerChecker.parseNumbers('fifty five'), [55]);
      expect(NumberAnswerChecker.parseNumbers('forty-two'), [42]);
      expect(NumberAnswerChecker.parseNumbers('one hundred'), [100]);
      expect(NumberAnswerChecker.parseNumbers('a hundred'), [100]);
      expect(NumberAnswerChecker.parseNumbers('fifty'), [50]);
      expect(NumberAnswerChecker.parseNumbers('cat'), isEmpty);
    });

    test('parseDigits splits runs for RAN', () {
      expect(NumberAnswerChecker.parseDigits('3 7 1'), [3, 7, 1]);
      expect(NumberAnswerChecker.parseDigits('371 4'), [3, 7, 1, 4]);
      expect(NumberAnswerChecker.parseDigits('three seven one'), [3, 7, 1]);
    });
  });

  group('teen/ty', () {
    test('every confusable pair is detected both ways', () async {
      for (final p in NumbersData.confusablePairs) {
        expect(await NumberAnswerChecker.isTeenTyConfusion(p.teen, p.ty), isTrue,
            reason: '${p.teen}/${p.ty}');
        expect(await NumberAnswerChecker.isTeenTyConfusion(p.ty, p.teen), isTrue,
            reason: '${p.ty}/${p.teen}');
      }
    });

    test('non-pairs are not flagged', () async {
      expect(await NumberAnswerChecker.isTeenTyConfusion(15, 60), isFalse);
      expect(await NumberAnswerChecker.isTeenTyConfusion(15, 16), isFalse);
      expect(await NumberAnswerChecker.isTeenTyConfusion(12, 20), isFalse);
    });

    test('tips', () {
      expect(NumberAnswerChecker.tipFor(15), 'fif-TEEN — stress the end');
      expect(NumberAnswerChecker.tipFor(50), 'FIF-ty — stress the start');
    });
  });

  group('check', () {
    final fifteen = NumbersData.item(15);

    test('digit transcript counts as correct even if scorer said WRONG', () async {
      final v = await NumberAnswerChecker.check(
        target: fifteen,
        result: const PronunciationResult(
            verdict: 'WRONG', stars: 0, xpEarned: 0, rawTranscript: 'fifteen'),
      );
      expect(v.verdict, 'OK');
      expect(v.stars, 3);
    });

    test('"50" for 15 is a teen/ty confusion with a tip', () async {
      final v = await NumberAnswerChecker.check(
        target: fifteen,
        result: const PronunciationResult(
            verdict: 'WRONG', stars: 0, xpEarned: 0, rawTranscript: '50'),
      );
      expect(v.verdict, 'WRONG');
      expect(v.teenTyConfusion, isTrue);
      expect(v.tip, 'fif-TEEN — stress the end');
    });

    test('near-miss word is ALMOST', () async {
      final v = await NumberAnswerChecker.check(
        target: fifteen,
        result: const PronunciationResult(
            verdict: 'WRONG', stars: 0, xpEarned: 0, rawTranscript: 'fiftee'),
      );
      expect(v.verdict, 'ALMOST');
    });
  });

  test('alignDigits counts correct, substitutions, omissions, insertions', () {
    final a = NumberAnswerChecker.alignDigits([1, 2, 3, 4, 5], [1, 9, 3, 5, 6]);
    expect(a.correct, 3); // 1, 3, 5
    expect(a.substitutions, 1); // 2 → 9
    expect(a.omissions, 1); // 4 skipped
    expect(a.insertions, 1); // extra 6
    expect(a.correctAt, [true, false, true, false, true]);
  });
}
