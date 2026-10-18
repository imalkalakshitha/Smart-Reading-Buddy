import 'package:smart_reading_buddy/core/data/word_data.dart';

class PronunciationSessionArgs {
  final List<WordItem> words;
  final String levelName;
  final String levelKey;
  // True only for a session launched from the "Assigned Practice" banner.
  // Regular level-selection sessions never set this, so their behavior is
  // completely unchanged.
  final bool isAssignedPractice;
  // The raw phoneme token this session was assigned for (only set when
  // isAssignedPractice is true) — carried through to sessions.assigned_phoneme.
  final String? assignedPhoneme;

  const PronunciationSessionArgs({
    required this.words,
    required this.levelName,
    required this.levelKey,
    this.isAssignedPractice = false,
    this.assignedPhoneme,
  });
}

class SessionCompleteArgs {
  final int correct;
  final int almost;
  final int wrong;
  final int xpEarned;
  final int durationSeconds;
  final String levelName;
  final List<String> hardPhonemes;
  final bool isAssignedPractice;

  const SessionCompleteArgs({
    required this.correct,
    required this.almost,
    required this.wrong,
    required this.xpEarned,
    required this.durationSeconds,
    required this.levelName,
    required this.hardPhonemes,
    this.isAssignedPractice = false,
  });
}
