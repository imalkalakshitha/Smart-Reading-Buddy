// Sinhala UI-chrome strings for EduPlay child-facing screens.
// Source: exact text supplied by the user in chat, transcribed once
// into a plain-text file and generated into this file by script —
// never hand-retyped into Dart source, to avoid transcription errors.
class EduPlaySiText {
  static String greeting(String name) => 'ආයුබෝවන්, $name!';
  static const String heroTitle = 'අලුත් දෙයක් ඉගෙන ගමු! 🌟';
  static const String heroSubtitle = 'පාඩමක් තෝරලා පටන් ගන්න!';
  static const String todaysPractice = 'අද පුහුණුව';
  static const String specialTask = 'ඔයාට විශේෂ වැඩක් තියෙනවා!';
  static const String yourLessons = 'ඔබේ පාඩම්';
  static const String start = 'පටන් ගන්න';
  static const String newBadge = 'අලුත්';
  static const String hint = 'ඉඟිය';
  static const String hintUsed = 'ඉඟිය දුන්නා';
  static const String clear = 'මකන්න';
  static const String submit = 'යවන්න';
  static const String tryAgain = 'ආයෙත් උත්සාහ කරන්න!';
  static const String greatJob = 'නියමයි! 🎉';
  static const String nextWord = '→ ඊළඟ වචනය';
  static const String next = '→ ඊළඟට';
  static const String backToJourney = '← ආපහු යන්න';
  static const String tapToHearWord = 'වචනය අහන්න 🔊 ඔබන්න!';
  static const String nowBuildWord = 'දැන් වචනය හදන්න!';
  static const String nowBuildSentence = 'දැන් වාක්‍යය හදන්න!';
  static const String chooseRightWord = 'හරි වචනය තෝරන්න!';
  static const String chooseMissingPart = 'නැති කොටස තෝරන්න!';
  static const String chooseRightAnswer = 'හරි උත්තරය තෝරන්න!';
  static const String dragLettersInstruction = 'හරි වචනය හදන්න අකුරු ඇදලා දාන්න!';
  static const String gradeWord = 'ශ්‍රේණිය';
  static const String levelBasic = 'මූලික';
  static const String levelAdvanced = 'දියුණු';
  static const String buildFoundation = 'පදනම හදාගන්න';
  static const String levelUpSkills = 'ඔයාගේ දැනුම වැඩි කරගන්න';
  static const String noTasksAvailable = 'තාම වැඩක් නෑ';
  static const String tapToHearSentence = 'වාක්‍යය අහන්න 🔊 ඔබන්න!';

  static String lessonN(int n) => 'පාඩම $n';
  static String nOf5Lessons(int n) => '$n / 5 පාඩම්';
  static String wordNOfTotal(int n, int total) => 'වචනය $n / $total';
  static String sentenceNOfTotal(int n, int total) => 'වාක්‍යය $n / $total';
  static String wordNCompleted(int n) => 'වචනය $n ඉවරයි!';
  static String sentenceNCompleted(int n) => 'වාක්‍යය $n ඉවරයි!';
  static String starsEarned(int n) => '⭐ තරු $nක් දිනුවා';
  static String nTasksAvailable(int n) => 'වැඩ $nක් තියෙනවා';

  static const Map<String, String> activityNames = {
    'letter_drag_drop': 'අකුරු ඇදගෙන යාම',
    'word_recognition': 'වචන හඳුනාගැනීම',
    'fill_blanks_word': 'හිස්තැන් පිරවීම',
    'sentence_drag_drop': 'වාක්‍ය ඇදගෙන යාම',
    'sentence_quiz': 'වාක්‍ය ප්‍රශ්නෝත්තර',
  };

  static const Map<String, String> activityDescriptions = {
    'letter_drag_drop': 'වචනයක් අහලා අකුරු වලින් හදන්න!',
    'word_recognition': 'හොඳින් අහලා හරි වචනය තෝරන්න.',
    'fill_blanks_word': 'නැති අකුර හෝ වචනය හොයන්න.',
    'sentence_drag_drop': 'වචන හරි පිළිවෙලට තියන්න.',
    'sentence_quiz': 'වාක්‍යයක් අහලා ප්‍රශ්නයට උත්තර දෙන්න.',
  };
}
