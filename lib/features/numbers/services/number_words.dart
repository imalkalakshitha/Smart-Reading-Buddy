/// English words for 0–9999, for the spoken (TTS) prompts in Number
/// Learning — e.g. 347 → "three hundred forty-seven". English only.
class NumberWords {
  NumberWords._();

  static const _units = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
    'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
    'sixteen', 'seventeen', 'eighteen', 'nineteen',
  ];

  static const _tens = [
    '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
    'eighty', 'ninety',
  ];

  static String of(int n) {
    if (n < 0 || n > 9999) return '$n';
    if (n < 20) return _units[n];
    final parts = <String>[];
    var rest = n;
    if (rest >= 1000) {
      parts.add('${_units[rest ~/ 1000]} thousand');
      rest %= 1000;
    }
    if (rest >= 100) {
      parts.add('${_units[rest ~/ 100]} hundred');
      rest %= 100;
    }
    if (rest > 0) {
      if (rest < 20) {
        parts.add(_units[rest]);
      } else {
        final ones = rest % 10;
        parts.add(ones == 0 ? _tens[rest ~/ 10] : '${_tens[rest ~/ 10]}-${_units[ones]}');
      }
    }
    return parts.join(' ');
  }
}
