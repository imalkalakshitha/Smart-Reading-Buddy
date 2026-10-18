import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';

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

/// Spacing between the parts of a question (instruction, picture card,
/// options), so they read as one block.
const kBlockGap = 18.0;

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

/// Small green ✓ badge for a right answer.
class CorrectBadge extends StatelessWidget {
  const CorrectBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: LearningColors.correct, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
    );
  }
}

/// A quick scale "pop" — played once when [child] appears, so callers wrap
/// only the "correct" state in it.
Widget correctPop(Widget child) =>
    child.animate().scaleXY(begin: 0.88, end: 1, duration: 450.ms, curve: Curves.elasticOut);

/// Wraps an answer row in the correct-answer pop + ✓ badge while [correct].
Widget correctMarked(Widget row, {required bool correct}) => correct
    ? correctPop(Stack(
        clipBehavior: Clip.none,
        children: [row, const Positioned(top: -12, right: 0, child: CorrectBadge())],
      ))
    : row;

enum FeedbackTone { good, tryAgain, revealed }

/// One feedback message, shown inside the question's [VisualCard]. A new
/// [id] re-plays the entrance (and the confetti) even when the text is the
/// same ("Let's try again!" twice in a row).
class FeedbackMessage {
  final int id;
  final String emoji;
  final String text;
  final FeedbackTone tone;

  const FeedbackMessage(this.id, this.emoji, this.text, this.tone);
}

/// Hands the session's current feedback message down to the activity's
/// [VisualCard], so the activities don't each pass it along.
class FeedbackScope extends InheritedWidget {
  final FeedbackMessage? message;

  const FeedbackScope({super.key, required this.message, required super.child});

  static FeedbackMessage? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FeedbackScope>()?.message;

  @override
  bool updateShouldNotify(FeedbackScope oldWidget) => oldWidget.message != message;
}

/// The question's picture (objects, number, sentence, …) on a white card.
/// Answer feedback appears inside it (see [CardFeedbackOverlay]), so the
/// child's eyes stay on the question rather than a separate message.
class VisualCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double minHeight;

  const VisualCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.minHeight = 96,
  });

  static const radius = 22.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: child,
        ),
        Positioned.fill(child: CardFeedbackOverlay(message: FeedbackScope.of(context))),
      ],
    );
  }
}

/// Feedback over a card: a soft tint with the message large in the middle,
/// fading in — plus a confetti burst for a right answer. Never blocks taps.
/// [scrim] false keeps the card's content fully visible (Number Match's
/// board, which stays playable).
class CardFeedbackOverlay extends StatelessWidget {
  final FeedbackMessage? message;
  final bool scrim;

  const CardFeedbackOverlay({super.key, required this.message, this.scrim = true});

  @override
  Widget build(BuildContext context) {
    final m = message;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(anim), child: child),
        ),
        child: m == null ? const SizedBox.expand(key: ValueKey('none')) : _content(m),
      ),
    );
  }

  Widget _content(FeedbackMessage m) {
    final (tint, border) = switch (m.tone) {
      FeedbackTone.good => (LearningColors.correctSurface, LearningColors.correct),
      FeedbackTone.tryAgain => (LearningColors.tryAgainSurface, LearningColors.wrongBorder),
      FeedbackTone.revealed => (LearningColors.correctSurface, LearningColors.correct),
    };
    final label = m.emoji.isEmpty ? m.text : '${m.text} ${m.emoji}';
    return Stack(
      key: ValueKey(m.id),
      clipBehavior: Clip.none,
      children: [
        if (scrim)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                // The revealed answer keeps the picture showing through.
                color: tint.withValues(alpha: m.tone == FeedbackTone.revealed ? 0.6 : 0.82),
                borderRadius: BorderRadius.circular(VisualCard.radius),
              ),
            ),
          ),
        Positioned.fill(
          child: LayoutBuilder(builder: (context, box) {
            final width = (box.maxWidth - 24).clamp(0.0, double.infinity);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: width),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border, width: 2.5),
                      boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (m.tone == FeedbackTone.good) const Positioned.fill(child: ConfettiBurst()),
      ],
    );
  }
}

/// A short burst of confetti from the middle of its box (~1 s, once).
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  late final List<_Piece> _pieces = _Piece.burst(28);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ConfettiPainter(_c, _pieces));
  }
}

class _Piece {
  final double dx, dy, spin, size;
  final Color color;

  const _Piece(this.dx, this.dy, this.spin, this.size, this.color);

  // Bright and cheerful — and no red.
  static const _colors = [
    Color(0xFF2ECC71),
    Color(0xFFF1C40F),
    Color(0xFF3498DB),
    Color(0xFF9B59B6),
    Color(0xFFFF8FB1),
    Color(0xFFF39C12),
  ];

  static List<_Piece> burst(int n) {
    final r = math.Random();
    return [
      for (var i = 0; i < n; i++)
        () {
          // Mostly upwards and outwards; gravity pulls them back down.
          final angle = -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.4;
          final speed = 120 + r.nextDouble() * 140;
          return _Piece(
            math.cos(angle) * speed,
            math.sin(angle) * speed,
            (r.nextDouble() - 0.5) * 12,
            5 + r.nextDouble() * 5,
            _colors[i % _colors.length],
          );
        }(),
    ];
  }
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> t;
  final List<_Piece> pieces;

  _ConfettiPainter(this.t, this.pieces) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final s = t.value; // 0 → 1 over the burst
    if (s >= 1) return;
    final origin = size.center(Offset.zero);
    final fade = s < 0.6 ? 1.0 : (1 - s) / 0.4;
    final paint = Paint();
    for (final p in pieces) {
      final pos = origin + Offset(p.dx * s, p.dy * s + 260 * s * s);
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * s);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}

/// Response callback for an activity: returns whether it was correct, so
/// the activity can style its own tapped option.
typedef SubmitAnswer = bool Function(Object response);

/// English TTS for prompts — slow and clear.
///
/// [speaking] is the "is speaking" flag; [onFinished] fires each time an
/// utterance finishes (or fails, or is stopped). They only observe the
/// engine's callbacks — how and what it speaks is unchanged. Used by the
/// Smart Buddy helper so a buddy reaction never talks over the app.
class NumberSpeaker {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  final ValueNotifier<bool> speaking = ValueNotifier(false);
  final StreamController<void> _finished = StreamController<void>.broadcast();

  bool get isSpeaking => speaking.value;
  Stream<void> get onFinished => _finished.stream;

  void _markFinished() {
    speaking.value = false;
    if (!_finished.isClosed) _finished.add(null);
  }

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() => speaking.value = true);
    _tts.setCompletionHandler(_markFinished);
    _tts.setErrorHandler((_) => _markFinished());
    // Not setCancelHandler: say() stops the previous utterance before the
    // next, and that cancel can arrive after the new one has started —
    // clearing the flag then would let a buddy reaction talk over it.
    // A real stop goes through stop() below, which clears it.
  }

  Future<void> say(String text) async {
    await _init();
    _runId++; // detaches any earlier sayWithProgress word callback
    _clearProgress();
    await _tts.stop();
    speaking.value = true;
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
    speaking.value = true;
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
    if (speaking.value) _markFinished();
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

/// [revealed]: the answer shown after the last try — a softer green, no
/// badge or pop (the child didn't pick it).
enum OptionLook { normal, wrong, correct, revealed }

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
      OptionLook.revealed => (LearningColors.correctSurface, LearningColors.correct.withValues(alpha: 0.6)),
    };
    final button = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: switch (look) { OptionLook.normal => 1.5, OptionLook.revealed => 2.5, _ => 3 }),
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
    return switch (look) {
      OptionLook.normal || OptionLook.revealed => button,
      // Right: ✓ badge + a quick pop (plays as this state appears).
      OptionLook.correct => correctPop(Stack(
          clipBehavior: Clip.none,
          children: [button, const Positioned(top: -8, right: -8, child: CorrectBadge())],
        )),
      // Wrong: 🔄 badge + one gentle shake (plays as this state appears).
      OptionLook.wrong => gentleShake(Stack(
          clipBehavior: Clip.none,
          children: [button, const Positioned(top: -8, right: -8, child: RetryBadge())],
        )),
    };
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
/// Callers keep the answer uneditable while [wrongShown], so the mark stays
/// up exactly as long as the "Let's try again!" message.
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
