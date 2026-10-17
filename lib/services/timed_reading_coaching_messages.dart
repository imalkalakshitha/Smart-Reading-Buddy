/// "Buddy Voice Coaching" substitute — short on-screen text messages
/// instead of audio, given the hardware/audio-recording complexity
/// already encountered elsewhere in this project. UI/timer-triggered
/// only; has no connection to STT/VAD/Gemini/mic recording at all.
///
/// Same shape as coaching_strategy.dart's CoachingStrategy — static
/// methods keyed by [lang] ('en'/'si'), short emoji-suffixed phrases.
/// Tone matches SentenceReportCard's existing standard: encouraging,
/// invitation-style, never "slow"/"behind"/"wrong" framing.
///
/// SINHALA: intentionally returns null until real, verified Sinhala copy
/// is supplied — this project's established rule is that Sinhala
/// Unicode text is never hand-typed directly; it must come through the
/// verified transcription pipeline. Same convention as
/// free_drawing_cues.dart's missing-cue entries: callers must treat a
/// null return as "show nothing", not an error. Fill these in once
/// verified text exists.
class TimedReadingCoachingMessages {
  TimedReadingCoachingMessages._();

  /// Shown once, when the reading session screen first loads.
  static String? start(String lang) {
    if (lang == 'si') return null; // pending verified Sinhala copy
    return "Let's read together! 📖";
  }

  /// Shown at most once per recording attempt, when elapsed time (from
  /// the same speech-onset baseline the post-hoc `stalled` check already
  /// uses) crosses the current sentence's upperThresholdSec while still
  /// actively recording. Deliberately never names "slow"/"behind" — just
  /// a forward-momentum nudge.
  static String? encouragePace(String lang) {
    if (lang == 'si') return null; // pending verified Sinhala copy
    return 'Keep going! 🌟';
  }

  /// Shown when advancing to the next sentence (not shown on the final
  /// unit — that transition uses [sessionComplete] instead).
  static String? nextUnit(String lang) {
    if (lang == 'si') return null; // pending verified Sinhala copy
    return 'Great job! Next one →';
  }

  /// Shown once, right before navigating away to Miscue Marking.
  static String? sessionComplete(String lang) {
    if (lang == 'si') return null; // pending verified Sinhala copy
    return 'All done — well read! 🎉';
  }
}
