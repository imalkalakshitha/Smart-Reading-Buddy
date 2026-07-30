/// Pure utility — no state, no timers.
/// All timing is based on word count × per-word constants (dyslexia-friendly pace).
class ReadingTimerService {
  static const int _msPerWordExpected = 1500;
  static const int _msPerWordFast     = 800;
  static const int _msPerWordSlow     = 2500;

  static int expectedMs(int wordCount)      => wordCount * _msPerWordExpected;
  static int fastThresholdMs(int wordCount) => wordCount * _msPerWordFast;
  static int slowThresholdMs(int wordCount) => wordCount * _msPerWordSlow;

  /// Interval between successive word highlights during auto-advance.
  static int wordIntervalMs(int wordCount) {
    if (wordCount <= 0) return _msPerWordExpected;
    return expectedMs(wordCount) ~/ wordCount;
  }

  /// 0.0 – 1.0 fill fraction for the countdown ring, clamped to [0, 1].
  static double ringProgress(int elapsedMs, int wordCount) {
    final total = slowThresholdMs(wordCount);
    if (total <= 0) return 0;
    return (elapsedMs / total).clamp(0.0, 1.0);
  }

  /// Remaining seconds to display on the countdown (may go negative = overtime).
  static int remainingSeconds(int elapsedMs, int wordCount) {
    return ((expectedMs(wordCount) - elapsedMs) / 1000).ceil();
  }
}
