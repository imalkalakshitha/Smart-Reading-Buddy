import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/reading_data.dart';
import '../models/app_state.dart';

/// Persists reading sessions to a dedicated SQLite database.
/// Uses a separate file (`reading_sessions.db`) to avoid schema conflicts
/// with the pronunciation session logger.
class ReadingSessionLogger {
  ReadingSessionLogger._();

  static Database? _db;

  static Future<Database> _open() async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), 'reading_sessions.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE reading_sessions (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            grade         TEXT    NOT NULL,
            level         INTEGER NOT NULL,
            level_name    TEXT    NOT NULL,
            language      TEXT    NOT NULL,
            date          TEXT    NOT NULL,
            total_sents   INTEGER NOT NULL,
            avg_time_ms   INTEGER NOT NULL,
            fastest_ms    INTEGER NOT NULL,
            buddy_prompts INTEGER NOT NULL,
            wpm           REAL    NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE reading_sent_attempts (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id  INTEGER NOT NULL,
            sentence    TEXT    NOT NULL,
            time_ms     INTEGER NOT NULL,
            was_fast    INTEGER NOT NULL,
            buddy_count INTEGER NOT NULL,
            FOREIGN KEY (session_id) REFERENCES reading_sessions(id)
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<void> save({
    required String grade,
    required int level,
    required String levelName,
    required List<SentenceResult> results,
  }) async {
    if (results.isEmpty) return;
    final db = await _open();

    final totalWords = results.fold<int>(
      0,
      (sum, r) => sum + r.sentence.split(' ').length,
    );
    final totalMs    = results.fold<int>(0, (s, r) => s + r.timeTakenMs);
    final avgMs      = totalMs ~/ results.length;
    final fastestMs  = results.map((r) => r.timeTakenMs).reduce(
          (a, b) => a < b ? a : b,
        );
    final totalBuddy = results.fold<int>(0, (s, r) => s + r.buddyPromptsCount);
    final wpm        = totalMs > 0 ? (totalWords / totalMs) * 60000.0 : 0.0;

    final sessionId = await db.insert('reading_sessions', {
      'grade':         grade,
      'level':         level,
      'level_name':    levelName,
      'language':      AppState.language,
      'date':          DateTime.now().toIso8601String(),
      'total_sents':   results.length,
      'avg_time_ms':   avgMs,
      'fastest_ms':    fastestMs,
      'buddy_prompts': totalBuddy,
      'wpm':           wpm,
    });

    final batch = db.batch();
    for (final r in results) {
      batch.insert('reading_sent_attempts', {
        'session_id':  sessionId,
        'sentence':    r.sentence,
        'time_ms':     r.timeTakenMs,
        'was_fast':    r.wasFast ? 1 : 0,
        'buddy_count': r.buddyPromptsCount,
      });
    }
    await batch.commit(noResult: true);
  }
}
