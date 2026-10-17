import '../data/numbers_data.dart';
import '../models/pronunciation_result.dart';
import 'cmu_phoneme_lookup.dart';

/// Outcome of one Number Word attempt, after number-aware re-checking.
class NumberWordVerdict {
  final String verdict; // 'OK' | 'ALMOST' | 'WRONG' | 'NO_SPEECH'
  final int stars;
  final int xpEarned;

  /// The number the child seems to have said, if one could be parsed.
  final int? heardValue;

  /// True when the child said the -teen/-ty partner (e.g. "fifty" for 15).
  final bool teenTyConfusion;

  /// Child-friendly stress tip ("fif-TEEN — stress the end"), set only when
  /// [teenTyConfusion] is true.
  final String? tip;

  const NumberWordVerdict({
    required this.verdict,
    required this.stars,
    required this.xpEarned,
    this.heardValue,
    this.teenTyConfusion = false,
    this.tip,
  });
}

/// Alignment of one RAN row (expected digits vs digits heard).
class DigitAlignment {
  /// Per expected digit: true = named correctly, false = wrong or skipped.
  final List<bool> correctAt;
  final int correct;
  final int substitutions;
  final int omissions;
  final int insertions;

  const DigitAlignment({
    required this.correctAt,
    required this.correct,
    required this.substitutions,
    required this.omissions,
    required this.insertions,
  });

  int get errors => substitutions + omissions + insertions;
}

/// Number-aware layer on top of HybridPronunciationScorer — ENGLISH ONLY.
///
/// The hybrid scorer matches the transcript against the expected word as
/// text, but Android's speech-to-text usually writes numbers as digits
/// ("15", not "fifteen"). This class re-reads the result's rawTranscript
/// and accepts either form, without changing the scorer itself. It also
/// uses CMU phonemes to spot -teen/-ty confusion (fifteen ↔ fifty).
class NumberAnswerChecker {
  NumberAnswerChecker._();

  static const Map<String, int> _wordValues = {
    'zero': 0, 'oh': 0, 'one': 1, 'won': 1, 'two': 2, 'to': 2, 'too': 2,
    'three': 3, 'four': 4, 'for': 4, 'fore': 4, 'five': 5, 'six': 6,
    'seven': 7, 'eight': 8, 'ate': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
    'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
    'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
  };

  static const Map<String, int> _tensValues = {
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fourty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  };

  /// Every number in [transcript], in order — digits ("15") and words
  /// ("fifteen", "fifty five", "one hundred") both count.
  static List<int> parseNumbers(String? transcript) {
    if (transcript == null) return const [];
    final tokens = transcript
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    final out = <int>[];
    int? pendingTens; // "fifty" waiting for a possible "five"
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      final asInt = int.tryParse(t);
      final unit = _wordValues[t];
      final tens = _tensValues[t];

      if (unit != null && pendingTens != null && unit >= 1 && unit <= 9) {
        out.add(pendingTens + unit);
        pendingTens = null;
        continue;
      }
      if (pendingTens != null) {
        out.add(pendingTens);
        pendingTens = null;
      }

      if (asInt != null) {
        out.add(asInt);
      } else if (t == 'hundred') {
        // "one hundred" / "a hundred" / bare "hundred" → 100
        if (i > 0 && const {'one', 'won', '1'}.contains(tokens[i - 1]) &&
            out.isNotEmpty && out.last == 1) {
          out.removeLast();
        }
        out.add(100);
      } else if (tens != null) {
        pendingTens = tens;
      } else if (unit != null) {
        out.add(unit);
      }
    }
    if (pendingTens != null) out.add(pendingTens);
    return out;
  }

  /// Every single digit in [transcript], in order, for Rapid Digit Naming.
  /// "3 7 1", "371" and "three seven one" all give [3, 7, 1].
  static List<int> parseDigits(String? transcript) {
    final digits = <int>[];
    for (final n in parseNumbers(transcript)) {
      digits.addAll('$n'.split('').map(int.parse));
    }
    return digits;
  }

  /// Re-checks the hybrid scorer's [result] for [target] with number-aware
  /// matching and -teen/-ty detection.
  static Future<NumberWordVerdict> check({
    required NumberItem target,
    required PronunciationResult result,
  }) async {
    if (result.verdict == 'NO_SPEECH') {
      return const NumberWordVerdict(verdict: 'NO_SPEECH', stars: 0, xpEarned: 0);
    }

    final heard = parseNumbers(result.rawTranscript);
    final heardValue = heard.isEmpty ? null : heard.first;

    if (heard.contains(target.value)) {
      final stars = result.verdict == 'OK' ? result.stars : 3;
      return NumberWordVerdict(
        verdict: 'OK',
        stars: stars,
        xpEarned: _xpForStars(stars),
        heardValue: target.value,
      );
    }

    if (heardValue != null && await isTeenTyConfusion(target.value, heardValue)) {
      return NumberWordVerdict(
        verdict: 'WRONG',
        stars: 0,
        xpEarned: 0,
        heardValue: heardValue,
        teenTyConfusion: true,
        tip: tipFor(target.value),
      );
    }

    // A clearly different number is wrong, even if the text matcher
    // thought it looked close (e.g. "16" vs "15").
    if (heardValue != null) {
      return NumberWordVerdict(
          verdict: 'WRONG', stars: 0, xpEarned: 0, heardValue: heardValue);
    }

    // No number parsed. The scorer was given the digit form (see
    // NumberWordSessionScreen._stopAndScore), so a near-miss on the word
    // ("fiftee" for fifteen) is caught here instead.
    if (result.verdict != 'OK' && _isNearMiss(result.rawTranscript, target.spokenWord)) {
      return const NumberWordVerdict(verdict: 'ALMOST', stars: 1, xpEarned: 3);
    }

    // Otherwise trust the hybrid scorer's own verdict (also covers the
    // energy fallback, which has no transcript).
    return NumberWordVerdict(
      verdict: result.verdict,
      stars: result.stars,
      xpEarned: result.xpEarned,
    );
  }

  /// True when [expected] and [heard] differ only in a -teen vs -ty ending,
  /// judged from CMU phonemes: -teen ends T IY1 N (stress on the end),
  /// -ty ends T/D IY0 (stress on the start), and the stems match once
  /// stress digits are removed.
  static Future<bool> isTeenTyConfusion(int expected, int heard) async {
    final a = await _phonemesFor(expected);
    final b = await _phonemesFor(heard);
    if (a == null || b == null) return false;
    final sa = _suffixType(a);
    final sb = _suffixType(b);
    if (sa == null || sb == null || sa == sb) return false;
    return _stem(a, sa).join(' ') == _stem(b, sb).join(' ');
  }

  /// "fif-TEEN — stress the end" / "FIF-ty — stress the start".
  static String? tipFor(int n) {
    final syllables = NumbersData.stressSyllables[n];
    if (syllables == null) return null;
    final isTeen = n >= 13 && n <= 19;
    return isTeen
        ? '$syllables — stress the end'
        : '$syllables — stress the start';
  }

  static Future<List<String>?> _phonemesFor(int n) async {
    final word = NumbersData.wordFor(n);
    if (word == null || word.contains(' ') || word.contains('-')) return null;
    return await CmuPhonemeLookup.lookup(word) ?? NumbersData.cmuPhonemes[word];
  }

  static String? _suffixType(List<String> p) {
    final len = p.length;
    if (len >= 3 && p[len - 3] == 'T' && p[len - 2] == 'IY1' && p[len - 1] == 'N') {
      return 'teen';
    }
    if (len >= 2 && (p[len - 2] == 'T' || p[len - 2] == 'D') && p[len - 1] == 'IY0') {
      return 'ty';
    }
    return null;
  }

  static List<String> _stem(List<String> p, String suffix) => p
      .sublist(0, p.length - (suffix == 'teen' ? 3 : 2))
      .map((s) => s.replaceAll(RegExp(r'\d'), ''))
      .toList();

  /// Edit distance ≤ 2 to [expected] (whole transcript or any single
  /// token), only for words of 4+ letters so "to"/"two" style pairs don't
  /// count.
  static bool _isNearMiss(String? transcript, String expected) {
    if (transcript == null || expected.length < 4) return false;
    final heard = transcript.toLowerCase().trim();
    if (heard.isEmpty) return false;
    if (_editDistance(heard, expected) <= 2) return true;
    return heard
        .split(RegExp(r'\s+'))
        .any((t) => t.length >= 3 && _editDistance(t, expected) <= 2);
  }

  static int _editDistance(String a, String b) {
    final prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      var diag = prev[0];
      prev[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final up = prev[j];
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final best = diag + cost;
        final alt = (up < prev[j - 1] ? up : prev[j - 1]) + 1;
        prev[j] = best < alt ? best : alt;
        diag = up;
      }
    }
    return prev[b.length];
  }

  // Same star → XP mapping as HybridPronunciationScorer.
  static int _xpForStars(int stars) {
    switch (stars) {
      case 3:  return 15;
      case 2:  return 10;
      case 1:  return 5;
      default: return 0;
    }
  }

  /// Levenshtein alignment of [expected] digits against [heard] digits.
  /// Among equally cheap alignments, the one with the most matches wins,
  /// so a skipped digit plus an extra one isn't read as a run of
  /// substitutions (which would undercount correct digits).
  static DigitAlignment alignDigits(List<int> expected, List<int> heard) {
    final m = expected.length, n = heard.length;
    // Score per cell: edit cost (lower is better), then matches (higher).
    final cost = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    final hits = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      cost[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      cost[0][j] = j;
    }
    bool better(int c1, int h1, int c2, int h2) => c1 < c2 || (c1 == c2 && h1 > h2);
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final same = expected[i - 1] == heard[j - 1];
        var c = cost[i - 1][j - 1] + (same ? 0 : 1);
        var h = hits[i - 1][j - 1] + (same ? 1 : 0);
        if (better(cost[i - 1][j] + 1, hits[i - 1][j], c, h)) {
          c = cost[i - 1][j] + 1;
          h = hits[i - 1][j];
        }
        if (better(cost[i][j - 1] + 1, hits[i][j - 1], c, h)) {
          c = cost[i][j - 1] + 1;
          h = hits[i][j - 1];
        }
        cost[i][j] = c;
        hits[i][j] = h;
      }
    }

    final correctAt = List.filled(m, false);
    var correct = 0, subs = 0, omissions = 0, insertions = 0;
    var i = m, j = n;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final same = expected[i - 1] == heard[j - 1];
        if (cost[i][j] == cost[i - 1][j - 1] + (same ? 0 : 1) &&
            hits[i][j] == hits[i - 1][j - 1] + (same ? 1 : 0)) {
          if (same) {
            correctAt[i - 1] = true;
            correct++;
          } else {
            subs++;
          }
          i--;
          j--;
          continue;
        }
      }
      if (i > 0 && cost[i][j] == cost[i - 1][j] + 1 && hits[i][j] == hits[i - 1][j]) {
        omissions++;
        i--;
      } else {
        insertions++;
        j--;
      }
    }
    return DigitAlignment(
      correctAt: correctAt,
      correct: correct,
      substitutions: subs,
      omissions: omissions,
      insertions: insertions,
    );
  }
}
