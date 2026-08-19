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
        'too_fast': r.tooFast ? 1 : 0,
        'no_speech_detected': r.noSpeechDetected ? 1 : 0,
        'transcript': r.transcript,
        'auto_misread_indexes': r.autoMisreadIndexes == null ? null : jsonEncode(r.autoMisreadIndexes),
        'final_misread_indexes': r.finalMisreadIndexes == null ? null : jsonEncode(r.finalMisreadIndexes),
        'audio_file_path': r.audioFilePath,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Sinhala only — clears a unit-timing row's audio_file_path once its
  /// recording has been listened to (and its file deleted) in Parent
  /// Dashboard, or swept by the 14-day safety net. [unitTimingId] is that
  /// row's own `id` (as returned by getUnitTimingsForSession), NOT the
  /// session id.
  static Future<void> clearAudioFilePath(int unitTimingId) async {
    final db = await _db;
    await db.update(
      'timed_reading_unit_timings',
      {'audio_file_path': null},
      where: 'id = ?',
      whereArgs: [unitTimingId],
    );
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

  // ── Calibration Insights (cross-profile, researcher/admin view) ─────────
  // Unlike every query above, these are NOT scoped to a single
  // profile_name — they aggregate real observed reading times across ALL
  // children, to empirically compare against the xlsx-sourced
  // expectedTimeSec (Research Question 3: how accurately does the
  // sentence-length-based timer threshold measure fluency). Gated behind
  // AppRouter.parentPin at the UI layer (see CalibrationInsightsScreen) —
  // not child-facing, not a specific-child Parent Dashboard view either.

  /// Per-sentence aggregate: one row per sentence_id, averaged across
  /// every recorded attempt (any profile) matching the optional filters.
  /// too_fast_n/stalled_n are included alongside the average (not
  /// excluded from it) so a systematically-miscalibrated expected time —
  /// which would show up as most/all readings flagged tooFast — remains
  /// visible in the average itself rather than being averaged away.
  static Future<List<Map<String, dynamic>>> getCalibrationStatsBySentence({
    String? grade,
    String? language,
    String? level,
  }) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <Object?>[];
    if (grade != null) {
      conditions.add('s.grade = ?');
      args.add(grade);
    }
    if (language != null) {
      conditions.add('s.language = ?');
      args.add(language);
    }
    if (level != null) {
      conditions.add('s.level = ?');
      args.add(level);
    }
    // Assigned-practice sessions (level = 'assigned_practice') deliberately
    // excluded — always. Their sentences are a hand-picked mix pulled from
    // whichever levels a parent flagged, not a real level bucket, so
    // including them would mix heterogeneous sentence sets into what's
    // meant to be a single calibration target.
    conditions.add("s.level != 'assigned_practice'");
    final where = 'WHERE ${conditions.join(' AND ')}';
    return db.rawQuery('''
      SELECT
        t.sentence_id,
        t.sentence_text_snapshot,
        t.expected_ms_snapshot,
        AVG(t.elapsed_ms) AS actual_avg_ms,
        COUNT(*) AS n,
        SUM(CASE WHEN t.too_fast = 1 THEN 1 ELSE 0 END) AS too_fast_n,
        SUM(CASE WHEN t.stalled = 1 THEN 1 ELSE 0 END) AS stalled_n
      FROM timed_reading_unit_timings t
      JOIN timed_reading_sessions s ON s.id = t.session_id
      $where
      GROUP BY t.sentence_id
      ORDER BY t.sentence_id
    ''', args);
  }

  /// Coarser aggregate: one row per content_set_id (grade+language+level
  /// bucket), spanning all its sentences. expected_avg_ms is an AVERAGE
  /// of expected_ms_snapshot across the bucket's different sentences
  /// (they don't share one expected value the way a single sentence_id
  /// does), so deviation% at this level compares actual_avg_ms against
  /// that average, not a single fixed target.
  static Future<List<Map<String, dynamic>>> getCalibrationStatsByContentSet() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT
        s.content_set_id,
        s.grade,
        s.language,
        s.level,
        AVG(t.elapsed_ms) AS actual_avg_ms,
        AVG(t.expected_ms_snapshot) AS expected_avg_ms,
        COUNT(*) AS n,
        SUM(CASE WHEN t.too_fast = 1 THEN 1 ELSE 0 END) AS too_fast_n,
        SUM(CASE WHEN t.stalled = 1 THEN 1 ELSE 0 END) AS stalled_n
      FROM timed_reading_unit_timings t
      JOIN timed_reading_sessions s ON s.id = t.session_id
      WHERE s.level != 'assigned_practice'
      GROUP BY s.content_set_id
      ORDER BY s.content_set_id
    ''');
  }

  /// Validation check, not a display query: returns any sentence_id that
  /// has more than one DISTINCT expected_ms_snapshot value recorded
  /// across its rows. expected_ms_snapshot is a denormalized snapshot
  /// that should be constant per sentence_id (it's copied from the
  /// content bank at attempt-save time) — more than one distinct value
  /// means the content bank's expectedTimeSec changed for that sentence
  /// between two attempts being recorded, which would make a plain
  /// average across all its rows silently mix two different targets.
  /// CalibrationInsightsScreen surfaces a warning if this returns any rows.
  static Future<List<Map<String, dynamic>>> getInconsistentExpectedSnapshots() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT sentence_id, COUNT(DISTINCT expected_ms_snapshot) AS distinct_values
      FROM timed_reading_unit_timings
      GROUP BY sentence_id
      HAVING COUNT(DISTINCT expected_ms_snapshot) > 1
    ''');
  }

  // ── "Practice These Again" — assigned-practice queue ─────────────────
  // Fully separate from Pronunciation's is_assigned_practice/
  // AssignedPractice (see local_storage.dart) — no shared table, no
  // shared state. A parent flags specific sentences from a past session
  // (Parent Dashboard); they queue here until the child completes an
  // assigned-practice session that includes them.

  /// Queues [sentences] for [profileName]. Skips any sentence_id that
  /// already has a PENDING (completed_at IS NULL) row for this profile,
  /// so re-flagging the same sentence from two different session cards
  /// doesn't stack duplicate pending rows — re-assigning after the prior
  /// one was completed is fine and creates a fresh row.
  static Future<void> assignSentencesForPractice({
    required String profileName,
    required String grade,
    required String language,
    required List<({String sentenceId, String text})> sentences,
  }) async {
    if (sentences.isEmpty) return;
    final db = await _db;
    final existingPending = await db.query(
      'timed_reading_assigned_practice',
      columns: ['sentence_id'],
      where: 'profile_name = ? AND completed_at IS NULL',
      whereArgs: [profileName],
    );
    final pendingIds = existingPending.map((r) => r['sentence_id'] as String).toSet();

    final toInsert = sentences.where((s) => !pendingIds.contains(s.sentenceId)).toList();
    if (toInsert.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final s in toInsert) {
      batch.insert('timed_reading_assigned_practice', {
        'profile_name': profileName,
        'grade': grade,
        'language': language,
        'sentence_id': s.sentenceId,
        'sentence_text_snapshot': s.text,
        'assigned_at': now,
        'completed_at': null,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Pending (not yet completed) assigned-practice rows for [profileName]
  /// + [grade] + [language], oldest-assigned first — what the Level
  /// Select banner checks for non-emptiness and what a tapped banner
  /// turns into a session's sentence list.
  static Future<List<Map<String, dynamic>>> getPendingPractice({
    required String profileName,
    required String grade,
    required String language,
  }) async {
    final db = await _db;
    return db.query(
      'timed_reading_assigned_practice',
      where: 'profile_name = ? AND grade = ? AND language = ? AND completed_at IS NULL',
      whereArgs: [profileName, grade, language],
      orderBy: 'assigned_at ASC',
    );
  }

  /// Marks exactly the given row [ids] (this session's own batch —
  /// not "every pending row", in case more were assigned mid-session)
  /// as completed.
  static Future<void> markPracticeCompleted(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE timed_reading_assigned_practice SET completed_at = ? WHERE id IN ($placeholders)',
      [DateTime.now().toIso8601String(), ...ids],
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
  final bool tooFast;
  final bool noSpeechDetected;
  final String? transcript;
  final List<int>? autoMisreadIndexes;
  final List<int>? finalMisreadIndexes;
  // Sinhala only — path in <appDocs>/tr_audio_review/ (moved there from
  // the temp recording location by MiscueMarkingScreen._saveSession,
  // once the real session id is known). Always null for English.
  final String? audioFilePath;

  const TimedReadingUnitTimingRow({
    required this.unitIndex,
    required this.sentenceId,
    required this.sentenceTextSnapshot,
    required this.expectedMsSnapshot,
    required this.elapsedMs,
    required this.stalled,
    this.tooFast = false,
    required this.noSpeechDetected,
    this.transcript,
    this.autoMisreadIndexes,
    this.finalMisreadIndexes,
    this.audioFilePath,
  });
}
