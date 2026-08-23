import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// EduPlay's own database — completely separate from reading_buddy.db
/// (Pronunciation + Timed Reading). Nothing in this file touches that
/// database or SessionLogger/TimedReadingDao.
class EduPlayDatabase {
  EduPlayDatabase._();

  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'eduplay.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE eduplay_child_profile (
        child_id TEXT PRIMARY KEY,
        grade TEXT NOT NULL,
        language TEXT NOT NULL,
        starting_level TEXT NOT NULL,
        support_need_level TEXT NOT NULL,
        main_focus_area TEXT NOT NULL,
        baseline_accuracy REAL NOT NULL DEFAULT 0,
        baseline_response_time_sec REAL NOT NULL DEFAULT 0,
        total_completed_activities INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE eduplay_sessions (
        session_id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        task_id TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        language TEXT NOT NULL,
        grade TEXT NOT NULL,
        level TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        skill_area TEXT NOT NULL,
        target_error_type TEXT NOT NULL,
        accuracy_percentage REAL NOT NULL,
        time_spent_seconds REAL NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 1,
        hints_used INTEGER NOT NULL DEFAULT 0,
        audio_replay_count INTEGER NOT NULL DEFAULT 0,
        mistake_count INTEGER NOT NULL DEFAULT 0,
        mistake_type TEXT NOT NULL DEFAULT 'none',
        performance_band TEXT NOT NULL,
        is_correct INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE eduplay_history_stats (
        child_id TEXT PRIMARY KEY,
        previous_activity_type TEXT NOT NULL DEFAULT 'none',
        previous_accuracy REAL NOT NULL DEFAULT 0,
        last_5_accuracy REAL NOT NULL DEFAULT 0,
        average_time_last_5 REAL NOT NULL DEFAULT 0,
        recent_mistake_rate REAL NOT NULL DEFAULT 0,
        weakest_skill_area TEXT NOT NULL DEFAULT 'letter_order',
        strongest_skill_area TEXT NOT NULL DEFAULT 'letter_order',
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE eduplay_recommendations (
        rec_id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        recommended_activity TEXT NOT NULL,
        recommended_level TEXT NOT NULL,
        confidence REAL NOT NULL,
        top_features TEXT NOT NULL,
        rule_tag TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        parent_choice TEXT,
        generated_at TEXT NOT NULL,
        actioned_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE eduplay_assigned_lessons (
        assignment_id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        rec_id TEXT,
        activity_type TEXT NOT NULL,
        level TEXT NOT NULL,
        assigned_at TEXT NOT NULL,
        completed_at TEXT,
        pre_accuracy REAL,
        post_accuracy REAL,
        status TEXT NOT NULL DEFAULT 'ASSIGNED'
      )
    ''');

    await db.execute('''
      CREATE TABLE eduplay_xp_ledger (
        ledger_id TEXT PRIMARY KEY,
        child_id TEXT NOT NULL,
        session_id TEXT,
        xp_delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // ── Session helpers ──────────────────────────────────────────────────

  static Future<String> insertSession(Map<String, dynamic> session) async {
    final db = await database;
    await db.insert('eduplay_sessions', session);
    return session['session_id'] as String;
  }

  static Future<void> updateHistoryStats(
      String childId, List<Map<String, dynamic>> recentSessions) async {
    final db = await database;

    String previousActivityType = 'none';
    double previousAccuracy = 0;
    double last5Accuracy = 0;
    double averageTimeLast5 = 0;
    double recentMistakeRate = 0;
    String weakestSkillArea = 'letter_order';
    String strongestSkillArea = 'letter_order';

    if (recentSessions.isNotEmpty) {
      // recentSessions is expected newest-first (see getRecentSessions).
      final newest = recentSessions.first;
      previousActivityType = newest['activity_type'] as String? ?? 'none';
      previousAccuracy = (newest['accuracy_percentage'] as num?)?.toDouble() ?? 0;

      final accuracies = recentSessions
          .map((s) => (s['accuracy_percentage'] as num?)?.toDouble() ?? 0)
          .toList();
      last5Accuracy = accuracies.reduce((a, b) => a + b) / accuracies.length;

      final times = recentSessions
          .map((s) => (s['time_spent_seconds'] as num?)?.toDouble() ?? 0)
          .toList();
      averageTimeLast5 = times.reduce((a, b) => a + b) / times.length;

      final totalMistakes = recentSessions.fold<int>(
          0, (sum, s) => sum + ((s['mistake_count'] as num?)?.toInt() ?? 0));
      final totalAttempts = recentSessions.fold<int>(
          0, (sum, s) => sum + ((s['attempt_count'] as num?)?.toInt() ?? 0));
      recentMistakeRate = totalAttempts == 0
          ? 0
          : (totalMistakes / (totalAttempts * 5)).clamp(0.0, 1.0);

      final bySkill = <String, List<double>>{};
      for (final s in recentSessions) {
        final skill = s['skill_area'] as String? ?? 'letter_order';
        final acc = (s['accuracy_percentage'] as num?)?.toDouble() ?? 0;
        bySkill.putIfAbsent(skill, () => []).add(acc);
      }
      if (bySkill.isNotEmpty) {
        final avgBySkill = bySkill.map(
            (skill, accs) => MapEntry(skill, accs.reduce((a, b) => a + b) / accs.length));
        weakestSkillArea =
            avgBySkill.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
        strongestSkillArea =
            avgBySkill.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      }
    }

    await db.insert(
      'eduplay_history_stats',
      {
        'child_id': childId,
        'previous_activity_type': previousActivityType,
        'previous_accuracy': previousAccuracy,
        'last_5_accuracy': last5Accuracy,
        'average_time_last_5': averageTimeLast5,
        'recent_mistake_rate': recentMistakeRate,
        'weakest_skill_area': weakestSkillArea,
        'strongest_skill_area': strongestSkillArea,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getHistoryStats(String childId) async {
    final db = await database;
    final rows = await db.query(
      'eduplay_history_stats',
      where: 'child_id = ?',
      whereArgs: [childId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<Map<String, dynamic>?> getChildProfile(String childId) async {
    final db = await database;
    final rows = await db.query(
      'eduplay_child_profile',
      where: 'child_id = ?',
      whereArgs: [childId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> upsertChildProfile(Map<String, dynamic> profile) async {
    final db = await database;
    await db.insert(
      'eduplay_child_profile',
      profile,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> countCompletedActivities(String childId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM eduplay_sessions WHERE child_id = ?',
      [childId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Recommendation helpers ──────────────────────────────────────────

  static Future<Map<String, dynamic>?> getPendingRecommendation(String childId) async {
    final db = await database;
    final rows = await db.query(
      'eduplay_recommendations',
      where: 'child_id = ? AND status = ?',
      whereArgs: [childId, 'PENDING'],
      orderBy: 'generated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<String> insertRecommendation(Map<String, dynamic> rec) async {
    final db = await database;
    await db.insert('eduplay_recommendations', rec);
    return rec['rec_id'] as String;
  }

  static Future<void> updateRecommendationStatus(
    String recId,
    String status, {
    String? parentChoice,
  }) async {
    final db = await database;
    final values = <String, dynamic>{
      'status': status,
      'actioned_at': DateTime.now().toIso8601String(),
    };
    if (parentChoice != null) values['parent_choice'] = parentChoice;
    await db.update(
      'eduplay_recommendations',
      values,
      where: 'rec_id = ?',
      whereArgs: [recId],
    );
  }

  // ── Assignment helpers ───────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getActiveAssignment(String childId) async {
    final db = await database;
    final rows = await db.query(
      'eduplay_assigned_lessons',
      where: 'child_id = ? AND status = ?',
      whereArgs: [childId, 'ASSIGNED'],
      orderBy: 'assigned_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<String> insertAssignment(Map<String, dynamic> assignment) async {
    final db = await database;
    await db.insert('eduplay_assigned_lessons', assignment);
    return assignment['assignment_id'] as String;
  }

  static Future<void> completeAssignment(String assignmentId, double postAccuracy) async {
    final db = await database;
    await db.update(
      'eduplay_assigned_lessons',
      {
        'completed_at': DateTime.now().toIso8601String(),
        'post_accuracy': postAccuracy,
        'status': 'COMPLETED',
      },
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
    );
  }

  // ── XP helpers ────────────────────────────────────────────────────────

  static Future<int> getTotalXp(String childId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(xp_delta) AS total FROM eduplay_xp_ledger WHERE child_id = ?',
      [childId],
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  static Future<void> addXp(
    String childId,
    int xp,
    String reason, {
    String? sessionId,
  }) async {
    final db = await database;
    await db.insert('eduplay_xp_ledger', {
      'ledger_id': _uuid(),
      'child_id': childId,
      'session_id': sessionId,
      'xp_delta': xp,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Progress helpers for parent dashboard ────────────────────────────

  static Future<List<Map<String, dynamic>>> getRecentSessions(
    String childId, {
    int limit = 20,
  }) async {
    final db = await database;
    return db.query(
      'eduplay_sessions',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'completed_at DESC',
      limit: limit,
    );
  }

  /// Count of past task submissions for this exact child+activity+level —
  /// used as the shuffle seed input for session rotation (see
  /// TaskRepository.getTasksFor) so a new 8-task subset is drawn every
  /// session, not just once per calendar day.
  static Future<int> countSessionsFor({
    required String childId,
    required String activityType,
    required String level,
  }) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM eduplay_sessions
      WHERE child_id = ? AND activity_type = ? AND level = ?
    ''', [childId, activityType, level]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns {'letter_order': '78%', 'spelling_gap': '62%', ...} — average
  /// accuracy per skill_area across every session this child has.
  static Future<Map<String, String>> getSkillAccuracyMap(String childId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT skill_area, AVG(accuracy_percentage) AS avg_accuracy
      FROM eduplay_sessions
      WHERE child_id = ?
      GROUP BY skill_area
    ''', [childId]);

    return {
      for (final row in rows)
        (row['skill_area'] as String): '${(row['avg_accuracy'] as num).round()}%',
    };
  }

  /// Average accuracy_percentage across every session this child has —
  /// the Journey dashboard's single "Overall Accuracy" figure. Plain
  /// AVG() read over the existing eduplay_sessions table, no new tracking.
  static Future<double> getOverallAccuracy(String childId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT AVG(accuracy_percentage) as avg_acc
      FROM eduplay_sessions WHERE child_id = ?
    ''', [childId]);
    final value = result.first['avg_acc'];
    return value == null ? 0.0 : (value as num).toDouble();
  }

  /// Sessions completed since the start of this calendar week (Monday) —
  /// the Journey dashboard's "Sessions This Week" figure. Plain COUNT()
  /// read over the existing eduplay_sessions table, no new tracking.
  static Future<int> getSessionCountThisWeek(String childId) async {
    final db = await database;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startIso = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).toIso8601String();
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM eduplay_sessions
      WHERE child_id = ? AND completed_at >= ?
    ''', [childId, startIso]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<List<Map<String, dynamic>>> getAssignmentHistory(String childId) async {
    final db = await database;
    return db.query(
      'eduplay_assigned_lessons',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'assigned_at DESC',
    );
  }

  // ── Internal ──────────────────────────────────────────────────────────

  static const _uuidGen = Uuid();

  static String _uuid() => _uuidGen.v4();
}
