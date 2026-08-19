/// A single just-completed EduPlay session, passed into FeatureBuilder and
/// EduPlayEngine — this is engine-internal, not a DB row (see
/// eduplay_database.dart's eduplay_sessions table for the persisted shape).
class EduPlaySessionResult {
  final String sessionId;
  final String childId;
  final String taskId;
  final String activityType;
  final String language;
  final String grade;
  final String level;
  final double accuracyPct; // 0-100
  final double timeSpentSec;
  final int attemptCount;
  final int hintsUsed;
  final int audioReplayCount;
  final int mistakeCount;
  final String mistakeType; // one of kMistakeTypes
  final bool isCorrect;

  const EduPlaySessionResult({
    required this.sessionId,
    required this.childId,
    required this.taskId,
    required this.activityType,
    required this.language,
    required this.grade,
    required this.level,
    required this.accuracyPct,
    required this.timeSpentSec,
    required this.attemptCount,
    required this.hintsUsed,
    required this.audioReplayCount,
    required this.mistakeCount,
    required this.mistakeType,
    required this.isCorrect,
  });
}

/// Builds the 30-column feature map RFModel.predict() expects, from live
/// app state — the just-completed session plus whatever history/profile/
/// task rows already exist (all nullable: a brand-new child has none of
/// them, handled by the cold-start medians below, which are the training
/// data's own numeric_medians/categorical_defaults from rf_model.json).
class FeatureBuilder {
  FeatureBuilder._();

  static Map<String, dynamic> build({
    required EduPlaySessionResult session,
    required Map<String, dynamic>? history,
    required Map<String, dynamic>? profile,
    required Map<String, dynamic>? task,
  }) {
    final performanceBand = _performanceBand(session.accuracyPct);

    return {
      // Numeric (13)
      'accuracy_percentage': session.accuracyPct,
      'time_spent_seconds': session.timeSpentSec,
      'attempt_count': session.attemptCount,
      'hints_used': session.hintsUsed,
      'audio_replay_count': session.audioReplayCount,
      'mistake_count': session.mistakeCount,
      'previous_accuracy': (history?['previous_accuracy'] as num?)?.toDouble() ?? 61.1,
      'last_5_accuracy': (history?['last_5_accuracy'] as num?)?.toDouble() ?? 60.0,
      'average_time_last_5': (history?['average_time_last_5'] as num?)?.toDouble() ?? 61.0,
      'recent_mistake_rate': (history?['recent_mistake_rate'] as num?)?.toDouble() ?? 0.6,
      'total_completed_activities':
          (profile?['total_completed_activities'] as num?)?.toInt() ?? 0,
      'baseline_accuracy': (profile?['baseline_accuracy'] as num?)?.toDouble() ?? 66.8,
      'baseline_response_time_seconds':
          (profile?['baseline_response_time_sec'] as num?)?.toDouble() ?? 41.2,

      // Categorical (17)
      'activity_type': session.activityType,
      'language': session.language,
      'grade': session.grade,
      'level': session.level,
      'difficulty': task?['difficulty'] ?? 'Easy',
      'mistake_type': session.mistakeType,
      'performance_band': performanceBand,
      'previous_activity_type': history?['previous_activity_type'] ?? 'none',
      'weakest_skill_area': history?['weakest_skill_area'] ?? 'letter_order',
      'strongest_skill_area': history?['strongest_skill_area'] ?? 'letter_order',
      'skill_area': task?['skill_area'] ?? 'letter_order',
      'target_error_type': task?['target_error_type'] ?? 'sound_confusion',
      'profile_grade': profile?['grade'] ?? session.grade,
      'starting_level': profile?['starting_level'] ?? 'Basic',
      'preferred_language': profile?['language'] ?? session.language,
      'support_need_level': profile?['support_need_level'] ?? 'Medium',
      'main_focus_area': profile?['main_focus_area'] ?? 'letter_order',
    };
  }

  static String _performanceBand(double accuracyPct) {
    if (accuracyPct >= 80) return 'High';
    if (accuracyPct < 60) return 'Low';
    return 'Medium';
  }
}
