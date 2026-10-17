import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reading_buddy/features/numbers/data/number_sentence_data.dart';
import 'package:smart_reading_buddy/features/numbers/data/numbers_data.dart';
import 'package:smart_reading_buddy/features/numbers/services/answer_checker.dart';
import 'package:smart_reading_buddy/features/numbers/services/level_config.dart';
import 'package:smart_reading_buddy/features/numbers/services/level_progress.dart';
import 'package:smart_reading_buddy/features/numbers/services/match_game.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_question.dart';
import 'package:smart_reading_buddy/features/numbers/services/question_generator.dart';

void main() {
  final levels = LevelRepository.parse(File('assets/numbers/practice_activities.json').readAsStringSync());
  const seeds = 40;

  LevelConfig byId(String id) => levels.firstWhere((l) => l.id == id);
  List<LevelConfig> track(String t) => LevelRepository.forTrack(levels, 0, t);

  List<NumberQuestion> sample(LevelConfig level) => [
        for (var s = 0; s < seeds; s++) ...QuestionGenerator(Random(s)).generateSession(level),
      ];

  group('practice_activities.json', () {
    test('3 activities × 3 levels, sequential, all playable', () {
      expect(levels.length, 9);
      expect(levels.map((l) => l.id).toSet().length, 9);
      for (final t in [PracticeTrack.spellWords, PracticeTrack.numberMatch, PracticeTrack.readAnswer]) {
        final ls = track(t);
        expect(ls.map((l) => l.level), [1, 2, 3], reason: t);
        expect(ls.every(LevelProgressRules.isPlayable), isTrue, reason: t);
      }
    });

    test('matches the plan', () {
      final spell = track(PracticeTrack.spellWords);
      expect([for (final l in spell) (l.min, l.max, l.step)], [(0, 10, 1), (11, 20, 1), (20, 100, 10)]);
      final match = track(PracticeTrack.numberMatch);
      expect(match.map((l) => l.pairsPerBoard), [3, 4, 6]);
      final read = track(PracticeTrack.readAnswer);
      expect([for (final l in read) (l.min, l.max)], [(1, 5), (1, 10), (10, 20)]);
      expect(read.every((l) => l.optionCount == 4), isTrue);
    });
  });

  group('generator constraints (every Spell / Read level, $seeds sessions each)', () {
    for (final level in levels.where((l) => l.activityType != ActivityType.numberMatch)) {
      test(level.id, () {
        for (var s = 0; s < seeds; s++) {
          final session = QuestionGenerator(Random(s)).generateSession(level);
          expect(session.length, 10);
          for (final q in session) {
            expect(QuestionGenerator.validate(q, level), isNull, reason: '${level.id} ${q.key}');
          }
        }
      });
    }
  });

  group('Spell Number Words', () {
    test('word is the English word; tiles = its letters + distractors', () {
      for (final level in track(PracticeTrack.spellWords)) {
        final seen = <int>{};
        for (final q in sample(level).cast<SpellWordQuestion>()) {
          expect(q.word, NumbersData.wordFor(q.value));
          expect((q.value - level.min) % level.step, 0);
          expect(q.tiles.length, q.letters.length + level.distractorLetters);
          final rest = [...q.tiles];
          for (final l in q.letters) {
            expect(rest.remove(l), isTrue, reason: '${q.word}: missing "$l"');
          }
          seen.add(q.value);
        }
        final expected = {for (var v = level.min; v <= level.max; v += level.step) v};
        expect(seen, expected, reason: '${level.id}: every value comes up');
      }
    });

    test('teen words get a "y" tile, ty words an "e" tile', () {
      for (final q in sample(byId('spell_2')).cast<SpellWordQuestion>()) {
        if (q.word.endsWith('teen')) {
          expect(q.tiles.where((t) => t == 'y').length, greaterThanOrEqualTo(1), reason: q.word);
        }
      }
      for (final q in sample(byId('spell_3')).cast<SpellWordQuestion>()) {
        if (q.word.endsWith('ty')) {
          final eInWord = q.letters.where((l) => l == 'e').length;
          expect(q.tiles.where((t) => t == 'e').length, greaterThan(eInWord), reason: q.word);
        }
      }
    });

    test('tiles are not laid out ready-made', () {
      final qs = sample(byId('spell_1')).cast<SpellWordQuestion>();
      final readyMade = qs.where((q) => q.tiles.take(q.letters.length).join() == q.letters.join()).length;
      expect(readyMade, lessThan(qs.length ~/ 20 + 1));
    });

    test('"one hundred" has a word gap, not a space tile', () {
      const q = SpellWordQuestion(value: 100, word: 'one hundred', tiles: []);
      expect(q.letters.join(), 'onehundred');
      expect(q.gapsAfter, {2});
      final qs = sample(byId('spell_3')).cast<SpellWordQuestion>().where((q) => q.value == 100);
      expect(qs, isNotEmpty);
      expect(qs.every((q) => !q.tiles.contains(' ')), isTrue);
    });

    test('checker compares letters in order', () {
      const q = SpellWordQuestion(value: 7, word: 'seven', tiles: ['n', 'e', 's', 'v', 'e', 'b']);
      expect(NumberAnswerCheck.isCorrect(q, ['s', 'e', 'v', 'e', 'n']), isTrue);
      expect(NumberAnswerCheck.isCorrect(q, ['s', 'e', 'v', 'n', 'e']), isFalse);
      expect(NumberAnswerCheck.isCorrect(q, 7), isFalse);
    });

    test('validate rejects broken spelling questions', () {
      final level = byId('spell_1');
      expect(QuestionGenerator.validate(
          const SpellWordQuestion(value: 7, word: 'seven', tiles: ['s', 'e', 'v', 'e', 'x', 'y']), level), isNotNull,
          reason: 'tiles cannot spell the word');
      expect(QuestionGenerator.validate(
          const SpellWordQuestion(value: 7, word: 'sevin', tiles: ['s', 'e', 'v', 'i', 'n', 'b', 'd']), level), isNotNull,
          reason: 'wrong word');
      expect(QuestionGenerator.validate(
          const SpellWordQuestion(value: 7, word: 'seven', tiles: ['s', 'e', 'v', 'e', 'n', 'b', 'd']), level), isNull);
    });
  });

  group('Read & Answer', () {
    test('answer is computed from the sentence parts; all numbers in range', () {
      for (final level in track(PracticeTrack.readAnswer)) {
        for (final q in sample(level).cast<ReadAnswerQuestion>()) {
          final expected = switch (q.ask) {
            SentenceAsk.total => q.a + (q.b ?? 0),
            SentenceAsk.first => q.a,
            SentenceAsk.second => q.b,
          };
          expect(q.answer, expected);
          expect(q.numbers.every((n) => n >= level.min && n <= level.max), isTrue, reason: q.sentence);
          expect(q.answer, inInclusiveRange(level.min, level.max), reason: q.sentence);
          for (final n in q.numbers) {
            expect(q.sentence, contains('$n '), reason: 'numbers are written as digits');
          }
          expect(q.options.length, 4);
          expect(q.options.toSet().length, 4);
          expect(q.options.where((o) => o == q.answer).length, 1);
          expect(q.options.every((o) => o >= 1), isTrue);
        }
      }
    });

    test('every template comes up; totals only when they fit the range', () {
      for (final level in track(PracticeTrack.readAnswer)) {
        final qs = sample(level).cast<ReadAnswerQuestion>().toList();
        expect(qs.map((q) => q.template).toSet(), SentenceTemplate.values.toSet(), reason: level.id);
        final totals = qs.where((q) => q.template == SentenceTemplate.colours && q.ask == SentenceAsk.total);
        if (level.id == 'read_1') expect(totals, isNotEmpty, reason: 'small numbers can ask the total');
        if (level.id == 'read_3') expect(totals, isEmpty, reason: '10–20 + 10–20 never fits in 10–20');
      }
    });

    test('the other number in the sentence is a likely distractor', () {
      final qs = sample(byId('read_2')).cast<ReadAnswerQuestion>().where((q) => q.b != null).toList();
      final withOther = qs.where((q) => q.numbers.where((n) => n != q.answer).every(q.options.contains)).length;
      expect(withOther, greaterThan(qs.length * 3 ~/ 4));
    });

    test('sentence and question text', () {
      const q = ReadAnswerQuestion(
        template: SentenceTemplate.colours,
        name: 'Sam',
        object: NumberObjectFixture.ball,
        colour1: 'red',
        colour2: 'blue',
        a: 3,
        b: 1,
        ask: SentenceAsk.second,
        options: [1, 3, 4, 2],
      );
      expect(q.sentence, 'Sam has 3 red balls and 1 blue ball.');
      expect(q.question, 'How many blue balls?');
      expect(q.answer, 1);
      expect(q.speaksItself, isTrue);
      expect(NumberAnswerCheck.isCorrect(q, 1), isTrue);
      expect(NumberAnswerCheck.isCorrect(q, 3), isFalse);
    });

    test('validate rejects equal numbers and out-of-range totals', () {
      final level = byId('read_1');
      expect(QuestionGenerator.validate(
          const ReadAnswerQuestion(
              template: SentenceTemplate.colours, name: 'Sam', object: NumberObjectFixture.ball,
              colour1: 'red', colour2: 'blue', a: 2, b: 2, ask: SentenceAsk.first, options: [2, 1, 3, 4]),
          level), isNotNull);
      expect(QuestionGenerator.validate(
          const ReadAnswerQuestion(
              template: SentenceTemplate.colours, name: 'Sam', object: NumberObjectFixture.ball,
              colour1: 'red', colour2: 'blue', a: 4, b: 3, ask: SentenceAsk.total, options: [7, 4, 3, 6]),
          level), isNotNull, reason: '7 is outside 1–5');
    });
  });

  group('Number Match boards', () {
    test('board sizes: 10 pairs, full boards, never a 1-pair board', () {
      expect(MatchBoardGenerator.boardSizes(3), [3, 3, 2, 2]);
      expect(MatchBoardGenerator.boardSizes(4), [4, 4, 2]);
      expect(MatchBoardGenerator.boardSizes(6), [6, 4]);
      for (var p = 2; p <= 6; p++) {
        final sizes = MatchBoardGenerator.boardSizes(p);
        expect(sizes.fold(0, (a, b) => a + b), 10);
        expect(sizes.every((s) => s >= 2 && s <= p), isTrue);
      }
    });

    test('every pair: two cards, different forms, allowed forms, distinct values per board', () {
      for (final level in track(PracticeTrack.numberMatch)) {
        final formsSeen = <CardForm>{};
        for (var s = 0; s < seeds; s++) {
          final boards = MatchBoardGenerator(Random(s)).generateSession(level);
          final sizes = MatchBoardGenerator.boardSizes(level.pairsPerBoard);
          expect(boards.map((b) => b.pairCount), sizes);
          for (var i = 0; i < boards.length; i++) {
            expect(MatchBoardGenerator.validate(boards[i], level, sizes[i]), isNull, reason: level.id);
            expect(boards[i].values.length, sizes[i], reason: 'distinct values on a board');
            formsSeen.addAll(boards[i].cards.map((c) => c.form));
          }
        }
        expect(formsSeen, level.forms.map(CardForm.values.byName).toSet(), reason: level.id);
      }
    });

    test('values from recent sessions are used last', () {
      final level = byId('match_2'); // 1–10, 4 pairs per board
      final avoid = {for (var v = 1; v <= 5; v++) 'match:$v:digit-word'};
      for (var s = 0; s < 20; s++) {
        final first = MatchBoardGenerator(Random(s)).generateSession(level, avoidKeys: avoid).first;
        expect(first.values.every((v) => v > 5), isTrue, reason: '${first.values}');
      }
    });
  });

  group('MatchGame scoring', () {
    // Cards: 0:1-digit 1:2-digit 2:1-word 3:2-word
    const board = MatchBoard([
      MatchCard(1, CardForm.digit),
      MatchCard(2, CardForm.digit),
      MatchCard(1, CardForm.word),
      MatchCard(2, CardForm.word),
    ]);

    test('exploring unseen cards is never a mistake', () {
      final g = MatchGame(board);
      expect(g.flip(0).outcome, FlipOutcome.firstUp);
      final r = g.flip(1); // 1 vs 2, nothing seen before
      expect(r.outcome, FlipOutcome.mismatch);
      expect(r.avoidable, isFalse);
      expect(g.flip(2).outcome, FlipOutcome.firstUp);
      expect(g.flip(0).outcome, FlipOutcome.match);
      expect(g.pairScore(1), 1);
    });

    test('missing a partner that was already seen costs that pair its point', () {
      final g = MatchGame(board);
      g.flip(0);
      g.flip(1); // sees 1-digit and 2-digit
      g.flip(3); // 2-word: its partner (card 1) was seen …
      final r = g.flip(2); // … but the child picks card 2 instead
      expect(r.outcome, FlipOutcome.mismatch);
      expect(r.avoidable, isTrue);
      expect(g.avoidableMistakes[2], 1);
      g.flip(3);
      g.flip(1);
      g.flip(0);
      g.flip(2);
      expect(g.done, isTrue);
      expect(g.pairScore(2), 0);
      expect(g.pairScore(1), 1);
      expect(g.tries[2], 2);
    });

    test('ignored flips: same card twice, matched cards', () {
      final g = MatchGame(board);
      g.flip(0);
      expect(g.flip(0).outcome, FlipOutcome.ignored);
      g.flip(2); // match
      expect(g.flip(0).outcome, FlipOutcome.ignored);
      expect(g.flip(9).outcome, FlipOutcome.ignored);
    });

    test('pair keys are stable for repetition control', () {
      expect(board.pairKey(1), 'match:1:digit-word');
    });
  });

  test('each activity is its own unlock chain', () {
    for (final t in [PracticeTrack.spellWords, PracticeTrack.numberMatch, PracticeTrack.readAnswer]) {
      final ls = track(t);
      var s = LevelProgressRules.states(ls, {}, trackUnlocked: true);
      expect(s[ls[0].id], LevelState.unlocked);
      expect(s[ls[1].id], LevelState.locked);
      s = LevelProgressRules.states(ls, {ls[0].id: 8}, trackUnlocked: true);
      expect(s[ls[1].id], LevelState.unlocked);
    }
  });
}

/// Test fixture objects.
class NumberObjectFixture {
  static const ball = NumberObject('ball', 'balls');
}
