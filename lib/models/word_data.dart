import 'app_state.dart';

class WordData {
  static List<String> get words {
    if (AppState.language == 'sinhala' && AppState.grade == 'grade3') {
      return ['අම්මා', 'තාත්තා', 'පොත', 'ගෙදර', 'වතුර', 'බල්ලා'];
    } else if (AppState.language == 'sinhala' && AppState.grade == 'grade4') {
      return ['යනවා', 'රතු', 'පාසල', 'කියවනවා', 'ලියනවා', 'සතුටු'];
    } else if (AppState.language == 'english' && AppState.grade == 'grade3') {
      return ['cat', 'dog', 'run', 'jump', 'ball', 'play'];
    } else {
      return ['frog', 'clap', 'step', 'this', 'that', 'from'];
    }
  }
}
