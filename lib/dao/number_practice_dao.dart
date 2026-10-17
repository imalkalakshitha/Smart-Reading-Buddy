import 'package:sqflite/sqflite.dart';
import '../services/session_logger.dart';

/// DAO for the Numbers practice table (number_practice_attempts), added to
/// the shared reading_buddy.db in schema version 18 — see
/// session_logger.dart's _createTables / onUpgrade oldVersion < 18 branch.
///
/// Uses SessionLogger.database (the app's one shared Database connection),
/// matching timed_reading_dao.dart / free_drawing_dao.dart. Only ever
/// touches number_practice_attempts.
class NumberPracticeDao {
  static Future<Database> get _db => SessionLogger.database;

  static const activityNumberWord = 'number_word';
  static const activityRapidDigitNaming = 'rapid_digit_naming';

  /// One Number Word attempt. [score] is 0.0–1.0 (stars / 3).
  /// [responseMs] is mic tap → first speech-to-text partial result, when
  /// one arrived.
  static Future<void> saveNumberWordAttempt({
    required String profileName,
    required String levelKey,
    required String item,
    required String? recognizedText,
    required String verdict,
    required double score,
    required int? responseMs,
    required bool teenTyError,
    required int attemptNumber,
  }) async {
    final db = await _db;
    await db.insert('number_practice_attempts', {
      'profile_name': profileName,
      'activity_type': activityNumberWord,
      'level_key': levelKey,
      'item': item,
      'recognized_text': recognizedText,
      'verdict': verdict,
      'score': score,
      'time_ms': responseMs,
      'digits_correct': null,
      'error_count': null,
      'teen_ty_error': teenTyError ? 1 : 0,
      'attempt_number': attemptNumber,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// One completed Rapid Digit Naming grid. [grid] is the 5 rows joined
  /// with '/', e.g. "3718.../...". [score] is digitsCorrect / total.
  static Future<void> saveRapidDigitNaming({
    required String profileName,
    required String grid,
    required String recognizedText,
    required double score,
    required int totalMs,
    required int digitsCorrect,
    required int errorCount,
  }) async {
    final db = await _db;
    await db.insert('number_practice_attempts', {
      'profile_name': profileName,
      'activity_type': activityRapidDigitNaming,
      'level_key': null,
      'item': grid,
      'recognized_text': recognizedText,
      'verdict': null,
      'score': score,
      'time_ms': totalMs,
      'digits_correct': digitsCorrect,
      'error_count': errorCount,
      'teen_ty_error': 0,
      'attempt_number': null,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Most recent attempts for [profileName], newest first.
  static Future<List<Map<String, Object?>>> getAttempts({
    required String profileName,
    String? activityType,
    int limit = 100,
  }) async {
    final db = await _db;
    return db.query(
      'number_practice_attempts',
      where: activityType == null
          ? 'profile_name = ?'
          : 'profile_name = ? AND activity_type = ?',
      whereArgs: activityType == null ? [profileName] : [profileName, activityType],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  /// How many Number Word attempts were -teen/-ty confusions.
  static Future<int> countTeenTyErrors(String profileName) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM number_practice_attempts '
      'WHERE profile_name = ? AND teen_ty_error = 1',
      [profileName],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
