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

  const PronunciationResult({
    required this.verdict,
    required this.stars,
    required this.xpEarned,
    this.confidence = 0.0,
    this.rawTranscript,
  });
}
