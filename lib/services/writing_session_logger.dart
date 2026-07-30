import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class LetterAccuracy {
  final String letter;
  final double averageAccuracy;
  final int sessionCount;

  const LetterAccuracy({
    required this.letter,
    required this.averageAccuracy,
    required this.sessionCount,
  });
}

class SessionTrend {
  final String date;      // ISO8601 date only
  final double accuracy;  // average accuracy that day

  const SessionTrend({required this.date, required this.accuracy});
}

class LetterMastery {
  final String letter;
  final double averageAccuracy;
  final int sessionCount;
  final double avgAttemptsToPass; // avg retries before passing (≥70%)
  final int avgCompletionSecs;    // avg seconds per session

  const LetterMastery({
    required this.letter,
    required this.averageAccuracy,
    required this.sessionCount,
    required this.avgAttemptsToPass,
    required this.avgCompletionSecs,
  });

  // Mastered = avg accuracy ≥ 70% AND at least 3 completed sessions
  bool get isMastered => averageAccuracy >= 70 && sessionCount >= 3;
  bool get isStarted => sessionCount > 0;

  // Letters needing most retries indicate confusion
  bool get needsAttention => avgAttemptsToPass >= 2.0 && isStarted;
}

// ── Logger ────────────────────────────────────────────────────────────────────

class WritingSessionLogger {
  static const int _dbVersion = 2;
  static Database? _db;

  static Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'writing_sessions.db');
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE writing_sessions (
            id                INTEGER PRIMARY KEY AUTOINCREMENT,
            profile_id        INTEGER NOT NULL,
            letter            TEXT NOT NULL,
            language          TEXT NOT NULL,
            grade             INTEGER NOT NULL,
            accuracy          REAL NOT NULL,
            xp_earned         INTEGER NOT NULL,
            completion_time_ms INTEGER NOT NULL DEFAULT 0,
            attempts_to_pass  INTEGER NOT NULL DEFAULT 1,
            timestamp         TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE writing_sessions ADD COLUMN completion_time_ms INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE writing_sessions ADD COLUMN attempts_to_pass INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
    );
  }

  static Future<void> saveSession({
    required int profileId,
    required String letter,
    required String language,
    required int grade,
    required double accuracy,
    required int xpEarned,
    int completionTimeMs = 0,
    int attemptsToPass = 1,
  }) async {
    final db = await _database;
    await db.insert('writing_sessions', {
      'profile_id': profileId,
      'letter': letter,
      'language': language,
      'grade': grade,
      'accuracy': accuracy,
      'xp_earned': xpEarned,
      'completion_time_ms': completionTimeMs,
      'attempts_to_pass': attemptsToPass,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ── Existing queries ────────────────────────────────────────────────────────

  static Future<List<LetterAccuracy>> getLetterAccuracies(
    int profileId,
    String language,
  ) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT letter,
             AVG(accuracy)  AS avg_acc,
             COUNT(*)       AS cnt
      FROM writing_sessions
      WHERE profile_id = ? AND language = ?
      GROUP BY letter
      ORDER BY letter
    ''', [profileId, language]);
    return rows
        .map((r) => LetterAccuracy(
              letter: r['letter'] as String,
              averageAccuracy: (r['avg_acc'] as num).toDouble(),
              sessionCount: r['cnt'] as int,
            ))
        .toList();
  }

  static Future<List<SessionTrend>> getRecentTrend(int profileId) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT date(timestamp) AS day,
             AVG(accuracy)   AS avg_acc
      FROM writing_sessions
      WHERE profile_id = ?
        AND timestamp >= date('now', '-14 days')
      GROUP BY day
      ORDER BY day ASC
    ''', [profileId]);
    return rows
        .map((r) => SessionTrend(
              date: r['day'] as String,
              accuracy: (r['avg_acc'] as num).toDouble(),
            ))
        .toList();
  }

  static Future<int> getTotalXp(int profileId) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT SUM(xp_earned) AS xp FROM writing_sessions WHERE profile_id = ?',
      [profileId],
    );
    return (rows.first['xp'] as int?) ?? 0;
  }

  static Future<List<LetterAccuracy>> getHardestLetters(
    int profileId,
    String language, {
    int limit = 5,
  }) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT letter,
             AVG(accuracy) AS avg_acc,
             COUNT(*)      AS cnt
      FROM writing_sessions
      WHERE profile_id = ? AND language = ?
      GROUP BY letter
      HAVING cnt >= 1
      ORDER BY avg_acc ASC
      LIMIT ?
    ''', [profileId, language, limit]);
    return rows
        .map((r) => LetterAccuracy(
              letter: r['letter'] as String,
              averageAccuracy: (r['avg_acc'] as num).toDouble(),
              sessionCount: r['cnt'] as int,
            ))
        .toList();
  }

  // ── New: full mastery data per letter ──────────────────────────────────────

  static Future<List<LetterMastery>> getLetterMastery(
    int profileId,
    String language,
  ) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT letter,
             AVG(accuracy)            AS avg_acc,
             COUNT(*)                 AS cnt,
             AVG(attempts_to_pass)    AS avg_attempts,
             AVG(completion_time_ms) / 1000.0 AS avg_secs
      FROM writing_sessions
      WHERE profile_id = ? AND language = ?
      GROUP BY letter
      ORDER BY letter
    ''', [profileId, language]);
    return rows
        .map((r) => LetterMastery(
              letter: r['letter'] as String,
              averageAccuracy: (r['avg_acc'] as num).toDouble(),
              sessionCount: r['cnt'] as int,
              avgAttemptsToPass: (r['avg_attempts'] as num? ?? 1).toDouble(),
              avgCompletionSecs: (r['avg_secs'] as num? ?? 0).toInt(),
            ))
        .toList();
  }

  // ── New: session counts per day for weekly activity heatmap ───────────────

  static Future<Map<String, int>> getWeeklyActivity(int profileId) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT date(timestamp) AS day, COUNT(*) AS cnt
      FROM writing_sessions
      WHERE profile_id = ?
        AND timestamp >= date('now', '-6 days')
      GROUP BY day
    ''', [profileId]);
    return {for (final r in rows) r['day'] as String: r['cnt'] as int};
  }

  // ── New: letters ordered by highest avg retries (most confusion) ──────────

  static Future<List<LetterMastery>> getMostRetriedLetters(
    int profileId,
    String language, {
    int limit = 5,
  }) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT letter,
             AVG(accuracy)            AS avg_acc,
             COUNT(*)                 AS cnt,
             AVG(attempts_to_pass)    AS avg_attempts,
             AVG(completion_time_ms) / 1000.0 AS avg_secs
      FROM writing_sessions
      WHERE profile_id = ? AND language = ?
      GROUP BY letter
      HAVING cnt >= 1
      ORDER BY avg_attempts DESC
      LIMIT ?
    ''', [profileId, language, limit]);
    return rows
        .map((r) => LetterMastery(
              letter: r['letter'] as String,
              averageAccuracy: (r['avg_acc'] as num).toDouble(),
              sessionCount: r['cnt'] as int,
              avgAttemptsToPass: (r['avg_attempts'] as num? ?? 1).toDouble(),
              avgCompletionSecs: (r['avg_secs'] as num? ?? 0).toInt(),
            ))
        .toList();
  }
}
