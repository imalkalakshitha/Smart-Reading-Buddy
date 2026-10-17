/// Building blocks for Read & Answer number sentences (Numbers hub,
/// Reading section) — ENGLISH ONLY. QuestionGenerator combines these with
/// rule-based templates; no sentence is stored whole.
///
/// Words are short, regular and easy to decode: one-syllable objects with
/// a plain "-s" plural, basic colours, and short names.
class NumberObject {
  final String singular;
  final String plural;

  const NumberObject(this.singular, this.plural);

  String forCount(int n) => n == 1 ? singular : plural;
}

class NumberSentenceData {
  NumberSentenceData._();

  static const names = ['Sam', 'Ravi', 'Nila', 'Amal', 'Mia', 'Tom', 'Dilan', 'Kasun'];

  static const objects = [
    NumberObject('ball', 'balls'),
    NumberObject('cat', 'cats'),
    NumberObject('book', 'books'),
    NumberObject('pen', 'pens'),
    NumberObject('cup', 'cups'),
    NumberObject('hat', 'hats'),
    NumberObject('car', 'cars'),
    NumberObject('bird', 'birds'),
    NumberObject('apple', 'apples'),
  ];

  static const colours = ['red', 'blue', 'green', 'yellow'];
}
