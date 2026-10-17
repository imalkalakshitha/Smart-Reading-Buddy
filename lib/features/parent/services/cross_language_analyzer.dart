import 'package:smart_reading_buddy/core/data/cross_language_phoneme_map.dart';
import 'package:smart_reading_buddy/core/services/session_logger.dart';

/// One flagged Sinhala/English phoneme pair where the child struggles with
/// both sides.
class CrossLanguagePattern {
  final PhonemeMapping mapping;
  final double sinhalaErrorRate;
  final double englishErrorRate;
  final int sinhalaAttempts;
  final int englishAttempts;

  const CrossLanguagePattern({
    required this.mapping,
    required this.sinhalaErrorRate,
    required this.englishErrorRate,
    required this.sinhalaAttempts,
    required this.englishAttempts,
  });
}

/// Cross-language phoneme transfer analysis, built on top of the existing
/// PEPA phoneme-attempt log (SessionLogger.getPhonemeStats).
///
/// For each Sinhala/English phoneme pair in [crossLanguagePhonemeMap], this
/// checks whether the child struggles with BOTH sides — a signal that the
/// difficulty is a shared articulatory pattern rather than two unrelated
/// language-specific issues.
class CrossLanguageAnalyzer {
  /// A phoneme is considered "struggling" at this error rate, matching the
  /// same rough cutoff PEPA's trouble-sounds list already sorts around
  /// (majority-wrong on that sound). Below [_minAttempts] samples the error
  /// rate is too noisy to draw a conclusion from, so it's skipped.
  static const double _strugglingThreshold = 0.4;
  static const int _minAttempts = 3;

  // Longest sinhalaSoundKey first, so e.g. 'tʃ' is tried before 't'.
  static final List<PhonemeMapping> _mappingsBySpecificity =
      List<PhonemeMapping>.from(crossLanguagePhonemeMap)
        ..sort((a, b) => b.sinhalaSoundKey.length.compareTo(a.sinhalaSoundKey.length));

  /// Returns cross-language difficulty patterns flagged for [profileName],
  /// using only real data already recorded in SQLite via PEPA.
  static Future<List<CrossLanguagePattern>> analyze({
    required String profileName,
  }) async {
    final siStats = await SessionLogger.getPhonemeStats(
      profileName: profileName,
      language: 'si',
    );
    final enStats = await SessionLogger.getPhonemeStats(
      profileName: profileName,
      language: 'en',
    );

    // English phonemes are logged as exact single IPA symbols, so index
    // them directly.
    final enByPhoneme = <String, Map<String, dynamic>>{
      for (final row in enStats) row['phoneme'] as String: row,
    };

    final patterns = <CrossLanguagePattern>[];

    for (final mapping in crossLanguagePhonemeMap) {
      // Aggregate all Sinhala phoneme tokens whose consonant sound matches
      // this mapping (tokens are romanized syllable chunks like 'rə', not
      // single letters, so match by prefix rather than exact equality).
      var siTotal = 0;
      var siIncorrect = 0;
      for (final row in siStats) {
        final token = row['phoneme'] as String;
        if (_matchesSound(token, mapping.sinhalaSoundKey)) {
          siTotal += row['total'] as int;
          siIncorrect += row['incorrect'] as int;
        }
      }

      final enRow = enByPhoneme[mapping.englishPhoneme];
      final enTotal = enRow == null ? 0 : enRow['total'] as int;
      final enIncorrect = enRow == null ? 0 : enRow['incorrect'] as int;

      if (siTotal < _minAttempts || enTotal < _minAttempts) continue;

      final siRate = siIncorrect / siTotal;
      final enRate = enIncorrect / enTotal;

      if (siRate >= _strugglingThreshold && enRate >= _strugglingThreshold) {
        patterns.add(CrossLanguagePattern(
          mapping: mapping,
          sinhalaErrorRate: siRate,
          englishErrorRate: enRate,
          sinhalaAttempts: siTotal,
          englishAttempts: enTotal,
        ));
      }
    }

    // Worst combined difficulty first.
    patterns.sort((a, b) => (b.sinhalaErrorRate + b.englishErrorRate)
        .compareTo(a.sinhalaErrorRate + a.englishErrorRate));

    return patterns;
  }

  /// A Sinhala phoneme token "matches" a consonant sound if it starts with
  /// that sound — checked against the longest (most specific) keys first
  /// so e.g. a 'tʃiː' token matches the 'tʃ' mapping, not 't'.
  static bool _matchesSound(String token, String soundKey) {
    if (!token.startsWith(soundKey)) return false;
    for (final other in _mappingsBySpecificity) {
      if (other.sinhalaSoundKey.length > soundKey.length &&
          token.startsWith(other.sinhalaSoundKey)) {
        return false; // a more specific mapping owns this token
      }
    }
    return true;
  }
}
