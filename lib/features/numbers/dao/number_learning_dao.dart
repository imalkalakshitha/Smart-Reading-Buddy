import 'package:sqflite/sqflite.dart';
import 'package:smart_reading_buddy/features/numbers/services/level_config.dart';
import 'package:smart_reading_buddy/core/services/session_logger.dart';

/// DAO for Number Learning's one table (number_learning_attempts), added to
/// the shared reading_buddy.db in schema version 19 — see session_logger.dart's
/// _createTables / onUpgrade oldVersion < 19 branch.
///
/// One row per question, written when the question resolves (answered
/// correctly, or revealed after the last try). A session is the rows that
/// share a session_id; its score is SUM(score).
class NumberLearningDao {
  static Future<Database> get _db => SessionLogger.database;

  static Future<void> saveAttempt({
    required String profileName,
    required String sessionId,
    required LevelConfig level,
    required int questionIndex,
    required String questionKey,
    required bool correct,
    required int attempts,
    required int timeMs,
    required int score,
    // Overrides level.grade — practice activities (grade 0) pass the
    // child's own grade.
    int? grade,
  }) async {
    final db = await _db;
    await db.insert('number_learning_attempts', {
      'profile_name': profileName,
      'session_id': sessionId,
      'grade': grade ?? level.grade,
      'track': level.track,
      'level_id': level.id,
      'level_number': level.level,
      'activity_type': level.activityType,
      'question_index': questionIndex,
      'question_key': questionKey,
      'correct': correct ? 1 : 0,
      'attempts': attempts,
      'time_ms': timeMs,
      'score': score,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Best score per level, counting only completed sessions (all
  /// [questionsPerSession] questions answered).
  static Future<Map<String, int>> bestScores(
    String profileName, {
    int questionsPerSession = 10,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT level_id, MAX(session_score) AS best FROM (
        SELECT level_id, session_id, SUM(score) AS session_score, COUNT(*) AS n
        FROM number_learning_attempts
        WHERE profile_name = ?
        GROUP BY level_id, session_id
        HAVING n >= ?
      ) GROUP BY level_id
    ''', [profileName, questionsPerSession]);
    return {
      for (final r in rows) r['level_id'] as String: (r['best'] as int?) ?? 0,
    };
  }

  /// Question keys from the child's last [sessions] sessions of [levelId]
  /// (finished or not) — used to avoid repeating questions.
  static Future<Set<String>> recentQuestionKeys(
    String profileName,
    String levelId, {
    int sessions = 2,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT question_key FROM number_learning_attempts
      WHERE profile_name = ? AND level_id = ? AND session_id IN (
        SELECT session_id FROM number_learning_attempts
        WHERE profile_name = ? AND level_id = ?
        GROUP BY session_id
        ORDER BY MAX(timestamp) DESC
        LIMIT ?
      )
    ''', [profileName, levelId, profileName, levelId, sessions]);
    return {for (final r in rows) r['question_key'] as String};
  }
}
