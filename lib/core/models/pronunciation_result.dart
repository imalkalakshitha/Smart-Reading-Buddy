class PronunciationResult {
  final String verdict;   // 'OK' | 'ALMOST' | 'WRONG' | 'NO_SPEECH'
  final int    stars;     // 0–3
  final int    xpEarned;
  final double confidence; // STT confidence 0.0–1.0 (0.0 = not reported)

  // What the child actually said, before any matching/normalisation —
  // English: raw speech_to_text recognizedWords. Sinhala: Gemini's raw
  // transcription. Null when nothing was recognized (NO_SPEECH/NO_INTERNET)
  // or the underlying scorer doesn't produce text (e.g. energy fallback).
  // Used for phonological substitution analysis (see
  // phoneme_substitution_analyzer.dart) — not persisted/used otherwise.
  final String? rawTranscript;

  // Persistent-storage path to the child's own recorded WAV for this
  // attempt — English only, and only ever set when the verdict was
  // WRONG (see HybridPronunciationScorer's English path: the parallel
  // `record`-package capture running alongside on-device STT is deleted
  // immediately for OK/ALMOST/NO_SPEECH attempts, kept only for WRONG,
  // per the storage-cleanup policy). Null for every other case —
  // Sinhala, DTW/energy-fallback, and any non-WRONG English attempt.
  final String? audioPath;

  // ── Decision Fusion (English only) ───────────────────────────────────
  // Both raw signals behind the fused verdict, kept for logging/research
  // (accuracy validation report, STT/DTW agreement analysis) — not used
  // to drive any other UI. Null for Sinhala and for English attempts
  // where DTW scoring didn't run (e.g. concurrent capture failed).

  // Which text-match strategy STT satisfied: 'S1'..'S5', or null if none
  // matched at all (verdict was WRONG on text alone).
  final String? sttStrategy;
  // Raw DTW distance from PronunciationScorer.scoreDetailsFromFile.
  final double? dtwDistance;
  // DTW's own independent verdict ('OK'/'ALMOST'/'WRONG'/'NO_SPEECH') —
  // may differ from this result's fused [verdict]; that disagreement is
  // exactly the signal being logged.
  final String? dtwVerdict;

  const PronunciationResult({
    required this.verdict,
    required this.stars,
    required this.xpEarned,
    this.confidence = 0.0,
    this.rawTranscript,
    this.audioPath,
    this.sttStrategy,
    this.dtwDistance,
    this.dtwVerdict,
  });
}
