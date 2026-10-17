import 'package:smart_reading_buddy/features/numbers/data/number_sentence_data.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_words.dart';

/// A generated Number Learning question. Every question is built at runtime
/// by QuestionGenerator from a LevelConfig — none are hardcoded.
sealed class NumberQuestion {
  const NumberQuestion();

  /// Stable identity used for repetition control (same key = same question).
  String get key;

  /// Short on-screen instruction.
  String get prompt;

  /// What TTS reads out (and the replay button repeats).
  String get speech;

  /// Second-step instruction, for questions with two steps (see
  /// RecognitionQuestion.colourQuantity). Null for one-step questions.
  String? get followUpPrompt => null;
  String? get followUpSpeech => null;

  /// True when the activity widget does its own reading aloud (Read &
  /// Answer highlights each word as it's spoken), so the session must not
  /// also speak [speech] when the question starts.
  bool get speaksItself => false;
}

/// Response for a "colour the quantity" step: how many objects are coloured.
class QuantityResponse {
  final int count;

  const QuantityResponse(this.count);
}

/// Hear a number, tap it among [options]. With [colourQuantity], the child
/// then colours that many stars.
class RecognitionQuestion extends NumberQuestion {
  final int answer;
  final List<int> options;
  final bool colourQuantity;

  /// Stars drawn for the colouring step (a ten-frame).
  static const quantitySlots = 10;

  const RecognitionQuestion({
    required this.answer,
    required this.options,
    this.colourQuantity = false,
  });

  @override
  String get key => 'recognition:$answer';
  @override
  String get prompt => 'Find the number you hear';
  @override
  String get speech => 'Find number ${NumberWords.of(answer)}';
  @override
  String? get followUpPrompt => colourQuantity ? 'Now colour $answer ${answer == 1 ? 'star' : 'stars'}' : null;
  @override
  String? get followUpSpeech => colourQuantity
      ? (answer == 0
          ? 'Zero! Colour no stars, then tap check'
          : 'Now colour ${NumberWords.of(answer)} ${answer == 1 ? 'star' : 'stars'}')
      : null;
}

/// Hear a number, build it from digit [tiles] (each tile used once).
class BuildQuestion extends NumberQuestion {
  final int answer;
  final List<int> tiles;

  const BuildQuestion({required this.answer, required this.tiles});

  List<int> get answerDigits => '$answer'.split('').map(int.parse).toList();
  int get digitCount => '$answer'.length;

  @override
  String get key => 'build:$answer';
  @override
  String get prompt => 'Build the number you hear';
  @override
  String get speech => 'Build the number ${NumberWords.of(answer)}';
}

/// Put [items] in order — smallest to biggest, or biggest to smallest.
class OrderingQuestion extends NumberQuestion {
  /// In the order shown to the child (never already sorted).
  final List<int> items;
  final bool descending;

  const OrderingQuestion({required this.items, required this.descending});

  List<int> get answer {
    final sorted = [...items]..sort();
    return descending ? sorted.reversed.toList() : sorted;
  }

  @override
  String get key => 'ordering:${descending ? 'desc' : 'asc'}:${([...items]..sort()).join(',')}';
  @override
  String get prompt => descending ? 'Biggest to smallest' : 'Smallest to biggest';
  @override
  String get speech => descending
      ? 'Put the numbers in order, from biggest to smallest'
      : 'Put the numbers in order, from smallest to biggest';
}

/// Find the missing number in a rule-based sequence.
class PatternQuestion extends NumberQuestion {
  final List<int> sequence;
  final int missingIndex;
  final int step;
  final List<int> options;

  /// Draw as a number road instead of cards.
  final bool road;

  const PatternQuestion({
    required this.sequence,
    required this.missingIndex,
    required this.step,
    required this.options,
    this.road = false,
  });

  int get answer => sequence[missingIndex];

  @override
  String get key => 'patterns:${sequence.first}:$step:$missingIndex';
  @override
  String get prompt => 'What number is missing?';
  @override
  String get speech => 'What number is missing?';
}

// ── Phase 2 ─────────────────────────────────────────────────────────────

/// Count the objects shown and tap how many. [grouped] draws base-ten
/// blocks: hundred flats, ten sticks and ones balls.
class CountingQuestion extends NumberQuestion {
  final int answer;
  final List<int> options;
  final String object;
  final bool grouped;
  final bool placeValueChart;

  const CountingQuestion({
    required this.answer,
    required this.options,
    required this.object,
    required this.grouped,
    this.placeValueChart = false,
  });

  int get hundreds => answer ~/ 100;
  int get tens => (answer % 100) ~/ 10;
  int get ones => answer % 10;

  @override
  String get key => 'counting:$answer';
  @override
  String get prompt => grouped ? 'How many altogether?' : 'How many can you count?';
  @override
  String get speech => grouped
      ? 'Count the sticks and balls. How many altogether?'
      : 'Count them. How many are there?';
}

/// Make the highest or lowest number from all of [digits].
class FormationQuestion extends NumberQuestion {
  /// The digit tiles, in the order shown (never already the answer).
  final List<int> digits;
  final bool highest;

  const FormationQuestion({required this.digits, required this.highest});

  /// Highest: digits big → small. Lowest: small → big, but a 0 can never
  /// go first, so the smallest non-zero digit leads.
  List<int> get answerDigits => answerFor(digits, highest: highest);

  static List<int> answerFor(List<int> digits, {required bool highest}) {
    final sorted = [...digits]..sort();
    if (highest) return sorted.reversed.toList();
    final firstNonZero = sorted.indexWhere((d) => d != 0);
    if (firstNonZero <= 0) return sorted;
    final lead = sorted.removeAt(firstNonZero);
    return [lead, ...sorted];
  }

  int get answer => int.parse(answerDigits.join());

  @override
  String get key => 'formation:${highest ? 'high' : 'low'}:${([...digits]..sort()).join()}';
  @override
  String get prompt => highest ? 'Make the BIGGEST number' : 'Make the SMALLEST number';
  @override
  String get speech => highest
      ? 'Use all the numbers to make the biggest number'
      : 'Use all the numbers to make the smallest number';
}

enum Operation { add, subtract, multiply, divide }

/// Visual add / subtract / multiply (groups) / divide (sharing).
///
/// add: [a] + [b]. subtract: [a] − [b]. multiply: [a] groups of [b].
/// divide: [a] shared into [b] groups.
class CalculationQuestion extends NumberQuestion {
  final Operation op;
  final int a;
  final int b;
  final List<int> options;
  final bool visual;

  const CalculationQuestion({
    required this.op,
    required this.a,
    required this.b,
    required this.options,
    this.visual = true,
  });

  int get answer => switch (op) {
        Operation.add => a + b,
        Operation.subtract => a - b,
        Operation.multiply => a * b,
        Operation.divide => a ~/ b,
      };

  String get symbol => switch (op) {
        Operation.add => '+',
        Operation.subtract => '−',
        Operation.multiply => '×',
        Operation.divide => '÷',
      };

  @override
  String get key => 'calc:${op.name}:$a:$b';
  @override
  String get prompt => switch (op) {
        Operation.add || Operation.multiply => 'How many altogether?',
        Operation.subtract => 'How many are left?',
        Operation.divide => 'How many in each group?',
      };
  @override
  String get speech {
    final x = NumberWords.of(a), y = NumberWords.of(b);
    return switch (op) {
      Operation.add => '$x plus $y. How many altogether?',
      Operation.subtract => '$x take away $y. How many are left?',
      Operation.multiply => '$x groups of $y. How many altogether?',
      Operation.divide => 'Share $x into $y groups. How many in each group?',
    };
  }
}

enum Place { hundreds, tens, ones }

/// "How many tens in 347?" with stick & ball blocks — 347 → 3, 4, 7.
class PlaceValueQuestion extends NumberQuestion {
  final int number;
  final Place place;
  final List<int> options;

  const PlaceValueQuestion({required this.number, required this.place, required this.options});

  int get answer => switch (place) {
        Place.hundreds => (number ~/ 100) % 10,
        Place.tens => (number ~/ 10) % 10,
        Place.ones => number % 10,
      };

  @override
  String get key => 'pv:$number:${place.name}';
  @override
  String get prompt => 'How many ${place.name.toUpperCase()} in $number?';
  @override
  String get speech => 'How many ${place.name} are in ${NumberWords.of(number)}?';
}

/// "Bigger or smaller?" — tap the bigger (or smaller) of two numbers.
class ComparisonQuestion extends NumberQuestion {
  /// In the order shown.
  final int a;
  final int b;
  final bool askBigger;

  const ComparisonQuestion({required this.a, required this.b, required this.askBigger});

  int get answer => askBigger ? (a > b ? a : b) : (a < b ? a : b);
  List<int> get options => [a, b];

  @override
  String get key {
    final lo = a < b ? a : b, hi = a < b ? b : a;
    return 'compare:${askBigger ? 'big' : 'small'}:$lo:$hi';
  }

  @override
  String get prompt => askBigger ? 'Which number is BIGGER?' : 'Which number is SMALLER?';
  @override
  String get speech => askBigger ? 'Which number is bigger?' : 'Which number is smaller?';
}

// ── Numbers hub practice: EduPlay + Encoding, Reading ───────────────────

/// Spell Number Words — see a digit, build its English word from letter
/// [tiles] (the word's own letters plus distractors, each used once).
class SpellWordQuestion extends NumberQuestion {
  final int value;

  /// e.g. "fifteen", "one hundred" (a space is a gap, not a tile).
  final String word;
  final List<String> tiles;

  const SpellWordQuestion({required this.value, required this.word, required this.tiles});

  /// The word's letters in order, without spaces.
  List<String> get letters => word.replaceAll(' ', '').split('');

  /// Letter-slot indices that are followed by a word gap ("one|hundred").
  Set<int> get gapsAfter {
    final out = <int>{};
    var n = 0;
    for (final ch in word.split('')) {
      if (ch == ' ') {
        out.add(n - 1);
      } else {
        n++;
      }
    }
    return out;
  }

  @override
  String get key => 'spell:$value';
  @override
  String get prompt => 'Spell this number';
  @override
  String get speech => 'Spell $word';
}

/// Templates for Read & Answer sentences.
enum SentenceTemplate {
  /// "Sam has 3 balls."
  one,

  /// "Sam has 3 red balls and 2 blue balls."
  colours,

  /// "Sam sees 3 cats and 2 birds."
  twoObjects,
}

/// Which number the Read & Answer question asks for.
enum SentenceAsk { total, first, second }

/// Read & Answer — a short generated number sentence, read aloud with each
/// word highlighted, then one question with 4 options.
class ReadAnswerQuestion extends NumberQuestion {
  final SentenceTemplate template;
  final String name;
  final NumberObject object;

  /// Second object (twoObjects only).
  final NumberObject? object2;

  /// Colours (colours only).
  final String? colour1;
  final String? colour2;
  final int a;

  /// Second number (colours / twoObjects); null for one.
  final int? b;
  final SentenceAsk ask;
  final List<int> options;

  const ReadAnswerQuestion({
    required this.template,
    required this.name,
    required this.object,
    this.object2,
    this.colour1,
    this.colour2,
    required this.a,
    this.b,
    required this.ask,
    required this.options,
  });

  /// Every number written in the sentence.
  List<int> get numbers => [a, ?b];

  int get answer => switch (ask) {
        SentenceAsk.total => a + (b ?? 0),
        SentenceAsk.first => a,
        SentenceAsk.second => b ?? 0,
      };

  String get sentence => switch (template) {
        SentenceTemplate.one => '$name has $a ${object.forCount(a)}.',
        SentenceTemplate.colours =>
          '$name has $a $colour1 ${object.forCount(a)} and $b $colour2 ${object.forCount(b!)}.',
        SentenceTemplate.twoObjects =>
          '$name sees $a ${object.forCount(a)} and $b ${object2!.forCount(b!)}.',
      };

  String get question => switch ((template, ask)) {
        (SentenceTemplate.one, _) => 'How many ${object.plural} does $name have?',
        (SentenceTemplate.colours, SentenceAsk.total) => 'How many ${object.plural}?',
        (SentenceTemplate.colours, SentenceAsk.first) => 'How many $colour1 ${object.plural}?',
        (SentenceTemplate.colours, SentenceAsk.second) => 'How many $colour2 ${object.plural}?',
        (SentenceTemplate.twoObjects, SentenceAsk.second) => 'How many ${object2!.plural}?',
        (SentenceTemplate.twoObjects, _) => 'How many ${object.plural}?',
      };

  @override
  String get key => 'read:${template.name}:${object.singular}:$a:${b ?? '-'}:${ask.name}';
  @override
  String get prompt => question;
  @override
  String get speech => '$sentence $question';
  @override
  bool get speaksItself => true;
}
