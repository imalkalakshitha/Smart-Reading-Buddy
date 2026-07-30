import 'word_data.dart';

class PronunciationSessionArgs {
  final List<WordItem> words;
  final String levelName;
  final String levelKey;

  const PronunciationSessionArgs({
    required this.words,
    required this.levelName,
    required this.levelKey,
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

  const SessionCompleteArgs({
    required this.correct,
    required this.almost,
    required this.wrong,
    required this.xpEarned,
    required this.durationSeconds,
    required this.levelName,
    required this.hardPhonemes,
  });
}
