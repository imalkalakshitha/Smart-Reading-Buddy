import 'app_state.dart';

class AppText {
  static bool get _si => AppState.language == 'sinhala';

  // Navigation / common
  static String get start => _si ? 'පටන් ගනිමු' : 'Start';
  static String get next => _si ? 'ඊළඟ' : 'Next';
  static String get continueBtn => _si ? 'ඉදිරියට →' : 'Continue →';
  static String get tryAgain => _si ? 'නැවත උත්සාහ කරන්න' : 'Try Again';
  static String get home => _si ? 'මුල් පිටුව' : 'Home';
  static String get back => _si ? 'පිටුපසට' : 'Back';
  static String get cancel => _si ? 'අවලංගු කරන්න' : 'Cancel';
  static String get delete => _si ? 'මකන්න' : 'Delete';
  static String get confirm => _si ? 'තහවුරු කරන්න' : 'Confirm';
  static String get settings => _si ? 'සැකසුම්' : 'Settings';
  static String get comingSoon => _si ? 'ඉක්මනින් එන්නේ 🚧' : 'Coming Soon 🚧';
  static String get smartReadingBuddy => _si ? 'ස්මාර්ට් රීඩිං බඩී' : 'Smart Reading Buddy';
  static String get letsLearnTogether => _si ? 'එකතුව ඉගෙන ගමු! 🌟' : 'Let\'s Learn Together! 🌟';
  static String get version => 'Smart Reading Buddy v1.0';
  static String get learningIsFun => _si ? 'ඉගෙනීම විනෝදයි!' : 'Learning is fun!';

  // Language selection
  static String get chooseLanguage => _si ? 'භාෂාව තෝරන්න' : 'Choose Language';
  static String get chooseLanguageSubtitle => 'Choose your language / භාෂාව තෝරන්න';
  static String get sinhala => 'සිංහල';
  static String get sinhalaEnglish => 'Sinhala';
  static String get english => 'English';
  static String get englishSinhala => 'ඉංග්‍රීසි';

  // Profile select
  static String get whoIsLearning => _si ? 'අද ඉගෙන ගන්නේ කවුද?' : 'Who\'s learning today?';
  static String get addChild => _si ? 'ළමයෙකු එකතු කරන්න' : 'Add Child';
  static String get noProfilesYet => _si ? 'තවම පැතිකඩ නැත' : 'No profiles yet';
  static String get addChildToStart => _si ? 'ළමයෙකු එකතු කරන්න!' : 'Add a child to get started!';
  static String get parent => _si ? 'දෙමාපිය 👨‍👩‍👧' : 'Parent 👨‍👩‍👧';
  static String get deleteProfile => _si ? 'පැතිකඩ මකන්න' : 'Delete Profile';
  static String get deleteConfirm => _si ? 'මෙම පැතිකඩ මකන්නද?' : 'Delete this profile?';
  static String get profileDeleted => _si ? 'Profile එක මකා දැමිණ' : 'Profile deleted';
  static String deleteWarning(String name) =>
      _si ? 'ඔබට ${name}ගේ profile එක\nමකා දැමීමට අවශ්‍යද?' : 'Delete ${name}\'s profile?\nThis cannot be undone.';
  static String get deleteConfirmBtn => _si ? 'මකා දමන්න' : 'Delete';
  static String get cancelBtn => _si ? 'අවලංගු කරන්න' : 'Cancel';

  // Create profile
  static String get newProfile => _si ? 'නව පැතිකඩ' : 'New Profile';
  static String get createProfile => _si ? 'පැතිකඩ සාදන්න' : 'Create Profile';
  static String get yourName => _si ? 'ළමයාගේ නම' : 'Child\'s name';
  static String get yourNameHint => _si ? 'ළමයාගේ නම / Child\'s name' : 'Child\'s name / ළමයාගේ නම';
  static String get yourGrade => _si ? 'ශ්‍රේණිය' : 'Grade';
  static String get grade3 => _si ? 'ශ්‍රේණිය 3' : 'Grade 3';
  static String get grade4 => _si ? 'ශ්‍රේණිය 4' : 'Grade 4';
  static String get pickAvatar => _si ? 'චරිතය තෝරන්න' : 'Pick an avatar';
  static String get createPin => _si ? 'PIN අංකයක් සාදන්න' : 'Create a PIN';
  static String get confirmPin => _si ? 'PIN නැවත ඇතුළු කරන්න' : 'Confirm your PIN';
  static String get pinMismatch => _si ? 'PIN ගැලපෙන්නේ නැත!' : 'PINs don\'t match!';
  static String get fillAllFields => _si ? 'සියල්ල පුරවන්න' : 'Please fill all fields';

  // PIN screen
  static String get enterPin => _si ? 'ඔබේ PIN ඇතුළු කරන්න' : 'Enter your PIN';
  static String get wrongPin => _si ? 'වැරදි PIN! නැවත උත්සාහ කරන්න' : 'Wrong PIN! Try again';
  static String get hi => _si ? 'හෙලෝ' : 'Hi';

  // Home screen
  static String get buddyConnected => _si ? 'Buddy සම්බන්ධයි' : 'Buddy Connected';
  static String get buddyOffline => _si ? 'Buddy ඕෆ්ලයින්' : 'Buddy Offline';
  static String get dayStreak => _si ? 'දින නිරන්තරය! 🔥' : 'Day Streak! 🔥';
  static String get xpToNextLevel => _si ? 'ඊළඟ මට්ටමට XP' : 'XP to next level';
  static String get pronunciation => _si ? 'උච්චාරණය' : 'Pronunciation';
  static String get pronunciationDesc => _si ? 'වචන නිවැරදිව කියන්න!' : 'Say words correctly!';
  static String get wordBuilding => _si ? 'වචන ගොඩනැගීම' : 'Word Building';
  static String get wordBuildingDesc => _si ? 'වචන හදන්න!' : 'Spell and build words!';
  static String get reading => _si ? 'කියවීම' : 'Reading';
  static String get readingDesc => _si ? 'කාලය සමග කියවන්න!' : 'Read with the timer!';
  static String get writing => _si ? 'ලිවීම' : 'Writing';
  static String get writingDesc => _si ? 'අකුරු ලියන්න!' : 'Trace and write letters!';
  static String get speak => _si ? 'කතා කරන්න' : 'Speak';
  static String get words => _si ? 'වචන' : 'Words';
  static String get switchProfile => _si ? 'Profile මාරු කරන්න' : 'Switch Profile';
  static String get changeLanguage => _si ? 'භාෂාව මාරු කරන්න' : 'Change Language';
  static String get parentDashboard => _si ? 'දෙමාපිය Dashboard' : 'Parent Dashboard';
  static String get startActivity => _si ? 'පටන් →' : 'Start →';
  static String get connectBuddy => _si ? 'බඩී සම්බන්ධ කරන්න' : 'Connect Smart Buddy';

  // Grades
  static String gradeLabel(String grade) =>
      grade == 'grade3' ? grade3 : grade4;

  // Greeting
  static String hiName(String name) => '${hi}, $name! 👋';
}
