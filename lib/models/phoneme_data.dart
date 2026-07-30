/// Parent-friendly display names for phoneme codes used in the word packs.
///
/// The app stores phonemes as simple ASCII strings (e.g. "sh", "th", "ae").
/// This map converts them to labels parents can read in the PEPA dashboard.
class PhonemeData {
  PhonemeData._();

  static const Map<String, String> _names = {
    // ── Single consonants ──────────────────────────────────────────────────
    'b': 'B sound',  'c': 'C sound',  'd': 'D sound',  'f': 'F sound',
    'g': 'G sound',  'h': 'H sound',  'j': 'J sound',  'k': 'K sound',
    'l': 'L sound',  'm': 'M sound',  'n': 'N sound',  'p': 'P sound',
    'q': 'Q sound',  'r': 'R sound',  's': 'S sound',  't': 'T sound',
    'v': 'V sound',  'w': 'W sound',  'x': 'X sound',  'y': 'Y sound',
    'z': 'Z sound',
    // ── Digraphs ───────────────────────────────────────────────────────────
    'ch': 'CH sound', 'sh': 'SH sound', 'th': 'TH sound',
    'wh': 'WH sound', 'ng': 'NG sound', 'ph': 'PH sound',
    // ── Short vowels ───────────────────────────────────────────────────────
    'a': 'Short A', 'e': 'Short E', 'i': 'Short I',
    'o': 'Short O', 'u': 'Short U',
    // ── Long vowels / digraph vowels ───────────────────────────────────────
    'ae': 'Long A',  'ee': 'Long E',  'ie': 'Long I',
    'oe': 'Long O',  'ue': 'Long U',  'oo': 'OO sound',
    'ou': 'OU sound','ow': 'OW sound','au': 'AU sound',
    'aw': 'AW sound','oi': 'OI sound','oy': 'OY sound',
    // ── IPA symbols (used in some word packs) ─────────────────────────────
    'æ': 'Short A', 'ɪ': 'Short I', 'ɔ': 'Short O', 'ʌ': 'Short U',
    'θ': 'TH (thin)', 'ð': 'TH (this)',
    'ʃ': 'SH sound', 'tʃ': 'CH sound', 'ŋ': 'NG sound',
  };

  /// Returns a readable label for [phoneme], or the phoneme itself if unknown.
  static String displayName(String phoneme) =>
      _names[phoneme] ?? phoneme.toUpperCase();
}
