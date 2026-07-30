import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── EduPlay Design System ─────────────────────────────────────────────────────

class EP {
  // Core palette
  static const Color bg        = Color(0xFFF5F2FF);
  static const Color primary   = Color(0xFF7B61FF);
  static const Color primaryDk = Color(0xFF5A45D5);
  static const Color primaryLt = Color(0xFFEDE9FF);
  static const Color orange    = Color(0xFFFF6B35);
  static const Color orangeLt  = Color(0xFFFFF0EA);
  static const Color teal      = Color(0xFF00B894);
  static const Color tealLt    = Color(0xFFE0F7F4);
  static const Color yellow    = Color(0xFFFFD600);
  static const Color yellowLt  = Color(0xFFFFF9C4);
  static const Color success   = Color(0xFF4CAF85);
  static const Color successLt = Color(0xFFE8F5E9);
  static const Color danger    = Color(0xFFFF5252);
  static const Color dangerLt  = Color(0xFFFFEBEB);
  static const Color card      = Color(0xFFFFFFFF);
  static const Color textDark  = Color(0xFF1E1B4B);
  static const Color textMid   = Color(0xFF5E5B8A);
  static const Color textLight = Color(0xFF9E9BC0);
  static const Color divider   = Color(0xFFEEEAFF);
  static const Color _shadow   = Color(0x197B61FF);

  // Per-lesson accent colors
  static const Color l1 = Color(0xFFFF6B6B); // Drag Drop Letters — coral
  static const Color l2 = Color(0xFF4ECDC4); // Word Sound         — teal
  static const Color l3 = Color(0xFFFF8C42); // Missing Spelling   — orange
  static const Color l4 = Color(0xFF7B61FF); // Sentence Drag      — purple
  static const Color l5 = Color(0xFF45B7D1); // Meaning Quiz       — sky blue

  static Color lessonColor(int idx) =>
      [l1, l2, l3, l4, l5][idx.clamp(0, 4)];

  // Text helpers
  static TextStyle head(double sz,
          {Color color = textDark,
          FontWeight w = FontWeight.w800}) =>
      GoogleFonts.nunito(fontSize: sz, fontWeight: w, color: color);

  static TextStyle body(double sz,
          {Color color = textMid,
          FontWeight w = FontWeight.w600}) =>
      GoogleFonts.nunito(fontSize: sz, fontWeight: w, color: color);

  // Shadow helpers
  static List<BoxShadow> get cardShadow =>
      [BoxShadow(color: _shadow, blurRadius: 14, offset: const Offset(0, 5))];

  static List<BoxShadow> colorShadow(Color c) =>
      [BoxShadow(color: c.withOpacity(0.30), blurRadius: 18, offset: const Offset(0, 7))];
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

/// Rounded pill progress bar (e.g. "Word 1 / 10").
class EduProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final Color color;

  const EduProgressBar({
    super.key,
    required this.current,
    required this.total,
    this.color = EP.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Word $current / $total',
                style: EP.body(13, color: EP.textLight)),
            Text('${((current / total) * 100).round()}%',
                style: EP.body(13, color: color, w: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: current / total),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 10,
              backgroundColor: EP.divider,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Buddy status bar shown at the top of every activity.
class BuddyBar extends StatelessWidget {
  final String message;
  final bool active;

  const BuddyBar({super.key, required this.message, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: active ? EP.successLt : EP.primaryLt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text('🦉', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: EP.body(14,
                    color: active ? EP.success : EP.primary,
                    w: FontWeight.w700)),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? EP.success : EP.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cat image card used in letter/word activities.
class ActivityImageCard extends StatelessWidget {
  final String emoji;
  final Color borderColor;

  const ActivityImageCard({
    super.key,
    this.emoji = '🐱',
    this.borderColor = EP.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        color: EP.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withOpacity(0.35), width: 2.5),
        boxShadow: EP.cardShadow,
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 72)),
      ),
    );
  }
}

/// Round audio / listen button.
class AudioButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final double size;

  const AudioButton({
    super.key,
    required this.onTap,
    this.color = EP.primary,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: EP.colorShadow(color),
        ),
        child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

/// Small pill "Listen Again" button.
class ListenAgainButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  const ListenAgainButton({
    super.key,
    required this.onTap,
    this.color = EP.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: EP.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.replay_rounded, color: color, size: 18),
            const SizedBox(width: 6),
            Text('Listen Again',
                style: EP.body(13, color: color, w: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Primary action button.
class EduButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final bool outline;
  final double? width;

  const EduButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = EP.primary,
    this.textColor = Colors.white,
    this.icon,
    this.outline = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
        decoration: BoxDecoration(
          color: outline ? EP.card : color,
          borderRadius: BorderRadius.circular(18),
          border: outline
              ? Border.all(color: color, width: 2)
              : null,
          boxShadow: outline ? null : EP.colorShadow(color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: outline ? color : textColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: EP.head(16,
                  color: outline ? color : textColor,
                  w: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom EduPlay navigation bar.
class EduBottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;

  const EduBottomNav({
    super.key,
    required this.selected,
    required this.onTap,
  });

  static const _items = [
    (Icons.map_rounded, 'Journey'),
    (Icons.sports_esports_rounded, 'Games'),
    (Icons.local_library_rounded, 'Library'),
    (Icons.bar_chart_rounded, 'Progress'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EP.card,
        boxShadow: [
          BoxShadow(
              color: EP._shadow, blurRadius: 20, offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == selected;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: active ? EP.primaryLt : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.$1,
                          color: active ? EP.primary : EP.textLight,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: EP.body(11,
                            color: active ? EP.primary : EP.textLight,
                            w: active ? FontWeight.w800 : FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Star reward badge.
class StarBadge extends StatelessWidget {
  final int count;

  const StarBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: EP.yellowLt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: EP.yellow, width: 1.5),
          ),
          child: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text('$count stars earned',
                  style: EP.head(14, color: EP.textDark)),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Word Star!" achievement chip.
class WordStarChip extends StatelessWidget {
  const WordStarChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: EP.orangeLt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EP.orange, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏅', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text('Word Star!', style: EP.head(14, color: EP.orange)),
        ],
      ),
    );
  }
}

/// Word success overlay shown after each correct word inside an activity.
class WordSuccessOverlay extends StatelessWidget {
  final int wordNumber;
  final int total;
  final String completedWord;
  final String emoji;
  final int stars;
  final Color accentColor;
  final VoidCallback onNextWord;
  final VoidCallback onBackToJourney;

  const WordSuccessOverlay({
    super.key,
    required this.wordNumber,
    required this.total,
    required this.completedWord,
    required this.emoji,
    required this.stars,
    required this.accentColor,
    required this.onNextWord,
    required this.onBackToJourney,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.55),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: EP.card,
            borderRadius: BorderRadius.circular(32),
            boxShadow: EP.colorShadow(accentColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Word $wordNumber Completed!',
                  style: EP.head(16, color: accentColor),
                ),
              ),
              const SizedBox(height: 12),

              // Progress
              Text(
                '$wordNumber / $total',
                style: EP.body(13, color: EP.textLight),
              ),
              const SizedBox(height: 6),

              // Great job
              Text('Great Job! 🎉',
                  style: EP.head(26, color: EP.textDark)),
              const SizedBox(height: 16),

              // Image
              Text(emoji, style: const TextStyle(fontSize: 68)),
              const SizedBox(height: 12),

              // Completed word
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: accentColor.withOpacity(0.4), width: 2),
                ),
                child: Text(
                  completedWord,
                  style: EP.head(28, color: accentColor),
                ),
              ),
              const SizedBox(height: 16),

              // Buddy message
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EP.primaryLt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text('🦉', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Awesome work, Buddy!\nYou\'re becoming a word master!',
                        style: EP.body(13, color: EP.primary, w: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Rewards
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  StarBadge(count: stars),
                  const WordStarChip(),
                ],
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: EduButton(
                      label: 'Next Word',
                      onTap: onNextWord,
                      color: accentColor,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onBackToJourney,
                child: Text(
                  '← Back to Journey',
                  style: EP.body(14, color: EP.textLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
