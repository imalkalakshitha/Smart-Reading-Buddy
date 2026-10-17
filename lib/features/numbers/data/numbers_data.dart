/// Numbers practice (Pronunciation module) — ENGLISH ONLY.
///
/// When the app language is Sinhala the feature is still shown, with a
/// short "English only" note (see numbers_hub_screen.dart) — it is never
/// hidden. No Sinhala number words live here: per this project's rule,
/// Sinhala Unicode text is never hand-typed, only taken from the verified
/// transcription pipeline.
class NumberItem {
  final int value;

  /// Display/word form, e.g. "fifteen", "twenty-one", "one hundred".
  final String word;

  const NumberItem(this.value, this.word);

  String get digits => '$value';

  /// Word form as speech-to-text would spell it ("twenty one", no hyphen).
  String get spokenWord => word.replaceAll('-', ' ');
}

/// One -teen/-ty confusable pair, e.g. 15/50.
class ConfusablePair {
  final int teen;
  final int ty;

  const ConfusablePair(this.teen, this.ty);
}

class NumbersData {
  NumbersData._();

  static const _units = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
    'sixteen', 'seventeen', 'eighteen', 'nineteen',
  ];

  static const _tens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
    'eighty', 'ninety',
  ];

  /// English word for 0–100, or null outside that range.
  static String? wordFor(int n) {
    if (n < 0 || n > 100) return null;
    if (n == 100) return 'one hundred';
    if (n < 20) return _units[n];
    final ones = n % 10;
    return ones == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]}-${_units[ones]}';
  }

  /// All numbers 0–100 (digit + English word).
  static final List<NumberItem> all =
      List.generate(101, (n) => NumberItem(n, wordFor(n)!));

  static NumberItem item(int n) => all[n];

  // ── Confusable -teen / -ty pairs ──────────────────────────────────────

  static const List<ConfusablePair> confusablePairs = [
    ConfusablePair(13, 30),
    ConfusablePair(14, 40),
    ConfusablePair(15, 50),
    ConfusablePair(16, 60),
    ConfusablePair(17, 70),
    ConfusablePair(18, 80),
    ConfusablePair(19, 90),
  ];

  /// The other half of [n]'s confusable pair (15 → 50, 50 → 15), or null.
  static int? confusablePartner(int n) {
    for (final p in confusablePairs) {
      if (p.teen == n) return p.ty;
      if (p.ty == n) return p.teen;
    }
    return null;
  }

  /// Stress-marked syllables for the tip, e.g. 15 → "fif-TEEN",
  /// 50 → "FIF-ty". Only defined for numbers in [confusablePairs].
  static const Map<int, String> stressSyllables = {
    13: 'thir-TEEN', 30: 'THIR-ty',
    14: 'four-TEEN', 40: 'FOR-ty',
    15: 'fif-TEEN',  50: 'FIF-ty',
    16: 'six-TEEN',  60: 'SIX-ty',
    17: 'seven-TEEN', 70: 'SEV-en-ty',
    18: 'eigh-TEEN', 80: 'EIGH-ty',
    19: 'nine-TEEN', 90: 'NINE-ty',
  };

  // ── Levels ─────────────────────────────────────────────────────────────

  static const levelZeroToTen = 'numbers_0_10';
  static const levelElevenToTwenty = 'numbers_11_20';
  static const levelTens = 'numbers_tens';
  static const levelConfusable = 'numbers_confusable';

  static const List<Map<String, dynamic>> levels = [
    {'key': levelZeroToTen, 'label': 'Numbers 0–10', 'emoji': '🔢', 'stars': 1},
    {'key': levelElevenToTwenty, 'label': 'Numbers 11–20', 'emoji': '🎈', 'stars': 2},
    {'key': levelTens, 'label': 'Tens 20–100', 'emoji': '🚀', 'stars': 2},
    {'key': levelConfusable, 'label': 'Teen or Ty?', 'emoji': '👂', 'stars': 3},
  ];

  /// Items for a level, in a fresh list (callers may shuffle it).
  static List<NumberItem> forLevel(String key) {
    switch (key) {
      case levelZeroToTen:
        return [for (var n = 0; n <= 10; n++) all[n]];
      case levelElevenToTwenty:
        return [for (var n = 11; n <= 20; n++) all[n]];
      case levelTens:
        return [for (var n = 20; n <= 100; n += 10) all[n]];
      case levelConfusable:
        return [
          for (final p in confusablePairs) ...[all[p.teen], all[p.ty]],
        ];
      default:
        return [];
    }
  }

  // ── CMU phonemes for number words ─────────────────────────────────────
  // The bundled assets/cmu_phonemes_subset.json only covers word_data.dart's
  // curriculum words, so it has no number words. These entries are copied
  // from the CMU Pronouncing Dictionary (ARPABET, with stress digits) and
  // used as a fallback by NumberAnswerChecker after CmuPhonemeLookup.
  static const Map<String, List<String>> cmuPhonemes = {
    'zero':      ['Z', 'IH1', 'R', 'OW0'],
    'one':       ['W', 'AH1', 'N'],
    'two':       ['T', 'UW1'],
    'three':     ['TH', 'R', 'IY1'],
    'four':      ['F', 'AO1', 'R'],
    'five':      ['F', 'AY1', 'V'],
    'six':       ['S', 'IH1', 'K', 'S'],
    'seven':     ['S', 'EH1', 'V', 'AH0', 'N'],
    'eight':     ['EY1', 'T'],
    'nine':      ['N', 'AY1', 'N'],
    'ten':       ['T', 'EH1', 'N'],
    'eleven':    ['IH0', 'L', 'EH1', 'V', 'AH0', 'N'],
    'twelve':    ['T', 'W', 'EH1', 'L', 'V'],
    'thirteen':  ['TH', 'ER0', 'T', 'IY1', 'N'],
    'fourteen':  ['F', 'AO0', 'R', 'T', 'IY1', 'N'],
    'fifteen':   ['F', 'IH0', 'F', 'T', 'IY1', 'N'],
    'sixteen':   ['S', 'IH0', 'K', 'S', 'T', 'IY1', 'N'],
    'seventeen': ['S', 'EH1', 'V', 'AH0', 'N', 'T', 'IY1', 'N'],
    'eighteen':  ['EY0', 'T', 'IY1', 'N'],
    'nineteen':  ['N', 'AY1', 'N', 'T', 'IY1', 'N'],
    'twenty':    ['T', 'W', 'EH1', 'N', 'T', 'IY0'],
    'thirty':    ['TH', 'ER1', 'D', 'IY0'],
    'forty':     ['F', 'AO1', 'R', 'T', 'IY0'],
    'fifty':     ['F', 'IH1', 'F', 'T', 'IY0'],
    'sixty':     ['S', 'IH1', 'K', 'S', 'T', 'IY0'],
    'seventy':   ['S', 'EH1', 'V', 'AH0', 'N', 'T', 'IY0'],
    'eighty':    ['EY1', 'T', 'IY0'],
    'ninety':    ['N', 'AY1', 'N', 'T', 'IY0'],
    'hundred':   ['HH', 'AH1', 'N', 'D', 'R', 'AH0', 'D'],
  };
}
