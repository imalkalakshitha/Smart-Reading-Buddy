import 'dart:math';
import 'package:smart_reading_buddy/features/numbers/services/level_config.dart';

/// How a Number Match card shows its number.
enum CardForm { digit, word, picture }

class MatchCard {
  final int value;
  final CardForm form;

  const MatchCard(this.value, this.form);
}

/// One board: every value appears on exactly two cards, in two different
/// forms (7 ↔ "seven", 7 ↔ 7 apples, "seven" ↔ 7 apples).
class MatchBoard {
  final List<MatchCard> cards;

  const MatchBoard(this.cards);

  int get pairCount => cards.length ~/ 2;

  List<int> get values => cards.map((c) => c.value).toSet().toList();

  /// Repetition-control key for the pair of [value] on this board.
  String pairKey(int value) {
    final forms = cards.where((c) => c.value == value).map((c) => c.form.name).toList()..sort();
    return 'match:$value:${forms.join('-')}';
  }
}

/// Rule-based Number Match boards for a level — no hardcoded boards.
///
/// A session is [pairsPerSession] pairs (the same 10 "questions" as every
/// other Numbers session). Boards are full size ([LevelConfig.pairsPerBoard])
/// except the last, which takes the remainder — never a 1-pair board
/// (3 pairs → 3, 3, 2, 2; 4 → 4, 4, 2; 6 → 6, 4).
class MatchBoardGenerator {
  final Random _rng;

  MatchBoardGenerator([Random? rng]) : _rng = rng ?? Random();

  static const pairsPerSession = 10;

  static List<int> boardSizes(int pairsPerBoard, {int total = pairsPerSession}) {
    final sizes = <int>[];
    var rem = total;
    while (rem > 0) {
      var s = min(pairsPerBoard, rem);
      if (rem - s == 1) s -= 1;
      sizes.add(s);
      rem -= s;
    }
    return sizes;
  }

  /// Boards for one session. Values from [avoidKeys] (the child's last
  /// sessions) are used last, only once the range runs out.
  List<MatchBoard> generateSession(LevelConfig level, {Set<String> avoidKeys = const {}}) {
    final recentValues = {
      for (final k in avoidKeys)
        if (k.startsWith('match:')) int.tryParse(k.split(':')[1]),
    }.whereType<int>().toSet();
    return [
      for (final size in boardSizes(level.pairsPerBoard)) _board(level, size, recentValues),
    ];
  }

  MatchBoard _board(LevelConfig level, int pairs, Set<int> recent) {
    final all = [for (var v = level.min; v <= level.max; v++) v]..shuffle(_rng);
    // Fresh values first, recent ones only if the range is too small.
    final ordered = [...all.where((v) => !recent.contains(v)), ...all.where(recent.contains)];
    final values = ordered.take(pairs).toList();
    final forms = level.forms.map(CardForm.values.byName).toList();
    final cards = <MatchCard>[];
    for (final v in values) {
      final f = [...forms]..shuffle(_rng);
      cards
        ..add(MatchCard(v, f[0]))
        ..add(MatchCard(v, f[1]));
    }
    cards.shuffle(_rng);
    return MatchBoard(cards);
  }

  /// Null when [board] is valid for [level] with [pairs] pairs.
  static String? validate(MatchBoard board, LevelConfig level, int pairs) {
    if (board.cards.length != pairs * 2) return 'wrong card count';
    if (pairs > level.pairsPerBoard) return 'too many pairs';
    final allowed = level.forms.map(CardForm.values.byName).toSet();
    for (final v in board.values) {
      final pair = board.cards.where((c) => c.value == v).toList();
      if (pair.length != 2) return 'value $v not exactly twice';
      if (pair[0].form == pair[1].form) return 'pair $v has the same form twice';
      if (!allowed.contains(pair[0].form) || !allowed.contains(pair[1].form)) return 'form not allowed';
      if (v < level.min || v > level.max) return 'value out of range';
    }
    return null;
  }
}

enum FlipOutcome { ignored, firstUp, match, mismatch }

class FlipResult {
  final FlipOutcome outcome;

  /// For match / mismatch: the two card indices.
  final int? first;
  final int? second;

  /// For mismatch: the first card's partner had already been seen, so the
  /// child could have remembered it.
  final bool avoidable;

  const FlipResult(this.outcome, {this.first, this.second, this.avoidable = false});
}

/// Memory-game state for one board (pure logic, no UI).
///
/// Scoring follows the "first try" rule of every Numbers session, adapted
/// to memory: a mismatch only counts against a pair when it was avoidable —
/// the first card's partner had already been turned over earlier, so the
/// child had seen where it was. Mismatches while exploring unseen cards
/// are part of the game and never cost a point.
class MatchGame {
  final MatchBoard board;
  final Set<int> _seen = {};
  final Set<int> matched = {};
  final Map<int, int> avoidableMistakes = {};
  final Map<int, int> tries = {};
  int? _first;

  MatchGame(this.board);

  int? get faceUp => _first;
  bool get done => matched.length == board.cards.length;

  int _partnerOf(int i) {
    final v = board.cards[i].value;
    for (var j = 0; j < board.cards.length; j++) {
      if (j != i && board.cards[j].value == v) return j;
    }
    return -1;
  }

  FlipResult flip(int i) {
    if (i < 0 || i >= board.cards.length || matched.contains(i) || i == _first) {
      return const FlipResult(FlipOutcome.ignored);
    }
    final first = _first;
    if (first == null) {
      _first = i;
      return FlipResult(FlipOutcome.firstUp, first: i);
    }
    _first = null;
    final value = board.cards[first].value;
    tries[value] = (tries[value] ?? 0) + 1;
    if (board.cards[i].value == value) {
      _seen.addAll([first, i]);
      matched.addAll([first, i]);
      return FlipResult(FlipOutcome.match, first: first, second: i);
    }
    final avoidable = _seen.contains(_partnerOf(first));
    if (avoidable) avoidableMistakes[value] = (avoidableMistakes[value] ?? 0) + 1;
    _seen.addAll([first, i]);
    return FlipResult(FlipOutcome.mismatch, first: first, second: i, avoidable: avoidable);
  }

  /// 1 if the pair of [value] was matched with no avoidable mistake.
  int pairScore(int value) => (avoidableMistakes[value] ?? 0) == 0 ? 1 : 0;
}
