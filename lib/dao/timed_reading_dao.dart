import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../services/session_logger.dart';

/// DAO for the Timed Reading module's two tables (timed_reading_sessions,
/// timed_reading_unit_timings), added to the shared reading_buddy.db in
/// schema version 7 — see session_logger.dart's _createTables /
/// onUpgrade oldVersion < 7 branch for the CREATE TABLE statements this
/// class assumes exist.
///
/// Uses SessionLogger.database (the app's one shared Database connection
/// to reading_buddy.db) rather than opening a second connection to the
/// same file. This class only ever reads/writes the two timed_reading_*
/// tables — never sessions/word_attempts/calibration_data/
/// phoneme_attempts/phoneme_substitutions, which remain SessionLogger's
/// exclusively.
///
/// NOT wired into any screen yet — schema/DAO only, pending approval.
class TimedReadingDao {
  static Future<Database> get _db => SessionLogger.database;

  // ── Insert ────────────────────────────────────────────────────────────

  /// Inserts one completed (or interrupted) Timed Reading session and
  /// returns its new `id` (the FK unit_timings rows must reference).
  static Future<int> insertSession({
    required String profileName,
    required String grade,
    required String language,
    required String level,
    required String contentSetId,
    int? challengeAttemptNumber,
    required DateTime startedAt,
    DateTime? completedAt,
    required bool interrupted,
    required bool accuracyMarked,
    double? wpm,
    double? wcpm,
  }) async {
    final db = await _db;
    return db.insert('timed_reading_sessions', {
      'profile_name': profileName,
      'grade': grade,
      'language': language,
      'level': level,
      'content_set_id': contentSetId,
      'challenge_attempt_number': challengeAttemptNumber,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'interrupted': interrupted ? 1 : 0,
      'accuracy_marked': accuracyMarked ? 1 : 0,
      'wpm': wpm,
      'wcpm': wcpm,
    });
  }

  /// Inserts every unit-timing row for [sessionId] in one batch. Pass one
  /// map per sentence, matching a session's UnitTiming + its SentenceSet
  /// snapshot; auto/finalMisreadIndexes are JSON-encoded here so callers
  /// just pass plain `List<int>?`.
  static Future<void> insertUnitTimings({
    required int sessionId,
    required List<TimedReadingUnitTimingRow> rows,
  }) async {
    if (rows.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final r in rows) {
      batch.insert('timed_reading_unit_timings', {
        'session_id': sessionId,
        'unit_index': r.unitIndex,
        'sentence_id': r.sentenceId,
        'sentence_text_snapshot': r.sentenceTextSnapshot,
        'expected_ms_snapshot': r.expectedMsSnapshot,
        'elapsed_ms': r.elapsedMs,
        'stalled': r.stalled ? 1 : 0,
        'no_speech_detected': r.noSpeechDetected ? 1 : 0,
        'transcript': r.transcript,
        'auto_misread_indexes': r.autoMisreadIndexes == null ? null : jsonEncode(r.autoMisreadIndexes),
        'final_misread_indexes': r.finalMisreadIndexes == null ? null : jsonEncode(r.finalMisreadIndexes),
      });
    }
    await batch.commit(noResult: true);
  }

  // ── Query ─────────────────────────────────────────────────────────────

  /// Most recent sessions for [profileName] + [grade] (Parent Dashboard's
  /// "Recent Sessions" list), newest first.
  static Future<List<Map<String, dynamic>>> getRecentSessions({
    required String profileName,
    required String grade,
    int limit = 10,
  }) async {
    final db = await _db;
    return db.query(
      'timed_reading_sessions',
      where: 'profile_name = ? AND grade = ?',
      whereArgs: [profileName, grade],
      orderBy: 'started_at DESC',
      limit: limit,
    );
  }

  /// Every unit-timing row for one session, in reading order — the
  /// sentence-level breakdown (SentenceReportCard data) for that session.
  static Future<List<Map<String, dynamic>>> getUnitTimingsForSession(int sessionId) async {
    final db = await _db;
    return db.query(
      'timed_reading_unit_timings',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'unit_index ASC',
    );
  }

  /// Past Repeated Reading Challenge attempts for [profileName] on this
  /// exact grade+language+level+contentSetId — challenge_attempt_number
  /// IS NOT NULL is what distinguishes a challenge attempt from a
  /// standalone session. Ordered oldest → newest so callers can show a
  /// 1→2→3 progression (matches RepeatedReadingChallengeScreen's own
  /// attempt ordering).
  static Future<List<Map<String, dynamic>>> getChallengeHistory({
    required String profileName,
    required String grade,
    required String language,
    required String level,
    required String contentSetId,
  }) async {
    final db = await _db;
    return db.query(
      'timed_reading_sessions',
      where: '''
        profile_name = ? AND grade = ? AND language = ? AND level = ?
        AND content_set_id = ? AND challenge_attempt_number IS NOT NULL
      ''',
      whereArgs: [profileName, grade, language, level, contentSetId],
      orderBy: 'challenge_attempt_number ASC',
    );
  }
}

/// Plain data holder for one row passed to [TimedReadingDao.insertUnitTimings]
/// — mirrors timed_reading_unit_timings' columns 1:1 (minus session_id,
/// supplied separately) so callers don't have to build raw maps.
class TimedReadingUnitTimingRow {
  final int unitIndex;
  final String sentenceId;
  final String sentenceTextSnapshot;
  final int expectedMsSnapshot;
  final int elapsedMs;
  final bool stalled;
  final bool noSpeechDetected;
  final String? transcript;
  final List<int>? autoMisreadIndexes;
  final List<int>? finalMisreadIndexes;

  const TimedReadingUnitTimingRow({
    required this.unitIndex,
    required this.sentenceId,
    required this.sentenceTextSnapshot,
    required this.expectedMsSnapshot,
    required this.elapsedMs,
    required this.stalled,
    required this.noSpeechDetected,
    this.transcript,
    this.autoMisreadIndexes,
    this.finalMisreadIndexes,
  });
}
