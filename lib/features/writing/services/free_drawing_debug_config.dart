/// Temporary dev overlay switch for tuning kTargetProbabilityThreshold /
/// kTargetRankTopN (see free_drawing_recognizer.dart) against real
/// on-device attempts. Shows p_target, target rank, and the raw top-1
/// prediction + confidence on the result screen when true. Flip to false
/// before any parent/child-facing demo — the child must never see these
/// numbers.
const bool kShowFreeDrawingDebugInfo = false;
