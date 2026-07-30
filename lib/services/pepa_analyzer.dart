import '../models/phoneme_data.dart';
import 'session_logger.dart';

/// PEPA — Pronunciation Error Pattern Analysis.
///
/// Reads from the phoneme_attempts table (populated after each session) and
/// surfaces which sounds a child struggles with, which they've mastered, and
/// generates a parent-friendly weekly report.
class PhonemeStats {
  final String phoneme;
  final String language;
  final int    totalAttempts;
  final int    incorrectAttempts;
  final double errorRate; // 0–100

  const PhonemeStats({
    required this.phoneme,
    required this.language,
    required this.totalAttempts,
    required this.incorrectAttempts,
    required this.errorRate,
  });

  /// Flagged when error rate ≥ 40 % AND at least 3 data points.
  bool get isFlagged => errorRate >= 40.0 && totalAttempts >= 3;

  String get displayName => PhonemeData.displayName(phoneme);
}

class PEPAReport {
  final String          profileName;
  final int             totalWordsAttempted;
  final List<PhonemeStats> allStats;
  final List<PhonemeStats> flagged; // error rate ≥ 40 %, ≥ 3 attempts
  final List<PhonemeStats> strong;  // error rate < 20 %, ≥ 3 attempts

  const PEPAReport({
    required this.profileName,
    required this.totalWordsAttempted,
    required this.allStats,
    required this.flagged,
    required this.strong,
  });

  bool get hasData => allStats.isNotEmpty;
}

class PEPAAnalyzer {
  PEPAAnalyzer._();

  /// Generate a report for [profileName] covering the last [days] days.
  static Future<PEPAReport> generateReport({
    required String profileName,
    int days = 7,
  }) async {
    final raw = await SessionLogger.getPhonemeStats(
      profileName: profileName,
      lastNDays:   days,
    );

    final stats = raw.map((r) {
      final total     = r['total']     as int;
      final incorrect = r['incorrect'] as int;
      return PhonemeStats(
        phoneme:           r['phoneme']  as String,
        language:          r['language'] as String,
        totalAttempts:     total,
        incorrectAttempts: incorrect,
        errorRate:         total > 0 ? incorrect / total * 100 : 0.0,
      );
    }).toList();

    final flagged = stats
        .where((s) => s.isFlagged)
        .toList()
      ..sort((a, b) => b.errorRate.compareTo(a.errorRate));

    final strong = stats
        .where((s) => s.errorRate < 20.0 && s.totalAttempts >= 3)
        .toList()
      ..sort((a, b) => a.errorRate.compareTo(b.errorRate));

    final wordCount = await SessionLogger.getPhonemeWordCount(
      profileName: profileName,
      lastNDays:   days,
    );

    return PEPAReport(
      profileName:         profileName,
      totalWordsAttempted: wordCount,
      allStats:            stats,
      flagged:             flagged,
      strong:              strong,
    );
  }
}
