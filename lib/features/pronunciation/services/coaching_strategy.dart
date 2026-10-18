/// Graduated coaching — more support each failed attempt.
///
/// Attempt 1 fail → minimal: "Try again!"
/// Attempt 2 fail → moderate: "Listen first!" + auto-play reference audio
/// Attempt 3 fail → maximum: "Watch mouth guide!" + audio + expand VMG
enum SupportLevel { none, minimal, moderate, maximum }

class CoachingResponse {
  final SupportLevel supportLevel;
  final String buddyMessage;
  final bool playReferenceAudio;
  final bool autoExpandVMG;

  const CoachingResponse({
    required this.supportLevel,
    required this.buddyMessage,
    this.playReferenceAudio = false,
    this.autoExpandVMG = false,
  });
}

class CoachingStrategy {
  CoachingStrategy._();

  static CoachingResponse forPass(String lang) => const CoachingResponse(
        supportLevel: SupportLevel.none,
        buddyMessage: '',
      );

  /// [attemptNumber] is 1-indexed (1 = first attempt, 3 = final attempt).
  static CoachingResponse forFail({
    required int attemptNumber,
    required String lang,
  }) {
    switch (attemptNumber) {
      case 1:
        return CoachingResponse(
          supportLevel: SupportLevel.minimal,
          buddyMessage: lang == 'si'
              ? 'නැවත උත්සාහ කරන්න! 💪'
              : 'Try again! 💪',
        );
      case 2:
        return CoachingResponse(
          supportLevel: SupportLevel.moderate,
          buddyMessage: lang == 'si'
              ? 'සවන් දෙන්න, පළමුව! 👂'
              : 'Listen carefully first! 👂',
          playReferenceAudio: true,
        );
      default: // attempt 3+ (final)
        return CoachingResponse(
          supportLevel: SupportLevel.maximum,
          buddyMessage: lang == 'si'
              ? 'කට හැඩය බලා කරන්න! 👀👂'
              : 'Watch the mouth guide! 👀👂',
          playReferenceAudio: true,
          autoExpandVMG: true,
        );
    }
  }
}
