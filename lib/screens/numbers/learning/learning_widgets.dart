import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/app_colors.dart';

/// Number Learning palette. Wrong answers are a soft orange, never red.
class LearningColors {
  LearningColors._();

  static const accent = Color(0xFFF39C12);
  static const tryAgain = Color(0xFFFFA726);
  static const tryAgainSurface = Color(0xFFFFF3E0);
  static const correct = AppColors.success;
  static const correctSurface = Color(0xFFE8F8EF);

  /// A wrong pick: peach fill + darker orange border — clearly different
  /// from the white/green selected state and the orange theme accents, and
  /// still never red.
  static const wrongFill = Color(0xFFFFE0B2);
  static const wrongBorder = Color(0xFFEF6C00);
}

/// How long a wrong pick stays marked before it resets for another try.
const kWrongResetDelay = Duration(milliseconds: 1500);

/// Small 🔄 "try again" badge for a wrong pick.
class RetryBadge extends StatelessWidget {
  const RetryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: LearningColors.wrongBorder, width: 2),
      ),
      child: const Text('🔄', style: TextStyle(fontSize: 14)),
    );
  }
}

/// A short, gentle sideways shake — played once when [child] appears, so
/// callers wrap only the "wrong" state in it.
Widget gentleShake(Widget child) =>
    child.animate().shake(hz: 4, offset: const Offset(5, 0), rotation: 0, duration: 420.ms);

enum FeedbackTone { good, tryAgain }

/// One inline feedback message. A new [id] re-plays the entrance animation
/// even when the text is the same ("Let's try again!" twice in a row).
class FeedbackMessage {
  final int id;
  final String emoji;
  final String text;
  final FeedbackTone tone;

  const FeedbackMessage(this.id, this.emoji, this.text, this.tone);
}

/// Fixed-height slot under the question that shows a small rounded
/// feedback card, fading and sliding in. Fixed height so the activity
/// below never jumps when a message comes and goes.
class FeedbackSlot extends StatelessWidget {
  final FeedbackMessage? message;

  const FeedbackSlot({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final m = message;
    return SizedBox(
      height: 64,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, -0.35), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: m == null ? const SizedBox.shrink(key: ValueKey('none')) : _card(m),
        ),
      ),
    );
  }

  Widget _card(FeedbackMessage m) {
    final good = m.tone == FeedbackTone.good;
    return Container(
      key: ValueKey(m.id),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: good ? LearningColors.correctSurface : LearningColors.wrongFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: good ? LearningColors.correct : LearningColors.wrongBorder, width: 2),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(m.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              m.text,
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Response callback for an activity: returns whether it was correct, so
/// the activity can style its own tapped option.
typedef SubmitAnswer = bool Function(Object response);

/// English TTS for prompts — slow and clear.
class NumberSpeaker {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4);
    await _tts.setPitch(1.0);
  }

  Future<void> say(String text) async {
    await _init();
    _runId++; // detaches any earlier sayWithProgress word callback
    _clearProgress();
    await _tts.stop();
    await _tts.speak(text);
  }

  Timer? _fallbackTimer;
  int _runId = 0;

  /// Speaks [text], calling [onWord] with the character range of each word
  /// as it's spoken (from the TTS engine's progress events), then
  /// [onWord](null) when done. Engines that don't report progress get a
  /// timer that steps through the words at roughly the speaking rate.
  Future<void> sayWithProgress(String text, void Function(TextRange? word) onWord) async {
    await _init();
    _clearProgress();
    await _tts.stop();
    final run = ++_runId;
    var gotProgress = false;
    _tts.setProgressHandler((_, start, end, _) {
      if (run != _runId) return;
      gotProgress = true;
      _fallbackTimer?.cancel();
      onWord(TextRange(start: start, end: end));
    });
    final words = RegExp(r'\S+').allMatches(text).toList();
    var w = 0;
    _fallbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (gotProgress || run != _runId) return;
      if (words.isNotEmpty) onWord(TextRange(start: words[0].start, end: words[0].end));
      w = 1;
      _fallbackTimer = Timer.periodic(const Duration(milliseconds: 520), (t) {
        if (run != _runId || w >= words.length) {
          t.cancel();
          return;
        }
        onWord(TextRange(start: words[w].start, end: words[w].end));
        w++;
      });
    });
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(text);
    await _tts.awaitSpeakCompletion(false);
    if (run == _runId) {
      _clearProgress();
      onWord(null);
    }
  }

  void _clearProgress() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  Future<void> stop() {
    _runId++;
    _clearProgress();
    return _tts.stop();
  }
}

/// Short instruction with a replay-audio button.
class InstructionBar extends StatelessWidget {
  final String prompt;
  final VoidCallback onReplay;

  const InstructionBar({super.key, required this.prompt, required this.onReplay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              prompt,
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
          Material(
            color: LearningColors.accent,
            shape: const CircleBorder(),
            child: IconButton(
              iconSize: 30,
              tooltip: 'Hear it again',
              onPressed: onReplay,
              icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

enum OptionLook { normal, wrong, correct }

/// Large, well-spaced number button.
class BigNumberButton extends StatelessWidget {
  final String label;
  final OptionLook look;
  final VoidCallback? onTap;
  final double fontSize;

  const BigNumberButton({
    super.key,
    required this.label,
    this.look = OptionLook.normal,
    this.onTap,
    this.fontSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border) = switch (look) {
      OptionLook.normal => (Colors.white, AppColors.divider),
      OptionLook.wrong => (LearningColors.wrongFill, LearningColors.wrongBorder),
      OptionLook.correct => (LearningColors.correctSurface, LearningColors.correct),
    };
    final button = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: look == OptionLook.normal ? 1.5 : 3),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
    if (look != OptionLook.wrong) return button;
    // Wrong: 🔄 badge + one gentle shake (plays as this state appears).
    return gentleShake(Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        const Positioned(top: -8, right: -8, child: RetryBadge()),
      ],
    ));
  }
}

/// Up to 4 option buttons, always centred: 2 or 3 options sit in one row
/// when they fit; otherwise rows of 2, with an odd last option centred
/// (never a lone option left-aligned).
class OptionGrid extends StatelessWidget {
  final List<Widget> children;

  const OptionGrid({super.key, required this.children});

  static const _gap = 16.0;
  static const _minOptionWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final n = children.length;
    return LayoutBuilder(builder: (context, box) {
      final oneRow = n <= 3 && box.maxWidth >= n * _minOptionWidth + (n - 1) * _gap;
      if (oneRow) return _row(children);
      final half = (box.maxWidth - _gap) / 2;
      final rows = <Widget>[];
      for (var i = 0; i < n; i += 2) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: _gap));
        rows.add(i + 1 < n
            ? _row([children[i], children[i + 1]])
            : Center(child: SizedBox(width: half, child: children[i])));
      }
      return Column(mainAxisSize: MainAxisSize.min, children: rows);
    });
  }

  Widget _row(List<Widget> items) => Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(child: items[i]),
          ],
        ],
      );
}

/// Wide pill button (Check, Next, etc.).
class PillButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const PillButton({super.key, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// A slot that a tile/number is placed into (Build, Ordering).
class AnswerSlot extends StatelessWidget {
  final String? value;
  final VoidCallback? onTap;
  final double width;
  final Color? highlight;

  /// Peach wrong-answer fill (pair it with a LearningColors.wrongBorder
  /// [highlight]).
  final bool wrong;

  const AnswerSlot({super.key, this.value, this.onTap, this.width = 64, this.highlight, this.wrong = false});

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: wrong ? LearningColors.wrongFill : (filled ? Colors.white : AppColors.primarySurface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight ?? (filled ? LearningColors.accent : AppColors.divider),
            width: highlight != null ? 3 : 2,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              value ?? '',
              style: GoogleFonts.nunito(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrong-answer handling for check-button activities (Ordering, colouring):
/// [showWrong] marks the answer for [kWrongResetDelay], then clears the
/// marking but keeps Check off until the child changes something
/// ([changed]), so the same wrong answer can't simply be re-submitted.
mixin WrongCheckReset<T extends StatefulWidget> on State<T> {
  bool checkedCorrect = false;
  bool wrongShown = false;
  bool _lockedUntilChange = false;
  Timer? _wrongTimer;

  bool get canCheck => !checkedCorrect && !wrongShown && !_lockedUntilChange;

  /// Highlight colour for the answer slots right now, if any.
  Color? get checkHighlight =>
      checkedCorrect ? LearningColors.correct : (wrongShown ? LearningColors.wrongBorder : null);

  void showWrong() {
    setState(() => wrongShown = true);
    _wrongTimer?.cancel();
    _wrongTimer = Timer(kWrongResetDelay, () {
      if (!mounted) return;
      setState(() {
        wrongShown = false;
        _lockedUntilChange = true;
      });
    });
  }

  /// Call inside setState whenever the child edits their answer.
  void changed() {
    _wrongTimer?.cancel();
    wrongShown = false;
    _lockedUntilChange = false;
  }

  @override
  void dispose() {
    _wrongTimer?.cancel();
    super.dispose();
  }
}

/// Wraps an answer row in the wrong-answer shake + 🔄 badge while [wrong].
Widget wrongMarked(Widget row, {required bool wrong}) => wrong
    ? gentleShake(Stack(
        clipBehavior: Clip.none,
        children: [row, const Positioned(top: -12, right: 0, child: RetryBadge())],
      ))
    : row;
