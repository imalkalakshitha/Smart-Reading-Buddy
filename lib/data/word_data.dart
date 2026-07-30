import '../models/app_state.dart';

class WordItem {
  final String word;
  final String? pronunciationKey; // romanized filename key; null = use word
  final String emoji;
  final List<String> phonemes;
  final String vmgType;
  final String meaningEn;
  final String meaningSi;

  const WordItem({
    required this.word,
    this.pronunciationKey,
    required this.emoji,
    required this.phonemes,
    required this.vmgType,
    required this.meaningEn,
    required this.meaningSi,
  });

  String get meaning => AppState.language == 'sinhala' ? meaningSi : meaningEn;
  String get pKey => pronunciationKey ?? word;
}

// VMG types: mouth_open_wide, lips_together, teeth_close, lips_rounded,
//            tongue_teeth, tongue_back, tongue_up, teeth_lip, mouth_open

// ── ENGLISH WORDS ─────────────────────────────────────────────────────────────

const _grade3BasicEn = [
  WordItem(word: 'cat',    emoji: '🐱', phonemes: ['k','æ','t'],         vmgType: 'teeth_close',    meaningEn: 'A small pet animal',           meaningSi: 'බළලා'),
  WordItem(word: 'dog',    emoji: '🐶', phonemes: ['d','ɒ','g'],         vmgType: 'mouth_open',     meaningEn: 'A friendly pet animal',         meaningSi: 'බල්ලා'),
  WordItem(word: 'pig',    emoji: '🐷', phonemes: ['p','ɪ','g'],         vmgType: 'lips_together',  meaningEn: 'A farm animal that oinks',      meaningSi: 'ඌරා'),
  WordItem(word: 'sun',    emoji: '☀️', phonemes: ['s','ʌ','n'],         vmgType: 'teeth_close',    meaningEn: 'Shines brightly in the sky',    meaningSi: 'හිරු'),
  WordItem(word: 'pen',    emoji: '🖊️', phonemes: ['p','ɛ','n'],         vmgType: 'lips_together',  meaningEn: 'You write with it',             meaningSi: 'පෑන'),
  WordItem(word: 'fish',   emoji: '🐠', phonemes: ['f','ɪ','ʃ'],         vmgType: 'teeth_lip',      meaningEn: 'Lives in water and swims',      meaningSi: 'මාළුවා'),
  WordItem(word: 'jump',   emoji: '🏃', phonemes: ['dʒ','ʌ','m','p'],    vmgType: 'lips_together',  meaningEn: 'To leap up into the air',       meaningSi: 'පනිනවා'),
  WordItem(word: 'rock',   emoji: '🪨', phonemes: ['r','ɒ','k'],         vmgType: 'lips_rounded',   meaningEn: 'A hard piece of stone',         meaningSi: 'ගල'),
  WordItem(word: 'rain',   emoji: '🌧️', phonemes: ['r','eɪ','n'],        vmgType: 'lips_rounded',   meaningEn: 'Water that falls from clouds',  meaningSi: 'වැස්ස'),
  WordItem(word: 'ship',   emoji: '🚢', phonemes: ['ʃ','ɪ','p'],         vmgType: 'lips_rounded',   meaningEn: 'A big boat on the sea',         meaningSi: 'නෞකාව'),
  WordItem(word: 'eat',    emoji: '🍽️', phonemes: ['iː','t'],            vmgType: 'mouth_open',     meaningEn: 'To take food into your mouth',  meaningSi: 'කනවා'),
  WordItem(word: 'ice',    emoji: '🧊', phonemes: ['aɪ','s'],            vmgType: 'mouth_open_wide',meaningEn: 'Frozen water, very cold',       meaningSi: 'අයිස්'),
  WordItem(word: 'open',   emoji: '🚪', phonemes: ['əʊ','p','ə','n'],    vmgType: 'lips_rounded',   meaningEn: 'Not closed, free to enter',     meaningSi: 'විවෘතයි'),
  WordItem(word: 'tiger',  emoji: '🐯', phonemes: ['t','aɪ','g','ə'],    vmgType: 'tongue_up',      meaningEn: 'A wild striped cat animal',     meaningSi: 'කොටියා'),
  WordItem(word: 'pencil', emoji: '✏️', phonemes: ['p','ɛ','n','s','l'], vmgType: 'lips_together',  meaningEn: 'Used to draw and write',        meaningSi: 'පැන්සල'),
];

const _grade3AdvancedEn = [
  WordItem(word: 'bother',    emoji: '😤', phonemes: ['b','ɒ','ð','ə'],           vmgType: 'tongue_teeth', meaningEn: 'To trouble or disturb someone',        meaningSi: 'කරදර කරනවා'),
  WordItem(word: 'table',     emoji: '🪑', phonemes: ['t','eɪ','b','l'],          vmgType: 'tongue_up',    meaningEn: 'A flat surface on four legs',           meaningSi: 'මේසය'),
  WordItem(word: 'mother',    emoji: '👩', phonemes: ['m','ʌ','ð','ə'],           vmgType: 'tongue_teeth', meaningEn: 'Your female parent',                    meaningSi: 'අම්මා'),
  WordItem(word: 'river',     emoji: '🏞️', phonemes: ['r','ɪ','v','ə'],           vmgType: 'teeth_lip',    meaningEn: 'A long flow of water on land',          meaningSi: 'ගඟ'),
  WordItem(word: 'weather',   emoji: '⛅', phonemes: ['w','ɛ','ð','ə'],           vmgType: 'tongue_teeth', meaningEn: 'Sun, rain or wind outside',             meaningSi: 'කාලගුණය'),
  WordItem(word: 'paper',     emoji: '📄', phonemes: ['p','eɪ','p','ə'],          vmgType: 'lips_together',meaningEn: 'Thin flat sheets you write on',         meaningSi: 'කඩදාසිය'),
  WordItem(word: 'window',    emoji: '🪟', phonemes: ['w','ɪ','n','d','əʊ'],      vmgType: 'teeth_lip',    meaningEn: 'Glass in a wall to see outside',        meaningSi: 'ජනේලය'),
  WordItem(word: 'green',     emoji: '🌿', phonemes: ['g','r','iː','n'],          vmgType: 'tongue_back',  meaningEn: 'The colour of grass and leaves',        meaningSi: 'කොළ පාට'),
  WordItem(word: 'beach',     emoji: '🏖️', phonemes: ['b','iː','tʃ'],            vmgType: 'teeth_close',  meaningEn: 'Sandy area next to the sea',            meaningSi: 'වෙරළ'),
  WordItem(word: 'plant',     emoji: '🌱', phonemes: ['p','l','æ','n','t'],       vmgType: 'lips_together',meaningEn: 'A living thing that grows in soil',     meaningSi: 'පැළය'),
  WordItem(word: 'bread',     emoji: '🍞', phonemes: ['b','r','ɛ','d'],           vmgType: 'lips_together',meaningEn: 'Baked food made from flour',            meaningSi: 'පාන්'),
  WordItem(word: 'light',     emoji: '💡', phonemes: ['l','aɪ','t'],             vmgType: 'tongue_up',    meaningEn: 'Brightness that lets you see',          meaningSi: 'ආලෝකය'),
  WordItem(word: 'computer',  emoji: '💻', phonemes: ['k','ə','m','p','j','uː','t','ə'], vmgType: 'lips_rounded', meaningEn: 'Electronic device for work and games', meaningSi: 'පරිගණකය'),
  WordItem(word: 'sunshine',  emoji: '☀️', phonemes: ['s','ʌ','n','ʃ','aɪ','n'],  vmgType: 'teeth_close',  meaningEn: 'Warm bright light from the sun',        meaningSi: 'හිරු රශ්මිය'),
  WordItem(word: 'butterfly', emoji: '🦋', phonemes: ['b','ʌ','t','ə','f','l','aɪ'], vmgType: 'lips_together', meaningEn: 'A flying insect with colourful wings', meaningSi: 'සමනළයා'),
];

const _grade4Level1En = [
  WordItem(word: 'green',   emoji: '🌿', phonemes: ['g','r','iː','n'],        vmgType: 'tongue_back',  meaningEn: 'The colour of nature and plants',  meaningSi: 'කොළ පාට'),
  WordItem(word: 'apple',   emoji: '🍎', phonemes: ['æ','p','l'],             vmgType: 'mouth_open_wide',meaningEn: 'A round red or green fruit',      meaningSi: 'ඇපල'),
  WordItem(word: 'tasty',   emoji: '😋', phonemes: ['t','eɪ','s','t','i'],    vmgType: 'tongue_up',    meaningEn: 'Having a very good flavour',       meaningSi: 'රසවත්'),
  WordItem(word: 'daily',   emoji: '📅', phonemes: ['d','eɪ','l','i'],        vmgType: 'mouth_open',   meaningEn: 'Happening every single day',       meaningSi: 'දෛනිකව'),
  WordItem(word: 'rings',   emoji: '💍', phonemes: ['r','ɪ','ŋ','z'],         vmgType: 'lips_rounded', meaningEn: 'Circular bands worn on fingers',   meaningSi: 'මෝතිරම්'),
  WordItem(word: 'orange',  emoji: '🍊', phonemes: ['ɒ','r','ɪ','n','dʒ'],    vmgType: 'lips_rounded', meaningEn: 'A round juicy citrus fruit',       meaningSi: 'දොඩම'),
  WordItem(word: 'happy',   emoji: '😊', phonemes: ['h','æ','p','i'],         vmgType: 'mouth_open',   meaningEn: 'Feeling very good and glad',       meaningSi: 'සතුටු'),
  WordItem(word: 'chair',   emoji: '🪑', phonemes: ['tʃ','ɛː'],               vmgType: 'teeth_close',  meaningEn: 'A seat with a back to sit on',     meaningSi: 'පුටුව'),
  WordItem(word: 'pencil',  emoji: '✏️', phonemes: ['p','ɛ','n','s','l'],     vmgType: 'lips_together',meaningEn: 'A writing tool with a graphite tip', meaningSi: 'පැන්සල'),
  WordItem(word: 'water',   emoji: '💧', phonemes: ['w','ɔː','t','ə'],        vmgType: 'teeth_lip',    meaningEn: 'Clear liquid essential for life',  meaningSi: 'වතුර'),
  WordItem(word: 'animal',  emoji: '🐾', phonemes: ['æ','n','ɪ','m','l'],     vmgType: 'mouth_open_wide',meaningEn: 'Any living creature that moves',  meaningSi: 'සත්ත්වයෙකු'),
  WordItem(word: 'table',   emoji: '🪑', phonemes: ['t','eɪ','b','l'],        vmgType: 'tongue_up',    meaningEn: 'Flat surface for meals or work',   meaningSi: 'මේසය'),
  WordItem(word: 'kite',    emoji: '🪁', phonemes: ['k','aɪ','t'],            vmgType: 'tongue_back',  meaningEn: 'A toy that flies in the wind',     meaningSi: 'ගාලිය'),
  WordItem(word: 'story',   emoji: '📖', phonemes: ['s','t','ɔː','r','i'],    vmgType: 'teeth_close',  meaningEn: 'A tale told with words',           meaningSi: 'කතාව'),
  WordItem(word: 'large',   emoji: '🔲', phonemes: ['l','ɑː','dʒ'],           vmgType: 'tongue_back',  meaningEn: 'Very big in size',                 meaningSi: 'විශාල'),
];

const _grade4Level2En = [
  WordItem(word: 'morning',   emoji: '🌅', phonemes: ['m','ɔː','n','ɪ','ŋ'],          vmgType: 'lips_together', meaningEn: 'The early part of the day',              meaningSi: 'උදෑසන'),
  WordItem(word: 'teacher',   emoji: '👩‍🏫',phonemes: ['t','iː','tʃ','ə'],             vmgType: 'tongue_up',    meaningEn: 'A person who helps you learn',           meaningSi: 'ගුරුවරිය'),
  WordItem(word: 'beautiful', emoji: '🌸', phonemes: ['b','j','uː','t','ɪ','f','l'],  vmgType: 'lips_together', meaningEn: 'Very pretty and pleasing to see',        meaningSi: 'ලස්සනා'),
  WordItem(word: 'bright',    emoji: '✨', phonemes: ['b','r','aɪ','t'],              vmgType: 'lips_together', meaningEn: 'Giving out a lot of light',              meaningSi: 'දීප්තිමත්'),
  WordItem(word: 'everyday',  emoji: '📆', phonemes: ['ɛ','v','r','i','d','eɪ'],      vmgType: 'mouth_open',   meaningEn: 'Happening each and every day',           meaningSi: 'සෑම දිනකම'),
  WordItem(word: 'picture',   emoji: '🖼️', phonemes: ['p','ɪ','k','tʃ','ə'],          vmgType: 'lips_together', meaningEn: 'A drawing or photograph',               meaningSi: 'පින්තූරය'),
  WordItem(word: 'homework',  emoji: '📝', phonemes: ['h','əʊ','m','w','ɜː','k'],     vmgType: 'mouth_open',   meaningEn: 'School work done at home',               meaningSi: 'ගෙදර වැඩ'),
  WordItem(word: 'classroom', emoji: '🏫', phonemes: ['k','l','ɑː','s','r','uː','m'], vmgType: 'lips_rounded', meaningEn: 'A room where students learn',            meaningSi: 'පංති කාමරය'),
  WordItem(word: 'evening',   emoji: '🌆', phonemes: ['iː','v','n','ɪ','ŋ'],          vmgType: 'mouth_open',   meaningEn: 'The end part of the day',               meaningSi: 'සවස'),
  WordItem(word: 'market',    emoji: '🛒', phonemes: ['m','ɑː','k','ɪ','t'],          vmgType: 'lips_together', meaningEn: 'A place things are bought and sold',    meaningSi: 'වෙළෙඳ පළ'),
  WordItem(word: 'rainbow',   emoji: '🌈', phonemes: ['r','eɪ','n','b','əʊ'],         vmgType: 'lips_rounded', meaningEn: 'Arc of seven colours after rain',        meaningSi: 'දේදුන්න'),
  WordItem(word: 'village',   emoji: '🏘️', phonemes: ['v','ɪ','l','ɪ','dʒ'],          vmgType: 'teeth_lip',    meaningEn: 'A small community in countryside',      meaningSi: 'ගම්මානය'),
  WordItem(word: 'student',   emoji: '🧑‍🎓',phonemes: ['s','t','j','uː','d','n','t'],  vmgType: 'teeth_close',  meaningEn: 'A person who studies at school',         meaningSi: 'ශිෂ්‍යයා'),
  WordItem(word: 'horse',     emoji: '🐴', phonemes: ['h','ɔː','s'],                  vmgType: 'mouth_open',   meaningEn: 'A large animal people ride',             meaningSi: 'අශ්වයා'),
  WordItem(word: 'healthy',   emoji: '💪', phonemes: ['h','ɛ','l','θ','i'],           vmgType: 'tongue_teeth', meaningEn: 'Being well and free from illness',       meaningSi: 'සෞඛ්‍ය සම්පන්න'),
];

// ── SINHALA WORDS ─────────────────────────────────────────────────────────────
// Phonemes use simplified romanized Sinhala syllables to guide pronunciation.

const _grade3BasicSi = [
  WordItem(word: 'ඇස',      pronunciationKey: 'asa',       emoji: '👁️',  phonemes: ['æ','sə'],               vmgType: 'mouth_open_wide',meaningEn: 'Eye — used for seeing',          meaningSi: 'දැකීමට යොදා ගන්නා ඉන්ද්‍රිය'),
  WordItem(word: 'එක',      pronunciationKey: 'eka',       emoji: '1️⃣',  phonemes: ['e','kə'],               vmgType: 'mouth_open',     meaningEn: 'One — the number 1',             meaningSi: 'ඒකය'),
  WordItem(word: 'ගම',      pronunciationKey: 'gama',      emoji: '🏘️',  phonemes: ['gə','mə'],              vmgType: 'tongue_back',    meaningEn: 'Village — where people live',    meaningSi: 'ජනයා ජීවත් වෙන ස්ථානය'),
  WordItem(word: 'උර',      pronunciationKey: 'ura',       emoji: '🫀',  phonemes: ['u','rə'],               vmgType: 'lips_rounded',   meaningEn: 'Chest — front of the body',      meaningSi: 'ශරීරයේ ඉදිරිකොටස'),
  WordItem(word: 'ඔය',      pronunciationKey: 'oya',       emoji: '💧',  phonemes: ['o','jə'],               vmgType: 'lips_rounded',   meaningEn: 'Stream — a small flow of water', meaningSi: 'කුඩා ජලාශය'),
  WordItem(word: 'කෙසෙල්',  pronunciationKey: 'kesel',     emoji: '🍌',  phonemes: ['ke','sel'],             vmgType: 'tongue_back',    meaningEn: 'Banana — a yellow fruit',        meaningSi: 'කහ රසවත් ගෙඩියක්'),
  WordItem(word: 'ගැහැනිය', pronunciationKey: 'gehaniya',  emoji: '👩',  phonemes: ['gæ','hæ','ni','jə'],   vmgType: 'tongue_back',    meaningEn: 'Woman — adult female person',    meaningSi: 'වැඩිහිටි ගැහැනු පුද්ගලයා'),
  WordItem(word: 'නියර',    pronunciationKey: 'niyara',    emoji: '🌾',  phonemes: ['ni','jə','rə'],         vmgType: 'tongue_up',      meaningEn: 'Ridge between paddy fields',     meaningSi: 'වී කුඹුරු අතර ඉංගිය'),
  WordItem(word: 'තාරාවා',  pronunciationKey: 'thaaraawa', emoji: '🦆',  phonemes: ['tɑː','rɑː','wɑː'],     vmgType: 'tongue_up',      meaningEn: 'Duck — a water bird',            meaningSi: 'ජලයේ ජීවත් කුරුල්ලෙකු'),
  WordItem(word: 'චීනය',    pronunciationKey: 'cheenaya',  emoji: '🇨🇳',  phonemes: ['tʃiː','nə','jə'],      vmgType: 'teeth_lip',      meaningEn: 'China — a country in Asia',      meaningSi: 'ආසියාවේ රටක්'),
  WordItem(word: 'බැගය',    pronunciationKey: 'baegaya',   emoji: '👜',  phonemes: ['bæ','gə','jə'],         vmgType: 'lips_together',  meaningEn: 'Bag — used to carry things',     meaningSi: 'දේ රැගෙන යෑමට'),
  WordItem(word: 'තීන්ත',   pronunciationKey: 'theentha',  emoji: '🖌️',  phonemes: ['tiːn','tə'],            vmgType: 'tongue_up',      meaningEn: 'Ink or paint for writing',       meaningSi: 'ලිවීමට හෝ ඇඳීමට'),
  WordItem(word: 'පූජාව',   pronunciationKey: 'poojaawa',  emoji: '🪷',  phonemes: ['puː','dʒɑː','wə'],     vmgType: 'lips_rounded',   meaningEn: 'Religious offering or worship',  meaningSi: 'දෙවියන්ට ඉදිරිපත් කිරීම'),
  WordItem(word: 'මුහුද',   pronunciationKey: 'muhuda',    emoji: '🌊',  phonemes: ['mu','hu','də'],         vmgType: 'lips_together',  meaningEn: 'Sea — vast body of saltwater',   meaningSi: 'ලවණ ජලය ඇති ස්ථානය'),
  WordItem(word: 'වේවැල',   pronunciationKey: 'wewela',    emoji: '🎋',  phonemes: ['weː','wæ','lə'],        vmgType: 'teeth_lip',      meaningEn: 'Cane or rattan plant',           meaningSi: 'ලී වැලක් ජාතියකි'),
];
const _grade3AdvancedSi = [
  WordItem(word: 'අත්සන',    pronunciationKey: 'athsana',        emoji: '✍️',  phonemes: ['at','sə','nə'],          vmgType: 'mouth_open_wide',meaningEn: 'Signature — personal sign',          meaningSi: 'ඔබේ පෞද්ගලික ලකුණ'),
  WordItem(word: 'කැමැත්ත',  pronunciationKey: 'kemaththa',      emoji: '💪',  phonemes: ['kæ','mæt','tə'],         vmgType: 'tongue_back',    meaningEn: 'Willingness — desire to do',         meaningSi: 'කිරීමට ඇති ආශාව'),
  WordItem(word: 'සිංහයා',   pronunciationKey: 'sinhaya',        emoji: '🦁',  phonemes: ['siŋ','hə','jɑː'],        vmgType: 'teeth_close',    meaningEn: 'Lion — the king of animals',         meaningSi: 'සතුන්ගේ රජ'),
  WordItem(word: 'ගුරුතුමා',  pronunciationKey: 'guruthuma',      emoji: '👨‍🏫',phonemes: ['gu','ru','tu','mɑː'],     vmgType: 'tongue_back',    meaningEn: 'Respected male teacher',             meaningSi: 'ගෞරවනීය ගුරුවරයා'),
  WordItem(word: 'තොවිලය',   pronunciationKey: 'thowilaya',      emoji: '🥁',  phonemes: ['to','wi','lə','jə'],     vmgType: 'tongue_up',      meaningEn: 'Traditional Sri Lankan ritual',      meaningSi: 'සාම්ප්‍රදායික ශ්‍රී ලාංකික චාරිත්‍රය'),
  WordItem(word: 'සීගිරිය',  pronunciationKey: 'sigiriya',       emoji: '🏔️',  phonemes: ['siː','gi','ri','jə'],    vmgType: 'teeth_close',    meaningEn: 'Sigiriya — ancient rock fortress',   meaningSi: 'ශ්‍රී ලංකා ඓතිහාසික කඳු'),
  WordItem(word: 'වරලස',     pronunciationKey: 'waralasa',       emoji: '💇',  phonemes: ['wə','rə','lə','sə'],     vmgType: 'teeth_lip',      meaningEn: 'Hair — strands on the head',         meaningSi: 'හිසේ කෙස් කළඹ'),
  WordItem(word: 'ඊතලය',    pronunciationKey: 'eethalaya',      emoji: '🏹',  phonemes: ['iː','tə','lə','jə'],     vmgType: 'mouth_open',     meaningEn: 'Arrow — pointed weapon',             meaningSi: 'ඊ දඬු ආයුධය'),
  WordItem(word: 'උදැල්ල',   pronunciationKey: 'udalla',         emoji: '⛏️',  phonemes: ['u','dæl','lə'],          vmgType: 'lips_rounded',   meaningEn: 'Hoe — a digging tool',               meaningSi: 'කැණීමට යොදන මෙවලම'),
  WordItem(word: 'කිරිබත්',  pronunciationKey: 'kiribath',       emoji: '🍚',  phonemes: ['ki','ri','bat'],         vmgType: 'tongue_back',    meaningEn: 'Milk rice — a Sri Lankan dish',      meaningSi: 'කිරි සහල් කෑම'),
  WordItem(word: 'විචාරය',   pronunciationKey: 'wichaaraya',     emoji: '🤔',  phonemes: ['wi','tʃɑː','rə','jə'],  vmgType: 'teeth_lip',      meaningEn: 'Inquiry or examination',             meaningSi: 'විමසීම හෝ පරීක්ෂාව'),
  WordItem(word: 'රූපකය',   pronunciationKey: 'rupakaya',       emoji: '🎭',  phonemes: ['ruː','pə','kə','jə'],   vmgType: 'lips_rounded',   meaningEn: 'A symbol or metaphor',               meaningSi: 'සංකේත රූපය'),
  WordItem(word: 'ජනතාව',   pronunciationKey: 'janathaawa',     emoji: '👥',  phonemes: ['dʒə','nə','tɑː','wə'],  vmgType: 'mouth_open',     meaningEn: 'People — a group of persons',        meaningSi: 'ජනසමූහය'),
  WordItem(word: 'පොහොසත්', pronunciationKey: 'pohosath',       emoji: '💰',  phonemes: ['po','ho','sat'],         vmgType: 'lips_rounded',   meaningEn: 'Rich or wealthy person',             meaningSi: 'ධනවත් කෙනෙකු'),
  WordItem(word: 'ගායනය',   pronunciationKey: 'gaayanaya',      emoji: '🎤',  phonemes: ['gɑː','jə','nə','jə'],   vmgType: 'tongue_back',    meaningEn: 'Singing or musical performance',     meaningSi: 'සංගීත ගායනා'),
];


const _grade4Level2Si = [
  WordItem(word: 'සම්පූර්ණ',     pronunciationKey: 'sampoorna',        emoji: '✅', phonemes: ['sam','puːr','ɳə'],              vmgType: 'teeth_close',    meaningEn: 'Complete or fully finished',        meaningSi: 'සම්පූර්ණ'),
  WordItem(word: 'පිළිහුඩුවා',    pronunciationKey: 'pilihuduwa',       emoji: '🐿️', phonemes: ['pi','ɭi','hu','ɖu','wɑː'],     vmgType: 'lips_rounded',   meaningEn: 'Squirrel — a small furry animal',   meaningSi: 'ගස්වල ජීවත් සත්ත්ව'),
  WordItem(word: 'සංවාදය',        pronunciationKey: 'sanwaadaya',       emoji: '💬', phonemes: ['saŋ','wɑː','də','jə'],          vmgType: 'teeth_close',    meaningEn: 'A conversation or discussion',      meaningSi: 'සංවාද'),
  WordItem(word: 'අවබෝධය',       pronunciationKey: 'awabodhaya',       emoji: '💡', phonemes: ['ə','wə','boː','ðə','jə'],       vmgType: 'tongue_teeth',   meaningEn: 'Understanding or comprehension',    meaningSi: 'දෙය තේරුම් ගැනීම'),
  WordItem(word: 'සංකල්ප',        pronunciationKey: 'sankalpa',         emoji: '🧠', phonemes: ['saŋ','kəl','pə'],               vmgType: 'teeth_close',    meaningEn: 'Concepts or ideas',                 meaningSi: 'අදහස් සහ සංකල්ප'),
  WordItem(word: 'නිර්මාණශීලී',  pronunciationKey: 'nirmaanasheelee',  emoji: '🎨', phonemes: ['nir','mɑː','ɳə','ʃiː','liː'], vmgType: 'tongue_up',      meaningEn: 'Creative or inventive',             meaningSi: 'නිර්මාණශීලී බව'),
  WordItem(word: 'සෞඛ්‍යය',       pronunciationKey: 'saukhya',          emoji: '💊', phonemes: ['so','kʰjə'],                    vmgType: 'lips_rounded',   meaningEn: 'Health or good physical condition', meaningSi: 'සෞඛ්‍ය'),
  WordItem(word: 'සංවිධානය',      pronunciationKey: 'sanvidhaanaya',    emoji: '📋', phonemes: ['saŋ','wi','ðɑː','nə','jə'],    vmgType: 'teeth_close',    meaningEn: 'Organization or arrangement',       meaningSi: 'සංවිධානය'),
  WordItem(word: 'ගෞරවය',        pronunciationKey: 'gaurawaya',        emoji: '🙏', phonemes: ['go','rə','wə','jə'],            vmgType: 'mouth_open',     meaningEn: 'Respect — honour for others',       meaningSi: 'අනුන්ට ගරු කිරීම'),
  WordItem(word: 'විස්තරය',       pronunciationKey: 'wistharaya',       emoji: '📝', phonemes: ['wis','tə','rə','jə'],           vmgType: 'teeth_lip',      meaningEn: 'Details or description',            meaningSi: 'විස්තර'),
  WordItem(word: 'නිගමනය',        pronunciationKey: 'nigamanaya',       emoji: '🏁', phonemes: ['ni','gə','mə','nə','jə'],       vmgType: 'tongue_up',      meaningEn: 'Conclusion or final result',        meaningSi: 'නිගමන'),
  WordItem(word: 'ආරක්ෂාව',      pronunciationKey: 'aarakshaawa',      emoji: '🛡️', phonemes: ['ɑː','rək','ʃɑː','wə'],         vmgType: 'mouth_open_wide',meaningEn: 'Safety or protection',              meaningSi: 'ආරක්ෂාව'),
  WordItem(word: 'ප්‍රයත්නය',     pronunciationKey: 'prayathnaya',      emoji: '💪', phonemes: ['prə','jat','nə','jə'],          vmgType: 'lips_together',  meaningEn: 'Effort or hard work',               meaningSi: 'ප්‍රයත්නය'),
  WordItem(word: 'අවධානය',       pronunciationKey: 'awadhaanaya',      emoji: '👁️', phonemes: ['ə','wə','ðɑː','nə','jə'],       vmgType: 'mouth_open',     meaningEn: 'Attention or focus',                meaningSi: 'අවධානය'),
  WordItem(word: 'ප්‍රායෝගික',    pronunciationKey: 'praayoogika',      emoji: '🔧', phonemes: ['prɑː','joː','gi','kə'],         vmgType: 'lips_together',  meaningEn: 'Practical or hands-on',             meaningSi: 'ප්‍රායෝගික'),
];

// ── Public API ─────────────────────────────────────────────────────────────────

class WordData {
  static List<WordItem> forLevel(String grade, String levelKey) {
    final isSinhala = AppState.language == 'sinhala';
    if (grade == 'grade3') {
      if (levelKey == 'basic') {
        return List.from(isSinhala ? _grade3BasicSi : _grade3BasicEn);
      }
      return List.from(isSinhala ? _grade3AdvancedSi : _grade3AdvancedEn);
    } else {
      if (!isSinhala && levelKey == 'level1') {
        return List.from(_grade4Level1En);
      }
      return List.from(isSinhala ? _grade4Level2Si : _grade4Level2En);
    }
  }

  static List<Map<String, dynamic>> levels(String grade) {
    if (grade == 'grade3') {
      return [
        {'key': 'basic',    'labelEn': 'Basic Words',    'labelSi': 'මූලික වචන',  'stars': 1, 'emoji': '⭐'},
        {'key': 'advanced', 'labelEn': 'Advanced Words', 'labelSi': 'උසස් වචන',  'stars': 2, 'emoji': '⭐⭐'},
      ];
    } else {
      if (AppState.language == 'sinhala') {
        return [
          {'key': 'level2', 'labelEn': 'Level 2', 'labelSi': 'මට්ටම 2', 'stars': 4, 'emoji': '🏆'},
        ];
      }
      return [
        {'key': 'level1', 'labelEn': 'Level 1', 'labelSi': 'මට්ටම 1', 'stars': 3, 'emoji': '⭐⭐⭐'},
        {'key': 'level2', 'labelEn': 'Level 2', 'labelSi': 'මට්ටම 2', 'stars': 4, 'emoji': '🏆'},
      ];
    }
  }

  static String levelLabel(Map<String, dynamic> level) =>
      AppState.language == 'sinhala' ? level['labelSi'] as String : level['labelEn'] as String;
}
