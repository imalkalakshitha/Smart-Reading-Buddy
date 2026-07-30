class PronunciationResult {
  final String verdict;   // 'OK' | 'ALMOST' | 'WRONG' | 'NO_SPEECH'
  final int    stars;     // 0–3
  final int    xpEarned;
  final double confidence; // STT confidence 0.0–1.0 (0.0 = not reported)

  const PronunciationResult({
    required this.verdict,
    required this.stars,
    required this.xpEarned,
    this.confidence = 0.0,
  });
}
