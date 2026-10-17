/// Hand-built Sinhala ↔ English phoneme similarity map, based on
/// articulatory place/manner of articulation.
///
/// [sinhalaScript] is the Sinhala consonant letter, shown to parents.
/// [sinhalaSoundKey] is the romanized consonant sound as it actually
/// appears at the start of the phoneme tokens logged by PEPA for Sinhala
/// words (see lib/data/word_data.dart — Sinhala "phonemes" are romanized
/// syllable chunks like 'rə', 'tə', 'ni', not single Sinhala letters), so
/// this is what CrossLanguageAnalyzer matches logged tokens against.
/// [englishPhoneme] is the exact IPA symbol logged for English words in
/// word_data.dart (e.g. 'r', 'tʃ', 'θ') — must match verbatim since
/// English phonemes are already logged as single IPA symbols.
class PhonemeMapping {
  final String sinhalaScript;
  final String sinhalaSoundKey;
  final String englishPhoneme;
  final String similarityNote;

  const PhonemeMapping({
    required this.sinhalaScript,
    required this.sinhalaSoundKey,
    required this.englishPhoneme,
    required this.similarityNote,
  });
}

/// Only covers phonemes that actually occur in the current PEPA data set
/// (see word_data.dart's `phonemes` lists for both languages) — no
/// invented categories.
const List<PhonemeMapping> crossLanguagePhonemeMap = [
  PhonemeMapping(
    sinhalaScript: 'ර',
    sinhalaSoundKey: 'r',
    englishPhoneme: 'r',
    similarityNote: 'both alveolar approximants',
  ),
  PhonemeMapping(
    sinhalaScript: 'ට',
    sinhalaSoundKey: 't',
    englishPhoneme: 't',
    similarityNote: 'both voiceless alveolar stops',
  ),
  PhonemeMapping(
    sinhalaScript: 'ද',
    sinhalaSoundKey: 'd',
    englishPhoneme: 'd',
    similarityNote: 'both voiced alveolar stops',
  ),
  PhonemeMapping(
    sinhalaScript: 'ස',
    sinhalaSoundKey: 's',
    englishPhoneme: 's',
    similarityNote: 'both voiceless alveolar fricatives',
  ),
  PhonemeMapping(
    sinhalaScript: 'ච',
    sinhalaSoundKey: 'tʃ',
    englishPhoneme: 'tʃ',
    similarityNote: 'both voiceless postalveolar affricates',
  ),
  PhonemeMapping(
    sinhalaScript: 'ල',
    sinhalaSoundKey: 'l',
    englishPhoneme: 'l',
    similarityNote: 'both alveolar laterals',
  ),
  PhonemeMapping(
    sinhalaScript: 'න',
    sinhalaSoundKey: 'n',
    englishPhoneme: 'n',
    similarityNote: 'both alveolar nasals',
  ),
  PhonemeMapping(
    sinhalaScript: 'ම',
    sinhalaSoundKey: 'm',
    englishPhoneme: 'm',
    similarityNote: 'both bilabial nasals',
  ),
  PhonemeMapping(
    sinhalaScript: 'ක',
    sinhalaSoundKey: 'k',
    englishPhoneme: 'k',
    similarityNote: 'both voiceless velar stops',
  ),
  PhonemeMapping(
    sinhalaScript: 'ග',
    sinhalaSoundKey: 'g',
    englishPhoneme: 'g',
    similarityNote: 'both voiced velar stops',
  ),
  PhonemeMapping(
    sinhalaScript: 'ප',
    sinhalaSoundKey: 'p',
    englishPhoneme: 'p',
    similarityNote: 'both voiceless bilabial stops',
  ),
  PhonemeMapping(
    sinhalaScript: 'බ',
    sinhalaSoundKey: 'b',
    englishPhoneme: 'b',
    similarityNote: 'both voiced bilabial stops',
  ),
  PhonemeMapping(
    sinhalaScript: 'හ',
    sinhalaSoundKey: 'h',
    englishPhoneme: 'h',
    similarityNote: 'both voiceless glottal fricatives',
  ),
];
