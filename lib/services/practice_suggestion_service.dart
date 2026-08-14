import '../data/cross_language_phoneme_map.dart';
import '../data/substitution_tips.dart';
import '../data/word_data.dart';
import 'session_logger.dart';

class PracticeSuggestion {
  final String expectedSound;
  final String producedSound;
  final String language; // 'en' | 'si'
  final int occurrences;
  final String tip;
  final List<WordItem> practiceWords;

  const PracticeSuggestion({
    required this.expectedSound,
    required this.producedSound,
    required this.language,
    required this.occurrences,
    required this.tip,
    required this.practiceWords,
  });
}

/// Turns confirmed substitution patterns (SessionLogger.getTopSubstitutionPatterns
/// — already threshold-filtered PEPA data) into parent-facing practice
/// suggestions: a hand-written tip (substitution_tips.dart) plus a handful
/// of existing app words that contain the target sound.
///
/// Deliberately no AI call and no invented words — the tip table is a
/// static hardcoded lookup, and practice words are filtered from
/// WordData's existing grade 3/4 lists. A detected pattern with no
/// matching tip is silently skipped, not given a generic fallback tip.
class PracticeSuggestionService {
  PracticeSuggestionService._();

  // Target range is 4-6 per the spec; if the word bank has fewer than 4
  // containing the sound, showing what's available beats inventing words.
  static const int _maxPracticeWords = 6;

  // Longest sinhalaSoundKey first, same approach as CrossLanguageAnalyzer,
  // so e.g. a 'tʃiː' token resolves to 'tʃ' rather than 't'.
  static final List<String> _sinhalaSoundKeysBySpecificity =
      crossLanguagePhonemeMap.map((m) => m.sinhalaSoundKey).toList()
        ..sort((a, b) => b.length.compareTo(a.length));

  static Future<List<PracticeSuggestion>> getSuggestions({
    required String profileName,
  }) async {
    final patterns = await SessionLogger.getTopSubstitutionPatterns(
      profileName: profileName,
    );

    final suggestions = <PracticeSuggestion>[];
    for (final row in patterns) {
      final expected = row['expected_phoneme'] as String;
      final produced = row['produced_phoneme'] as String;
      final language = row['language'] as String;
      final occurrences = row['occurrences'] as int;

      final expectedKey = language == 'si' ? _resolveSinhalaSoundKey(expected) : expected;
      final producedKey = language == 'si' ? _resolveSinhalaSoundKey(produced) : produced;
      if (expectedKey == null || producedKey == null) continue;

      final tip = _findTip(language, expectedKey, producedKey);
      if (tip == null) continue;

      final words = _practiceWordsFor(language: language, soundKey: expectedKey);

      suggestions.add(PracticeSuggestion(
        expectedSound: expected,
        producedSound: produced,
        language: language,
        occurrences: occurrences,
        tip: tip,
        practiceWords: words,
      ));
    }
    return suggestions;
  }

  static String? _findTip(String language, String expectedKey, String producedKey) {
    for (final t in substitutionTips) {
      if (t.language == language &&
          t.expectedSound == expectedKey &&
          t.producedSound == producedKey) {
        return t.tip;
      }
    }
    return null;
  }

  static String? _resolveSinhalaSoundKey(String token) {
    for (final key in _sinhalaSoundKeysBySpecificity) {
      if (token.startsWith(key)) return key;
    }
    return null;
  }

  /// Resolves a raw Sinhala phoneme token (e.g. 'rə') to its Sinhala script
  /// letter (e.g. 'ර') for child-friendly display. Returns null if no
  /// mapping exists (English phonemes should just be shown as-is).
  static String? sinhalaScriptFor(String phoneme) {
    final key = _resolveSinhalaSoundKey(phoneme);
    if (key == null) return null;
    for (final m in crossLanguagePhonemeMap) {
      if (m.sinhalaSoundKey == key) return m.sinhalaScript;
    }
    return null;
  }

  /// Public entry point so other features (e.g. the Assigned Practice
  /// child-side session) can reuse the exact same word-filtering rules
  /// used for Practice Suggestions, instead of re-implementing them.
  /// [phoneme] is the raw phoneme/token as stored in an AssignedPractice
  /// record (an IPA symbol for English, or a Sinhala romanized token).
  static List<WordItem> wordsForPhoneme({
    required String language,
    required String phoneme,
  }) {
    final soundKey = language == 'si' ? _resolveSinhalaSoundKey(phoneme) : phoneme;
    if (soundKey == null) return [];
    return _practiceWordsFor(language: language, soundKey: soundKey);
  }

  /// Existing words (grade 3 + grade 4, no invented content) whose phoneme
  /// list contains the target sound. English: exact IPA-symbol match.
  /// Sinhala: prefix match, since word_data.dart's Sinhala phonemes are
  /// romanized syllable chunks (e.g. 'rə'), not bare consonant letters.
  static List<WordItem> _practiceWordsFor({
    required String language,
    required String soundKey,
  }) {
    final words = WordData.allWordsForLanguage(language);
    final matches = words.where((w) => w.phonemes.any((p) =>
        language == 'si' ? p.startsWith(soundKey) : p == soundKey));

    // De-dupe by word text (same word can appear in multiple grade lists).
    final seen = <String>{};
    final result = <WordItem>[];
    for (final w in matches) {
      if (seen.add(w.word)) result.add(w);
      if (result.length >= _maxPracticeWords) break;
    }
    return result;
  }
}
