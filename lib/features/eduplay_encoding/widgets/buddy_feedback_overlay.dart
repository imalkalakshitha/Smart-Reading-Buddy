import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';

// ── BuddyFeedbackOverlay ──────────────────────────────────────────────────────

/// Shown as a Stack overlay on exercise screens.
/// Correct → green, auto-dismiss 2 s.
/// Wrong   → coral, auto-dismiss 1.5 s.
/// Third   → yellow, shows answer, manual Next button.
class BuddyFeedbackOverlay extends StatefulWidget {
  final bool isCorrect;
  final bool isThirdAttempt;
  final String? revealAnswer;
  final int xpGain;
  final VoidCallback onDismiss;
  final VoidCallback onNext;

  const BuddyFeedbackOverlay({
    super.key,
    required this.isCorrect,
    required this.isThirdAttempt,
    required this.onDismiss,
    required this.onNext,
    this.revealAnswer,
    this.xpGain = 10,
  });

  @override
  State<BuddyFeedbackOverlay> createState() => _BuddyFeedbackOverlayState();
}

class _BuddyFeedbackOverlayState extends State<BuddyFeedbackOverlay> {
  @override
  void initState() {
    super.initState();
    if (!widget.isThirdAttempt) {
      final delay = widget.isCorrect
          ? const Duration(milliseconds: 2000)
          : const Duration(milliseconds: 1600);
      Future.delayed(delay, () {
        if (mounted) widget.onDismiss();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String emoji;
    final String title;
    final Color textColor;

    if (widget.isThirdAttempt) {
      bg = const Color(0xFFFFF3CD);
      emoji = '💡';
      title = 'Here is the answer!';
      textColor = const Color(0xFF856404);
    } else if (widget.isCorrect) {
      bg = const Color(0xFFD4EDDA);
      emoji = '⭐';
      title = 'Well done!';
      textColor = const Color(0xFF155724);
    } else {
      bg = const Color(0xFFFFE0DC);
      emoji = '💪';
      title = 'Try again!';
      textColor = const Color(0xFF842029);
    }

    return GestureDetector(
      onTap: widget.isThirdAttempt ? null : widget.onDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji + XP row
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 64))
                        .animate()
                        .scale(
                          begin: const Offset(0.3, 0.3),
                          curve: Curves.elasticOut,
                          duration: 600.ms,
                        ),
                    if (widget.isCorrect && !widget.isThirdAttempt)
                      _XpBadge(xp: widget.xpGain),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),

                // Reveal answer (third attempt)
                if (widget.isThirdAttempt && widget.revealAnswer != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.revealAnswer!,
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF333333),
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 400.ms).scale(
                        begin: const Offset(0.85, 0.85),
                        curve: Curves.easeOut,
                      ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: widget.onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Next',
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.4),
                ],
              ],
            ),
          ).animate().scale(
            begin: const Offset(0.7, 0.7),
            curve: Curves.easeOut,
            duration: 300.ms,
          ),
        ),
      ),
    );
  }
}

// ── XP badge flying up ────────────────────────────────────────────────────────

class _XpBadge extends StatelessWidget {
  final int xp;
  const _XpBadge({required this.xp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '+$xp XP',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF7B5800),
        ),
      ),
    )
        .animate()
        .slideY(begin: 0, end: -0.8, duration: 1200.ms, curve: Curves.easeOut)
        .fadeOut(delay: 800.ms, duration: 600.ms);
  }
}

// ── BuddyStatusCard ───────────────────────────────────────────────────────────

/// Persistent bottom card showing buddy state + animated sound bars.
class BuddyStatusCard extends StatelessWidget {
  final String word;
  final bool isSinhala;

  const BuddyStatusCard({
    super.key,
    required this.word,
    this.isSinhala = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryLight, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🦉', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSinhala ? 'Buddy සවන් දෙයි...' : 'Buddy Listening...',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isSinhala
                      ? 'ඇදගෙන යන්න: "$word"'
                      : 'Drag & Drop: "$word"',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Animated bars
          const _SoundBars(),
        ],
      ),
    );
  }
}

// ── Animated sound bars ───────────────────────────────────────────────────────

class _SoundBars extends StatefulWidget {
  const _SoundBars();

  @override
  State<_SoundBars> createState() => _SoundBarsState();
}

class _SoundBarsState extends State<_SoundBars> with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 380 + i * 110),
        value: i * 0.33,
      )..repeat(reverse: true);
      return c;
    });
    _anims = _ctrls
        .map((c) => Tween<double>(begin: 6, end: 22)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(
            width: 4,
            height: _anims[i].value,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
