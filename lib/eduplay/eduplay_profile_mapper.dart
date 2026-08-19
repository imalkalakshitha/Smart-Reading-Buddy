import 'package:flutter/foundation.dart';

/// Maps LocalStorage/UserProfile's lowercase grade/language values
/// ('sinhala'/'english', 'grade3'/'grade4' — confirmed exact, no third
/// variant anywhere in the ~50 existing call sites, e.g.
/// create_profile_screen.dart's own toggle only ever sets 'grade3' or
/// 'grade4') to the Title Case values EduPlay's task JSON / rf_model.json
/// were trained on ('Sinhala'/'English', 'Grade 3'/'Grade 4').
class EduPlayProfileMapper {
  EduPlayProfileMapper._();

  /// Maps 'sinhala'/'english' to 'Sinhala'/'English'.
  static String mapLanguage(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'sinhala':
        return 'Sinhala';
      case 'english':
        return 'English';
      default:
        debugPrint('[EduPlay] mapLanguage: unrecognised value "$raw", falling back to English');
        return 'English';
    }
  }

  /// Maps 'grade3'/'grade4' to 'Grade 3'/'Grade 4'. Exact-match, not a
  /// substring/contains check — the confirmed value set is exactly these
  /// two strings, so exact match is more precise (e.g. would correctly
  /// reject a hypothetical 'grade34' typo that .contains('3') would not).
  static String mapGrade(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'grade3':
        return 'Grade 3';
      case 'grade4':
        return 'Grade 4';
      default:
        debugPrint('[EduPlay] mapGrade: unrecognised value "$raw", falling back to Grade 4');
        return 'Grade 4';
    }
  }
}
