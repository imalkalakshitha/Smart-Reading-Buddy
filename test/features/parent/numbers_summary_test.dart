import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reading_buddy/core/services/numbers/learner_grade.dart';
import 'package:smart_reading_buddy/core/services/numbers/level_config.dart';
import 'package:smart_reading_buddy/features/parent/services/numbers_summary.dart';

void main() {
  final levels = LevelRepository.parse(File('assets/numbers/levels.json').readAsStringSync());
  final practiceLevels = LevelRepository.parse(File('assets/numbers/practice_activities.json').readAsStringSync());
  const grade3 = LearnerGrade(3);

  var seq = 0;
  String ts([int? minute]) => DateTime(2026, 10, 1, 9, minute ?? seq++).toIso8601String();

  Map<String, Object?> learn(String levelId, String type, int score, {String? at}) => {
        'level_id': levelId,
        'activity_type': type,
        'score': score,
        'session_id': 's',
        'timestamp': at ?? ts(),
      };

  Map<String, Object?> word(String levelKey, String item, String verdict,
          {int attempt = 1, int teenTy = 0, String? at}) =>
      {
        'activity_type': 'number_word',
        'level_key': levelKey,
        'item': item,
        'verdict': verdict,
        'attempt_number': attempt,
        'teen_ty_error': teenTy,
        'timestamp': at ?? ts(),
      };

  Map<String, Object?> ran(DateTime date, int ms, int digits, int errors) => {
        'activity_type': 'rapid_digit_naming',
        'time_ms': ms,
        'digits_correct': digits,
        'error_count': errors,
        'timestamp': date.toIso8601String(),
      };

  NumbersSummary build({
    Map<String, int> best = const {},
    List<Map<String, Object?>> learning = const [],
    List<Map<String, Object?>> practice = const [],
    LearnerGrade grade = grade3,
  }) =>
      NumbersSummaryBuilder.build(
        levels: levels,
        practiceLevels: practiceLevels,
        grade: grade,
        bestScores: best,
        learningRows: learning,
        practiceRows: practice,
      );

  test('no activity yet: empty state, first level open, the rest locked', () {
    final s = build();
    expect(s.hasData, isFalse);
    expect(s.overall.rate, isNull);
    expect((s.basicPassed, s.basicTotal), (0, 7));
    expect((s.advancedPassed, s.advancedTotal), (0, 7));
    expect(s.basic.first.status, NumberLevelStatus.notStarted);
    expect(s.basic.skip(1).every((r) => r.status == NumberLevelStatus.locked), isTrue);
    expect(s.advanced.every((r) => r.status == NumberLevelStatus.locked), isTrue);
    expect(s.practice.keys, ['spell_words', 'number_match', 'read_answer']);
    expect(s.latestRan, isNull);
    expect(s.needsPractice, isEmpty);
  });

  test('level statuses: passed, in progress, locked; grade from the profile', () {
    final s = build(
      best: {'g3_basic_1': 9, 'g3_basic_2': 6},
      learning: [learn('g3_basic_1', 'recognition', 1), learn('g3_basic_2', 'build', 0)],
    );
    expect(s.basic[0].status, NumberLevelStatus.passed);
    expect(s.basic[0].best, 9);
    expect(s.basic[1].status, NumberLevelStatus.inProgress);
    expect(s.basic[1].best, 6);
    expect(s.basic[2].status, NumberLevelStatus.locked);
    expect(s.basicPassed, 1);

    final g4 = build(grade: const LearnerGrade(4));
    expect(g4.basic.every((r) => r.level.grade == 4), isTrue);
    expect((g4.basicTotal, g4.advancedTotal), (5, 5));
  });

  test('Advanced opens only when every Basic level is passed', () {
    final allBasic = {for (var i = 1; i <= 7; i++) 'g3_basic_$i': 8};
    final s = build(best: allBasic);
    expect((s.basicPassed, s.basicTotal), (7, 7));
    expect(s.advanced.first.status, NumberLevelStatus.notStarted);
    expect(s.advanced[1].status, NumberLevelStatus.locked);
  });

  test('accuracy is first-try: Number Learning score + Number Words first attempt', () {
    final s = build(
      learning: [
        learn('g3_basic_1', 'recognition', 1),
        learn('g3_basic_1', 'recognition', 1),
        learn('g3_basic_1', 'recognition', 0),
        learn('g3_basic_2', 'build', 1),
        learn('g3_basic_2', 'build', 0),
        learn('spell_1', 'spell_word', 1),
      ],
      practice: [
        word('numbers_0_10', '7', 'OK'),
        word('numbers_0_10', '9', 'WRONG'),
        word('numbers_0_10', '9', 'OK', attempt: 2), // retries don't count
      ],
    );
    expect(s.hasData, isTrue);
    expect((s.overall.correct, s.overall.total), (5, 8)); // (2 + 1 + 1) + 1 of 6 + 2
    expect(s.byActivity.keys, ['recognition', 'build', 'spell_word'], reason: 'parent order, tried types only');
    expect(s.byActivity['recognition']!.rate, closeTo(2 / 3, 1e-9));
    expect(s.byActivity['build']!.rate, 0.5);
    expect(s.numberWordsByLevel['numbers_0_10']!.rate, 0.5);
  });

  test('-teen/-ty confusions: counted both ways round, top pairs first', () {
    final s = build(practice: [
      word('numbers_confusable', '15', 'WRONG', teenTy: 1),
      word('numbers_confusable', '15', 'WRONG', teenTy: 1, attempt: 2),
      word('numbers_confusable', '50', 'WRONG', teenTy: 1),
      word('numbers_confusable', '14', 'WRONG', teenTy: 1),
      word('numbers_confusable', '16', 'OK'),
    ]);
    expect(s.teenTyConfusions, 4);
    expect(s.confusedPairs.map((p) => (p.label, p.count)), [('15 / 50', 3), ('14 / 40', 1)]);
  });

  test('RAN: digits per second over time, latest result', () {
    final s = build(practice: [
      ran(DateTime(2026, 10, 3), 20000, 48, 2),
      ran(DateTime(2026, 10, 1), 25000, 45, 5),
    ]);
    expect(s.hasData, isTrue, reason: 'RAN alone counts as activity');
    expect(s.overall.total, 0, reason: 'RAN is speed, not part of accuracy');
    expect(s.ran.map((r) => r.date.day), [1, 3], reason: 'oldest first');
    expect(s.ran.first.digitsPerSecond, closeTo(1.8, 1e-9));
    expect(s.latestRan!.digitsPerSecond, closeTo(2.4, 1e-9));
    expect((s.latestRan!.totalMs, s.latestRan!.errors), (20000, 2));
  });

  test('needs practice: lowest recent accuracy, enough answers, below 100 %', () {
    final rows = <Map<String, Object?>>[
      // Patterns level: 2 / 6 → 33 %
      for (var i = 0; i < 6; i++) learn('g3_basic_6', 'patterns', i < 2 ? 1 : 0),
      // Recognition: 6 / 6 → perfect, never listed
      for (var i = 0; i < 6; i++) learn('g3_basic_1', 'recognition', 1),
      // Build: only 4 answers → not judged yet
      for (var i = 0; i < 4; i++) learn('g3_basic_2', 'build', 0),
      // Counting: 5 early misses, then 20 right → recent window is 100 %
      for (var i = 0; i < 25; i++) learn('g3_basic_3', 'counting', i < 5 ? 0 : 1),
      // Ordering: 4 / 6 → 67 %
      for (var i = 0; i < 6; i++) learn('g3_basic_4', 'ordering', i < 4 ? 1 : 0),
      // Formation: 5 / 6 → 83 %
      for (var i = 0; i < 6; i++) learn('g3_basic_5', 'formation', i < 5 ? 1 : 0),
    ];
    final words = [for (var i = 0; i < 5; i++) word('numbers_confusable', '1$i', i == 0 ? 'OK' : 'WRONG')];
    final s = build(learning: rows, practice: words);
    expect(s.needsPractice.map((n) => n.label), [
      'Number Words · Teen or Ty?', // 20 %
      'Patterns · Missing numbers', // 33 %
      'Ordering · Number train', // 67 %
    ]);
    expect(s.needsPractice.first.recent.rate, closeTo(0.2, 1e-9));
  });

  test('a defaulted grade is reported', () {
    final s = build(grade: LearnerGrade.fromProfile(''));
    expect(s.grade, 3);
    expect(s.gradeDefaulted, isTrue);
  });
}
