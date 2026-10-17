import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Activity types in assets/numbers/levels.json.
class ActivityType {
  ActivityType._();

  static const recognition = 'recognition';
  static const build = 'build';
  static const counting = 'counting';
  static const ordering = 'ordering';
  static const formation = 'formation';
  static const patterns = 'patterns';
  static const calculation = 'calculation';
  static const placeValue = 'place_value';

  static const all = {
    recognition, build, counting, ordering, formation, patterns, calculation, placeValue,
  };
}

class Track {
  Track._();

  static const basic = 'basic';
  static const advanced = 'advanced';
}

/// One level from assets/numbers/levels.json. The rule params are read as
/// typed getters; unknown keys are kept in [raw] for activity-specific use.
class LevelConfig {
  final String id;
  final int grade;
  final String track;
  final int level;
  final String title;
  final String activityType;
  final Map<String, dynamic> raw;

  const LevelConfig({
    required this.id,
    required this.grade,
    required this.track,
    required this.level,
    required this.title,
    required this.activityType,
    required this.raw,
  });

  factory LevelConfig.fromJson(Map<String, dynamic> json) => LevelConfig(
        id: json['id'] as String,
        grade: json['grade'] as int,
        track: json['track'] as String,
        level: json['level'] as int,
        title: json['title'] as String,
        activityType: json['activityType'] as String,
        raw: json,
      );

  int? get digitCount => raw['digitCount'] as int?;

  /// Allowed digit counts, e.g. [3, 4] for "3 & 4-digit" levels. Each
  /// generated number picks one of these at random. `digitCount: n` is the
  /// same as `digitCounts: [n]`; null means the level uses min/max only.
  List<int>? get digitCounts {
    final list = raw['digitCounts'] as List?;
    if (list != null) return list.cast<int>();
    final d = digitCount;
    return d == null ? null : [d];
  }

  /// Smallest / largest number with exactly [d] digits (no leading zero).
  static int lowestWithDigits(int d) => d == 1 ? 0 : _pow10(d - 1);
  static int highestWithDigits(int d) => _pow10(d) - 1;

  /// Overall inclusive range. With digit counts set, the range covers every
  /// number with an allowed digit count (so never a leading zero), narrowed
  /// by any explicit min/max.
  int get min {
    final explicit = raw['min'] as int?;
    final counts = digitCounts;
    final fromDigits = counts == null ? null : lowestWithDigits(counts.reduce((a, b) => a < b ? a : b));
    if (explicit == null) return fromDigits ?? 0;
    return fromDigits == null || explicit > fromDigits ? explicit : fromDigits;
  }

  int get max {
    final explicit = raw['max'] as int?;
    final counts = digitCounts;
    final fromDigits = counts == null ? null : highestWithDigits(counts.reduce((a, b) => a > b ? a : b));
    if (explicit == null) return fromDigits ?? 100;
    return fromDigits == null || explicit < fromDigits ? explicit : fromDigits;
  }

  /// Whether [n] is a valid number for this level: inside min/max and, when
  /// digit counts are set, with an allowed number of digits.
  bool contains(int n) {
    if (n < min || n > max) return false;
    final counts = digitCounts;
    return counts == null || counts.contains('$n'.length);
  }

  // ── Phase 2 / display params ──────────────────────────────────────────
  /// Recognition: after finding the number, colour that many objects.
  bool get colourQuantity => raw['colourQuantity'] as bool? ?? false;
  /// Patterns: 'road' draws the sequence as a number road.
  String get display => raw['display'] as String? ?? 'cards';
  /// Counting: object kinds to draw (star, apple, fish …).
  List<String> get objects => ((raw['objects'] as List?) ?? const ['star']).cast<String>();
  /// Counting: draw as base-ten blocks (hundred flats, ten sticks, balls).
  bool get grouped => raw['grouped'] as bool? ?? false;
  /// Counting: label the groups with an H / T / O place-value chart.
  bool get placeValueChart => raw['placeValueChart'] as bool? ?? false;
  /// Formation: 'highest', 'lowest' or 'either'.
  String get goal => raw['goal'] as String? ?? 'either';
  /// Calculation: any of add, subtract, multiply, divide.
  List<String> get operations => ((raw['operations'] as List?) ?? const ['add']).cast<String>();
  /// Calculation: answers stay within [answerMin, answerLimit].
  int get answerLimit => raw['answerLimit'] as int? ?? max;
  int get answerMin => raw['answerMin'] as int? ?? 0;
  /// Calculation (× ÷): number of groups / divisor is 2..maxFactor.
  int get maxFactor => raw['maxFactor'] as int? ?? 5;
  /// Calculation (×): objects per group is 1..maxGroupSize.
  int get maxGroupSize => raw['maxGroupSize'] as int? ?? 10;
  bool get visual => raw['visual'] as bool? ?? true;
  /// Place value: 'place_value' or 'comparison'.
  String get mode => raw['mode'] as String? ?? 'place_value';

  /// Multiple-choice options shown, capped at 4 (dyslexia-friendly).
  int get optionCount {
    final n = raw['optionCount'] as int? ?? 3;
    return n.clamp(2, 4);
  }

  int get extraTiles => raw['extraTiles'] as int? ?? 2;
  int get itemCount => (raw['itemCount'] as int? ?? 4).clamp(2, 5);
  String get direction => raw['direction'] as String? ?? 'ascending';
  List<int> get steps => ((raw['steps'] as List?) ?? const [1]).cast<int>();
  int get patternLength => raw['length'] as int? ?? 5;

  static int _pow10(int e) {
    var v = 1;
    for (var i = 0; i < e; i++) {
      v *= 10;
    }
    return v;
  }
}

/// Loads and caches assets/numbers/levels.json.
class LevelRepository {
  LevelRepository._();

  static const assetPath = 'assets/numbers/levels.json';
  static List<LevelConfig>? _cache;

  static Future<List<LevelConfig>> load() async {
    return _cache ??= parse(await rootBundle.loadString(assetPath));
  }

  /// Parses the JSON text — separate from [load] so tests can feed the file
  /// directly.
  static List<LevelConfig> parse(String jsonText) {
    final json = jsonDecode(jsonText) as Map<String, dynamic>;
    return (json['levels'] as List)
        .map((e) => LevelConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Levels for one grade + track, in level order.
  static List<LevelConfig> forTrack(List<LevelConfig> all, int grade, String track) =>
      all.where((l) => l.grade == grade && l.track == track).toList()
        ..sort((a, b) => a.level.compareTo(b.level));
}
