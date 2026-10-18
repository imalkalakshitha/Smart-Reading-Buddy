import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reading_buddy/features/numbers/services/answer_checker.dart';
import 'package:smart_reading_buddy/core/services/numbers/learner_grade.dart';
import 'package:smart_reading_buddy/core/services/numbers/level_config.dart';
import 'package:smart_reading_buddy/core/services/numbers/level_progress.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_question.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_words.dart';
import 'package:smart_reading_buddy/features/numbers/services/question_generator.dart';

Iterable<List<int>> permutations(List<int> xs) sync* {
  if (xs.length <= 1) {
    yield xs;
    return;
  }
  for (var i = 0; i < xs.length; i++) {
    final rest = [...xs]..removeAt(i);
    for (final p in permutations(rest)) {
      yield [xs[i], ...p];
    }
  }
}

void main() {
  final levels = LevelRepository.parse(File('assets/numbers/levels.json').readAsStringSync());
  const seeds = 40;

  LevelConfig byId(String id) => levels.firstWhere((l) => l.id == id);

  /// Every question from [seeds] seeded sessions of [level].
  List<NumberQuestion> sample(LevelConfig level) => [
        for (var s = 0; s < seeds; s++)
          ...QuestionGenerator(Random(s)).generateSession(level),
      ];

  group('levels.json', () {
    test('24 levels: G3 Basic 7, G3 Advanced 7, G4 Basic 5, G4 Advanced 5', () {
      int count(int g, String t) => levels.where((l) => l.grade == g && l.track == t).length;
      expect(levels.length, 24);
      expect(count(3, Track.basic), 7);
      expect(count(3, Track.advanced), 7);
      expect(count(4, Track.basic), 5);
      expect(count(4, Track.advanced), 5);
    });

    test('ids unique, level numbers sequential, known types, ≤ 4 options', () {
      expect(levels.map((l) => l.id).toSet().length, levels.length);
      for (final g in [3, 4]) {
        for (final t in [Track.basic, Track.advanced]) {
          final track = LevelRepository.forTrack(levels, g, t);
          expect(track.map((l) => l.level), List.generate(track.length, (i) => i + 1));
        }
      }
      for (final l in levels) {
        expect(ActivityType.all, contains(l.activityType), reason: l.id);
        expect(QuestionGenerator.supports(l.activityType), isTrue, reason: l.id);
        expect(l.optionCount, lessThanOrEqualTo(4), reason: l.id);
        expect(l.min, lessThanOrEqualTo(l.max), reason: l.id);
      }
    });

    // The agreed plan, level by level: (activity type, digit counts or
    // range, extra rule) for each grade + track in order.
    test('matches the plan', () {
      void expectTrack(int grade, String track, List<void Function(LevelConfig)> checks) {
        final t = LevelRepository.forTrack(levels, grade, track);
        expect(t.length, checks.length, reason: 'G$grade $track');
        for (var i = 0; i < checks.length; i++) {
          checks[i](t[i]);
        }
      }

      void Function(LevelConfig) is_(String type, {List<int>? digits, int? min, int? max, void Function(LevelConfig)? also}) =>
          (l) {
            expect(l.activityType, type, reason: l.id);
            if (digits != null) expect(l.digitCounts, digits, reason: '${l.id} digit counts');
            if (min != null) expect(l.min, min, reason: '${l.id} min');
            if (max != null) expect(l.max, max, reason: '${l.id} max');
            also?.call(l);
          };

      expectTrack(3, Track.basic, [
        is_(ActivityType.recognition, min: 0, max: 9, also: (l) => expect(l.colourQuantity, isTrue)),
        is_(ActivityType.build, min: 0, max: 9),
        is_(ActivityType.counting, min: 0, max: 9, also: (l) => expect(l.grouped, isFalse)),
        is_(ActivityType.ordering, min: 0, max: 9),
        is_(ActivityType.formation, digits: [2, 3], also: (l) => expect(l.goal, 'either')),
        is_(ActivityType.patterns, min: 0, max: 9),
        is_(ActivityType.calculation, also: (l) {
          expect(l.operations, unorderedEquals(['add', 'subtract']));
          expect(l.answerLimit, 9);
          expect(l.visual, isTrue);
        }),
      ]);
      expectTrack(3, Track.advanced, [
        is_(ActivityType.recognition, digits: [2]),
        is_(ActivityType.build, digits: [2]),
        is_(ActivityType.counting, digits: [2], also: (l) => expect(l.grouped, isTrue)),
        is_(ActivityType.ordering, digits: [2], also: (l) => expect(l.direction, 'either')),
        is_(ActivityType.formation, digits: [4]),
        is_(ActivityType.patterns, min: 10, max: 999),
        is_(ActivityType.calculation, also: (l) {
          expect(l.operations, unorderedEquals(['multiply', 'divide']));
          expect(l.answerMin, 10);
          expect(l.answerLimit, lessThanOrEqualTo(99));
          expect(l.visual, isTrue);
        }),
      ]);
      expectTrack(4, Track.basic, [
        is_(ActivityType.recognition, digits: [3]),
        is_(ActivityType.build, digits: [3]),
        is_(ActivityType.ordering, digits: [3]),
        is_(ActivityType.patterns, min: 10, max: 999, also: (l) => expect(l.display, 'road')),
        is_(ActivityType.placeValue, digits: [2, 3], also: (l) => expect(l.mode, 'place_value')),
      ]);
      expectTrack(4, Track.advanced, [
        is_(ActivityType.recognition, digits: [3, 4]),
        is_(ActivityType.build, digits: [3, 4]),
        is_(ActivityType.counting, digits: [3], also: (l) {
          expect(l.grouped, isTrue);
          expect(l.placeValueChart, isTrue);
        }),
        is_(ActivityType.ordering, digits: [3, 4], also: (l) => expect(l.direction, 'either')),
        is_(ActivityType.placeValue, digits: [3, 4], also: (l) => expect(l.mode, 'comparison')),
      ]);
    });
  });

  group('generator constraints (every level, $seeds sessions each)', () {
    for (final level in levels) {
      test(level.id, () {
        for (var s = 0; s < seeds; s++) {
          final session = QuestionGenerator(Random(s)).generateSession(level);
          expect(session.length, 10);
          for (final q in session) {
            expect(QuestionGenerator.validate(q, level), isNull, reason: '${level.id} ${q.key}');
          }
          // Small ranges (0–9) may relax this — see repetition tests.
          if (level.max - level.min >= 30) {
            expect(session.map((q) => q.key).toSet().length, 10,
                reason: 'no repeats within a session');
          }
        }
      });
    }
  });

  group('Phase 1 rules', () {
    test('options: unique, answer once, shuffled position', () {
      for (final level in levels) {
        final qs = sample(level);
        final positions = <int>{};
        var checked = false;
        for (final q in qs) {
          final pair = switch (q) {
            RecognitionQuestion() => (q.answer, q.options),
            PatternQuestion() => (q.answer, q.options),
            CountingQuestion() => (q.answer, q.options),
            CalculationQuestion() => (q.answer, q.options),
            PlaceValueQuestion() => (q.answer, q.options),
            _ => null,
          };
          if (pair == null) continue;
          checked = true;
          final (answer, options) = pair;
          expect(options.toSet().length, options.length);
          expect(options.where((o) => o == answer).length, 1);
          expect(options.length, lessThanOrEqualTo(4));
          positions.add(options.indexOf(answer));
        }
        if (checked) {
          expect(positions.length, level.optionCount,
              reason: '${level.id}: answer should appear in every position');
        }
      }
    });

    test('distractors are meaningful when possible (digit swap / ±1 on a digit)', () {
      for (final q in sample(byId('g4_basic_1')).cast<RecognitionQuestion>()) {
        final meaningful = QuestionGenerator.meaningfulDistractors(q.answer).toSet();
        expect(q.options.where((o) => o != q.answer).every(meaningful.contains), isTrue,
            reason: '${q.answer} → ${q.options}');
      }
    });

    test('meaningfulDistractors: swaps and ±1, never a leading zero', () {
      expect(QuestionGenerator.meaningfulDistractors(47), containsAll([74, 37, 57, 46, 48]));
      final forty = QuestionGenerator.meaningfulDistractors(40);
      expect(forty, isNot(contains(4)), reason: '"04" has a leading zero');
      expect(forty.every((n) => '$n'.length == 2), isTrue);
      expect(QuestionGenerator.meaningfulDistractors(105).every((n) => n >= 100), isTrue);
      expect(QuestionGenerator.meaningfulDistractors(7), [6, 8]);
    });

    test('mixed digit counts: 3 & 4-digit levels produce both', () {
      final lengths = sample(byId('g4_adv_1')).cast<RecognitionQuestion>().map((q) => '${q.answer}'.length).toSet();
      expect(lengths, {3, 4});
      final ordering = sample(byId('g4_adv_4')).cast<OrderingQuestion>();
      expect(ordering.any((q) => q.items.map((n) => '$n'.length).toSet().length == 2), isTrue,
          reason: 'some trains mix 3- and 4-digit numbers');
    });

    test('build: no leading zero, tiles can build the answer, not laid out ready-made', () {
      for (final level in levels.where((l) => l.activityType == ActivityType.build)) {
        var readyMade = 0;
        final qs = sample(level).cast<BuildQuestion>();
        for (final q in qs) {
          if (q.digitCount > 1) expect(q.answerDigits.first, isNot(0));
          expect(q.digitCount, inInclusiveRange('${level.min}'.length, '${level.max}'.length));
          final rest = [...q.tiles];
          for (final d in q.answerDigits) {
            expect(rest.remove(d), isTrue);
          }
          if (q.tiles.take(q.digitCount).toList().toString() == q.answerDigits.toString()) {
            readyMade++;
          }
        }
        expect(readyMade, lessThan(qs.length ~/ 20 + 1), reason: level.id);
      }
    });

    test('ordering: unique items, never pre-sorted, direction honoured', () {
      for (final level in levels.where((l) => l.activityType == ActivityType.ordering)) {
        final dirs = <bool>{};
        for (final q in sample(level).cast<OrderingQuestion>()) {
          expect(q.items.toSet().length, q.items.length);
          expect(q.items, isNot(equals(q.answer)));
          dirs.add(q.descending);
        }
        switch (level.direction) {
          case 'ascending':
            expect(dirs, {false}, reason: level.id);
          case 'descending':
            expect(dirs, {true}, reason: level.id);
          default:
            expect(dirs, {true, false}, reason: level.id);
        }
      }
    });

    test('patterns: exact step, never negative, within range, gap not first', () {
      for (final level in levels.where((l) => l.activityType == ActivityType.patterns)) {
        final stepsSeen = <int>{};
        for (final q in sample(level).cast<PatternQuestion>()) {
          for (var i = 1; i < q.sequence.length; i++) {
            expect(q.sequence[i] - q.sequence[i - 1], q.step);
          }
          expect(q.sequence.every((v) => v >= 0 && v >= level.min && v <= level.max), isTrue);
          expect(q.missingIndex, greaterThan(0));
          expect(q.options.every((o) => o >= 0), isTrue);
          if (q.step.abs() >= 5) expect(q.sequence.first % q.step.abs(), 0);
          expect(q.road, level.display == 'road');
          stepsSeen.add(q.step);
        }
        expect(stepsSeen, level.steps.toSet(), reason: '${level.id}: every configured step used');
      }
    });
  });

  group('Phase 2: counting', () {
    test('ungrouped 0–9 objects, all object kinds used', () {
      final level = byId('g3_basic_3');
      final qs = sample(level).cast<CountingQuestion>();
      expect(qs.every((q) => q.answer >= 0 && q.answer <= 9 && !q.grouped), isTrue);
      expect(qs.map((q) => q.object).toSet(), level.objects.toSet());
    });

    test('grouped: answer = hundreds × 100 + tens × 10 + ones, ≥ 10', () {
      for (final id in ['g3_adv_3', 'g4_adv_3']) {
        final level = byId(id);
        for (final q in sample(level).cast<CountingQuestion>()) {
          expect(q.grouped, isTrue);
          expect(q.answer, greaterThanOrEqualTo(10));
          expect(q.hundreds * 100 + q.tens * 10 + q.ones, q.answer);
          expect(q.placeValueChart, level.placeValueChart);
          expect(level.contains(q.answer), isTrue);
        }
      }
    });
  });

  group('Phase 2: formation', () {
    test('highest / lowest from the digits, 0 never first', () {
      expect(FormationQuestion.answerFor([3, 0, 1, 7], highest: true), [7, 3, 1, 0]);
      expect(FormationQuestion.answerFor([3, 0, 1, 7], highest: false), [1, 0, 3, 7]);
      expect(FormationQuestion.answerFor([0, 5], highest: false), [5, 0]);
      expect(FormationQuestion.answerFor([4, 2, 9], highest: false), [2, 4, 9]);
    });

    test('generated: unique digits, valid answer, not pre-arranged, both goals', () {
      for (final level in levels.where((l) => l.activityType == ActivityType.formation)) {
        final goals = <bool>{};
        final lengths = <int>{};
        var sawZeroLowest = false;
        for (final q in sample(level).cast<FormationQuestion>()) {
          expect(q.digits.toSet().length, q.digits.length);
          expect(q.answerDigits.first, isNot(0));
          expect(q.digits, isNot(equals(q.answerDigits)));
          // Brute force: the best of every arrangement without a leading 0.
          final valid = permutations(q.digits).where((p) => p.first != 0).map((p) => int.parse(p.join()));
          expect(q.answer, q.highest ? valid.reduce(max) : valid.reduce(min));
          goals.add(q.highest);
          lengths.add(q.digits.length);
          if (!q.highest && q.digits.contains(0)) sawZeroLowest = true;
        }
        expect(goals, {true, false}, reason: level.id);
        expect(lengths, level.digitCounts!.toSet(), reason: level.id);
        expect(sawZeroLowest, isTrue, reason: '${level.id}: the 0 case should come up');
      }
    });
  });

  group('Phase 2: calculations (arithmetic rules)', () {
    test('G3 Basic add/subtract: sum ≤ limit, never negative, 1-digit answers', () {
      final level = byId('g3_basic_7');
      final qs = sample(level).cast<CalculationQuestion>();
      expect(qs.map((q) => q.op).toSet(), {Operation.add, Operation.subtract});
      for (final q in qs) {
        if (q.op == Operation.add) expect(q.a + q.b, lessThanOrEqualTo(level.answerLimit));
        if (q.op == Operation.subtract) expect(q.a, greaterThanOrEqualTo(q.b));
        expect(q.answer, inInclusiveRange(0, 9));
        expect(q.a, greaterThanOrEqualTo(1));
        expect(q.b, greaterThanOrEqualTo(1));
      }
    });

    test('G3 Advanced multiply/divide: no remainder, 2-digit results', () {
      final level = byId('g3_adv_7');
      final qs = sample(level).cast<CalculationQuestion>();
      expect(qs.map((q) => q.op).toSet(), {Operation.multiply, Operation.divide});
      for (final q in qs) {
        expect(q.answer, inInclusiveRange(10, 99));
        expect(q.answer, inInclusiveRange(level.answerMin, level.answerLimit));
        if (q.op == Operation.divide) {
          expect(q.a % q.b, 0, reason: '${q.a} ÷ ${q.b}');
          expect(q.b * q.answer, q.a, reason: 'dividend = divisor × quotient');
          expect(q.b, inInclusiveRange(2, level.maxFactor));
        } else {
          expect(q.a, inInclusiveRange(2, level.maxFactor));
          expect(q.b, inInclusiveRange(1, level.maxGroupSize));
        }
      }
    });

    test('validate rejects broken arithmetic', () {
      final basic = byId('g3_basic_7');
      final adv = byId('g3_adv_7');
      String? v(CalculationQuestion q, LevelConfig l) => QuestionGenerator.validate(q, l);
      expect(v(const CalculationQuestion(op: Operation.add, a: 5, b: 6, options: [11, 10, 12]), basic), isNotNull,
          reason: 'sum over limit');
      expect(v(const CalculationQuestion(op: Operation.subtract, a: 3, b: 5, options: [-2, 2, 8]), basic), isNotNull,
          reason: 'negative');
      expect(v(const CalculationQuestion(op: Operation.divide, a: 25, b: 2, options: [12, 13, 11, 14]), adv), isNotNull,
          reason: 'remainder');
      expect(v(const CalculationQuestion(op: Operation.multiply, a: 3, b: 2, options: [6, 5, 7, 8]), adv), isNotNull,
          reason: 'answer below 2 digits');
      expect(v(const CalculationQuestion(op: Operation.add, a: 4, b: 3, options: [7, 6, 8]), basic), isNull);
      expect(v(const CalculationQuestion(op: Operation.divide, a: 24, b: 2, options: [12, 11, 13, 10]), adv), isNull);
    });
  });

  group('Phase 2: place value & comparison', () {
    test('place value: answer is the digit in that place; only real places asked', () {
      final level = byId('g4_basic_5');
      final qs = sample(level).cast<PlaceValueQuestion>();
      expect(qs.map((q) => '${q.number}'.length).toSet(), {2, 3});
      expect(qs.map((q) => q.place).toSet(), Place.values.toSet());
      for (final q in qs) {
        final s = '${q.number}';
        final expected = switch (q.place) {
          Place.hundreds => s[s.length - 3],
          Place.tens => s[s.length - 2],
          Place.ones => s[s.length - 1],
        };
        expect('${q.answer}', expected);
        if (s.length == 2) expect(q.place, isNot(Place.hundreds));
        expect(q.options.every((o) => o >= 0 && o <= 9), isTrue);
      }
      expect(const PlaceValueQuestion(number: 347, place: Place.hundreds, options: []).answer, 3);
      expect(const PlaceValueQuestion(number: 347, place: Place.tens, options: []).answer, 4);
      expect(const PlaceValueQuestion(number: 347, place: Place.ones, options: []).answer, 7);
    });

    test('comparison: two different numbers, both asks, close pairs common', () {
      final level = byId('g4_adv_5');
      final qs = sample(level).cast<ComparisonQuestion>();
      expect(qs.map((q) => q.askBigger).toSet(), {true, false});
      var close = 0;
      for (final q in qs) {
        expect(q.a, isNot(q.b));
        expect(q.answer, q.askBigger ? max(q.a, q.b) : min(q.a, q.b));
        if (QuestionGenerator.meaningfulDistractors(q.a).contains(q.b)) close++;
      }
      expect(close, greaterThan(qs.length ~/ 3), reason: 'mostly confusable pairs');
    });
  });

  group('repetition control', () {
    test('keys from recent sessions are avoided when the range allows', () {
      final level = byId('g4_basic_1'); // 900 numbers
      final first = QuestionGenerator(Random(1)).generateSession(level);
      final second = QuestionGenerator(Random(2)).generateSession(level);
      final avoid = {...first.map((q) => q.key), ...second.map((q) => q.key)};
      for (var s = 3; s < 23; s++) {
        final next = QuestionGenerator(Random(s)).generateSession(level, avoidKeys: avoid);
        expect(next.any((q) => avoid.contains(q.key)), isFalse);
      }
    });

    test('a tiny range relaxes instead of failing', () {
      final level = byId('g3_basic_1'); // 0–9
      final avoid = {for (var n = 0; n <= 9; n++) 'recognition:$n'};
      final session = QuestionGenerator(Random(5)).generateSession(level, avoidKeys: avoid);
      expect(session.length, 10);
    });

    test('unknown activity types are refused', () {
      final bogus = LevelConfig.fromJson({
        'id': 'x', 'grade': 3, 'track': 'basic', 'level': 1, 'title': 'x', 'activityType': 'juggling',
      });
      expect(() => QuestionGenerator().generateSession(bogus), throwsUnsupportedError);
    });
  });

  group('answer checker', () {
    test('recognition and patterns', () {
      const q = RecognitionQuestion(answer: 47, options: [74, 47, 46]);
      expect(NumberAnswerCheck.isCorrect(q, 47), isTrue);
      expect(NumberAnswerCheck.isCorrect(q, 74), isFalse);
      expect(NumberAnswerCheck.isCorrect(q, '47'), isFalse);
      const p = PatternQuestion(sequence: [5, 10, 15, 20, 25], missingIndex: 2, step: 5, options: [15, 16, 20]);
      expect(NumberAnswerCheck.isCorrect(p, 15), isTrue);
      expect(NumberAnswerCheck.isCorrect(p, 20), isFalse);
    });

    test('recognition with colouring is two steps', () {
      const q = RecognitionQuestion(answer: 6, options: [6, 5, 7], colourQuantity: true);
      expect(NumberAnswerCheck.evaluate(q, 5), AnswerResult.wrong);
      expect(NumberAnswerCheck.evaluate(q, 6), AnswerResult.stepDone);
      expect(NumberAnswerCheck.evaluate(q, const QuantityResponse(5)), AnswerResult.wrong);
      expect(NumberAnswerCheck.evaluate(q, const QuantityResponse(6)), AnswerResult.correct);
      expect(q.followUpPrompt, 'Now colour 6 stars');
    });

    test('build and formation compare digits, so a leading zero never passes', () {
      const q = BuildQuestion(answer: 47, tiles: [4, 7, 0, 3]);
      expect(NumberAnswerCheck.isCorrect(q, [4, 7]), isTrue);
      expect(NumberAnswerCheck.isCorrect(q, [7, 4]), isFalse);
      expect(NumberAnswerCheck.isCorrect(q, [0, 4, 7]), isFalse);
      const f = FormationQuestion(digits: [0, 5, 2], highest: false);
      expect(NumberAnswerCheck.isCorrect(f, [2, 0, 5]), isTrue);
      expect(NumberAnswerCheck.isCorrect(f, [0, 2, 5]), isFalse);
    });

    test('ordering both directions', () {
      const asc = OrderingQuestion(items: [30, 5, 12, 8], descending: false);
      expect(NumberAnswerCheck.isCorrect(asc, [5, 8, 12, 30]), isTrue);
      expect(NumberAnswerCheck.isCorrect(asc, [30, 12, 8, 5]), isFalse);
      const desc = OrderingQuestion(items: [30, 5, 12, 8], descending: true);
      expect(NumberAnswerCheck.isCorrect(desc, [30, 12, 8, 5]), isTrue);
    });

    test('calculation, place value, comparison, counting', () {
      expect(NumberAnswerCheck.isCorrect(
          const CalculationQuestion(op: Operation.divide, a: 24, b: 2, options: [12, 11]), 12), isTrue);
      expect(NumberAnswerCheck.isCorrect(
          const PlaceValueQuestion(number: 347, place: Place.tens, options: [3, 4, 7]), 4), isTrue);
      expect(NumberAnswerCheck.isCorrect(
          const ComparisonQuestion(a: 47, b: 74, askBigger: false), 47), isTrue);
      expect(NumberAnswerCheck.isCorrect(
          const ComparisonQuestion(a: 47, b: 74, askBigger: false), 74), isFalse);
      expect(NumberAnswerCheck.isCorrect(
          const CountingQuestion(answer: 34, options: [34, 43], object: 'blocks', grouped: true), 43), isFalse);
    });
  });

  group('unlock rules', () {
    final g3basic = LevelRepository.forTrack(levels, 3, Track.basic);

    test('first level open, the rest locked', () {
      final s = LevelProgressRules.states(g3basic, {}, trackUnlocked: true);
      expect(s[g3basic.first.id], LevelState.unlocked);
      for (final l in g3basic.skip(1)) {
        expect(s[l.id], LevelState.locked);
      }
    });

    test('8/10 unlocks the next level; 7/10 does not', () {
      var s = LevelProgressRules.states(g3basic, {g3basic[0].id: 7}, trackUnlocked: true);
      expect(s[g3basic[1].id], LevelState.locked);
      s = LevelProgressRules.states(g3basic, {g3basic[0].id: 8}, trackUnlocked: true);
      expect(s[g3basic[0].id], LevelState.passed);
      expect(s[g3basic[1].id], LevelState.unlocked);
    });

    test('Advanced opens only when every Basic level is passed', () {
      final allButLast = {for (final l in g3basic.take(g3basic.length - 1)) l.id: 10};
      expect(LevelProgressRules.trackComplete(g3basic, allButLast), isFalse);
      expect(LevelProgressRules.trackComplete(g3basic, {for (final l in g3basic) l.id: 8}), isTrue);
      final g3adv = LevelRepository.forTrack(levels, 3, Track.advanced);
      final locked = LevelProgressRules.states(g3adv, {}, trackUnlocked: false);
      expect(locked.values.where((v) => v == LevelState.unlocked), isEmpty);
    });
  });

  test('grade comes from the profile, defaulting to Grade 3', () {
    expect(LearnerGrade.fromProfile('grade4').grade, 4);
    expect(LearnerGrade.fromProfile('grade3').defaulted, isFalse);
    final missing = LearnerGrade.fromProfile('');
    expect(missing.grade, 3);
    expect(missing.defaulted, isTrue);
  });

  test('number words for TTS', () {
    expect(NumberWords.of(7), 'seven');
    expect(NumberWords.of(47), 'forty-seven');
    expect(NumberWords.of(300), 'three hundred');
    expect(NumberWords.of(347), 'three hundred forty-seven');
    expect(NumberWords.of(4012), 'four thousand twelve');
  });
}
