import 'dart:ui';
import 'package:smart_reading_buddy/features/writing/services/canvas_ink_guard.dart';

/// Scribble/nonsense rejection — runs AFTER model inference but BEFORE the
/// target-based accept/reject decision (see FreeDrawingRecognizer
/// .evaluateAgainstTarget). The model has no "not a character" class, so a
/// random scribble still gets scored against every one of the 95 classes
/// and something always comes out on top; this guard exists to catch that
/// case independently of what the model happened to guess.
///
/// Tunable thresholds — all four in one place so they can be adjusted
/// together after on-device testing. Start-point values, not calibrated
/// against real scribble data yet:
///   - kMinPeakConfidence: below this, the model isn't confident about
///     ANYTHING (a real letter gives a clear peak; a scribble spreads
///     probability thinly across many classes).
///   - kMinTopGap: below this top1-minus-top2 gap, the model is
///     essentially guessing between two-plus classes rather than
///     recognising one.
///   - kMaxStrokes: no single letter in either script (English or Sinhala)
///     needs more pen-lifts than this; more implies scribbling/repeated
///     cover-up strokes rather than one deliberate character.
///   - kMaxInkRatio: dark-pixel fraction of the ink's own bounding box: a
///     drawn character is mostly negative space even inside its own
///     bounds; a scribble fills much more of it solid.
const double kMinPeakConfidence = 0.30;
const double kMinTopGap = 0.10;
const int kMaxStrokes = 6;
const double kMaxInkRatio = 0.45;

/// One of these fires → do not accept, regardless of how well the drawing
/// scores against the target. Values are internal/technical (parent
/// dashboard + debug overlay only) — never surfaced to the child, who only
/// ever sees the normal "Let's try again!" message.
enum ScribbleRejectionReason {
  lowPeakConfidence,
  flatDistribution,
  tooManyStrokes,
  excessiveInk,
}

extension ScribbleRejectionReasonLabel on ScribbleRejectionReason {
  /// Stored in free_drawing_attempts.rejection_reason and shown in the
  /// debug overlay / parent technical-details breakdown.
  String get dbValue => switch (this) {
        ScribbleRejectionReason.lowPeakConfidence => 'low_peak_confidence',
        ScribbleRejectionReason.flatDistribution => 'flat_distribution',
        ScribbleRejectionReason.tooManyStrokes => 'too_many_strokes',
        ScribbleRejectionReason.excessiveInk => 'excessive_ink',
      };
}

class ScribbleGuard {
  ScribbleGuard._();

  /// Returns the first rejection reason that fires, or null if the drawing
  /// passes every check. Checked in the order listed in the class doc
  /// comment; only one reason is ever recorded per attempt.
  static ScribbleRejectionReason? check({
    required double rawTop1Confidence,
    required double rawTop2Confidence,
    required List<Offset?> strokePoints,
    required double inkRatio,
  }) {
    if (rawTop1Confidence < kMinPeakConfidence) {
      return ScribbleRejectionReason.lowPeakConfidence;
    }
    if (rawTop1Confidence - rawTop2Confidence < kMinTopGap) {
      return ScribbleRejectionReason.flatDistribution;
    }
    if (CanvasInkGuard.strokeCount(strokePoints) > kMaxStrokes) {
      return ScribbleRejectionReason.tooManyStrokes;
    }
    if (inkRatio > kMaxInkRatio) {
      return ScribbleRejectionReason.excessiveInk;
    }
    return null;
  }
}
