import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_mouth.dart';

/// Steps through a [NumberMouth]'s pictures while the word is spoken.
///
/// The TTS engine reports only start and finish, so the timing is an
/// estimate: [play] when speech starts (each sound ~200 ms, the stressed
/// syllable's a little longer — it's said longer), [finish] when it
/// finishes (jumps to the last shape, then rests). If the sequence runs
/// out first it holds the last shape until [finish].
class MouthPlayer extends ChangeNotifier {
  static const startDelay = Duration(milliseconds: 120);
  static const stepMs = 200;
  static const stressedStepMs = 300;
  static const _rest = Duration(milliseconds: 400);
  static const _safety = Duration(milliseconds: 1500);

  int? _index;
  Timer? _timer;
  int _run = 0;
  int _length = 0;

  /// The step being shown, or null at rest.
  int? get index => _index;
  bool get playing => _index != null;

  void play(NumberMouth mouth) {
    _cancel();
    if (mouth.steps.isEmpty) return;
    final run = ++_run;
    _length = mouth.steps.length;
    var i = 0;
    void next() {
      if (run != _run) return;
      _index = i;
      notifyListeners();
      final ms = mouth.steps[i].stressed ? stressedStepMs : stepMs;
      i++;
      // Last shape: hold for finish(), with a safety stop if it never comes.
      _timer = i < mouth.steps.length
          ? Timer(Duration(milliseconds: ms), next)
          : Timer(_safety, () => _toRest(run));
    }

    _timer = Timer(startDelay, next);
  }

  /// Speech finished: show the last shape briefly, then rest.
  void finish() {
    if (_timer == null && _index == null) return;
    _cancel();
    final run = _run;
    _index = _length - 1;
    notifyListeners();
    _timer = Timer(_rest, () => _toRest(run));
  }

  void stop() {
    _cancel();
    _run++;
    if (_index != null) {
      _index = null;
      notifyListeners();
    }
  }

  void _toRest(int run) {
    if (run != _run) return;
    _timer = null;
    _index = null;
    notifyListeners();
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }
}

/// A number word's mouth picture with its syllables: the stressed syllable
/// is in capitals and tinted ("fif·TEEN"); while [player] plays, the
/// picture steps through the sounds, the syllable being said lights up,
/// and on the stressed syllable the picture grows a little with a ring.
class NumberMouthStrip extends StatelessWidget {
  final NumberMouth mouth;
  final MouthPlayer player;

  /// Small caption above ("Watch my mouth", "You said 50").
  final String caption;

  /// Side-by-side size: picture on top, smaller.
  final bool compact;

  const NumberMouthStrip({
    super.key,
    required this.mouth,
    required this.player,
    this.caption = 'Watch my mouth',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final i = player.index;
        final step = i == null ? null : mouth.steps[i];
        final picture = _picture(step);
        final chips = _chips(step?.syllable);
        final label = Text(
          caption,
          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        );
        if (compact) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            // One line each (scaled down if needed), so the side-by-side
            // stays a fixed height.
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: label),
              const SizedBox(height: 6),
              picture,
              const SizedBox(height: 8),
              FittedBox(fit: BoxFit.scaleDown, child: chips),
            ],
          );
        }
        return Row(
          children: [
            picture,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [label, const SizedBox(height: 6), chips],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _picture(MouthStep? step) {
    final size = compact ? 64.0 : 88.0;
    final onStress = step?.stressed ?? false;
    final image = (step ?? mouth.steps.first).image;
    return AnimatedScale(
      scale: onStress ? 1.08 : 1,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: onStress ? AppColors.pronunciation : AppColors.divider,
            width: onStress ? 3 : 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            image,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => SizedBox(
              width: size,
              height: size,
              child: const Icon(Icons.image_not_supported_rounded, color: AppColors.divider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chips(int? active) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var s = 0; s < mouth.syllables.length; s++) ...[
            if (s > 0) const SizedBox(width: 4),
            _chip(s, active == s),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: compact ? WrapAlignment.center : WrapAlignment.start,
      children: [
        for (var s = 0; s < mouth.syllables.length; s++) _chip(s, active == s),
      ],
    );
  }

  Widget _chip(int s, bool active) {
    final stressed = s == mouth.stressedSyllable;
    final text = stressed ? mouth.syllables[s].toUpperCase() : mouth.syllables[s];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? AppColors.pronunciation
            : (stressed ? AppColors.pronunciation.withValues(alpha: 0.14) : AppColors.primarySurface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: stressed ? AppColors.pronunciation : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: compact ? 14 : 18,
          fontWeight: stressed ? FontWeight.w900 : FontWeight.w700,
          color: active ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// After a -teen/-ty mix-up: what the child said next to the target, each
/// with its mouth sequence, and a button to hear both.
class MouthContrast extends StatelessWidget {
  final int heard;
  final int target;
  final NumberMouth heardMouth;
  final NumberMouth targetMouth;
  final MouthPlayer heardPlayer;
  final MouthPlayer targetPlayer;
  final VoidCallback? onReplay;

  const MouthContrast({
    super.key,
    required this.heard,
    required this.target,
    required this.heardMouth,
    required this.targetMouth,
    required this.heardPlayer,
    required this.targetPlayer,
    this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    // "Hear both" sits between the two, so the card stays short enough for
    // the mic button to stay on screen at phone width.
    return Row(
      children: [
        Expanded(
          child: NumberMouthStrip(
            mouth: heardMouth,
            player: heardPlayer,
            caption: 'You said $heard',
            compact: true,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: onReplay == null ? AppColors.divider : AppColors.pronunciation,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Hear both',
                onPressed: onReplay,
                icon: const Icon(Icons.replay_rounded, color: Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hear both',
              style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.pronunciation),
            ),
          ],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: NumberMouthStrip(
            mouth: targetMouth,
            player: targetPlayer,
            caption: 'Say $target',
            compact: true,
          ),
        ),
      ],
    );
  }
}
