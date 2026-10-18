/// The Number Learning grade for a child, from their profile's grade field
/// (UserProfile.grade → AppState.grade: 'grade3' / 'grade4', set at profile
/// creation). Profiles without a usable grade fall back to Grade 3, with
/// [defaulted] set so the UI can show a small note.
class LearnerGrade {
  final int grade;
  final bool defaulted;

  const LearnerGrade(this.grade, {this.defaulted = false});

  factory LearnerGrade.fromProfile(String profileGrade) {
    switch (profileGrade) {
      case 'grade3':
        return const LearnerGrade(3);
      case 'grade4':
        return const LearnerGrade(4);
      default:
        return const LearnerGrade(3, defaulted: true);
    }
  }
}
