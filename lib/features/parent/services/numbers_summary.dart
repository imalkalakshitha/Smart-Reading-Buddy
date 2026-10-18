import 'package:smart_reading_buddy/core/dao/number_learning_dao.dart';
import 'package:smart_reading_buddy/core/dao/number_practice_dao.dart';
import 'package:smart_reading_buddy/core/data/numbers_data.dart';
import 'package:smart_reading_buddy/core/models/local_storage.dart';
import 'package:smart_reading_buddy/core/services/numbers/learner_grade.dart';
import 'package:smart_reading_buddy/core/services/numbers/level_config.dart';
import 'package:smart_reading_buddy/core/services/numbers/level_progress.dart';

/// A level's status for the parent view.
enum NumberLevelStatus { passed, inProgress, notStarted, locked, comingSoon }

class NumberLevelRow {
  final LevelConfig level;
  final NumberLevelStatus status;

  /// Best score of a completed session (out of 10), if any.
  final int? best;
  final int attempts;

  const NumberLevelRow({required this.level, required this.status, this.best, this.attempts = 0});
}

/// First-try correct answers out of answered questions.
class AccuracyStat {
  final int correct;
  final int total;

  const AccuracyStat(this.correct, this.total);

  static const empty = AccuracyStat(0, 0);

  double? get rate => total == 0 ? null : correct / total;

  AccuracyStat operator +(AccuracyStat o) => AccuracyStat(correct + o.correct, total + o.total);
}

/// A -teen/-ty pair and how often the child mixed it up (e.g. 15/50 × 3).
class ConfusedPair {
  final int teen;
  final int ty;
  final int count;

  const ConfusedPair(this.teen, this.ty, this.count);

  String get label => '$teen / $ty';
}

/// One finished Rapid Digit Naming grid.
class RanResult {
  final DateTime date;
  final int totalMs;
  final int digitsCorrect;
  final int errors;

  const RanResult({required this.date, required this.totalMs, required this.digitsCorrect, required this.errors});

  /// Correct digits per second — the same measure the RAN results screen
  /// shows to the child.
  double get digitsPerSecond => totalMs > 0 ? digitsCorrect / (totalMs / 1000) : 0;
}

/// An activity level with low recent accuracy.
class PracticeNeed {
  final String label;
  final AccuracyStat recent;

  const PracticeNeed(this.label, this.recent);
}

/// Everything the parent sees about one child's Numbers work.
class NumbersSummary {
  final int grade;
  final bool gradeDefaulted;
  final List<NumberLevelRow> basic;
  final List<NumberLevelRow> advanced;

  /// Numbers hub practice activities, keyed by PracticeTrack.
  final Map<String, List<NumberLevelRow>> practice;

  /// Number Learning + hub practice + Number Words, first-try.
  final AccuracyStat overall;

  /// Keyed by ActivityType, in [NumbersSummaryBuilder.activityOrder] order;
  /// only activity types the child has tried.
  final Map<String, AccuracyStat> byActivity;

  /// Number Words first-try accuracy per level key (NumbersData levels).
  final Map<String, AccuracyStat> numberWordsByLevel;
  final int teenTyConfusions;

  /// Most-confused -teen/-ty pairs, most frequent first (top 3).
  final List<ConfusedPair> confusedPairs;

  /// Finished RAN grids, oldest first.
  final List<RanResult> ran;

  /// Up to 3 levels with the lowest recent accuracy (below 100 %).
  final List<PracticeNeed> needsPractice;

  const NumbersSummary({
    required this.grade,
    required this.gradeDefaulted,
    required this.basic,
    required this.advanced,
    required this.practice,
    required this.overall,
    required this.byActivity,
    required this.numberWordsByLevel,
    required this.teenTyConfusions,
    required this.confusedPairs,
    required this.ran,
    required this.needsPractice,
  });

  int _passed(List<NumberLevelRow> rows) => rows.where((r) => r.status == NumberLevelStatus.passed).length;

  int get basicPassed => _passed(basic);
  int get basicTotal => basic.length;
  int get advancedPassed => _passed(advanced);
  int get advancedTotal => advanced.length;

  RanResult? get latestRan => ran.isEmpty ? null : ran.last;

  /// False when the child hasn't done any Numbers activity yet.
  bool get hasData => overall.total > 0 || ran.isNotEmpty;
}

/// Pure summary calculations (no storage) — see [NumbersSummaryLoader] for
/// reading the data.
///
/// Accuracy is "first try", matching how Numbers sessions score: a Number
/// Learning / hub practice question counts as correct when its saved
/// `score` is 1 (answered right with no wrong try); a Number Words item
/// counts from its first attempt row (`attempt_number` 1) and is correct
/// when that attempt's verdict was OK. Rapid Digit Naming is a speed
/// measure, so it's reported separately and not part of accuracy.
class NumbersSummaryBuilder {
  NumbersSummaryBuilder._();

  /// Parent-facing activity order and labels.
  static const activityOrder = [
    ActivityType.recognition,
    ActivityType.build,
    ActivityType.counting,
    ActivityType.ordering,
    ActivityType.formation,
    ActivityType.patterns,
    ActivityType.calculation,
    ActivityType.placeValue,
    ActivityType.spellWord,
    ActivityType.numberMatch,
    ActivityType.readAnswer,
  ];

  static const activityLabels = {
    ActivityType.recognition: 'Recognition',
    ActivityType.build: 'Build',
    ActivityType.counting: 'Counting',
    ActivityType.ordering: 'Ordering',
    ActivityType.formation: 'Formation',
    ActivityType.patterns: 'Patterns',
    ActivityType.calculation: 'Calculations',
    ActivityType.placeValue: 'Place Value / Comparison',
    ActivityType.spellWord: 'Spell Number Words',
    ActivityType.numberMatch: 'Number Match',
    ActivityType.readAnswer: 'Read & Answer',
  };

  /// Short chart axis labels, same order as [activityOrder].
  static const activityShortLabels = {
    ActivityType.recognition: 'Rec',
    ActivityType.build: 'Build',
    ActivityType.counting: 'Count',
    ActivityType.ordering: 'Order',
    ActivityType.formation: 'Form',
    ActivityType.patterns: 'Patt',
    ActivityType.calculation: 'Calc',
    ActivityType.placeValue: 'PV',
    ActivityType.spellWord: 'Spell',
    ActivityType.numberMatch: 'Match',
    ActivityType.readAnswer: 'Read',
  };

  /// How many recent answers per level "Needs practice" looks at, and the
  /// minimum before a level is judged at all.
  static const recentWindow = 20;
  static const minRecentAttempts = 5;

  static const practiceTrackOrder = [PracticeTrack.spellWords, PracticeTrack.numberMatch, PracticeTrack.readAnswer];

  static NumbersSummary build({
    required List<LevelConfig> levels,
    required List<LevelConfig> practiceLevels,
    required LearnerGrade grade,
    required Map<String, int> bestScores,
    required List<Map<String, Object?>> learningRows,
    required List<Map<String, Object?>> practiceRows,
  }) {
    // ── Level progress ──────────────────────────────────────────────────
    final attemptsPerLevel = <String, int>{};
    for (final r in learningRows) {
      final id = r['level_id'] as String;
      attemptsPerLevel[id] = (attemptsPerLevel[id] ?? 0) + 1;
    }
    List<NumberLevelRow> rowsFor(List<LevelConfig> track, {required bool unlocked}) {
      final states = LevelProgressRules.states(track, bestScores, trackUnlocked: unlocked);
      return [
        for (final l in track)
          NumberLevelRow(
            level: l,
            best: bestScores[l.id],
            attempts: attemptsPerLevel[l.id] ?? 0,
            status: switch (states[l.id]!) {
              LevelState.passed => NumberLevelStatus.passed,
              LevelState.locked => NumberLevelStatus.locked,
              LevelState.comingSoon => NumberLevelStatus.comingSoon,
              LevelState.unlocked =>
                (attemptsPerLevel[l.id] ?? 0) > 0 ? NumberLevelStatus.inProgress : NumberLevelStatus.notStarted,
            },
          ),
      ];
    }

    final basicTrack = LevelRepository.forTrack(levels, grade.grade, Track.basic);
    final advancedTrack = LevelRepository.forTrack(levels, grade.grade, Track.advanced);
    final basic = rowsFor(basicTrack, unlocked: true);
    final advanced = rowsFor(advancedTrack, unlocked: LevelProgressRules.trackComplete(basicTrack, bestScores));
    final practice = {
      for (final t in practiceTrackOrder) t: rowsFor(LevelRepository.forTrack(practiceLevels, 0, t), unlocked: true),
    };

    // ── Accuracy ────────────────────────────────────────────────────────
    final byActivityRaw = <String, AccuracyStat>{};
    var learningTotal = AccuracyStat.empty;
    for (final r in learningRows) {
      final stat = AccuracyStat((r['score'] as int? ?? 0) > 0 ? 1 : 0, 1);
      final type = r['activity_type'] as String;
      byActivityRaw[type] = (byActivityRaw[type] ?? AccuracyStat.empty) + stat;
      learningTotal = learningTotal + stat;
    }
    final byActivity = {
      for (final t in activityOrder)
        if (byActivityRaw.containsKey(t)) t: byActivityRaw[t]!,
    };

    final wordRows = practiceRows.where((r) => r['activity_type'] == NumberPracticeDao.activityNumberWord).toList();
    final firstTries = wordRows.where((r) => (r['attempt_number'] as int? ?? 1) == 1).toList();
    final numberWordsRaw = <String, AccuracyStat>{};
    var wordsTotal = AccuracyStat.empty;
    for (final r in firstTries) {
      final stat = AccuracyStat(r['verdict'] == 'OK' ? 1 : 0, 1);
      final key = r['level_key'] as String? ?? '';
      numberWordsRaw[key] = (numberWordsRaw[key] ?? AccuracyStat.empty) + stat;
      wordsTotal = wordsTotal + stat;
    }
    final numberWordsByLevel = {
      for (final l in NumbersData.levels)
        if (numberWordsRaw.containsKey(l['key'])) l['key'] as String: numberWordsRaw[l['key']]!,
    };

    // ── -teen / -ty confusions ──────────────────────────────────────────
    final confusions = wordRows.where((r) => (r['teen_ty_error'] as int? ?? 0) == 1).toList();
    final pairCounts = <String, ConfusedPair>{};
    for (final r in confusions) {
      final target = int.tryParse(r['item'] as String? ?? '');
      final partner = target == null ? null : NumbersData.confusablePartner(target);
      if (target == null || partner == null) continue;
      final teen = target < partner ? target : partner;
      final ty = target < partner ? partner : target;
      final prev = pairCounts['$teen/$ty'];
      pairCounts['$teen/$ty'] = ConfusedPair(teen, ty, (prev?.count ?? 0) + 1);
    }
    final confusedPairs = pairCounts.values.toList()
      ..sort((a, b) => b.count != a.count ? b.count.compareTo(a.count) : a.teen.compareTo(b.teen));

    // ── Rapid Digit Naming ──────────────────────────────────────────────
    final ran = [
      for (final r in practiceRows)
        if (r['activity_type'] == NumberPracticeDao.activityRapidDigitNaming)
          RanResult(
            date: DateTime.tryParse(r['timestamp'] as String? ?? '') ?? DateTime(1970),
            totalMs: r['time_ms'] as int? ?? 0,
            digitsCorrect: r['digits_correct'] as int? ?? 0,
            errors: r['error_count'] as int? ?? 0,
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    // ── Needs practice: lowest recent accuracy per level ────────────────
    final allLevels = {for (final l in [...levels, ...practiceLevels]) l.id: l};
    final perLevel = <String, List<Map<String, Object?>>>{};
    for (final r in learningRows) {
      (perLevel[r['level_id'] as String] ??= []).add(r);
    }
    final needs = <PracticeNeed>[];
    perLevel.forEach((id, rows) {
      rows.sort((a, b) => _ts(a).compareTo(_ts(b)));
      final recent = rows.length > recentWindow ? rows.sublist(rows.length - recentWindow) : rows;
      if (recent.length < minRecentAttempts) return;
      final stat = AccuracyStat(recent.where((r) => (r['score'] as int? ?? 0) > 0).length, recent.length);
      final level = allLevels[id];
      final type = level?.activityType ?? (rows.first['activity_type'] as String);
      final title = level == null ? id : level.title;
      needs.add(PracticeNeed('${activityLabels[type] ?? type} · $title', stat));
    });
    final wordsPerLevel = <String, List<Map<String, Object?>>>{};
    for (final r in firstTries) {
      (wordsPerLevel[r['level_key'] as String? ?? ''] ??= []).add(r);
    }
    wordsPerLevel.forEach((key, rows) {
      rows.sort((a, b) => _ts(a).compareTo(_ts(b)));
      final recent = rows.length > recentWindow ? rows.sublist(rows.length - recentWindow) : rows;
      if (recent.length < minRecentAttempts) return;
      final stat = AccuracyStat(recent.where((r) => r['verdict'] == 'OK').length, recent.length);
      needs.add(PracticeNeed('Number Words · ${numberWordsLevelLabel(key)}', stat));
    });
    needs.removeWhere((n) => n.recent.correct == n.recent.total);
    needs.sort((a, b) {
      final byRate = a.recent.rate!.compareTo(b.recent.rate!);
      return byRate != 0 ? byRate : b.recent.total.compareTo(a.recent.total);
    });

    return NumbersSummary(
      grade: grade.grade,
      gradeDefaulted: grade.defaulted,
      basic: basic,
      advanced: advanced,
      practice: practice,
      overall: learningTotal + wordsTotal,
      byActivity: byActivity,
      numberWordsByLevel: numberWordsByLevel,
      teenTyConfusions: confusions.length,
      confusedPairs: confusedPairs.take(3).toList(),
      ran: ran,
      needsPractice: needs.take(3).toList(),
    );
  }

  /// Number Words level label from NumbersData (e.g. "Teen or Ty?").
  static String numberWordsLevelLabel(String key) {
    for (final l in NumbersData.levels) {
      if (l['key'] == key) return l['label'] as String;
    }
    return key;
  }

  static String _ts(Map<String, Object?> r) => r['timestamp'] as String? ?? '';
}

/// Reads one child's Numbers data and builds their [NumbersSummary].
class NumbersSummaryLoader {
  NumbersSummaryLoader._();

  static Future<NumbersSummary> load(String profileName) async {
    final profiles = await LocalStorage.getAllProfiles();
    final matches = profiles.where((p) => p.name == profileName);
    final grade = LearnerGrade.fromProfile(matches.isEmpty ? '' : matches.first.grade);
    final results = await Future.wait([
      LevelRepository.load(),
      LevelRepository.loadPractice(),
      NumberLearningDao.bestScores(profileName),
      NumberLearningDao.allAttempts(profileName),
      NumberPracticeDao.getAttempts(profileName: profileName, limit: 100000),
    ]);
    return NumbersSummaryBuilder.build(
      levels: results[0] as List<LevelConfig>,
      practiceLevels: results[1] as List<LevelConfig>,
      grade: grade,
      bestScores: results[2] as Map<String, int>,
      learningRows: results[3] as List<Map<String, Object?>>,
      practiceRows: results[4] as List<Map<String, Object?>>,
    );
  }
}
