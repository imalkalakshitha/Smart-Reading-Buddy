import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/core/models/app_text.dart';
import 'package:smart_reading_buddy/core/router/app_router.dart';
import 'package:smart_reading_buddy/core/services/ble_command_service.dart';
import 'package:smart_reading_buddy/core/services/session_logger.dart';
import 'package:smart_reading_buddy/core/screens/calibration_insights_screen.dart';
import 'package:smart_reading_buddy/features/parent/screens/parent_pin_screen.dart';

const _avatarEmoji = {
  'owl': '🦉', 'tiger': '🐯', 'frog': '🐸',
  'fox': '🦊', 'panda': '🐼', 'lion': '🦁',
};

Widget _buildCalibrationInsights(BuildContext context) => const CalibrationInsightsScreen();

// ── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  int _xp = 0;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final xp     = await SessionLogger.getTotalXp(AppState.grade);
    final streak = await SessionLogger.getStreakDays(AppState.grade);
    if (mounted) setState(() { _xp = xp; _streakDays = streak; });
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MenuSheet(
        onSwitchProfile: () {
          Navigator.pop(context);
          Navigator.pushNamedAndRemoveUntil(
              context, AppRouter.profiles, (r) => false);
        },
        onChangeLanguage: () {
          Navigator.pop(context);
          Navigator.pushNamedAndRemoveUntil(
              context, AppRouter.language, (r) => false);
        },
        onParentDashboard: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, AppRouter.parentPin);
        },
        onSettings: () {
          Navigator.pop(context);
          // Calibration Insights (researcher/admin aggregate view) —
          // reuses the same Parent PIN gate as Parent Dashboard, just
          // with a different destination after correct entry. Not real
          // "Settings" yet; this is the one thing Settings currently
          // leads to.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ParentPinScreen(
                destinationBuilder: _buildCalibrationInsights,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarEmoji[AppState.avatar] ?? '🦉';
    final name = AppState.name.isNotEmpty ? AppState.name : 'Friend';

    final pages = [
      _HomeContent(
        avatar: avatar,
        name: name,
        xp: _xp,
        streakDays: _streakDays,
        onMenuTap: _showMenu,
      ),
      _PlaceholderTab(icon: '🎤', label: AppText.speak),
      _PlaceholderTab(icon: '✍️', label: AppText.words),
      _PlaceholderTab(icon: '📖', label: AppText.reading),
      _PlaceholderTab(icon: '✏️', label: AppText.writing),
    ];

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _navIndex, children: pages),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _navIndex,
        onTap: (i) {
          if (i == 1) {
            Navigator.pushNamed(context, AppRouter.pronunciation);
          } else if (i == 2) {
            Navigator.pushNamed(context, AppRouter.eduplayDashboard, arguments: AppState.name);
          } else if (i == 3) {
            Navigator.pushNamed(context, AppRouter.timedReading);
          } else if (i == 4) {
            Navigator.pushNamed(context, AppRouter.writing);
          } else {
            setState(() => _navIndex = i);
          }
        },
      ),
    );
  }
}

// ── Home tab content ──────────────────────────────────────────────────────────

class _HomeContent extends StatelessWidget {
  final String avatar;
  final String name;
  final int xp;
  final int streakDays;
  final VoidCallback onMenuTap;

  const _HomeContent({
    required this.avatar,
    required this.name,
    required this.xp,
    required this.streakDays,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _AnimatedHeader(
            avatar: avatar,
            name: name,
            xp: xp,
            streakDays: streakDays,
            onMenuTap: onMenuTap,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _StreakCard(xp: xp, streakDays: streakDays)
                .animate(delay: 200.ms)
                .fadeIn()
                .slideY(begin: 0.3, curve: Curves.easeOut),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildListDelegate([
              _ActivityCard(
                icon: '🎤',
                title: AppText.pronunciation,
                description: AppText.pronunciationDesc,
                gradientColors: const [Color(0xFF2ECC71), Color(0xFF1ABC9C)],
                delay: 300,
                onTap: () => Navigator.pushNamed(context, AppRouter.pronunciation),
              ),
              _ActivityCard(
                icon: '🎮',
                title: AppText.eduplay,
                description: 'Fun lessons & activities!',
                gradientColors: const [Color(0xFF7B61FF), Color(0xFF5B41DF)],
                delay: 380,
                // EduPlay's real dashboard now exists — points here
                // instead of the ComingSoonPlaceholder at AppRouter.eduplay
                // (that route/screen is left in place, just no longer
                // linked from this card).
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRouter.eduplayDashboard,
                  arguments: AppState.name,
                ),
              ),
              _ActivityCard(
                icon: '📖',
                title: AppText.reading,
                description: AppText.readingDesc,
                gradientColors: const [Color(0xFF16A085), Color(0xFF0E7C63)],
                delay: 460,
                onTap: () => Navigator.pushNamed(context, AppRouter.timedReading),
              ),
              _ActivityCard(
                icon: '✏️',
                title: AppText.writing,
                description: AppText.writingDesc,
                gradientColors: const [Color(0xFF9B59B6), Color(0xFF7D3C98)],
                delay: 540,
                onTap: () => Navigator.pushNamed(context, AppRouter.writing),
              ),
              // Shared, cross-module feature (English only) — see
              // NumbersHubScreen. Not tied to any one team's module.
              _ActivityCard(
                icon: '🔢',
                title: 'Numbers',
                description: 'Say numbers & speed games!',
                gradientColors: const [Color(0xFFF39C12), Color(0xFFE67E22)],
                delay: 620,
                onTap: () => Navigator.pushNamed(context, AppRouter.numbers),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Animated Header ───────────────────────────────────────────────────────────

class _AnimatedHeader extends StatefulWidget {
  final String avatar;
  final String name;
  final int xp;
  final int streakDays;
  final VoidCallback onMenuTap;

  const _AnimatedHeader({
    required this.avatar,
    required this.name,
    required this.xp,
    required this.streakDays,
    required this.onMenuTap,
  });

  @override
  State<_AnimatedHeader> createState() => _AnimatedHeaderState();
}

class _AnimatedHeaderState extends State<_AnimatedHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _orb;

  @override
  void initState() {
    super.initState();
    _orb = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _orb.dispose();
    super.dispose();
  }

  bool get _isSi => AppState.language == 'sinhala';

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        height: 248,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF27AE60), Color(0xFF1ABC9C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Animated floating orbs
            AnimatedBuilder(
              animation: _orb,
              builder: (_, __) {
                final t = _orb.value * 2 * pi;
                return Stack(children: [
                  Positioned(
                    left: 24 + 10 * sin(t),
                    top: 10 + 8 * sin(t + 1.0),
                    child: _Orb(size: 90, opacity: 0.12),
                  ),
                  Positioned(
                    right: 16 + 8 * sin(t + 2.0),
                    top: 50 + 10 * sin(t + 0.5),
                    child: _Orb(size: 120, opacity: 0.09),
                  ),
                  Positioned(
                    left: 130 + 6 * sin(t + 3.0),
                    top: 130 + 6 * sin(t + 1.5),
                    child: _Orb(size: 64, opacity: 0.10),
                  ),
                  Positioned(
                    right: 70 + 8 * sin(t + 1.2),
                    top: 155 + 6 * sin(t + 2.2),
                    child: _Orb(size: 50, opacity: 0.08),
                  ),
                ]);
              },
            ),

            // Header content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: avatar + greeting + menu button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.55),
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Text(widget.avatar,
                              style: const TextStyle(fontSize: 32)),
                        ),
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0.5, 0.5),
                            curve: Curves.elasticOut,
                            duration: 750.ms,
                          )
                          .fadeIn(),
                      const SizedBox(width: 14),
                      // Name + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSi
                                  ? 'හෙලෝ, ${widget.name}! 👋'
                                  : 'Hi, ${widget.name}! 👋',
                              style: GoogleFonts.nunito(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isSi
                                  ? 'අද ඉගෙන ගනිමු! 🌟'
                                  : 'Ready to learn today? 🌟',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 160.ms).slideX(begin: -0.2),
                      ),
                      const SizedBox(width: 8),
                      // Menu button
                      GestureDetector(
                        onTap: widget.onMenuTap,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1),
                          ),
                          child: const Icon(Icons.more_vert,
                              color: Colors.white, size: 22),
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                  ),

                  const Spacer(),

                  // Bottom row: XP pill + streak pill + BLE chip
                  Row(
                    children: [
                      _HeaderPill(
                        icon: '⚡',
                        label: '${widget.xp} XP',
                        delay: 300,
                      ),
                      const SizedBox(width: 8),
                      _HeaderPill(
                        icon: '🔥',
                        label: '${widget.streakDays} ${widget.streakDays == 1 ? 'Day' : 'Days'}',
                        delay: 380,
                      ),
                      const Spacer(),
                      const _BuddyChip().animate().fadeIn(delay: 340.ms),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── BLE buddy chip ────────────────────────────────────────────────────────────
//
// Reflects/controls BleCommandService.instance's real connection state —
// same ValueListenableBuilder pattern as EduPlayChildDashboard's AppBar
// icon. This is a second, independent trigger point for the same shared
// singleton; EduPlayChildDashboard's own scanAndConnect() call in initState
// is untouched.

class _BuddyChip extends StatelessWidget {
  const _BuddyChip();

  void _onTap() {
    final ble = BleCommandService.instance;
    if (ble.isConnected) {
      ble.disconnect(); // fire and forget, same as scanAndConnect below
    } else {
      ble.scanAndConnect(); // fails silently on no device/timeout — see BleCommandService
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: ValueListenableBuilder<bool>(
        valueListenable: BleCommandService.instance.connected,
        builder: (context, connected, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? Colors.white : Colors.white.withOpacity(0.35),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                connected ? AppText.buddyConnected : AppText.buddyOffline,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header pill chip ──────────────────────────────────────────────────────────

class _HeaderPill extends StatelessWidget {
  final String icon;
  final String label;
  final int delay;
  const _HeaderPill({required this.icon, required this.label, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideX(begin: -0.3, curve: Curves.easeOut);
  }
}

// ── Wave Clipper ──────────────────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 44);
    path.quadraticBezierTo(
      size.width * 0.25, size.height,
      size.width * 0.5, size.height - 22,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height - 44,
      size.width, size.height - 12,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Floating orb ──────────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  final double size;
  final double opacity;
  const _Orb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ── Streak card ───────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final int xp;
  final int streakDays;

  const _StreakCard({required this.xp, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    final streak   = streakDays;
    const days     = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIdx = DateTime.now().weekday - 1; // Mon=0 … Sun=6

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Text('🔥', style: const TextStyle(fontSize: 26))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.88, 0.88),
                    end: const Offset(1.12, 1.12),
                    duration: 900.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$streak ${AppText.dayStreak}',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '⚡ $xp XP',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Day bubbles — filled for the last `streak` days up to and including today
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final daysAgo = todayIdx - i;
              final done = daysAgo >= 0 && daysAgo < streak;
              return _DayBubble(
                label: days[i],
                done: done,
                isToday: i == todayIdx,
                delay: i * 55,
              );
            }),
          ),

          const SizedBox(height: 16),

          // XP progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level 2',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$xp / 100 XP',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: xp / 100),
            duration: const Duration(milliseconds: 1300),
            curve: Curves.easeOut,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 13,
                backgroundColor: AppColors.divider,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day bubble ────────────────────────────────────────────────────────────────

class _DayBubble extends StatelessWidget {
  final String label;
  final bool done;
  final bool isToday;
  final int delay;

  const _DayBubble({
    required this.label,
    required this.done,
    required this.isToday,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? (isToday ? AppColors.primary : AppColors.primaryLight)
                : AppColors.divider,
            border: isToday
                ? Border.all(color: AppColors.primaryDark, width: 2.5)
                : null,
          ),
          child: Center(
            child: done
                ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: isToday ? Colors.white : AppColors.primaryDark,
                  )
                : Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                    ),
                  ),
          ),
        )
            .animate(delay: Duration(milliseconds: delay))
            .scale(
              begin: const Offset(0.3, 0.3),
              curve: Curves.elasticOut,
              duration: 550.ms,
            )
            .fadeIn(),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: done ? AppColors.primaryDark : AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

// ── Activity card ─────────────────────────────────────────────────────────────

class _ActivityCard extends StatefulWidget {
  final String icon;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final int delay;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors[0].withOpacity(0.42),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                right: -24,
                top: -24,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: -32,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon bubble
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(widget.icon,
                            style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                    // Text + button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.description,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppText.startActivity,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
          .animate(delay: widget.delay.ms)
          .fadeIn()
          .slideY(begin: 0.4, curve: Curves.easeOut),
    );
  }
}

// ── Placeholder tabs ──────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  final String icon;
  final String label;

  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppText.comingSoon,
            style: GoogleFonts.nunito(
                fontSize: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Bottom navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final items = [
      ('🏠', AppText.home),
      ('🎤', AppText.speak),
      ('🎮', AppText.eduplay),
      ('📖', AppText.reading),
      ('✏️', AppText.writing),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 22,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 68,
            child: Row(
              children: items.indexed.map((entry) {
                final i = entry.$1;
                final item = entry.$2;
                final selected = currentIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          width: selected ? 50 : 36,
                          height: selected ? 36 : 28,
                          decoration: selected
                              ? BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(14),
                                )
                              : null,
                          child: Center(
                            child: Text(
                              item.$1,
                              style: TextStyle(
                                  fontSize: selected ? 22 : 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected
                                ? AppColors.navSelected
                                : AppColors.navUnselected,
                          ),
                          child: Text(item.$2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: bottomPad),
        ],
      ),
    );
  }
}

// ── Menu sheet ────────────────────────────────────────────────────────────────

class _MenuSheet extends StatelessWidget {
  final VoidCallback onSwitchProfile;
  final VoidCallback onChangeLanguage;
  final VoidCallback onParentDashboard;
  final VoidCallback onSettings;

  const _MenuSheet({
    required this.onSwitchProfile,
    required this.onChangeLanguage,
    required this.onParentDashboard,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.swap_horiz_rounded, AppText.switchProfile, onSwitchProfile),
      (Icons.language_rounded, AppText.changeLanguage, onChangeLanguage),
      (Icons.family_restroom_rounded, AppText.parentDashboard, onParentDashboard),
      (Icons.settings_rounded, AppText.settings, onSettings),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ...items.indexed.map((entry) {
              final i = entry.$1;
              final item = entry.$2;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 60,
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.$1,
                            color: AppColors.primary, size: 24),
                      ),
                      title: Text(
                        item.$2,
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      onTap: item.$3,
                    ),
                  ),
                  if (i < items.length - 1)
                    Divider(
                        height: 1,
                        indent: 24,
                        endIndent: 24,
                        color: AppColors.divider),
                ],
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
