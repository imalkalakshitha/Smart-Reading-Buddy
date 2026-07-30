/// Phonetic syllable breakdowns for all Sinhala practice words.
///
/// Used by HybridPronunciationScorer to do partial-syllable matching when
/// the en_US STT engine returns only part of the word.
class SinhalaSyllables {
  static const Map<String, List<String>> syllableMap = {
    // ── Grade 3 Basic ────────────────────────────────────────────────────────
    'asa':        ['a', 'sa'],
    'eka':        ['e', 'ka'],
    'gama':       ['ga', 'ma'],
    'ura':        ['u', 'ra'],
    'oya':        ['o', 'ya'],
    'kesel':      ['ke', 'sel'],
    'gehaniya':   ['ge', 'ha', 'ni', 'ya'],
    'niyara':     ['ni', 'ya', 'ra'],
    'thaaraawa':  ['thaa', 'raa', 'wa'],
    'cheenaya':   ['chee', 'na', 'ya'],
    'baegaya':    ['bae', 'ga', 'ya'],
    'theentha':   ['theen', 'tha'],
    'poojaawa':   ['poo', 'jaa', 'wa'],
    'muhuda':     ['mu', 'hu', 'da'],
    'wewela':     ['we', 'we', 'la'],
    // ── Grade 3 Advanced ─────────────────────────────────────────────────────
    'athsana':    ['ath', 'sa', 'na'],
    'kemaththa':  ['ke', 'math', 'tha'],
    'sinhaya':    ['sin', 'ha', 'ya'],
    'guruthuma':  ['gu', 'ru', 'thu', 'ma'],
    'thowilaya':  ['tho', 'wi', 'la', 'ya'],
    'sigiriya':   ['si', 'gi', 'ri', 'ya'],
    'waralasa':   ['wa', 'ra', 'la', 'sa'],
    'eethalaya':  ['ee', 'tha', 'la', 'ya'],
    'udalla':     ['u', 'dal', 'la'],
    'kiribath':   ['ki', 'ri', 'bath'],
    'wichaaraya': ['wi', 'chaa', 'ra', 'ya'],
    'rupakaya':   ['ru', 'pa', 'ka', 'ya'],
    'janathaawa': ['ja', 'na', 'thaa', 'wa'],
    'pohosath':   ['po', 'ho', 'sath'],
    'gaayanaya':  ['gaa', 'ya', 'na', 'ya'],
    // ── Grade 4 Level 2 ──────────────────────────────────────────────────────
    'sampoorna':       ['sam', 'poor', 'na'],
    'pilihuduwa':      ['pi', 'li', 'hu', 'du', 'wa'],
    'sanwaadaya':      ['san', 'waa', 'da', 'ya'],
    'awabodhaya':      ['a', 'wa', 'bo', 'dha', 'ya'],
    'sankalpa':        ['san', 'kal', 'pa'],
    'nirmaanasheelee': ['nir', 'maa', 'na', 'shee', 'lee'],
    'saukhya':         ['sau', 'khya'],
    'sanvidhaanaya':   ['san', 'vi', 'dhaa', 'na', 'ya'],
    'gaurawaya':       ['gau', 'ra', 'wa', 'ya'],
    'wistharaya':      ['wis', 'tha', 'ra', 'ya'],
    'nigamanaya':      ['ni', 'ga', 'ma', 'na', 'ya'],
    'aarakshaawa':     ['aa', 'rak', 'shaa', 'wa'],
    'prayathnaya':     ['pra', 'yath', 'na', 'ya'],
    'awadhaanaya':     ['a', 'wa', 'dhaa', 'na', 'ya'],
    'praayoogika':     ['praa', 'yoo', 'gi', 'ka'],
  };

  static List<String>? getSyllables(String word) =>
      syllableMap[word.toLowerCase()];

  static bool hasSyllables(String word) =>
      syllableMap.containsKey(word.toLowerCase());
}
