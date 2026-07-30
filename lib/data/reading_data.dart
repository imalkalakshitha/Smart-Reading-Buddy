import '../models/app_state.dart';

// ── English sentence banks ─────────────────────────────────────────────────────

const _grade3En1 = [
  "I eat rice.", "Kids sing songs.", "She reads books.",
  "He kicks ball.", "We love school.", "They play games.",
  "The sun shines.", "Birds fly high.", "Dogs bark loudly.",
  "I drink milk.", "She is drawing.", "He writes letters.",
  "We watch TV.", "The cat sleeps.", "Fish swim fast.",
];

const _grade3En2 = [
  "I go to school", "The dog runs fast", "She reads a book",
  "We play in garden", "Sun shines in sky", "He eats an apple",
  "Cat sleeps on bed", "Birds fly in sky", "She eats a mango",
  "I have a pencil", "They are good friends", "Boy runs very fast",
  "We drink clean water", "We eat tasty food.", "We read story books.",
];

const _grade4En1 = [
  "The cat sat on mat.", "She reads a small book.",
  "The frog jumps on log.", "I see a blue bird.",
  "We play in the garden.", "The boy plays with toy.",
  "The rat ran to hat.", "The cat sleeps on sofa.",
  "The bell rings in well.", "Mom cooks tasty rice today.",
  "I like fresh green apples.", "The ball is under table.",
  "Birds fly in the sky.", "Dad drives to the office.",
  "We wash our hands daily.",
];

const _grade4En2 = [
  "The rain falls on trees.", "I pack my school bag.",
  "The kite flies high in sky.", "The teacher talks loudly.",
  "The rat ran near old hat.", "The boy enjoys his new toy.",
  "She paints a beautiful picture.", "The sky is so clear today.",
  "The red apple is very sweet.", "The goat walks near wet boat.",
  "He reads an interesting storybook.", "The bell rings near deep well.",
  "The duck swims across small luck.", "She does her homework daily",
  "I read my book everyday",
];

// ── Sinhala sentence banks ─────────────────────────────────────────────────────

const _grade3Si1 = [
  "මම ගමට යමි", "අපි සෙල්ලම් කරමු", "කමලා පන්තියට ආවාය",
  "ගුරුතුමා කතාවක් කියවයි", "ඇය ගසක් සිටුවයි",
  "ඔහු පාඩම් කරයි", "අක්කා මිදුල අතුගායි",
  "අම්මා බත් උයයි", "විමල් මලක් කැඩුවේය",
  "මල්ලි ඈතට දුවයි", "නැන්දා රෙදි සෝදයි",
  "මාමා බසය පදවයි", "ඔවුහු ගෙදර ආවෝය",
  "ඔහු පොතක් කියවයි", "ඇය වල් පැළ ගලවයි",
];

const _grade3Si2 = [
  "අම්මා මට බත් කවයි", "තාත්තා ගෙදර වැඩ කරයි.",
  "සුදු පූසා කිරි බොයි.", "හිරු උදේට පායමින් එයි.",
  "වැස්ස වෙලාවට කුඩය ගනිමි.", "රෑට අහසේ තරු පායයි.",
  "මම තනියම වැඩ කරමි.", "කළු බල්ලා බුරමින් දුවයි.",
  "ගඟේ මාළුන් පීනමින් සිටියි", "මම පාසල් යන්න කැමතියි.",
  "අක්කා පොතක් කියවයි.", "මම රස කෙසෙල් කමි.",
  "අද උදේ කිරි බීවෙමි.", "අම්මා රසට කෑම උයයි.",
  "මල්ලි සෙල්ලම් බඩු ගනියි.",
];

const _grade4Si1 = [
  "අම්මා මට ලස්සන කතන්දර කියාදෙයි.",
  "මම පාසල් ගොස් හොඳින් ඉගෙනගනිමි.",
  "අපි පරිසරය පිරිසිදුව තබා ගත යුතුය.",
  "වත්තේ ලස්සන රතු පාට මල් පිපෙයි.",
  "ගුරුතුමිය අපට අලුත් පාඩම් කියාදෙයි.",
  "උදෑසන අවදි වී දෙමාපියන් වඳින්නෙමි.",
  "කුඩා ළමයි මිදුලේ සතුටින් සෙල්ලම්කරති.",
  "අහසේ වලාකුළු අතරින් හඳ පෙනෙයි.",
  "ගස උඩ සිටින කුරුල්ලා ගීත ගයයි.",
  "වැඩ අවසන් කර මම පොත් අසුරමි.",
  "කෑමට පෙර අත් සබන් දා සෝදන්න.",
  "නංගි පාට පැන්සල් වලින් ලස්සනට අඳියි.",
  "අපි හැමෝම එකට එකතු වී වැඩකරමු.",
  "පොත් කියවීමෙන් අපේ දැනුම වැඩි වෙයි.",
  "මම මගේ පාසල් නිල ඇඳුම අඳින්නෙමි.",
];

const _grade4Si2 = [
  "පිළිහුඩුවා උස අත්තක නැගී වටපිට බලමින් සිටියි",
  "අයියා බයිසිකල් තරගයෙන් දිනුවේය",
  "අපි ඉස්කෝලේ නිවාඩුවට ගමට ගියෙමු",
  "ඈත අහසේ ඉර පායාගෙන එයි",
  "යහළුවෝ පොහොය දිනයට පන්සල් යති",
  "සැඩ සුළඟට ගස් වේගයෙන් සෙලවෙයි",
  "අක්කගේ දුඹුරු පාට හැට්ටය ලස්සනයි",
  "සඳ අහසේ තරුත් එක්ක ලස්සනට සිනාසෙයි",
  "අම්මා මට සිනි මුරුක්කු ගෙනත් දුන්නාය",
  "සේපාලිකා මල් රෑට පිපී සුවඳ හමයි",
  "කුරුල්ලෝ රංචුවක් සර සර ගාමින් ඉගිලී ගියෝය",
  "තාත්තා මට දුන් ප්‍රහේලිකාව විසඳා අවසන් කලෙමි",
  "ගමේ වැවේ ඕලු, නෙළුම්, මානෙල් පිපී හිනැහෙයි",
  "පොත් කියවීමෙන් මිනිසා සම්පුර්ණ වෙයි",
  "වේගයෙන් එන මුහුදු රැල්ලක් ගලක හැපී විසිරී යයි",
];

// ── Public API ─────────────────────────────────────────────────────────────────

List<String> getReadingSentences(String grade, int level) {
  final si = AppState.language == 'sinhala';
  if (grade == 'grade3') {
    return level == 1
        ? List.unmodifiable(si ? _grade3Si1 : _grade3En1)
        : List.unmodifiable(si ? _grade3Si2 : _grade3En2);
  }
  return level == 1
      ? List.unmodifiable(si ? _grade4Si1 : _grade4En1)
      : List.unmodifiable(si ? _grade4Si2 : _grade4En2);
}

// ── Navigation arg classes ─────────────────────────────────────────────────────

class ReadingSessionArgs {
  final String grade;
  final int level;
  final String levelName;
  final List<String> sentences;

  const ReadingSessionArgs({
    required this.grade,
    required this.level,
    required this.levelName,
    required this.sentences,
  });
}

class SentenceResult {
  final String sentence;
  final int timeTakenMs;
  final bool wasFast;
  final int buddyPromptsCount;

  const SentenceResult({
    required this.sentence,
    required this.timeTakenMs,
    required this.wasFast,
    required this.buddyPromptsCount,
  });
}

class ReadingCompleteArgs {
  final List<SentenceResult> results;
  final String grade;
  final int level;
  final String levelName;
  final List<String> sentences;

  const ReadingCompleteArgs({
    required this.results,
    required this.grade,
    required this.level,
    required this.levelName,
    required this.sentences,
  });
}
