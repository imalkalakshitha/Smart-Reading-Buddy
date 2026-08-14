/// Per-sentence timing for one Timed Reading attempt.
class UnitTiming {
  final int unitIndex;
  final int elapsedMs;
  final bool stalled;
  // Word indices (local to this sentence's own word list) that STT/Gemini
  // diffing flagged as possibly misread. English: on-device diff via
  // HybridPronunciationScorer's transcript. Sinhala: Gemini transcript
  // diff (only when online — see TimedReadingSpeechBridge). null means no
  // diff ran for this unit (offline Sinhala fallback, or STT/Gemini
  // unavailable) — not "no errors found". An empty (non-null) list means
  // diffing ran and found none.
  final List<int>? autoDetectedMisreadIndexes;
  // True if the engine returned empty/no-match content (silence, dummy
  // noise) — elapsedMs is 0 for this unit in that case and the child
  // should be prompted to try the sentence again, rather than a bad
  // timing being recorded silently.
  final bool noSpeechDetected;

  const UnitTiming({
    required this.unitIndex,
    required this.elapsedMs,
    required this.stalled,
    this.autoDetectedMisreadIndexes,
    this.noSpeechDetected = false,
  });
}

/// Mutable in-memory state for one Timed Reading attempt. Frontend-only
/// for now (no SQLite writes) — kept as its own file, separate from the
/// const content bank in timed_reading_data.dart, so it can be persisted
/// to SQLite later without reshaping.
class TimedReadingSession {
  final String activityId;
  // Single field standing in for a future numeric child id — populated
  // from AppState.name, does not require any AppState refactor.
  final String childKey;

  final List<UnitTiming> unitTimings = [];
  // Indexes into the flattened word list across all sentences in this
  // session — used by MiscueMarkingScreen's word-chip grid.
  final Set<int> misreadWordIndexes = {};

  DateTime? startedAt;
  DateTime? endedAt;
  bool accuracyMarked = false;
  // Set true if the app was backgrounded mid-session (see
  // ReadingScreen's WidgetsBindingObserver handling).
  bool interrupted = false;
  // Set true if this session fell back to plain tap-advance + manual
  // marking at start — either Sinhala's connectivity pre-check failed, or
  // English's on-device STT pre-check found it unavailable.
  // MiscueMarkingScreen shows the original blank manual state (no
  // "Auto-detected" caption) when this is true, matching pre-STT
  // behavior exactly.
  bool manualFallback = false;

  TimedReadingSession({
    required this.activityId,
    required this.childKey,
  });

  int get totalElapsedMs =>
      unitTimings.fold(0, (sum, t) => sum + t.elapsedMs);

  int get errorCount => misreadWordIndexes.length;
}
