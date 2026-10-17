import 'dart:math';

/// Turns a Rapid Digit Naming transcript into the single-digit sequence the
/// child read. A fast row of digits can come back from the recogniser as
/// "864", "8 6 4", "eight six four" or "eight hundred sixty-four" — all of
/// these become [8, 6, 4].
///
/// Number words are read as English numbers (so compound forms like
/// "eight hundred sixty-four" or "twenty five" stay together), then every
/// number is split into its digits. Separate words that can't belong to
/// one number ("eight six") stay separate.
class RanTranscript {
  RanTranscript._();

  // Includes the usual mishearings of single digits.
  static const _units = {
    'zero': 0, 'oh': 0, 'one': 1, 'won': 1, 'two': 2, 'to': 2, 'too': 2,
    'three': 3, 'tree': 3, 'four': 4, 'for': 4, 'fore': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'ate': 8, 'nine': 9,
  };
  static const _teens = {
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
  };
  static const _tens = {
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fourty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  };

  static List<int> toDigits(String? transcript) {
    if (transcript == null) return const [];
    final text = transcript
        .toLowerCase()
        .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}${m[2]}') // 4,512 → 4512
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    final out = <int>[];
    final number = _NumberBuilder(out);
    for (final t in text.split(RegExp(r'\s+'))) {
      if (t.isEmpty || t == 'and' || t == 'a') continue;
      if (RegExp(r'^\d+$').hasMatch(t)) {
        number.flush();
        out.addAll(t.split('').map(int.parse));
      } else if (_units.containsKey(t)) {
        number.unit(_units[t]!);
      } else if (_teens.containsKey(t)) {
        number.teen(_teens[t]!);
      } else if (_tens.containsKey(t)) {
        number.tens(_tens[t]!);
      } else if (t == 'hundred') {
        number.hundred();
      } else if (t == 'thousand') {
        number.thousand();
      } else {
        number.flush(); // an unknown word ends any number in progress
      }
    }
    number.flush();
    return out;
  }
}

enum _Last { none, unit, teen, tens, hundred, thousand }

/// Builds one English number word by word; [flush] emits its digits.
class _NumberBuilder {
  final List<int> out;
  int _total = 0;
  int _current = 0;
  _Last _last = _Last.none;

  _NumberBuilder(this.out);

  bool get _active => _last != _Last.none;

  void unit(int v) {
    // A unit can only follow a tens word or a hundred/thousand
    // ("sixty four", "eight hundred four"); after another unit it starts a
    // new number ("eight six").
    if (_last == _Last.unit || _last == _Last.teen) flush();
    _current += v;
    _last = _Last.unit;
  }

  void teen(int v) {
    if (_last == _Last.unit || _last == _Last.teen || _last == _Last.tens) flush();
    _current += v;
    _last = _Last.teen;
  }

  void tens(int v) {
    if (_last == _Last.unit || _last == _Last.teen || _last == _Last.tens) flush();
    _current += v;
    _last = _Last.tens;
  }

  void hundred() {
    if (_last == _Last.hundred || _last == _Last.tens) flush();
    _current = (_current == 0 ? 1 : _current) * 100;
    _last = _Last.hundred;
  }

  void thousand() {
    if (_last == _Last.thousand) flush();
    _total += (_current == 0 ? 1 : _current) * 1000;
    _current = 0;
    _last = _Last.thousand;
  }

  void flush() {
    if (!_active) return;
    out.addAll('${_total + _current}'.split('').map(int.parse));
    _total = 0;
    _current = 0;
    _last = _Last.none;
  }
}

/// Why a RAN row ended.
enum RanRowEnd { allDigits, silence, manual, timeout }

/// One RAN row's listening state, as pure logic (no plugin), so the rules
/// are testable. Times are milliseconds on the caller's clock.
///
/// - The transcript is APPENDED across recogniser restarts: results within
///   one session replace each other (partials grow), and a session's text
///   is committed when it ends, so the next session starts after it.
/// - Speech activity comes from both new recognised text and sound level
///   (an adaptive threshold between the quietest and loudest levels heard,
///   since devices report very different scales).
/// - The row ends when every digit has been recognised, or after [silence]
///   with no speech once at least one digit was heard. As a backstop for
///   noisy sound levels, [stale] with no new text also ends it.
/// - Row time runs from the first partial result to the last recognised
///   speech, so the silence wait at the end isn't counted.
class RanRowTracker {
  final int expectedCount;
  final Duration silence;
  final Duration stale;

  RanRowTracker({
    required this.expectedCount,
    this.silence = const Duration(milliseconds: 2000),
    this.stale = const Duration(milliseconds: 4000),
  });

  String _committed = '';
  String _current = '';
  int? firstPartialMs;
  int? lastResultMs;
  int? lastLoudMs;
  double? _floor;
  double? _peak;

  /// Sound level range below which levels are treated as flat noise.
  static const _minLevelRange = 2.0;

  String get transcript => [_committed, _current].where((s) => s.isNotEmpty).join(' ');

  List<int> get digits => RanTranscript.toDigits(transcript);

  /// A recogniser result for the current session. With [timing] false (the
  /// final result that arrives after the mic is stopped) the text still
  /// counts but the row time isn't extended.
  void onResult(String words, {required bool isFinal, required int nowMs, bool timing = true}) {
    final w = words.trim();
    if (w.isNotEmpty) {
      if (timing) {
        firstPartialMs ??= nowMs;
        if (w != _current) lastResultMs = nowMs;
      }
      _current = w;
    }
    if (isFinal) commit();
  }

  /// The current session ended — keep its text and start fresh after it.
  void commit() {
    if (_current.isEmpty) return;
    _committed = transcript;
    _current = '';
  }

  void onSoundLevel(double level, int nowMs) {
    _floor = min(_floor ?? level, level);
    _peak = max(_peak ?? level, level);
    final range = _peak! - _floor!;
    if (range >= _minLevelRange && level >= _floor! + range * 0.5) lastLoudMs = nowMs;
  }

  int? get lastSpeechMs {
    final r = lastResultMs, l = lastLoudMs;
    if (r == null) return l;
    if (l == null) return r;
    return max(r, l);
  }

  /// Non-null once the row should end.
  RanRowEnd? check(int nowMs) {
    final heard = digits.length;
    if (heard >= expectedCount) return RanRowEnd.allDigits;
    if (heard == 0) return null;
    final last = lastSpeechMs;
    if (last != null && nowMs - last >= silence.inMilliseconds) return RanRowEnd.silence;
    final r = lastResultMs;
    if (r != null && nowMs - r >= stale.inMilliseconds) return RanRowEnd.silence;
    return null;
  }

  /// First partial result → last recognised speech.
  int get elapsedMs {
    final first = firstPartialMs;
    if (first == null) return 0;
    return max(0, (lastSpeechMs ?? first) - first);
  }
}
