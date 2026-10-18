import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:smart_reading_buddy/core/dao/eduplay_database.dart';
import 'package:smart_reading_buddy/features/eduplay_encoding/services/feature_builder.dart';
import 'package:smart_reading_buddy/features/eduplay_encoding/services/rf_inference.dart';

/// Orchestrates the full post-session EduPlay flow: persist the session,
/// roll up history stats, run the RF model, store a recommendation, award
/// XP, and close out any matching assigned lesson. Called once per
/// completed session by the (not-yet-built) EduPlay UI layer.
class EduPlayEngine {
  final RFModel _model;
  static const _uuid = Uuid();

  EduPlayEngine._(this._model);

  static Future<EduPlayEngine> create() async {
    return EduPlayEngine._(await RFModel.load());
  }

  /// Call this after every session ends.
  Future<void> onSessionComplete(
    EduPlaySessionResult result,
    Map<String, dynamic> task,
  ) async {
    // 1. Performance band.
    final performanceBand = _performanceBand(result.accuracyPct);

    // 2. Persist the session.
    await EduPlayDatabase.insertSession({
      'session_id': result.sessionId,
      'child_id': result.childId,
      'task_id': result.taskId,
      'activity_type': result.activityType,
      'language': result.language,
      'grade': result.grade,
      'level': result.level,
      'difficulty': task['difficulty'] ?? 'Easy',
      'skill_area': task['skill_area'] ?? 'letter_order',
      'target_error_type': task['target_error_type'] ?? 'sound_confusion',
      'accuracy_percentage': result.accuracyPct,
      'time_spent_seconds': result.timeSpentSec,
      'attempt_count': result.attemptCount,
      'hints_used': result.hintsUsed,
      'audio_replay_count': result.audioReplayCount,
      'mistake_count': result.mistakeCount,
      'mistake_type': result.mistakeType,
      'performance_band': performanceBand,
      'is_correct': result.isCorrect ? 1 : 0,
      'completed_at': DateTime.now().toIso8601String(),
    });

    // 3. Last 5 sessions for this child (newest first).
    final recentSessions =
        await EduPlayDatabase.getRecentSessions(result.childId, limit: 5);

    // 4-5. Compute + persist updated history stats.
    await EduPlayDatabase.updateHistoryStats(result.childId, recentSessions);

    // 6. Fetch profile and (now-updated) history.
    final profile = await EduPlayDatabase.getChildProfile(result.childId);
    final history = await EduPlayDatabase.getHistoryStats(result.childId);

    // 7. Build feature vector.
    final features = FeatureBuilder.build(
      session: result,
      history: history,
      profile: profile,
      task: task,
    );

    // 8. Guards — skip recommendation entirely for a perfect score (with
    // nothing already pending), or if one is already pending.
    final existingPending = await EduPlayDatabase.getPendingRecommendation(result.childId);
    final isPerfectScore = result.isCorrect && result.accuracyPct == 100.0;
    final skipPerfect = isPerfectScore && existingPending == null;

    if (!skipPerfect && existingPending == null) {
      // 9. Predict.
      final prediction = _model.predict(features);

      // 10. Store the recommendation.
      await EduPlayDatabase.insertRecommendation({
        'rec_id': _uuid.v4(),
        'child_id': result.childId,
        'recommended_activity': prediction.activity,
        'recommended_level': result.level,
        'confidence': prediction.confidence,
        'top_features': _encodeTopFeatures(prediction.topFeatures),
        'rule_tag': prediction.ruleTag,
        'status': 'PENDING',
        'parent_choice': null,
        'generated_at': DateTime.now().toIso8601String(),
        'actioned_at': null,
      });
    }
    // else: perfect score with nothing pending, or already pending —
    // skip, per spec.

    // 11. Award XP.
    var xp = 10;
    if (result.accuracyPct >= 80) xp += 5;
    if (result.accuracyPct == 100) xp += 5;

    final activeAssignment = await EduPlayDatabase.getActiveAssignment(result.childId);
    final matchesActiveAssignment = activeAssignment != null &&
        activeAssignment['activity_type'] == result.activityType &&
        activeAssignment['level'] == result.level;
    if (matchesActiveAssignment) xp += 10;

    await EduPlayDatabase.addXp(
      result.childId,
      xp,
      matchesActiveAssignment ? 'assigned_lesson' : 'session_complete',
      sessionId: result.sessionId,
    );

    // 12. Close out the matching active assignment, if any.
    if (matchesActiveAssignment) {
      await EduPlayDatabase.completeAssignment(
        activeAssignment['assignment_id'] as String,
        result.accuracyPct,
      );
    }
  }

  /// Returns the pending recommendation for display in the parent dashboard.
  Future<Map<String, dynamic>?> getPendingRecommendation(String childId) =>
      EduPlayDatabase.getPendingRecommendation(childId);

  /// Parent approves the recommendation.
  Future<String> approveRecommendation(String recId, String childId) async {
    final rec = await _requireRecommendation(recId, childId);

    await EduPlayDatabase.updateRecommendationStatus(recId, 'APPROVED');

    final assignmentId = _uuid.v4();
    await EduPlayDatabase.insertAssignment({
      'assignment_id': assignmentId,
      'child_id': childId,
      'rec_id': recId,
      'activity_type': rec['recommended_activity'],
      'level': rec['recommended_level'],
      'assigned_at': DateTime.now().toIso8601String(),
      'completed_at': null,
      'pre_accuracy': null,
      'post_accuracy': null,
      'status': 'ASSIGNED',
    });
    return assignmentId;
  }

  /// Parent overrides with their own choice.
  Future<String> overrideRecommendation(
    String recId,
    String childId,
    String chosenActivity,
    String chosenLevel,
  ) async {
    await EduPlayDatabase.updateRecommendationStatus(
      recId,
      'OVERRIDDEN',
      parentChoice: chosenActivity,
    );

    final assignmentId = _uuid.v4();
    await EduPlayDatabase.insertAssignment({
      'assignment_id': assignmentId,
      'child_id': childId,
      'rec_id': recId,
      'activity_type': chosenActivity,
      'level': chosenLevel,
      'assigned_at': DateTime.now().toIso8601String(),
      'completed_at': null,
      'pre_accuracy': null,
      'post_accuracy': null,
      'status': 'ASSIGNED',
    });
    return assignmentId;
  }

  /// Parent dismisses without assigning.
  Future<void> dismissRecommendation(String recId) =>
      EduPlayDatabase.updateRecommendationStatus(recId, 'DISMISSED');

  // ── Internal ──────────────────────────────────────────────────────────

  /// The spec's DB helper list only exposes getPendingRecommendation(by
  /// childId), not a lookup by rec_id — approve/override are always called
  /// on a recommendation the caller already fetched via
  /// getPendingRecommendation, so this re-fetches by childId and asserts
  /// it's the same row, rather than adding a new DB method beyond spec.
  Future<Map<String, dynamic>> _requireRecommendation(String recId, String childId) async {
    final rec = await EduPlayDatabase.getPendingRecommendation(childId);
    if (rec == null || rec['rec_id'] != recId) {
      throw StateError('No pending recommendation $recId found for child $childId');
    }
    return rec;
  }

  String _performanceBand(double accuracyPct) {
    if (accuracyPct >= 80) return 'High';
    if (accuracyPct < 60) return 'Low';
    return 'Medium';
  }

  String _encodeTopFeatures(List<TopFeature> features) {
    final list = features
        .map((f) => {'feature': f.name, 'value': f.value, 'impact': f.impact})
        .toList();
    return jsonEncode(list);
  }
}
