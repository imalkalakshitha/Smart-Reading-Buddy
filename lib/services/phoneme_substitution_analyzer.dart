/// Phonological Substitution Pattern Analysis — for a WRONG/ALMOST attempt,
/// figures out WHAT the child said instead of the expected sound, by
/// aligning the expected phoneme sequence (already tracked by PEPA, see
/// word_data.dart's `phonemes` lists) against the raw transcript actually
/// heard (PronunciationResult.rawTranscript).
///
/// Important limitation, stated plainly rather than glossed over: there is
/// no phonemizer/G2P engine anywhere in this app, so the "produced" side
/// can't be a true phoneme sequence — it has to be approximated from the
/// transcript text:
///   - Sinhala: the transcript is already in Sinhala script, which is a
///     syllabic abugida — each grapheme cluster (base consonant + optional
///     vowel sign/virama) corresponds closely to one spoken syllable, which
///     is also how word_data.dart already chunks Sinhala phonemes (e.g.
///     'gə','mə'). Segmenting the transcript into grapheme clusters is a
///     reasonable proxy for its syllable/phoneme sequence.
///   - English: English orthography is not phonemic (letters don't map
///     1:1 to sounds), and there's no G2P engine here to fix that. The
///     best available proxy without adding a new dependency is splitting
///     the recognized word into individual letters. This is cruder than
///     the Sinhala case — a mismatch may reflect spelling-vs-sound quirks
///     as much as an actual articulation substitution. Treat English
///     substitution patterns as a lower-confidence signal than Sinhala's.
///
/// Alignment itself (matching expected vs produced tokens position-by-
/// position) uses standard Levenshtein edit-distance backtracking — a well
/// defined algorithm, not a fabricated heuristic — to find the cheapest set
/// of substitute/insert/delete operations, and only the substitute
/// operations are recorded (insertions/deletions aren't a "sound A became
/// sound B" event).
class PhonemeSubstitutionAnalyzer {
  PhonemeSubstitutionAnalyzer._();

  /// Returns the list of (expected, produced) phoneme substitutions found
  /// by aligning [expectedPhonemes] against [rawTranscript]. Empty if there's
  /// nothing to align (no transcript, or sequences too different in length
  /// to produce a meaningful alignment).
  static List<({String expected, String produced})> extract({
    required List<String> expectedPhonemes,
    required String?      rawTranscript,
    required String       language,
  }) {
    if (rawTranscript == null || rawTranscript.trim().isEmpty) return [];
    if (expectedPhonemes.isEmpty) return [];

    final produced = language == 'si'
        ? _sinhalaGraphemeClusters(rawTranscript)
        : _englishLetters(rawTranscript);
    if (produced.isEmpty) return [];

    return _alignSubstitutions(expectedPhonemes, produced);
  }

  // ── Segmentation ─────────────────────────────────────────────────────────

  /// Splits Sinhala text into grapheme clusters: a base consonant/vowel
  /// character plus any trailing combining vowel signs and virama
  /// (U+0DCA, "hal kirīma"), which is what turns a consonant into a bare
  /// consonant sound rather than consonant+inherent-vowel.
  static List<String> _sinhalaGraphemeClusters(String text) {
    final clusters = <String>[];
    final buffer = StringBuffer();
    // Sinhala combining marks (dependent vowel signs + virama) live in the
    // U+0DCA and U+0DD0-U+0DDF / U+0DF2-U+0DF3 ranges.
    bool isCombining(int rune) =>
        rune == 0x0DCA || (rune >= 0x0DD0 && rune <= 0x0DDF) || (rune >= 0x0DF2 && rune <= 0x0DF3);

    for (final rune in text.trim().runes) {
      final ch = String.fromCharCode(rune);
      if (isCombining(rune) && buffer.isNotEmpty) {
        buffer.write(ch);
      } else {
        if (buffer.isNotEmpty) clusters.add(buffer.toString());
        buffer.clear();
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) clusters.add(buffer.toString());
    return clusters.where((c) => c.trim().isNotEmpty).toList();
  }

  /// English: letter-by-letter, lowercase — see class doc for why this is
  /// a coarse proxy rather than a true phoneme sequence.
  static List<String> _englishLetters(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '').split('');
  }

  // ── Alignment ────────────────────────────────────────────────────────────

  /// Levenshtein alignment between [expected] and [produced] token
  /// sequences, returning only the substitution pairs from the cheapest
  /// edit path (insertions/deletions are not substitutions).
  static List<({String expected, String produced})> _alignSubstitutions(
    List<String> expected,
    List<String> produced,
  ) {
    final m = expected.length, n = produced.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) { dp[i][0] = i; }
    for (var j = 0; j <= n; j++) { dp[0][j] = j; }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        if (expected[i - 1] == produced[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
              .reduce((a, b) => a < b ? a : b);
        }
      }
    }

    // Backtrack from (m, n) to (0, 0), collecting substitution steps.
    final subs = <({String expected, String produced})>[];
    var i = m, j = n;
    while (i > 0 && j > 0) {
      if (expected[i - 1] == produced[j - 1]) {
        i--; j--;
        continue;
      }
      final sub    = dp[i - 1][j - 1];
      final del    = dp[i - 1][j];
      final ins    = dp[i][j - 1];
      final cheapest = [sub, del, ins].reduce((a, b) => a < b ? a : b);
      if (cheapest == sub) {
        subs.add((expected: expected[i - 1], produced: produced[j - 1]));
        i--; j--;
      } else if (cheapest == del) {
        i--; // expected phoneme with nothing produced — not a substitution
      } else {
        j--; // extra produced token with no expected counterpart — not a substitution
      }
    }
    return subs;
  }
}
