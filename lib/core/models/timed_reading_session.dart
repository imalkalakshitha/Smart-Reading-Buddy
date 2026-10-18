/// Per-sentence timing for one Timed Reading attempt.
class UnitTiming {
  final int unitIndex;
  final int elapsedMs;
  final bool stalled;
  // True if elapsedMs came in under lowerThresholdSec for this sentence —
  // the "too fast" counterpart to [stalled]. Plausibility/data-quality
  // signal only, not punitive: flags a time for review (e.g. a tap-
  // through without genuinely reading aloud) rather than silently
  // accepting it as valid. Never affects elapsedMs/WPM/WCPM themselves —
  // purely informational, same as [stalled].
  final bool tooFast;
  // Word indices (local to this sentence's own word list) that STT
  // diffing flagged as possibly misread. English only: on-device diff via
  // HybridPronunciationScorer's transcript. Sinhala no longer runs any
  // transcription/diff at all (see TimedReadingAudioRecorder — Gemini was
  // removed from Sinhala Timed Reading entirely in favor of parent-listen
  // + manual marking), so this is always null for Sinhala units. null
  // means no diff ran for this unit — not "no errors found". An empty
  // (non-null) list means diffing ran and found none.
  final List<int>? autoDetectedMisreadIndexes;
  // True if the engine returned empty/no-match content (silence, dummy
  // noise) — elapsedMs is 0 for this unit in that case and the child
  // should be prompted to try the sentence again, rather than a bad
  // timing being recorded silently. English only (Sinhala's manual-Done
  // design has no "no valid speech" concept — every Done tap is valid).
  final bool noSpeechDetected;
  // Sinhala only: path to this unit's recorded temp WAV, so
  // MiscueMarkingScreen can offer playback for manual marking. In-memory
  // only until MiscueMarkingScreen._saveSession moves it into permanent
  // Parent Dashboard review storage (see TimedReadingAudioRecorder) —
  // deleted once a parent listens, or by the 14-day safety-net sweep.
  // Always null for English.
  final String? audioFilePath;

  const UnitTiming({
    required this.unitIndex,
    required this.elapsedMs,
    required this.stalled,
    this.tooFast = false,
    this.autoDetectedMisreadIndexes,
    this.noSpeechDetected = false,
    this.audioFilePath,
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
  // marking at start — English's on-device STT pre-check found it
  // unavailable. (Sinhala's old connectivity pre-check no longer exists —
  // Sinhala recording is fully offline now and always available.)
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
