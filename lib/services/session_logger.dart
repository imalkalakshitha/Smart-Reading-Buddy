import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SessionLogger {
  static Database? _db;

  static Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'reading_buddy.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: _createTables,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 → recreate everything (early dev schema)
          await db.execute('DROP TABLE IF EXISTS word_attempts');
          await db.execute('DROP TABLE IF EXISTS sessions');
          await _createTables(db, newVersion);
        } else {
          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS calibration_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                profile_name TEXT NOT NULL,
                word TEXT NOT NULL,
                dtw_score REAL NOT NULL,
                raw_threshold REAL NOT NULL,
                date TEXT NOT NULL
              )
            ''');
          }
          if (oldVersion < 4) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS phoneme_attempts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                profile_name TEXT NOT NULL,
                session_id INTEGER NOT NULL,
                word TEXT NOT NULL,
                language TEXT NOT NULL,
                phoneme TEXT NOT NULL,
                correct INTEGER NOT NULL DEFAULT 0,
                timestamp TEXT NOT NULL
              )
            ''');
          }
        }
      },
    );
  }

  static Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE phoneme_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_name TEXT NOT NULL,
        session_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        language TEXT NOT NULL,
        phoneme TEXT NOT NULL,
        correct INTEGER NOT NULL DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE calibration_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_name TEXT NOT NULL,
        word TEXT NOT NULL,
        dtw_score REAL NOT NULL,
        raw_threshold REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sessions (
        session_id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade TEXT NOT NULL,
        language TEXT NOT NULL,
        level_key TEXT NOT NULL,
        level_name TEXT NOT NULL,
        date TEXT NOT NULL,
        total_xp INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        correct INTEGER NOT NULL,
        almost INTEGER NOT NULL,
        wrong INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE word_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        phonemes TEXT NOT NULL,
        result TEXT NOT NULL,
        attempt_number INTEGER NOT NULL,
        dtw_score REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(session_id)
      )
    ''');
  }

  static Future<int> saveSession({
    required String grade,
    required String language,
    required String levelKey,
    required String levelName,
    required int totalXp,
    required int durationSeconds,
    required int correct,
    required int almost,
    required int wrong,
  }) async {
    final db = await _database;
    return db.insert('sessions', {
      'grade': grade,
      'language': language,
      'level_key': levelKey,
      'level_name': levelName,
      'date': DateTime.now().toIso8601String(),
      'total_xp': totalXp,
      'duration_seconds': durationSeconds,
      'correct': correct,
      'almost': almost,
      'wrong': wrong,
    });
  }

  static Future<void> saveWordAttempts(
    int sessionId,
    List<Map<String, dynamic>> attempts,
  ) async {
    final db = await _database;
    final batch = db.batch();
    for (final a in attempts) {
      batch.insert('word_attempts', {
        'session_id': sessionId,
        'word': a['word'],
        'phonemes': a['phonemes'],
        'result': a['result'],
        'attempt_number': a['attempt_number'],
        'dtw_score': a['dtw_score'],
      });
    }
    await batch.commit(noResult: true);
  }

  // Returns phonemes that appear in WRONG attempts most often.
  static Future<List<String>> getHardPhonemes(String grade) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT wa.phonemes
      FROM word_attempts wa
      JOIN sessions s ON s.session_id = wa.session_id
      WHERE wa.result = 'WRONG' AND s.grade = ?
      ORDER BY wa.id DESC
      LIMIT 50
    ''', [grade]);
    final counts = <String, int>{};
    for (final row in rows) {
      final phonemes = (row['phonemes'] as String).split(',');
      for (final p in phonemes) {
        counts[p] = (counts[p] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  static Future<int> getTotalXp(String grade) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT SUM(total_xp) as xp FROM sessions WHERE grade = ?',
      [grade],
    );
    return (rows.first['xp'] as int?) ?? 0;
  }

  static Future<int> getStreakDays(String grade) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT date(date) as d FROM sessions WHERE grade = ? ORDER BY d DESC',
      [grade],
    );
    if (rows.isEmpty) return 0;
    int streak = 0;
    DateTime cursor = DateTime.now();
    for (final row in rows) {
      final d = DateTime.parse(row['d'] as String);
      final diff = cursor.difference(d).inDays;
      if (diff <= 1) {
        streak++;
        cursor = d;
      } else {
        break;
      }
    }
    return streak;
  }

  static Future<void> saveCalibrationScore({
    required String profileName,
    required String word,
    required double dtwScore,
    required double rawThreshold,
  }) async {
    final db = await _database;
    await db.insert('calibration_data', {
      'profile_name': profileName,
      'word':         word,
      'dtw_score':    dtwScore,
      'raw_threshold': rawThreshold,
      'date':         DateTime.now().toIso8601String(),
    });
  }

  /// Returns the [limit] most recent calibration rows for [profileName].
  static Future<List<Map<String, dynamic>>> getCalibrationScores(
    String profileName, {
    int limit = 10,
  }) async {
    final db = await _database;
    return db.query(
      'calibration_data',
      where:   'profile_name = ?',
      whereArgs: [profileName],
      orderBy: 'id DESC',
      limit:   limit,
    );
  }

  // ── PEPA ──────────────────────────────────────────────────────────────────

  /// Log one row per phoneme per word for PEPA analysis.
  ///
  /// Uses the BEST result per word (OK > ALMOST > WRONG) so that a word
  /// attempted three times is counted as one success or failure, not three.
  static Future<void> savePhonemeAttempts({
    required int    sessionId,
    required String profileName,
    required String language,
    required List<Map<String, dynamic>> wordAttempts,
  }) async {
    // Compute best verdict per word from the attempts list.
    final Map<String, String> best = {};
    for (final a in wordAttempts) {
      final w = a['word'] as String;
      final r = a['result'] as String;
      final cur = best[w] ?? 'WRONG';
      if (r == 'OK' || (r == 'ALMOST' && cur == 'WRONG')) {
        best[w] = r;
      } else {
        best[w] ??= 'WRONG';
      }
    }

    final db  = await _database;
    final bat = db.batch();
    final now = DateTime.now().toIso8601String();
    final seen = <String>{};

    for (final a in wordAttempts) {
      final w = a['word'] as String;
      if (seen.contains(w)) continue; // one entry per word per session
      seen.add(w);

      final phonemes = (a['phonemes'] as String).split(',');
      final correct  = best[w] == 'OK' ? 1 : 0;

      for (final p in phonemes) {
        final trimmed = p.trim();
        if (trimmed.isEmpty) continue;
        bat.insert('phoneme_attempts', {
          'profile_name': profileName,
          'session_id':   sessionId,
          'word':         w,
          'language':     language,
          'phoneme':      trimmed,
          'correct':      correct,
          'timestamp':    now,
        });
      }
    }
    await bat.commit(noResult: true);
  }

  /// Aggregate phoneme error rates for [profileName].
  ///
  /// Returns rows sorted by error count descending.
  /// Pass [lastNDays] to restrict to a recent window.
  static Future<List<Map<String, dynamic>>> getPhonemeStats({
    required String profileName,
    String?         language,
    int?            lastNDays,
  }) async {
    final db   = await _database;
    var where  = 'profile_name = ?';
    final args = <dynamic>[profileName];

    if (language != null) {
      where += ' AND language = ?';
      args.add(language);
    }
    if (lastNDays != null) {
      where += " AND timestamp >= datetime('now', '-$lastNDays days')";
    }

    return db.rawQuery('''
      SELECT
        phoneme,
        language,
        COUNT(*)                                        AS total,
        SUM(CASE WHEN correct = 0 THEN 1 ELSE 0 END)  AS incorrect
      FROM phoneme_attempts
      WHERE $where
      GROUP BY phoneme, language
      ORDER BY incorrect DESC, total DESC
    ''', args);
  }

  /// Count distinct words attempted in PEPA data for [profileName].
  static Future<int> getPhonemeWordCount({
    required String profileName,
    int?            lastNDays,
  }) async {
    final db   = await _database;
    var where  = 'profile_name = ?';
    final args = <dynamic>[profileName];

    if (lastNDays != null) {
      where += " AND timestamp >= datetime('now', '-$lastNDays days')";
    }

    final rows = await db.rawQuery(
      'SELECT COUNT(DISTINCT word) AS cnt FROM phoneme_attempts WHERE $where',
      args,
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }
}
