import '../data/timed_reading_data.dart' show splitWords;

String _stripPunctuation(String w) =>
    w.toLowerCase().replaceAll(RegExp(r'[^\w඀-෿]'), '');

/// Pure positional word diff — v1 simplicity, no edit-distance alignment.
/// Compares [expected] and [transcribed] word-by-word at the same index;
/// returns the local (0-based, within this sentence) indices of expected
/// words that don't match. If the transcript is shorter than expected,
/// every expected word past the transcript's length is flagged too
/// (nothing was heard for it).
List<int> diffWords({required String expected, required String transcribed}) {
  final expectedWords = splitWords(expected).map(_stripPunctuation).toList();
  final gotWords = splitWords(transcribed).map(_stripPunctuation).toList();

  final misread = <int>[];
  for (var i = 0; i < expectedWords.length; i++) {
    if (i >= gotWords.length || gotWords[i] != expectedWords[i]) {
      misread.add(i);
    }
  }
  return misread;
}
