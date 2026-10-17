import 'dart:math';
import 'level_config.dart';
import 'number_question.dart';

/// Rule-based question generator for Number Learning — one generator per
/// activity type, driven entirely by the LevelConfig from levels.json.
///
/// Every candidate is checked with [validate]; invalid ones are rejected
/// and regenerated. Constraints enforced:
/// - no leading zero (digit-swap/±1 distractors that would start with 0
///   are dropped; digit-count ranges start at 10^(n-1); formation "lowest"
///   never puts 0 first)
/// - unique options (≤ 4), answer exactly once, options shuffled
/// - meaningful distractors first: digit swap (47 → 74), ±1 on one digit
///   (47 → 37, 57, 46, 48), then near numbers
/// - ordering items unique and never shown already sorted
/// - pattern terms follow the step exactly and stay within the range (≥ 0)
/// - calculation: addition sum ≤ answerLimit, subtraction never negative,
///   division has no remainder (dividend = divisor × quotient), every
///   answer within [answerMin, answerLimit]
class QuestionGenerator {
  final Random _rng;

  QuestionGenerator([Random? rng]) : _rng = rng ?? Random();

  static const _supported = {
    ActivityType.recognition,
    ActivityType.build,
    ActivityType.ordering,
    ActivityType.patterns,
    ActivityType.counting,
    ActivityType.formation,
    ActivityType.calculation,
    ActivityType.placeValue,
  };

  static bool supports(String activityType) => _supported.contains(activityType);

  static const _maxAttempts = 3000;
  // Past these attempt counts the session rules relax, so a level whose
  // range is too small to satisfy them (e.g. 0–9) still fills a session
  // instead of looping forever: first recent-session keys may repeat, then
  // keys within this session may repeat.
  static const _relaxAvoidAfter = 800;
  static const _relaxUniqueAfter = 2000;

  /// [count] valid questions for [level]. Keys in [avoidKeys] (questions
  /// from the child's last sessions) and repeats within the session are
  /// skipped while the range allows it.
  List<NumberQuestion> generateSession(
    LevelConfig level, {
    int count = 10,
    Set<String> avoidKeys = const {},
  }) {
    if (!supports(level.activityType)) {
      throw UnsupportedError('Unknown activity type: ${level.activityType}');
    }
    final out = <NumberQuestion>[];
    final used = <String>{};
    var attempts = 0;
    while (out.length < count && attempts < _maxAttempts) {
      attempts++;
      final q = generateOne(level);
      if (q == null || validate(q, level) != null) continue;
      if (used.contains(q.key) && attempts < _relaxUniqueAfter) continue;
      if (avoidKeys.contains(q.key) && attempts < _relaxAvoidAfter) continue;
      out.add(q);
      used.add(q.key);
    }
    if (out.length < count) {
      throw StateError('Could not generate $count questions for ${level.id}');
    }
    return out;
  }

  /// One candidate question (may be null if this attempt hit a dead end).
  NumberQuestion? generateOne(LevelConfig level) {
    switch (level.activityType) {
      case ActivityType.recognition:
        return _recognition(level);
      case ActivityType.build:
        return _build(level);
      case ActivityType.ordering:
        return _ordering(level);
      case ActivityType.patterns:
        return _pattern(level);
      case ActivityType.counting:
        return _counting(level);
      case ActivityType.formation:
        return _formation(level);
      case ActivityType.calculation:
        return _calculation(level);
      case ActivityType.placeValue:
        return level.mode == 'comparison' ? _comparison(level) : _placeValue(level);
      default:
        return null;
    }
  }

  /// A random number valid for [level]: with digit counts, first pick one
  /// of the allowed counts, then a number with exactly that many digits.
  int _number(LevelConfig level) {
    final counts = level.digitCounts;
    if (counts == null) return _randIn(level.min, level.max);
    final d = counts[_rng.nextInt(counts.length)];
    final lo = max(level.min, LevelConfig.lowestWithDigits(d));
    final hi = min(level.max, LevelConfig.highestWithDigits(d));
    return hi < lo ? _randIn(level.min, level.max) : _randIn(lo, hi);
  }

  // ── Recognition ──────────────────────────────────────────────────────

  RecognitionQuestion? _recognition(LevelConfig level) {
    final answer = _number(level);
    final options = _optionsFor(
      answer,
      level.optionCount,
      meaningful: meaningfulDistractors(answer),
      fallbackMin: level.min,
      fallbackMax: level.max,
    );
    if (options == null) return null;
    return RecognitionQuestion(
      answer: answer,
      options: options,
      colourQuantity: level.colourQuantity,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  BuildQuestion? _build(LevelConfig level) {
    final answer = _number(level);
    final digits = '$answer'.split('').map(int.parse).toList();
    // Extra tiles are near-miss digits (±1 of a digit in the answer) where
    // possible, so the wrong tiles are tempting rather than random.
    final near = <int>{
      for (final d in digits) ...[if (d > 0) d - 1, if (d < 9) d + 1],
    }.toList()
      ..shuffle(_rng);
    final extras = <int>[];
    for (final d in near) {
      if (extras.length == level.extraTiles) break;
      extras.add(d);
    }
    while (extras.length < level.extraTiles) {
      extras.add(_rng.nextInt(10));
    }
    final tiles = [...digits, ...extras];
    // Shuffle so the answer isn't laid out ready-made (skip when every tile
    // is the same digit and no order differs).
    for (var i = 0; i < 20; i++) {
      tiles.shuffle(_rng);
      if (!_startsWith(tiles, digits)) break;
    }
    return BuildQuestion(answer: answer, tiles: tiles);
  }

  // ── Ordering ─────────────────────────────────────────────────────────

  OrderingQuestion? _ordering(LevelConfig level) {
    final n = level.itemCount;
    if (level.max - level.min + 1 < n) return null;
    final set = <int>{};
    var guard = 0;
    while (set.length < n && guard++ < 200) {
      set.add(_number(level));
    }
    if (set.length < n) return null;
    final descending = switch (level.direction) {
      'descending' => true,
      'either' => _rng.nextBool(),
      _ => false,
    };
    final items = set.toList()..shuffle(_rng);
    return OrderingQuestion(items: items, descending: descending);
  }

  // ── Patterns ─────────────────────────────────────────────────────────

  PatternQuestion? _pattern(LevelConfig level) {
    final step = level.steps[_rng.nextInt(level.steps.length)];
    final len = level.patternLength;
    final span = step.abs() * (len - 1);
    final lo = step > 0 ? level.min : level.min + span;
    final hi = step > 0 ? level.max - span : level.max;
    if (hi < lo) return null;
    var start = _randIn(lo, hi);
    // Skip-counting by 5, 10, 25… starts on a multiple of the step so the
    // sequence looks like real skip counting (5, 10, 15 — not 7, 12, 17).
    if (step.abs() >= 5) {
      final m = step.abs();
      start = (start ~/ m) * m;
      if (start < lo) start += m;
      if (start > hi) return null;
    }
    final sequence = [for (var i = 0; i < len; i++) start + step * i];
    // Never the first term — the child needs at least one number before
    // the gap to see the rule.
    final missingIndex = 1 + _rng.nextInt(len - 1);
    final answer = sequence[missingIndex];
    final options = _optionsFor(
      answer,
      level.optionCount,
      meaningful: [
        answer + 1,
        answer - 1,
        answer + step,
        answer - step,
        ...meaningfulDistractors(answer),
      ],
      fallbackMin: max(0, answer - step.abs() * 2),
      fallbackMax: answer + step.abs() * 2,
    );
    if (options == null) return null;
    return PatternQuestion(
      sequence: sequence,
      missingIndex: missingIndex,
      step: step,
      options: options,
      road: level.display == 'road',
    );
  }

  // ── Counting ─────────────────────────────────────────────────────────

  CountingQuestion? _counting(LevelConfig level) {
    final answer = _number(level);
    final options = _optionsFor(
      answer,
      level.optionCount,
      meaningful: [
        answer + 1,
        answer - 1,
        if (level.grouped) ...[answer + 10, answer - 10],
        ...meaningfulDistractors(answer),
      ],
      fallbackMin: level.min,
      fallbackMax: level.max,
    );
    if (options == null) return null;
    final objects = level.objects;
    return CountingQuestion(
      answer: answer,
      options: options,
      object: level.grouped ? 'blocks' : objects[_rng.nextInt(objects.length)],
      grouped: level.grouped,
      placeValueChart: level.placeValueChart,
    );
  }

  // ── Formation ────────────────────────────────────────────────────────

  FormationQuestion? _formation(LevelConfig level) {
    final counts = level.digitCounts ?? const [3];
    final d = counts[_rng.nextInt(counts.length)];
    if (d < 2 || d > 10) return null;
    final digits = (List.generate(10, (i) => i)..shuffle(_rng)).take(d).toList();
    final highest = switch (level.goal) {
      'highest' => true,
      'lowest' => false,
      _ => _rng.nextBool(),
    };
    final answer = FormationQuestion.answerFor(digits, highest: highest);
    for (var i = 0; i < 20 && _listEq(digits, answer); i++) {
      digits.shuffle(_rng);
    }
    return FormationQuestion(digits: digits, highest: highest);
  }

  // ── Calculation ──────────────────────────────────────────────────────

  CalculationQuestion? _calculation(LevelConfig level) {
    final ops = level.operations;
    final op = Operation.values.byName(ops[_rng.nextInt(ops.length)]);
    final limit = level.answerLimit;
    final operandMax = level.max;
    int a, b;
    switch (op) {
      case Operation.add:
        // sum ≤ answerLimit by construction; both parts at least 1 so
        // there's something to draw on each side.
        final aMax = min(operandMax, limit - 1);
        if (aMax < 1) return null;
        a = _randIn(1, aMax);
        final bMax = min(operandMax, limit - a);
        if (bMax < 1) return null;
        b = _randIn(1, bMax);
      case Operation.subtract:
        // b ≤ a, so the answer is never negative.
        a = _randIn(1, operandMax);
        b = _randIn(1, a);
      case Operation.multiply:
        a = _randIn(2, level.maxFactor); // groups
        b = _randIn(1, level.maxGroupSize); // in each group
      case Operation.divide:
        // dividend = divisor × quotient, so there's never a remainder.
        b = _randIn(2, level.maxFactor);
        final qLo = max(1, level.answerMin);
        final qHi = min(limit, operandMax ~/ b);
        if (qHi < qLo) return null;
        a = b * _randIn(qLo, qHi);
    }
    final q = CalculationQuestion(op: op, a: a, b: b, options: const [], visual: level.visual);
    final answer = q.answer;
    final options = _optionsFor(
      answer,
      level.optionCount,
      meaningful: [
        answer + 1,
        answer - 1,
        ...switch (op) {
          // The other operation's result is the classic mix-up.
          Operation.add => [a - b, answer + b, answer - b],
          Operation.subtract => [a + b, answer + b],
          Operation.multiply => [a + b, answer + a, answer - a, answer + b, answer - b],
          Operation.divide => [b, answer + b, a - b],
        },
        ...meaningfulDistractors(answer),
      ],
      fallbackMin: max(0, answer - 5),
      fallbackMax: answer + 5,
    );
    if (options == null) return null;
    return CalculationQuestion(op: op, a: a, b: b, options: options, visual: level.visual);
  }

  // ── Place value ──────────────────────────────────────────────────────

  PlaceValueQuestion? _placeValue(LevelConfig level) {
    final number = _number(level);
    final places = _placesFor(number);
    final place = places[_rng.nextInt(places.length)];
    final q = PlaceValueQuestion(number: number, place: place, options: const []);
    final answer = q.answer;
    // The number's other digits are the most tempting wrong answers
    // (347: "how many tens?" → 3 or 7 are the likely mistakes).
    final digits = '$number'.split('').map(int.parse);
    final pool = [...digits, answer + 1, answer - 1]
        .where((d) => d >= 0 && d <= 9 && d != answer)
        .toSet()
        .toList()
      ..shuffle(_rng);
    final options = <int>{answer};
    for (final d in pool) {
      if (options.length == level.optionCount) break;
      options.add(d);
    }
    while (options.length < level.optionCount) {
      options.add(_rng.nextInt(10));
    }
    return PlaceValueQuestion(
      number: number,
      place: place,
      options: options.toList()..shuffle(_rng),
    );
  }

  static List<Place> _placesFor(int number) => switch ('$number'.length) {
        1 => const [Place.ones],
        2 => const [Place.tens, Place.ones],
        _ => const [Place.hundreds, Place.tens, Place.ones],
      };

  // ── Comparison ───────────────────────────────────────────────────────

  ComparisonQuestion? _comparison(LevelConfig level) {
    final a = _number(level);
    // Mostly a close, confusable partner (47 vs 74, 3482 vs 3428); otherwise
    // any valid number, which also mixes digit counts on 3 & 4-digit levels.
    final close = meaningfulDistractors(a).where(level.contains).toList();
    final b = close.isNotEmpty && _rng.nextDouble() < 0.6
        ? close[_rng.nextInt(close.length)]
        : _number(level);
    if (a == b) return null;
    return ComparisonQuestion(a: a, b: b, askBigger: _rng.nextBool());
  }

  // ── Shared helpers ───────────────────────────────────────────────────

  /// Digit swaps and ±1 on one digit, excluding [n] itself, negatives and
  /// anything that would start with a leading zero.
  static List<int> meaningfulDistractors(int n) {
    final s = '$n';
    final out = <int>{};
    for (var i = 0; i < s.length; i++) {
      for (var j = i + 1; j < s.length; j++) {
        if (s[i] == s[j]) continue;
        final chars = s.split('');
        final t = chars[i];
        chars[i] = chars[j];
        chars[j] = t;
        if (chars.length > 1 && chars.first == '0') continue;
        out.add(int.parse(chars.join()));
      }
    }
    for (var i = 0; i < s.length; i++) {
      final d = int.parse(s[i]);
      for (final nd in [d - 1, d + 1]) {
        if (nd < 0 || nd > 9) continue;
        if (i == 0 && nd == 0 && s.length > 1) continue;
        out.add(int.parse(s.replaceRange(i, i + 1, '$nd')));
      }
    }
    out.remove(n);
    return out.where((v) => v >= 0).toList();
  }

  /// [count] unique options including [answer] once, meaningful
  /// distractors first, then near numbers in [fallbackMin, fallbackMax];
  /// shuffled. Null if not enough distinct values exist.
  List<int>? _optionsFor(
    int answer,
    int count, {
    required List<int> meaningful,
    required int fallbackMin,
    required int fallbackMax,
  }) {
    final pool = meaningful.where((v) => v >= 0 && v != answer).toSet().toList()
      ..shuffle(_rng);
    final options = <int>{answer};
    for (final v in pool) {
      if (options.length == count) break;
      options.add(v);
    }
    var tries = 0;
    while (options.length < count && tries < 200) {
      tries++;
      final v = _randIn(max(0, fallbackMin), max(fallbackMin, fallbackMax));
      options.add(v);
    }
    if (options.length < count) return null;
    return options.toList()..shuffle(_rng);
  }

  int _randIn(int lo, int hi) => lo + _rng.nextInt(hi - lo + 1);

  static bool _startsWith(List<int> list, List<int> prefix) {
    if (list.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (list[i] != prefix[i]) return false;
    }
    return true;
  }

  // ── Validation ───────────────────────────────────────────────────────

  /// Null when [q] satisfies every constraint for [level], otherwise a
  /// short reason (used by tests and to reject candidates).
  static String? validate(NumberQuestion q, LevelConfig level) {
    switch (q) {
      case RecognitionQuestion():
        if (!level.contains(q.answer)) return 'answer out of range';
        if (q.colourQuantity && q.answer >= RecognitionQuestion.quantitySlots) {
          return 'too many to colour';
        }
        return _validateOptions(q.answer, q.options, level.optionCount);
      case BuildQuestion():
        if (!level.contains(q.answer)) return 'answer out of range';
        if (q.digitCount > 1 && q.answerDigits.first == 0) return 'leading zero';
        if (q.tiles.length != q.digitCount + level.extraTiles) return 'wrong tile count';
        final remaining = [...q.tiles];
        for (final d in q.answerDigits) {
          if (!remaining.remove(d)) return 'tiles cannot build answer';
        }
        if (q.tiles.any((t) => t < 0 || t > 9)) return 'invalid tile';
        return null;
      case OrderingQuestion():
        if (q.items.length != level.itemCount) return 'wrong item count';
        if (q.items.toSet().length != q.items.length) return 'duplicate items';
        if (!q.items.every(level.contains)) return 'item out of range';
        if (_listEq(q.items, q.answer)) return 'already in order';
        return null;
      case PatternQuestion():
        if (q.sequence.length != level.patternLength) return 'wrong length';
        if (!level.steps.contains(q.step)) return 'step not in config';
        for (var i = 1; i < q.sequence.length; i++) {
          if (q.sequence[i] - q.sequence[i - 1] != q.step) return 'step broken';
        }
        if (q.sequence.any((v) => v < 0 || v < level.min || v > level.max)) {
          return 'term out of range';
        }
        if (q.missingIndex < 1 || q.missingIndex >= q.sequence.length) return 'bad gap';
        return _validateOptions(q.answer, q.options, level.optionCount);
      case CountingQuestion():
        if (!level.contains(q.answer)) return 'answer out of range';
        if (q.grouped && q.answer < 10) return 'grouped count needs tens';
        return _validateOptions(q.answer, q.options, level.optionCount);
      case FormationQuestion():
        final counts = level.digitCounts ?? const [3];
        if (!counts.contains(q.digits.length)) return 'wrong digit count';
        if (q.digits.toSet().length != q.digits.length) return 'duplicate digits';
        if (q.digits.any((d) => d < 0 || d > 9)) return 'invalid digit';
        if (q.answerDigits.first == 0) return 'leading zero';
        if (_listEq(q.digits, q.answerDigits)) return 'already the answer';
        if (level.goal == 'highest' && !q.highest) return 'goal mismatch';
        if (level.goal == 'lowest' && q.highest) return 'goal mismatch';
        return null;
      case CalculationQuestion():
        if (!level.operations.contains(q.op.name)) return 'operation not in config';
        if (q.a < 0 || q.b < 0) return 'negative operand';
        switch (q.op) {
          case Operation.add:
            if (q.a + q.b > level.answerLimit) return 'sum over limit';
            if (q.a > level.max || q.b > level.max) return 'operand over limit';
          case Operation.subtract:
            if (q.b > q.a) return 'negative result';
            if (q.a > level.max) return 'operand over limit';
          case Operation.multiply:
            if (q.a < 2 || q.a > level.maxFactor) return 'bad group count';
            if (q.b < 1 || q.b > level.maxGroupSize) return 'bad group size';
          case Operation.divide:
            if (q.b < 2 || q.b > level.maxFactor) return 'bad divisor';
            if (q.a % q.b != 0) return 'remainder';
            if (q.a > level.max) return 'dividend over limit';
        }
        if (q.answer < level.answerMin || q.answer > level.answerLimit) {
          return 'answer outside limits';
        }
        return _validateOptions(q.answer, q.options, level.optionCount);
      case PlaceValueQuestion():
        if (!level.contains(q.number)) return 'number out of range';
        if (!_placesFor(q.number).contains(q.place)) return 'place not in number';
        if (q.options.any((o) => o < 0 || o > 9)) return 'option not a digit';
        return _validateOptions(q.answer, q.options, level.optionCount);
      case ComparisonQuestion():
        if (q.a == q.b) return 'equal numbers';
        if (!level.contains(q.a) || !level.contains(q.b)) return 'number out of range';
        return null;
    }
  }

  static String? _validateOptions(int answer, List<int> options, int count) {
    if (options.length != count) return 'wrong option count';
    if (options.length > 4) return 'too many options';
    if (options.toSet().length != options.length) return 'duplicate options';
    if (options.where((o) => o == answer).length != 1) return 'answer not exactly once';
    if (options.any((o) => o < 0)) return 'negative option';
    return null;
  }

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
