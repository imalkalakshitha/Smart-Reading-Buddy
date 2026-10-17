import 'package:flutter/material.dart';
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
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
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
      OptionLook.wrong => (LearningColors.tryAgainSurface, LearningColors.tryAgain),
      OptionLook.correct => (LearningColors.correctSurface, LearningColors.correct),
    };
    return GestureDetector(
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
  }
}

/// 2-column grid of up to 4 option buttons.
class OptionGrid extends StatelessWidget {
  final List<Widget> children;

  const OptionGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: children[i]),
          const SizedBox(width: 16),
          Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
        ],
      ));
      if (i + 2 < children.length) rows.add(const SizedBox(height: 16));
    }
    return Column(children: rows);
  }
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

  const AnswerSlot({super.key, this.value, this.onTap, this.width = 64, this.highlight});

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
          color: filled ? Colors.white : AppColors.primarySurface,
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
