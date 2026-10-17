import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';

// ─── Asset paths ──────────────────────────────────────────────────────────────

const _kClosed        = 'assets/images/mouth/mouth_closed.png';
const _kTeethLip      = 'assets/images/mouth/mouth_teeth_lip.png';
const _kOpenWide      = 'assets/images/mouth/mouth_open_wide.png';
const _kRounded       = 'assets/images/mouth/mouth_rounded.png';
const _kTeethClose    = 'assets/images/mouth/mouth_teeth_close.png';
const _kTongueUp      = 'assets/images/mouth/mouth_tongue_up.png';
const _kTongueBetween = 'assets/images/mouth/mouth_tongue_between.png';
const _kOpenMid       = 'assets/images/mouth/mouth_open_mid.png';

// ─── Widget ───────────────────────────────────────────────────────────────────

class PhonemeImageWidget extends StatefulWidget {
  final List<String> phonemes;
  final bool isPlaying;
  final VoidCallback? onComplete;

  const PhonemeImageWidget({
    super.key,
    required this.phonemes,
    this.isPlaying = false,
    this.onComplete,
  });

  /// Auto-generates the phoneme list by splitting [word] according to [language].
  factory PhonemeImageWidget.fromWord(
    String word,
    String language, {
    bool isPlaying = false,
    VoidCallback? onComplete,
  }) {
    return PhonemeImageWidget(
      phonemes: _generatePhonemes(word, language),
      isPlaying: isPlaying,
      onComplete: onComplete,
    );
  }

  // ── Phoneme → image ────────────────────────────────────────────────────────

  /// Returns the mouth image asset path for [phoneme].
  /// Accepts Sinhala characters, IPA symbols, English letters, and digraphs.
  static String getImageForPhoneme(String phoneme) {
    final p = phoneme
        .toLowerCase()
        .trim()
        .replaceAll('/', '')
        .replaceAll('[', '')
        .replaceAll(']', '');
    if (p.isEmpty) return _kOpenMid;

    // Full-string matches (digraphs, IPA multi-char sequences, Sinhala chars)
    switch (p) {
      // ─ Sinhala bilabials
      case 'ම': case 'බ': case 'ප':                return _kClosed;
      // ─ Sinhala labiodentals
      case 'ෆ': case 'ව':                           return _kTeethLip;
      // ─ Sinhala open vowels
      case 'අ': case 'ආ':                           return _kOpenWide;
      // ─ Sinhala rounded vowels
      case 'උ': case 'ඌ':                           return _kRounded;
      // ─ Sinhala alveolars / sibilants
      case 'ස': case 'ශ': case 'ත': case 'ද': case 'න': return _kTeethClose;
      // ─ Sinhala liquids
      case 'ල': case 'ළ': case 'ර':                return _kTongueUp;
      // ─ Sinhala velars / mid vowels
      case 'ක': case 'ග': case 'එ': case 'ඉ':      return _kOpenMid;
      // ─ English / IPA dentals (TH)
      case 'th': case 'θ': case 'ð':               return _kTongueBetween;
      // ─ English / IPA postalveolars
      case 'sh': case 'ʃ': case 'ʒ': case 'zh':    return _kTeethClose;
      // ─ Velars / nasals
      case 'ng': case 'ŋ': case 'ch':               return _kOpenMid;
      // ─ IPA long vowels
      case 'aː': case 'ɑː': case 'æː':             return _kOpenWide;
      case 'uː': case 'ɔː':                         return _kRounded;
      case 'iː':                                     return _kOpenMid;
    }

    // First-character fallback — handles IPA syllable strings like 'kæt', 'ðə', 'saŋ'
    switch (p[0]) {
      case 'm': case 'b': case 'p':
        return _kClosed;
      case 'f': case 'v':
        return _kTeethLip;
      case 'æ': case 'ɑ': case 'ɒ': case 'a':
        return _kOpenWide;
      case 'u': case 'ʊ': case 'ɔ': case 'o':
        return _kRounded;
      case 's': case 'z': case 't': case 'd': case 'n':
        return _kTeethClose;
      case 'l': case 'r': case 'ɹ':
        return _kTongueUp;
      case 'k': case 'g': case 'e': case 'ɛ': case 'i':
      case 'ɪ': case 'ə': case 'ɜ': case 'h': case 'w':
      case 'j': case 'y': case 'x':
        return _kOpenMid;
      default:
        return _kOpenMid;
    }
  }

  // ── Word → phoneme splitting ───────────────────────────────────────────────

  static List<String> _generatePhonemes(String word, String language) {
    return language == 'sinhala'
        ? _splitSinhala(word)
        : _splitEnglish(word);
  }

  /// Groups Sinhala base characters with their combining vowel signs and halant.
  static List<String> _splitSinhala(String word) {
    // Sinhala Unicode ranges:
    //   Vowels:       U+0D85–U+0D96
    //   Consonants:   U+0D9A–U+0DC6
    //   Vowel signs:  U+0DCF–U+0DDF, U+0DF2–U+0DF3
    //   Halant (්):   U+0DCA
    final re = RegExp(
      r'[අ-ඖක-ෆ][ා-ෟ්ෲෳ]*',
    );
    final matches = re.allMatches(word).map((m) => m.group(0)!).toList();
    return matches.isNotEmpty ? matches : word.split('').where((c) => c.trim().isNotEmpty).toList();
  }

  /// Splits an English word, keeping common digraphs together.
  static List<String> _splitEnglish(String word) {
    const digraphs = {'th', 'sh', 'ch', 'ph', 'wh', 'ng', 'ck', 'gh', 'qu'};
    final lower = word.toLowerCase();
    final out = <String>[];
    int i = 0;
    while (i < lower.length) {
      if (i + 1 < lower.length && digraphs.contains(lower.substring(i, i + 2))) {
        out.add(lower.substring(i, i + 2));
        i += 2;
      } else {
        final c = lower[i];
        if (c.trim().isNotEmpty) out.add(c);
        i++;
      }
    }
    return out;
  }

  @override
  State<PhonemeImageWidget> createState() => _PhonemeImageWidgetState();
}

// ─── State ────────────────────────────────────────────────────────────────────

class _PhonemeImageWidgetState extends State<PhonemeImageWidget> {
  int _currentIndex = 0;
  Timer? _timer;
  bool _internalPlaying = false;

  @override
  void initState() {
    super.initState();
    _internalPlaying = widget.isPlaying;
    if (_internalPlaying) _startTimer();
  }

  @override
  void didUpdateWidget(PhonemeImageWidget old) {
    super.didUpdateWidget(old);
    // Sync with external isPlaying changes
    if (widget.isPlaying != old.isPlaying) {
      _internalPlaying = widget.isPlaying;
      _internalPlaying ? _startTimer() : _stopTimer();
    }
    // Reset index when phoneme list changes
    if (widget.phonemes != old.phonemes) {
      setState(() => _currentIndex = 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.phonemes.isEmpty) return;
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted) return;
      final next = (_currentIndex + 1) % widget.phonemes.length;
      setState(() => _currentIndex = next);
      if (next == 0) widget.onComplete?.call();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _togglePlayPause() {
    setState(() {
      _internalPlaying = !_internalPlaying;
      _internalPlaying ? _startTimer() : _stopTimer();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.phonemes.isEmpty) return const SizedBox.shrink();

    final isSinhala = AppState.language == 'sinhala';
    final phoneme = widget.phonemes[_currentIndex];
    final imagePath = PhonemeImageWidget.getImageForPhoneme(phoneme);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSinhala ? 'මෙලෙස කට හදන්න' : 'Watch how to say it',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF888888),
                ),
              ),
              GestureDetector(
                onTap: _togglePlayPause,
                child: Icon(
                  _internalPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: const Color(0xFF2ECC71),
                  size: 28,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Mouth image ─────────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: ClipRRect(
              key: ValueKey(imagePath),
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                imagePath,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.image_not_supported_rounded,
                    color: Color(0xFFCCCCCC),
                    size: 48,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Phoneme chips ────────────────────────────────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: List.generate(widget.phonemes.length, (i) {
              final active = i == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF27AE60)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  widget.phonemes[i],
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF666666),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
