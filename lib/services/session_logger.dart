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
      version: 7,
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
          if (oldVersion < 5) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS phoneme_substitutions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                profile_name TEXT NOT NULL,
                session_id INTEGER NOT NULL,
                word TEXT NOT NULL,
                language TEXT NOT NULL,
                expected_phoneme TEXT NOT NULL,
                produced_phoneme TEXT NOT NULL,
                timestamp TEXT NOT NULL
              )
            ''');
          }
          if (oldVersion < 6) {
            // Tags sessions launched from the child-side "Assigned Practice"
            // banner, so the parent dashboard can show their history
            // separately from regular level-selection sessions. Regular
            // sessions are unaffected — the new column defaults to 0/NULL.
            await db.execute(
                'ALTER TABLE sessions ADD COLUMN is_assigned_practice INTEGER NOT NULL DEFAULT 0');
            await db.execute('ALTER TABLE sessions ADD COLUMN assigned_phoneme TEXT');
          }
          if (oldVersion < 7) {
            // Timed Reading module's own tables — additive only, no
            // existing table touched. See timed_reading_dao.dart for the
            // only code that reads/writes these two tables.
            await db.execute('''
              CREATE TABLE IF NOT EXISTS timed_reading_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                profile_name TEXT NOT NULL,
                grade TEXT NOT NULL,
                language TEXT NOT NULL,
                level TEXT NOT NULL,
                content_set_id TEXT NOT NULL,
                challenge_attempt_number INTEGER,
                started_at TEXT NOT NULL,
                completed_at TEXT,
                interrupted INTEGER NOT NULL DEFAULT 0,
                accuracy_marked INTEGER NOT NULL DEFAULT 0,
                wpm REAL,
                wcpm REAL
              )
            ''');
            await db.execute('''
              CREATE TABLE IF NOT EXISTS timed_reading_unit_timings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL,
                unit_index INTEGER NOT NULL,
                sentence_id TEXT NOT NULL,
                sentence_text_snapshot TEXT NOT NULL,
                expected_ms_snapshot INTEGER NOT NULL,
                elapsed_ms INTEGER NOT NULL,
                stalled INTEGER NOT NULL DEFAULT 0,
                no_speech_detected INTEGER NOT NULL DEFAULT 0,
                transcript TEXT,
                auto_misread_indexes TEXT,
                final_misread_indexes TEXT,
                FOREIGN KEY (session_id) REFERENCES timed_reading_sessions(id)
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
      CREATE TABLE phoneme_substitutions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_name TEXT NOT NULL,
        session_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        language TEXT NOT NULL,
        expected_phoneme TEXT NOT NULL,
        produced_phoneme TEXT NOT NULL,
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
        wrong INTEGER NOT NULL,
        is_assigned_practice INTEGER NOT NULL DEFAULT 0,
        assigned_phoneme TEXT
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
    // Timed Reading module's own tables — additive only, mirrors the
    // oldVersion < 7 branch above exactly so a fresh install and an
    // upgraded install end up with identical schemas.
    await db.execute('''
      CREATE TABLE timed_reading_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_name TEXT NOT NULL,
        grade TEXT NOT NULL,
        language TEXT NOT NULL,
        level TEXT NOT NULL,
        content_set_id TEXT NOT NULL,
        challenge_attempt_number INTEGER,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        interrupted INTEGER NOT NULL DEFAULT 0,
        accuracy_marked INTEGER NOT NULL DEFAULT 0,
        wpm REAL,
        wcpm REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE timed_reading_unit_timings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        unit_index INTEGER NOT NULL,
        sentence_id TEXT NOT NULL,
        sentence_text_snapshot TEXT NOT NULL,
        expected_ms_snapshot INTEGER NOT NULL,
        elapsed_ms INTEGER NOT NULL,
        stalled INTEGER NOT NULL DEFAULT 0,
        no_speech_detected INTEGER NOT NULL DEFAULT 0,
        transcript TEXT,
        auto_misread_indexes TEXT,
        final_misread_indexes TEXT,
        FOREIGN KEY (session_id) REFERENCES timed_reading_sessions(id)
      )
    ''');
  }

  /// Shared Database connection, exposed for other modules' DAO code
  /// (e.g. timed_reading_dao.dart) so they don't open a second
  /// connection to the same reading_buddy.db file. Purely additive —
  /// does not change how SessionLogger itself uses [_database] anywhere
  /// above. Callers must only touch their own tables; this file remains
  /// the sole owner of Pronunciation's 5 tables.
  static Future<Database> get database => _database;

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
    bool         isAssignedPractice = false,
    String?      assignedPhoneme,
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
      'is_assigned_practice': isAssignedPractice ? 1 : 0,
      'assigned_phoneme': assignedPhoneme,
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

  /// Count distinct pronunciation sessions [profileName] has completed.
  ///
  /// The `sessions` table has no profile_name column (it's shared across
  /// whoever last played on a given grade), so this uses phoneme_attempts
  /// instead, which does record profile_name per session_id.
  static Future<int> getSessionCount({required String profileName}) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT COUNT(DISTINCT session_id) AS cnt FROM phoneme_attempts WHERE profile_name = ?',
      [profileName],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  /// Word-level (not phoneme-level) accuracy for [profileName], reconstructed
  /// from phoneme_attempts' per-word `correct` flag (same value repeated
  /// across every phoneme row of a given word/session — see
  /// savePhonemeAttempts' "best result per word" comment).
  static Future<({int totalWords, int correctWords})> getWordAccuracy({
    required String profileName,
  }) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT MAX(correct) AS word_correct
      FROM phoneme_attempts
      WHERE profile_name = ?
      GROUP BY session_id, word
    ''', [profileName]);
    final total = rows.length;
    final correct = rows.where((r) => (r['word_correct'] as int?) == 1).length;
    return (totalWords: total, correctWords: correct);
  }

  /// Day streak for [profileName], based on the days they actually logged
  /// pronunciation attempts (phoneme_attempts.timestamp), unlike
  /// [getStreakDays] which is grade-wide, not per-child.
  static Future<int> getStreakDaysForProfile(String profileName) async {
    final db = await _database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT date(timestamp) as d FROM phoneme_attempts WHERE profile_name = ? ORDER BY d DESC",
      [profileName],
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

  /// Per-session word accuracy for [profileName], ordered oldest → newest
  /// (session_id is autoincrement, so it doubles as a chronological key).
  /// Used to show whether accuracy is trending up or down recently.
  static Future<List<({int sessionId, int totalWords, int correctWords})>>
      getSessionAccuracyTimeline({required String profileName}) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT session_id,
             COUNT(*) AS total_words,
             SUM(word_correct) AS correct_words
      FROM (
        SELECT session_id, word, MAX(correct) AS word_correct
        FROM phoneme_attempts
        WHERE profile_name = ?
        GROUP BY session_id, word
      )
      GROUP BY session_id
      ORDER BY session_id ASC
    ''', [profileName]);

    return rows
        .map((r) => (
              sessionId: r['session_id'] as int,
              totalWords: r['total_words'] as int,
              correctWords: (r['correct_words'] as int?) ?? 0,
            ))
        .toList();
  }

  // ── Phonological substitution patterns ──────────────────────────────────

  /// Logs one row per detected (expected → produced) phoneme substitution
  /// for a WRONG/ALMOST attempt — see PhonemeSubstitutionAnalyzer, which
  /// computes [substitutions] from the expected phoneme sequence vs the raw
  /// transcript actually heard.
  static Future<void> savePhonemeSubstitutions({
    required int    sessionId,
    required String profileName,
    required String word,
    required String language,
    required List<({String expected, String produced})> substitutions,
  }) async {
    if (substitutions.isEmpty) return;
    final db  = await _database;
    final bat = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final s in substitutions) {
      bat.insert('phoneme_substitutions', {
        'profile_name':     profileName,
        'session_id':       sessionId,
        'word':             word,
        'language':         language,
        'expected_phoneme': s.expected,
        'produced_phoneme': s.produced,
        'timestamp':        now,
      });
    }
    await bat.commit(noResult: true);
  }

  /// Most frequent (expected → produced) substitution pairs for
  /// [profileName], optionally scoped to one [language]. Only pairs with at
  /// least [minOccurrences] instances are returned — 3, matching the same
  /// "meaningful pattern" threshold CrossLanguageAnalyzer already uses for
  /// flagging cross-language phoneme difficulty (see
  /// cross_language_analyzer.dart's _minAttempts) rather than a new number.
  static Future<List<Map<String, dynamic>>> getTopSubstitutionPatterns({
    required String profileName,
    String?         language,
    int             minOccurrences = 3,
  }) async {
    final db   = await _database;
    var where  = 'profile_name = ?';
    final args = <dynamic>[profileName];

    if (language != null) {
      where += ' AND language = ?';
      args.add(language);
    }
    args.add(minOccurrences);

    return db.rawQuery('''
      SELECT expected_phoneme, produced_phoneme, language, COUNT(*) AS occurrences
      FROM phoneme_substitutions
      WHERE $where
      GROUP BY expected_phoneme, produced_phoneme, language
      HAVING COUNT(*) >= ?
      ORDER BY occurrences DESC
    ''', args);
  }

  /// Completed sessions launched from the child-side "Assigned Practice"
  /// banner (sessions.is_assigned_practice = 1), most recent first, for the
  /// Parent dashboard's "Assigned Practice History" card. Scoped to
  /// [profileName] the same way every other per-child query here is —
  /// via a phoneme_attempts join, since `sessions` itself has no profile
  /// column (see getSessionCount for the same pattern).
  ///
  /// For each session, also reports the phoneme's error rate in the window
  /// strictly before vs strictly after that session (excluding the
  /// session's own rows), but only when there are at least 3 phoneme_attempts
  /// rows for that phoneme on BOTH sides — otherwise beforeErrorRate/
  /// afterErrorRate are left null and the caller should just show the raw
  /// session result without an improvement comparison.
  static Future<List<Map<String, dynamic>>> getAssignedPracticeHistory({
    required String profileName,
    int             limit = 5,
  }) async {
    final db = await _database;
    final sessions = await db.rawQuery('''
      SELECT session_id, assigned_phoneme, language, date, correct, almost, wrong
      FROM sessions
      WHERE is_assigned_practice = 1
        AND session_id IN (SELECT DISTINCT session_id FROM phoneme_attempts WHERE profile_name = ?)
      ORDER BY date DESC
      LIMIT ?
    ''', [profileName, limit]);

    const minAttemptsPerSide = 3;
    final result = <Map<String, dynamic>>[];
    for (final row in sessions) {
      final sessionId = row['session_id'] as int;
      final phoneme = row['assigned_phoneme'] as String?;
      final language = row['language'] as String;
      final date = row['date'] as String;

      double? beforeErrorRate;
      double? afterErrorRate;
      if (phoneme != null) {
        final before = await db.rawQuery('''
          SELECT COUNT(*) AS total, SUM(CASE WHEN correct = 0 THEN 1 ELSE 0 END) AS errors
          FROM phoneme_attempts
          WHERE profile_name = ? AND phoneme = ? AND language = ? AND session_id != ? AND timestamp < ?
        ''', [profileName, phoneme, language, sessionId, date]);
        final after = await db.rawQuery('''
          SELECT COUNT(*) AS total, SUM(CASE WHEN correct = 0 THEN 1 ELSE 0 END) AS errors
          FROM phoneme_attempts
          WHERE profile_name = ? AND phoneme = ? AND language = ? AND session_id != ? AND timestamp > ?
        ''', [profileName, phoneme, language, sessionId, date]);

        final beforeTotal = (before.first['total'] as int?) ?? 0;
        final afterTotal = (after.first['total'] as int?) ?? 0;
        if (beforeTotal >= minAttemptsPerSide && afterTotal >= minAttemptsPerSide) {
          beforeErrorRate = (before.first['errors'] as int? ?? 0) / beforeTotal;
          afterErrorRate = (after.first['errors'] as int? ?? 0) / afterTotal;
        }
      }

      result.add({
        'sessionId': sessionId,
        'phoneme': phoneme,
        'language': language,
        'date': date,
        'correct': row['correct'] as int,
        'almost': row['almost'] as int,
        'wrong': row['wrong'] as int,
        'beforeErrorRate': beforeErrorRate,
        'afterErrorRate': afterErrorRate,
      });
    }
    return result;
  }
}
