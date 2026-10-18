import 'package:smart_reading_buddy/core/data/numbers_data.dart';
import 'package:smart_reading_buddy/core/widgets/phoneme_image_widget.dart';

/// One mouth picture in a number word's sequence.
class MouthStep {
  /// CMU (ARPAbet) phoneme, stress digit removed ("IY").
  final String phoneme;

  /// Mouth image asset (one of assets/images/mouth/).
  final String image;

  /// Index into [NumberMouth.syllables].
  final int syllable;

  /// In the stressed syllable ("fif-TEEN" → T IY N).
  final bool stressed;

  const MouthStep(this.phoneme, this.image, this.syllable, {required this.stressed});
}

/// The mouth shapes for saying a number word, from its CMU phonemes
/// (NumbersData.cmuPhonemes), grouped into syllables with the stressed one
/// marked — "fif-TEEN" vs "FIF-ty".
///
/// The picture for each phoneme comes from the shared
/// PhonemeImageWidget.getImageForPhoneme (the same mapping Pronunciation
/// uses), via the IPA symbol for the CMU phoneme.
class NumberMouth {
  final String word;
  final List<String> syllables;

  /// Index of the stressed syllable, or null for a one-syllable word
  /// (nothing to contrast).
  final int? stressedSyllable;
  final List<MouthStep> steps;

  const NumberMouth._(this.word, this.syllables, this.stressedSyllable, this.steps);

  /// The mouth sequence for [n], or null when a word has no phoneme data.
  static NumberMouth? forNumber(int n) {
    final word = NumbersData.wordFor(n);
    if (word == null) return null;
    final parts = word.split(RegExp(r'[ -]'));
    final syllables = <String>[];
    final steps = <MouthStep>[];
    int? stressed;
    for (final part in parts) {
      final phonemes = NumbersData.cmuPhonemes[part];
      if (phonemes == null) return null;
      final split = _syllabify(phonemes);
      final labels = _labels(part, n, split.length);
      final local = labels.stressed ?? _primaryStress(split);
      final offset = syllables.length;
      // Only a word of 2+ syllables has a stress to show; in "one hundred"
      // that's HUN.
      if (split.length > 1) stressed ??= offset + local;
      syllables.addAll(labels.text);
      for (var s = 0; s < split.length; s++) {
        for (final p in split[s]) {
          final base = p.replaceAll(RegExp(r'\d'), '');
          steps.add(MouthStep(base, imageFor(base), offset + s,
              stressed: split.length > 1 && offset + s == stressed));
        }
      }
    }
    return NumberMouth._(word, syllables, stressed, steps);
  }

  /// Mouth image for a CMU phoneme (stress digit optional).
  static String imageFor(String cmu) {
    final base = cmu.replaceAll(RegExp(r'\d'), '').toUpperCase();
    return PhonemeImageWidget.getImageForPhoneme(_ipa[base] ?? base.toLowerCase());
  }

  /// CMU → IPA, so the shared mapping picks the right picture.
  static const _ipa = {
    'AA': 'ɑ', 'AE': 'æ', 'AH': 'ʌ', 'AO': 'ɔː', 'AW': 'aʊ', 'AY': 'aɪ',
    'EH': 'ɛ', 'ER': 'ɜ', 'EY': 'eɪ', 'IH': 'ɪ', 'IY': 'iː', 'OW': 'oʊ',
    'OY': 'ɔɪ', 'UH': 'ʊ', 'UW': 'uː',
    'B': 'b', 'CH': 'tʃ', 'D': 'd', 'DH': 'ð', 'F': 'f', 'G': 'g', 'HH': 'h',
    'JH': 'dʒ', 'K': 'k', 'L': 'l', 'M': 'm', 'N': 'n', 'NG': 'ŋ', 'P': 'p',
    'R': 'ɹ', 'S': 's', 'SH': 'ʃ', 'T': 't', 'TH': 'θ', 'V': 'v',
    // W is said with rounded lips ("one", "twelve", "twenty"); the shared
    // mapping shows a plain 'w' as open-mid, so use a rounded vowel here.
    'W': 'uː',
    'Y': 'j', 'Z': 'z', 'ZH': 'ʒ',
  };

  static bool _isVowel(String p) => RegExp(r'\d$').hasMatch(p);

  /// Splits CMU phonemes into syllables, one vowel each: a lone consonant
  /// between vowels starts the next syllable; in a cluster only the last
  /// consonant does (fif-teen, twen-ty), unless the last two make a usual
  /// onset (hun-dred).
  static List<List<String>> _syllabify(List<String> p) {
    final vowels = [for (var i = 0; i < p.length; i++) if (_isVowel(p[i])) i];
    if (vowels.length <= 1) return [p];
    final starts = <int>[0];
    for (var v = 1; v < vowels.length; v++) {
      final prev = vowels[v - 1];
      final cur = vowels[v];
      final cluster = cur - prev - 1;
      var start = cur;
      if (cluster >= 1) start = cur - 1;
      if (cluster >= 2 && _onsets.contains('${p[cur - 2]} ${p[cur - 1]}')) start = cur - 2;
      starts.add(start);
    }
    return [
      for (var s = 0; s < starts.length; s++)
        p.sublist(starts[s], s + 1 < starts.length ? starts[s + 1] : p.length),
    ];
  }

  static const _onsets = {'D R', 'T R', 'T W', 'TH R', 'B R', 'P R', 'K R', 'G R', 'F R'};

  /// The syllable whose vowel has primary stress (1); the last one when
  /// there are two (seventeen: SEV + TEEN — -teen words stress the end).
  static int _primaryStress(List<List<String>> split) {
    var at = 0;
    for (var s = 0; s < split.length; s++) {
      if (split[s].any((x) => x.endsWith('1'))) at = s;
    }
    return at;
  }

  /// Child-friendly syllable labels. Uses NumbersData.stressSyllables
  /// ("fif-TEEN", the same text as the stress tip) when it splits the word
  /// into the same number of syllables as the phonemes do.
  static ({List<String> text, int? stressed}) _labels(String part, int n, int count) {
    final tip = part == NumbersData.wordFor(n) ? NumbersData.stressSyllables[n] : null;
    final source = (tip != null && tip.split('-').length == count) ? tip : _extraLabels[part];
    if (source == null || source.split('-').length != count) {
      return (text: count == 1 ? [part] : _even(part, count), stressed: null);
    }
    final bits = source.split('-');
    final upper = bits.indexWhere((b) => b == b.toUpperCase() && b != b.toLowerCase());
    return (text: [for (final b in bits) b.toLowerCase()], stressed: upper < 0 ? null : upper);
  }

  /// Labels for the other words of 2+ syllables (stressed part in capitals).
  static const _extraLabels = {
    'zero': 'ZE-ro',
    'seven': 'SEV-en',
    'eleven': 'e-LEV-en',
    'seventeen': 'sev-en-TEEN',
    'twenty': 'TWEN-ty',
    'hundred': 'HUN-dred',
  };

  /// Fallback: the word cut into [count] roughly equal pieces.
  static List<String> _even(String w, int count) {
    final size = (w.length / count).ceil();
    return [
      for (var i = 0; i < w.length; i += size) w.substring(i, i + size > w.length ? w.length : i + size),
    ];
  }
}
