import 'package:sqflite/sqflite.dart';
import 'package:smart_reading_buddy/core/services/session_logger.dart';

/// DAO for the Free Drawing Recognition module's one table
/// (free_drawing_attempts), added to the shared reading_buddy.db in
/// schema version 12 — see session_logger.dart's _createTables /
/// onUpgrade oldVersion < 12 branch for the CREATE TABLE statement this
/// class assumes exists.
///
/// Uses SessionLogger.database (the app's one shared Database connection)
/// rather than opening a second connection to the same file, matching
/// timed_reading_dao.dart's pattern. Only ever touches free_drawing_attempts.
class FreeDrawingDao {
  static Future<Database> get _db => SessionLogger.database;

  /// Logs one drawing attempt — always the raw numbers, regardless of
  /// what the child was shown. [levelType] is currently always 'letter'
  /// (Word Level was dropped); target_word/slot_index stay in the schema
  /// as unused nullable columns rather than forcing another migration.
  static Future<void> saveAttempt({
    required String profileName,
    required String levelType,
    required String language,
    required String targetCharacter,
    required String top1Prediction,
    required double top1Confidence,
    required double pTarget,
    required int targetRank,
    required bool accepted,
    required int attemptNumber,
    String? rejectionReason,
  }) async {
    final db = await _db;
    await db.insert('free_drawing_attempts', {
      'profile_name': profileName,
      'timestamp': DateTime.now().toIso8601String(),
      'level_type': levelType,
      'language': language,
      'target_character': targetCharacter,
      'target_word': null,
      'slot_index': null,
      'top1_prediction': top1Prediction,
      'top1_confidence': top1Confidence,
      'p_target': pTarget,
      'target_rank': targetRank,
      'accepted': accepted ? 1 : 0,
      'attempt_number': attemptNumber,
      'rejection_reason': rejectionReason,
    });
  }

  /// 1-based attempt number for [profileName] on [targetCharacter] within
  /// [levelType] — counts every attempt ever logged for that character,
  /// not just the current visit, so the number keeps climbing across
  /// separate sessions the same way Pronunciation's attempt numbering
  /// does within a session.
  static Future<int> nextAttemptNumber({
    required String profileName,
    required String levelType,
    required String targetCharacter,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM free_drawing_attempts '
      'WHERE profile_name = ? AND level_type = ? AND target_character = ?',
      [profileName, levelType, targetCharacter],
    );
    return ((rows.first['cnt'] as int?) ?? 0) + 1;
  }

  /// Characters [profileName] has at least one accepted attempt for, in
  /// [language] — the Letter Picker's star/tick markers. No percentages,
  /// no counts, just "has this one been completed at least once".
  static Future<Set<String>> getCompletedCharacters({
    required String profileName,
    required String language,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT target_character FROM free_drawing_attempts '
      'WHERE profile_name = ? AND level_type = ? AND language = ? AND accepted = 1',
      [profileName, 'letter', language],
    );
    return rows.map((r) => r['target_character'] as String).toSet();
  }

  // ── Parent Dashboard ─────────────────────────────────────────────────

  /// "At a glance" summary: distinct letters practised, total attempts,
  /// and how many letters have at least one accepted attempt.
  static Future<({int lettersPractised, int totalAttempts, int lettersCompleted})> getAtAGlance({
    required String profileName,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(DISTINCT target_character) AS letters_practised,
        COUNT(*) AS total_attempts,
        COUNT(DISTINCT CASE WHEN accepted = 1 THEN target_character END) AS letters_completed
      FROM free_drawing_attempts
      WHERE profile_name = ?
    ''', [profileName]);
    final row = rows.first;
    return (
      lettersPractised: (row['letters_practised'] as int?) ?? 0,
      totalAttempts: (row['total_attempts'] as int?) ?? 0,
      lettersCompleted: (row['letters_completed'] as int?) ?? 0,
    );
  }

  /// Which of the last 14 calendar days (oldest first, today last) had at
  /// least one attempt — the "days practised" dot strip.
  static Future<List<bool>> getDaysPractisedLast2Weeks({required String profileName}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT DISTINCT date(timestamp) AS d FROM free_drawing_attempts
      WHERE profile_name = ? AND timestamp >= datetime('now', '-13 days')
    ''', [profileName]);
    final practisedDays = rows.map((r) => r['d'] as String).toSet();

    final today = DateTime.now();
    return [
      for (int i = 13; i >= 0; i--)
        practisedDays.contains(_dateOnly(today.subtract(Duration(days: i)))),
    ];
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Letters ranked by difficulty — average attempts per acceptance
  /// (letters never yet accepted use their raw attempt count, which still
  /// reads as "needs practice"), average p_target as the tiebreaker for
  /// letters with the same average-attempts figure. Capped at [limit] so
  /// the dashboard stays actionable rather than listing every letter.
  static Future<List<LetterDifficulty>> getLetterDifficulty({
    required String profileName,
    required String language,
    int limit = 8,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        target_character,
        COUNT(*) AS total_attempts,
        SUM(CASE WHEN accepted = 1 THEN 1 ELSE 0 END) AS accepted_count,
        AVG(p_target) AS avg_p_target
      FROM free_drawing_attempts
      WHERE profile_name = ? AND language = ? AND level_type = 'letter'
      GROUP BY target_character
    ''', [profileName, language]);

    final items = rows.map((r) {
      final total = r['total_attempts'] as int;
      final acceptedCount = (r['accepted_count'] as int?) ?? 0;
      final avgPTarget = (r['avg_p_target'] as num?)?.toDouble() ?? 0.0;
      final avgAttempts = acceptedCount > 0 ? total / acceptedCount : total.toDouble();
      return LetterDifficulty(
        letter: r['target_character'] as String,
        totalAttempts: total,
        avgAttemptsPerCompletion: avgAttempts,
        avgPTarget: avgPTarget,
        everCompleted: acceptedCount > 0,
      );
    }).toList();

    items.sort((a, b) {
      final byAttempts = b.avgAttemptsPerCompletion.compareTo(a.avgAttemptsPerCompletion);
      if (byAttempts != 0) return byAttempts;
      return a.avgPTarget.compareTo(b.avgPTarget);
    });

    return items.take(limit).toList();
  }

  /// Acceptance rate per calendar day, oldest first — Progress Over Time's
  /// data source.
  static Future<List<({DateTime date, int total, int accepted})>> getAcceptanceTimeline({
    required String profileName,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        date(timestamp) AS d,
        COUNT(*) AS total,
        SUM(CASE WHEN accepted = 1 THEN 1 ELSE 0 END) AS accepted
      FROM free_drawing_attempts
      WHERE profile_name = ?
      GROUP BY date(timestamp)
      ORDER BY d ASC
    ''', [profileName]);
    return rows
        .map((r) => (
              date: DateTime.parse(r['d'] as String),
              total: r['total'] as int,
              accepted: (r['accepted'] as int?) ?? 0,
            ))
        .toList();
  }

  /// Technical-details data (see ParentFreeDrawingAnalyticsScreen's
  /// collapsed "Technical details" section) — not shown to parents by
  /// default, this is model-evaluation data for the research report.
  static Future<TechnicalDetails> getTechnicalDetails({required String profileName}) async {
    final db = await _db;

    final rescuedRows = await db.rawQuery('''
      SELECT COUNT(*) AS cnt FROM free_drawing_attempts
      WHERE profile_name = ? AND accepted = 1 AND top1_prediction != target_character
    ''', [profileName]);
    final rescuedCount = (rescuedRows.first['cnt'] as int?) ?? 0;

    final avgRows = await db.rawQuery('''
      SELECT AVG(p_target) AS avg_p_target, AVG(top1_confidence) AS avg_top1_confidence, COUNT(*) AS total
      FROM free_drawing_attempts WHERE profile_name = ?
    ''', [profileName]);
    final avgRow = avgRows.first;

    final wrongRows = await db.rawQuery('''
      SELECT target_character, top1_prediction, COUNT(*) AS cnt
      FROM free_drawing_attempts
      WHERE profile_name = ? AND top1_prediction != target_character
      GROUP BY target_character, top1_prediction
      ORDER BY cnt DESC
      LIMIT 10
    ''', [profileName]);

    // Scribble/nonsense rejection breakdown (see scribble_guard.dart) — how
    // often each rule fired, for model-evaluation purposes. Rows with a
    // NULL rejection_reason (accepted, or rejected on target-score alone)
    // are excluded by the WHERE clause, not counted as a "reason".
    final rejectionRows = await db.rawQuery('''
      SELECT rejection_reason, COUNT(*) AS cnt
      FROM free_drawing_attempts
      WHERE profile_name = ? AND rejection_reason IS NOT NULL
      GROUP BY rejection_reason
      ORDER BY cnt DESC
    ''', [profileName]);

    return TechnicalDetails(
      rescuedByTargetScoringCount: rescuedCount,
      totalAttempts: (avgRow['total'] as int?) ?? 0,
      avgPTarget: (avgRow['avg_p_target'] as num?)?.toDouble() ?? 0.0,
      avgTop1Confidence: (avgRow['avg_top1_confidence'] as num?)?.toDouble() ?? 0.0,
      commonWrongPredictions: wrongRows
          .map((r) => (
                target: r['target_character'] as String,
                wrongPrediction: r['top1_prediction'] as String,
                count: r['cnt'] as int,
              ))
          .toList(),
      rejectionReasonCounts: {
        for (final r in rejectionRows) r['rejection_reason'] as String: r['cnt'] as int,
      },
    );
  }

  /// For each target character that has at least one NOT-accepted attempt,
  /// the most recent such attempt's raw top-1 prediction and rejection
  /// reason — the Parent Dashboard's "what they wrote instead" view (see
  /// ParentWritingAnalyticsScreen's _NeedsPracticeCard). Pulled entirely
  /// from columns already saved per attempt (top1_prediction,
  /// rejection_reason) — no new tracking, no schema change.
  ///
  /// [wrote] is the raw top1_prediction, meaningful as "what they wrote"
  /// only when the attempt wasn't a scribble rejection (see
  /// scribble_guard.dart) — when [rejectionReason] is non-null, the raw
  /// top-1 guess is not a meaningful "what they wrote" and callers should
  /// show the rejection reason instead (e.g. "unclear drawing"), not the
  /// letter in [wrote].
  static Future<Map<String, ({String wrote, String? rejectionReason})>> getRecentMismatches({
    required String profileName,
    required String language,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT fa.target_character, fa.top1_prediction, fa.rejection_reason
      FROM free_drawing_attempts fa
      WHERE fa.profile_name = ? AND fa.language = ? AND fa.level_type = 'letter' AND fa.accepted = 0
        AND fa.id = (
          SELECT fa2.id FROM free_drawing_attempts fa2
          WHERE fa2.target_character = fa.target_character
            AND fa2.profile_name = fa.profile_name
            AND fa2.language = fa.language
            AND fa2.level_type = 'letter'
            AND fa2.accepted = 0
          ORDER BY fa2.id DESC
          LIMIT 1
        )
    ''', [profileName, language]);

    return {
      for (final r in rows)
        r['target_character'] as String: (
          wrote: r['top1_prediction'] as String,
          rejectionReason: r['rejection_reason'] as String?,
        ),
    };
  }

  /// Every raw attempt row for [profileName], oldest first — CSV export's
  /// data source. Returns plain maps (already exactly the DB columns) so
  /// the export code doesn't need a dedicated model class.
  static Future<List<Map<String, dynamic>>> getAllAttempts({required String profileName}) async {
    final db = await _db;
    return db.query(
      'free_drawing_attempts',
      where: 'profile_name = ?',
      whereArgs: [profileName],
      orderBy: 'timestamp ASC',
    );
  }
}

class LetterDifficulty {
  final String letter;
  final int totalAttempts;
  final double avgAttemptsPerCompletion;
  final double avgPTarget;
  final bool everCompleted;
  const LetterDifficulty({
    required this.letter,
    required this.totalAttempts,
    required this.avgAttemptsPerCompletion,
    required this.avgPTarget,
    required this.everCompleted,
  });
}

class TechnicalDetails {
  final int rescuedByTargetScoringCount;
  final int totalAttempts;
  final double avgPTarget;
  final double avgTop1Confidence;
  final List<({String target, String wrongPrediction, int count})> commonWrongPredictions;
  // Keyed by ScribbleRejectionReason.dbValue (e.g. 'low_peak_confidence'),
  // count of attempts rejected for that reason. Empty map = no scribble
  // rejections logged yet for this profile.
  final Map<String, int> rejectionReasonCounts;
  const TechnicalDetails({
    required this.rescuedByTargetScoringCount,
    required this.totalAttempts,
    required this.avgPTarget,
    required this.avgTop1Confidence,
    required this.commonWrongPredictions,
    this.rejectionReasonCounts = const {},
  });
}
