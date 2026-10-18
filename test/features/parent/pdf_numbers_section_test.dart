import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reading_buddy/core/services/numbers/learner_grade.dart';
import 'package:smart_reading_buddy/core/services/numbers/level_config.dart';
import 'package:smart_reading_buddy/features/parent/services/numbers_summary.dart';
import 'package:smart_reading_buddy/features/parent/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final levels = LevelRepository.parse(File('assets/numbers/levels.json').readAsStringSync());
  final practiceLevels = LevelRepository.parse(File('assets/numbers/practice_activities.json').readAsStringSync());

  NumbersSummary summary({bool withData = true}) => NumbersSummaryBuilder.build(
        levels: levels,
        practiceLevels: practiceLevels,
        grade: const LearnerGrade(3),
        bestScores: withData ? const {'g3_basic_1': 9} : const {},
        learningRows: withData
            ? [
                for (var i = 0; i < 10; i++)
                  {
                    'level_id': 'g3_basic_1',
                    'activity_type': 'recognition',
                    'score': i < 9 ? 1 : 0,
                    'timestamp': '2026-10-01T09:0$i:00.000',
                  },
              ]
            : const [],
        practiceRows: withData
            ? [
                {
                  'activity_type': 'number_word',
                  'level_key': 'numbers_confusable',
                  'item': '15',
                  'verdict': 'WRONG',
                  'attempt_number': 1,
                  'teen_ty_error': 1,
                  'timestamp': '2026-10-01T10:00:00.000',
                },
                {
                  'activity_type': 'rapid_digit_naming',
                  'time_ms': 25000,
                  'digits_correct': 45,
                  'error_count': 5,
                  'timestamp': '2026-10-01T11:00:00.000',
                },
              ]
            : const [],
      );

  Future<List<int>> pdf({NumbersSummary? numbers, bool sinhala = false}) => PdfReportService.generate(
        childName: 'Test Child',
        grade: 'Grade 3',
        sinhala: sinhala,
        sessionCount: 2,
        accuracy: 0.75,
        wordsPracticed: 12,
        phonemeStats: const [],
        crossPatterns: const [],
        substitutionPatterns: const [],
        numbers: numbers,
      );

  test('report with a Numbers section builds (English and Sinhala mode)', () async {
    final s = summary();
    expect(s.hasData, isTrue);
    final withNumbers = await pdf(numbers: s);
    final withoutNumbers = await pdf(numbers: summary(withData: false));
    expect(withNumbers, isNotEmpty);
    expect(withNumbers.length, greaterThan(withoutNumbers.length), reason: 'the section adds content');
    expect(await pdf(numbers: s, sinhala: true), isNotEmpty);
  });

  test('when Numbers data can\'t be loaded, the report still builds without it', () async {
    // No database / shared preferences in tests → the loader throws, and
    // generate() must leave the section out instead of failing.
    expect(await pdf(), isNotEmpty);
  });
}
