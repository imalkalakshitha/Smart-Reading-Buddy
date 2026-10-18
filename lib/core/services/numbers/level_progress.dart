import 'package:smart_reading_buddy/core/services/numbers/level_config.dart';

enum LevelState { locked, unlocked, passed, comingSoon }

/// Unlock rules for Number Learning (pure logic, no storage):
/// - a level passes with [passScore]/10 or more in one completed session
/// - level 1 of an unlocked track is open; each next level opens when the
///   previous PLAYABLE level is passed
/// - Advanced opens only once every playable Basic level is passed
/// - activity types not built yet are "coming soon" and skipped in the
///   chain, so they never block later levels
class LevelProgressRules {
  LevelProgressRules._();

  static const passScore = 8;
  static const questionsPerSession = 10;

  /// Every type in [ActivityType.all] has a generator — QuestionGenerator,
  /// or MatchBoardGenerator for Number Match. (Checked against the type
  /// list rather than the generator so this file can live in core/,
  /// which can't import the Numbers feature; a Numbers test keeps the two
  /// in sync.)
  static bool isPlayable(LevelConfig l) => ActivityType.all.contains(l.activityType);

  static Map<String, LevelState> states(
    List<LevelConfig> trackLevels,
    Map<String, int> bestScores, {
    required bool trackUnlocked,
  }) {
    final out = <String, LevelState>{};
    var previousPassed = trackUnlocked;
    for (final l in trackLevels) {
      if (!isPlayable(l)) {
        out[l.id] = LevelState.comingSoon;
        continue;
      }
      final passed = (bestScores[l.id] ?? 0) >= passScore;
      if (passed) {
        out[l.id] = LevelState.passed;
      } else if (previousPassed) {
        out[l.id] = LevelState.unlocked;
      } else {
        out[l.id] = LevelState.locked;
      }
      previousPassed = passed;
    }
    return out;
  }

  /// Every playable level in [trackLevels] passed (and at least one exists).
  static bool trackComplete(List<LevelConfig> trackLevels, Map<String, int> bestScores) {
    final playable = trackLevels.where(isPlayable).toList();
    return playable.isNotEmpty &&
        playable.every((l) => (bestScores[l.id] ?? 0) >= passScore);
  }
}
