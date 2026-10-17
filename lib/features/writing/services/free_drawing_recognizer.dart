import 'dart:typed_data';
import 'dart:ui';
import 'package:smart_reading_buddy/features/writing/services/canvas_ink_guard.dart';
import 'package:smart_reading_buddy/features/writing/services/character_model_service.dart';
import 'package:smart_reading_buddy/features/writing/services/drawing_preprocessing.dart';
import 'package:smart_reading_buddy/features/writing/services/scribble_guard.dart';

/// Calibrated from Stage 1 on-device testing: correct answers came back as
/// low as 57% confidence, so anything higher would reject genuinely
/// correct writing. Confidence alone never decides correctness though —
/// see [FreeDrawingRecognizer.isCorrect].
const double kFreeDrawingConfidenceThreshold = 0.45;

/// Stage 2 scoring, replaces top-1-vs-threshold as the rule Letter/Word
/// Level actually score against (see [FreeDrawingRecognizer
/// .evaluateAgainstTarget]): since the target is known, we look up the
/// probability the model gave that exact target rather than trusting its
/// top-1 guess. Starting point per on-device testing — the current
/// (55-images-per-class) model confuses several character pairs at high
/// top-1 confidence, so top-1 matching alone rejects too much genuinely
/// correct writing.
const double kTargetProbabilityThreshold = 0.25;
const int kTargetRankTopN = 3;

/// Everything one drawing attempt needs, both for the lenient child-facing
/// accept/reject decision and for the raw numbers the parent
/// dashboard/model evaluation need. [rawTop1Character]/[rawTop1Confidence]
/// are always the model's genuine top-1 guess over the full language mask,
/// so they reflect where the model itself is wrong, independent of scoring.
class TargetEvaluation {
  final String rawTop1Character;
  final double rawTop1Confidence;
  final double pTarget; // renormalised over the full language-allowed range
  final int targetRank; // 1-based rank of the target within that range
  final bool accepted;
  // Non-null when ScribbleGuard rejected this attempt (see its doc comment)
  // — accepted is always false when this is set, regardless of pTarget/
  // targetRank. Null on every accepted attempt and on every rejection that
  // was a genuine wrong-target guess rather than a scribble.
  final ScribbleRejectionReason? rejectionReason;
  const TargetEvaluation({
    required this.rawTop1Character,
    required this.rawTop1Confidence,
    required this.pTarget,
    required this.targetRank,
    required this.accepted,
    this.rejectionReason,
  });
}

class RecognitionResult {
  final String predictedCharacter;
  final int predictedIndex; // real index into the full 95-class list
  final double confidence; // renormalised over the language-allowed slice only
  const RecognitionResult({
    required this.predictedCharacter,
    required this.predictedIndex,
    required this.confidence,
  });
}

/// Combines preprocessing + model inference + language filtering into the
/// single entry point the UI calls. The model always returns all 95
/// class probabilities regardless of account language, so filtering to
/// the relevant script happens here, after inference — including
/// renormalising confidence over just the allowed slice, since otherwise
/// splitting off ~half the softmax mass makes every confidence look
/// wrongly low.
class FreeDrawingRecognizer {
  // index 0-25 English upper, 26-51 English lower, 52-94 Sinhala (43 chars).
  // Public so Letter/Word Level screens can build their own target-character
  // sequences from CharacterModelService.classNames using the same bounds.
  static const int enStart = 0;
  static const int enEnd = 51;
  static const int siStart = 52;
  static const int siEnd = 94;

  /// Returns null when the canvas has no ink — caller should show
  /// "Nothing drawn yet" and must not treat this as a low-confidence
  /// prediction. [strokePoints] is the same null-separated point list the
  /// canvas painted from; it's checked first (cheap, no image decode) and
  /// stops inference outright before the pixel-level fallback in
  /// DrawingPreprocessor even runs.
  static Future<RecognitionResult?> recognize({
    required Uint8List pngBytes,
    required bool isSinhala,
    required List<Offset?> strokePoints,
  }) async {
    if (!CanvasInkGuard.hasInk(strokePoints)) return null;

    final pre = DrawingPreprocessor.process(pngBytes);
    if (!pre.hasInk) return null;

    await CharacterModelService.instance.load();
    final raw = CharacterModelService.instance.predictRaw(pre.input);
    final classNames = CharacterModelService.instance.classNames;

    final start = isSinhala ? siStart : enStart;
    final end = isSinhala ? siEnd : enEnd;

    int bestIndex = start;
    double bestP = raw[start];
    double sum = 0.0;
    for (int i = start; i <= end; i++) {
      sum += raw[i];
      if (raw[i] > bestP) {
        bestP = raw[i];
        bestIndex = i;
      }
    }
    final confidence = sum > 0 ? bestP / sum : 0.0;

    return RecognitionResult(
      predictedCharacter: classNames[bestIndex],
      predictedIndex: bestIndex,
      confidence: confidence,
    );
  }

  /// Old strict rule — kept available but unused by Letter/Word Level as
  /// of Stage 2 (see [evaluateAgainstTarget]'s doc comment for why: with
  /// this dataset-limited model, top-1 matching alone rejected too much
  /// genuinely correct writing). Left in place so scoring can be switched
  /// back to this if the retrained model changes the calculus.
  static bool isCorrect(RecognitionResult result, String target) =>
      result.predictedCharacter == target && result.confidence >= kFreeDrawingConfidenceThreshold;

  /// The rule Letter Level actually uses: the target character is known,
  /// so score the model's probability FOR that target rather than
  /// trusting its top-1 guess. Accepts when p_target clears
  /// [kTargetProbabilityThreshold] OR the target lands in the top
  /// [kTargetRankTopN] ranked classes — either is enough, since a
  /// genuinely correct drawing can still lose the top-1 slot to a
  /// visually-similar class this dataset-limited model confuses.
  static Future<TargetEvaluation?> evaluateAgainstTarget({
    required Uint8List pngBytes,
    required bool isSinhala,
    required List<Offset?> strokePoints,
    required String target,
  }) async {
    if (!CanvasInkGuard.hasInk(strokePoints)) return null;

    final pre = DrawingPreprocessor.process(pngBytes);
    if (!pre.hasInk) return null;

    await CharacterModelService.instance.load();
    final raw = CharacterModelService.instance.predictRaw(pre.input);
    final classNames = CharacterModelService.instance.classNames;

    final start = isSinhala ? siStart : enStart;
    final end = isSinhala ? siEnd : enEnd;
    final range = [for (int i = start; i <= end; i++) i];

    final sum = range.fold<double>(0.0, (s, i) => s + raw[i]);
    double probOf(int i) => sum > 0 ? raw[i] / sum : 0.0;

    int rawTop1Index = start;
    double rawTop1P = raw[start];
    for (final i in range) {
      if (raw[i] > rawTop1P) {
        rawTop1P = raw[i];
        rawTop1Index = i;
      }
    }
    final rawTop1Confidence = probOf(rawTop1Index);

    // Second-highest probability in range, for ScribbleGuard's flat-
    // distribution check — same range/renormalisation as top-1 above.
    int rawTop2Index = -1;
    double rawTop2P = -1;
    for (final i in range) {
      if (i == rawTop1Index) continue;
      if (raw[i] > rawTop2P) {
        rawTop2P = raw[i];
        rawTop2Index = i;
      }
    }
    final rawTop2Confidence = rawTop2Index >= 0 ? probOf(rawTop2Index) : 0.0;

    final targetIndex = classNames.indexOf(target);
    double pTarget = 0.0;
    int targetRank = range.length + 1; // sentinel: target not in this language's range at all
    if (range.contains(targetIndex)) {
      pTarget = probOf(targetIndex);
      final rankedDesc = [...range]..sort((a, b) => probOf(b).compareTo(probOf(a)));
      targetRank = rankedDesc.indexOf(targetIndex) + 1;
    }

    // Scribble/nonsense rejection runs BEFORE the target-based accept
    // decision below — see ScribbleGuard's doc comment. Any fired reason
    // overrides an otherwise-passing pTarget/targetRank result.
    final rejectionReason = ScribbleGuard.check(
      rawTop1Confidence: rawTop1Confidence,
      rawTop2Confidence: rawTop2Confidence,
      strokePoints: strokePoints,
      inkRatio: pre.inkRatio,
    );

    final targetAccepted = pTarget >= kTargetProbabilityThreshold || targetRank <= kTargetRankTopN;
    final accepted = rejectionReason == null && targetAccepted;

    return TargetEvaluation(
      rawTop1Character: classNames[rawTop1Index],
      rawTop1Confidence: rawTop1Confidence,
      pTarget: pTarget,
      targetRank: targetRank,
      accepted: accepted,
      rejectionReason: rejectionReason,
    );
  }
}
