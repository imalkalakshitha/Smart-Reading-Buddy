import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

/// Loads and queries assets/eduplay/eduplay_tasks.json — 875 tasks, ~1.2 MB,
/// loaded once at app start and held in memory for the rest of the run.
class TaskRepository {
  static TaskRepository? _instance;
  static TaskRepository get instance => _instance!;

  final List<Map<String, dynamic>> _tasks;

  TaskRepository._(this._tasks);

  static Future<void> initialize() async {
    final raw = await rootBundle.loadString('assets/eduplay/eduplay_tasks.json');
    final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _instance = TaskRepository._(decoded);
  }

  /// Tasks for a given activity, grade, language, level — only ones with
  /// real audio (audio_available == true), shuffled with a per-child,
  /// per-day seed so the same child sees variety session-to-session but
  /// the same set within one day (stable across a single sitting).
  List<Map<String, dynamic>> getTasksFor({
    required String activityType,
    required String grade,
    required String language,
    required String level,
    required String childId,
  }) {
    final matches = _tasks
        .where((t) =>
            t['activity_type'] == activityType &&
            t['grade'] == grade &&
            t['language'] == language &&
            t['level'] == level &&
            t['audio_available'] == true)
        .toList();

    final seed = childId.hashCode ^ DateTime.now().day;
    matches.shuffle(Random(seed));
    return matches;
  }

  /// Single task by id.
  Map<String, dynamic>? getTaskById(String taskId) {
    for (final task in _tasks) {
      if (task['task_id'] == taskId) return task;
    }
    return null;
  }

  /// This task's audio path, or null if none is available.
  String? getAudioPath(String taskId) {
    final task = getTaskById(taskId);
    if (task == null || task['audio_available'] != true) return null;
    return task['audio_path'] as String?;
  }
}
