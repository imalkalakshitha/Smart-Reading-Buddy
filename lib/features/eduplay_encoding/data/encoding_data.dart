// All word, sentence, and emoji data for the encoding (word/sentence building) module.

const Map<String, List<String>> wordData = {
  'en_grade3_basic': [
    'Cat', 'Dog', 'Pig', 'Sun', 'Pen',
    'Fish', 'Jump', 'Rock', 'Rain', 'Ship',
  ],
  'en_grade3_advanced': [
    'Table', 'Mother', 'River', 'Weather',
    'Paper', 'Window', 'Green', 'Beach', 'Plant', 'Bread',
  ],
  'en_grade4_level1': [
    'Apple', 'Happy', 'Chair', 'Pencil',
    'Water', 'Animal', 'Table', 'Kite', 'Story', 'Large',
  ],
  'en_grade4_level2': [
    'Morning', 'Teacher', 'Beautiful',
    'Picture', 'Homework', 'Classroom', 'Rainbow', 'Village',
    'Student', 'Healthy',
  ],
  'si_grade3_basic': [
    'ගම', 'එක', 'ඇය', 'උර', 'ඔය',
    'කෙසෙල්', 'නියර', 'මුහුද', 'තීන්ත', 'වේවැල',
  ],
  'si_grade3_advanced': [
    'අත්සන', 'කැමැත්ත', 'සිංහයා',
    'ගුරුතුමා', 'කොච්චිය', 'සීගිරිය', 'කිරිබත්',
    'පොහොසත්', 'ගායනය', 'අන්නාසි',
  ],
  'si_grade4_level1': [
    'ගණිතය', 'කුරුල්ලා', 'වලාකුළ',
    'සටහන්', 'ලස්සන', 'පැන්සල්', 'කුසලතා',
    'කියවීම', 'පන්සල්', 'අන්නාසි',
  ],
  'si_grade4_level2': [
    'සම්පූර්ණ', 'සංවාදය', 'අවබෝධය',
    'සංකල්ප', 'සෞඛ්‍යය', 'සංවිධානය', 'විස්තරය',
    'නිගමනය', 'ආරක්ෂාව', 'අවධානය',
  ],
};

const Map<String, List<String>> sentenceData = {
  'en_grade3_level1': [
    'I eat rice',
    'Kids sing songs',
    'She reads books',
    'He kicks ball',
    'We love school',
    'Birds fly high',
    'Dogs bark loudly',
    'I drink milk',
    'The cat sleeps',
    'Fish swim fast',
  ],
  'en_grade3_level2': [
    'The dog runs fast',
    'She reads a book',
    'Sun shines in sky',
    'He eats an apple',
    'Cat sleeps on bed',
    'Birds fly in sky',
    'I have a pencil',
    'Boy runs very fast',
    'We drink clean water',
    'We read story books',
  ],
  'en_grade4_level1': [
    'The cat sat on mat',
    'She reads a small book',
    'I see a blue bird',
    'We play in the garden',
    'Mom cooks tasty rice today',
    'I like fresh green apples',
    'Birds fly in the sky',
    'Dad drives to the office',
    'We wash our hands daily',
    'The ball is under table',
  ],
  'en_grade4_level2': [
    'The rain falls on trees',
    'I pack my school bag',
    'The kite flies high in sky',
    'She paints a beautiful picture',
    'The sky is so clear today',
    'The red apple is very sweet',
    'He reads an interesting storybook',
    'She does her homework daily',
    'I read my book everyday',
    'The teacher talks to students',
  ],
  'si_grade3_level1': [
    'මම ගමට යමි',
    'අපි සෙල්ලම් කරමු',
    'ඔහු පාඩම් කරයි',
    'අම්මා බත් උයයි',
    'මල්ලි ඈතට දුවයි',
    'ඔහු පොතක් කියවයි',
  ],
  'si_grade3_level2': [
    'අම්මා මට බත් කවයි',
    'සුදු පූසා කිරි බොයි',
    'හිරු උදේට පායමින් එයි',
    'රෑට අහසේ තරු පායයි',
    'අක්කා පොතක් කියවයි',
    'මල්ලි සෙල්ලම් බඩු ගනියි',
  ],
  'si_grade4_level1': [
    'අම්මා මට කතන්දර කියාදෙයි',
    'මම පාසල් ගොස් ඉගෙනගනිමි',
    'වත්තේ ලස්සන මල් පිපෙයි',
    'ගස උඩ කුරුල්ලා ගීත ගයයි',
    'නංගි පැන්සල් වලින් අඳියි',
  ],
  'si_grade4_level2': [
    'අයියා බයිසිකල් තරගයෙන් දිනුවේය',
    'අපි ඉස්කෝලේ නිවාඩුවට ගමට ගියෙමු',
    'සැඩ සුළඟට ගස් සෙලවෙයි',
    'කුරුල්ලෝ රංචුවක් ඉගිලී ගියෝය',
    'පොත් කියවීමෙන් දැනුම වැඩි වෙයි',
  ],
};

const Map<String, String> wordEmoji = {
  'Cat': '🐱', 'Dog': '🐶', 'Pig': '🐷', 'Sun': '☀️', 'Pen': '✏️',
  'Fish': '🐟', 'Jump': '🦘', 'Rock': '🪨', 'Rain': '🌧️', 'Ship': '🚢',
  'Table': '🪑', 'Mother': '👩', 'River': '🌊', 'Weather': '🌤️',
  'Paper': '📄', 'Window': '🪟', 'Green': '🌿', 'Beach': '🏖️',
  'Plant': '🌱', 'Bread': '🍞', 'Apple': '🍎', 'Happy': '😊',
  'Chair': '🪑', 'Pencil': '✏️', 'Water': '💧', 'Animal': '🦁',
  'Kite': '🪁', 'Story': '📖', 'Morning': '🌅', 'Teacher': '👩‍🏫',
  'Beautiful': '🌸', 'Picture': '🖼️', 'Homework': '📝',
  'Classroom': '🏫', 'Rainbow': '🌈', 'Village': '🏘️',
  'Student': '👦', 'Healthy': '💪', 'Large': '📏',
};

const Map<String, String> _siWordEmoji = {
  'ගම': '🏘️', 'එක': '1️⃣', 'ඇය': '👩', 'උර': '💪', 'ඔය': '🌊',
  'කෙසෙල්': '🍌', 'නියර': '🌾', 'මුහුද': '🌊', 'තීන්ත': '🎨',
  'වේවැල': '🌿', 'අත්සන': '✍️', 'කැමැත්ත': '❤️', 'සිංහයා': '🦁',
  'ගුරුතුමා': '👩‍🏫', 'කොච්චිය': '🚂', 'සීගිරිය': '🗻', 'කිරිබත්': '🍚',
  'පොහොසත්': '💎', 'ගායනය': '🎵', 'අන්නාසි': '🍍', 'ගණිතය': '🔢',
  'කුරුල්ලා': '🐦', 'වලාකුළ': '☁️', 'සටහන්': '📝', 'ලස්සන': '🌸',
  'පැන්සල්': '✏️', 'කුසලතා': '⭐', 'කියවීම': '📖', 'පන්සල්': '🛕',
  'සම්පූර්ණ': '✅', 'සංවාදය': '💬', 'අවබෝධය': '💡', 'සංකල්ප': '🧠',
  'සෞඛ්‍යය': '❤️', 'සංවිධානය': '📋', 'විස්තරය': '📄', 'නිගමනය': '🏁',
  'ආරක්ෂාව': '🛡️', 'අවධානය': '👁️',
};

/// Returns the best emoji for a word (English or Sinhala).
String wordEmojiFor(String word) =>
    wordEmoji[word] ?? _siWordEmoji[word] ?? '📝';

// ── EncodingArgs ──────────────────────────────────────────────────────────────

class EncodingArgs {
  final String language; // 'en' or 'si'
  final int grade;       // 3 or 4
  final int level;       // 1 or 2
  final int profileId;

  const EncodingArgs({
    required this.language,
    required this.grade,
    required this.level,
    required this.profileId,
  });

  bool get isSinhala => language == 'si';

  String get wordKey {
    if (language == 'en') {
      if (grade == 3) return level == 1 ? 'en_grade3_basic' : 'en_grade3_advanced';
      return level == 1 ? 'en_grade4_level1' : 'en_grade4_level2';
    }
    if (grade == 3) return level == 1 ? 'si_grade3_basic' : 'si_grade3_advanced';
    return level == 1 ? 'si_grade4_level1' : 'si_grade4_level2';
  }

  String get sentenceKey => '${language}_grade${grade}_level$level';
}

// ── Letter / syllable splitting ───────────────────────────────────────────────

/// Splits a word into display units.
/// English → uppercase individual letters.
/// Sinhala → syllable clusters (consonant + its vowel signs).
List<String> splitToLetters(String word, bool isSinhala) {
  if (!isSinhala) return word.toUpperCase().split('');

  final result = <String>[];
  final runes = word.runes.toList();
  var i = 0;
  while (i < runes.length) {
    var syllable = String.fromCharCode(runes[i]);
    i++;
    while (i < runes.length) {
      final cp = runes[i];
      // Absorb vowel signs (U+0DCF–U+0DDF), AL-lakuna (U+0DCA), ZWJ (U+200D)
      if ((cp >= 0x0DCF && cp <= 0x0DDF) || cp == 0x0DCA || cp == 0x200D) {
        syllable += String.fromCharCode(cp);
        i++;
        // After ZWJ, also consume the next consonant
        if (cp == 0x200D && i < runes.length) {
          syllable += String.fromCharCode(runes[i]);
          i++;
        }
      } else {
        break;
      }
    }
    result.add(syllable);
  }
  return result;
}

// ── Decoy generation ──────────────────────────────────────────────────────────

const _enPool = [
  'A','B','C','D','E','F','G','H','I','J','K','L','M',
  'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
];
const _siPool = [
  'ක','ග','ච','ජ','ට','ඩ','ත','ද','න','ප','බ','ම',
  'ය','ර','ල','ව','ස','හ','ළ','ෆ',
];

/// Returns [count] decoy letters/syllables not present in [letters].
List<String> generateDecoys(
    List<String> letters, bool isSinhala, {int count = 3}) {
  final used = letters.toSet();
  final pool = (isSinhala ? _siPool : _enPool)
      .where((l) => !used.contains(l))
      .toList()
    ..shuffle();
  return pool.take(count).toList();
}
