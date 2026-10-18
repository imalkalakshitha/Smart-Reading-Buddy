import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Encoding design constants ─────────────────────────────────────────────────
const _kPrimary   = Color(0xFF2ECC71);
const _kSecondary = Color(0xFFFFD166);
const _kAccent    = Color(0xFFFF6B6B);
const _kBg        = Color(0xFFF0FBF4);
const _kSuccess   = Color(0xFF06D6A0);
const _kText      = Color(0xFF1A1A2E);
const _kTeal      = Color(0xFF48CAE4);

// ── Screen ────────────────────────────────────────────────────────────────────

class EncodingOnboardingScreen extends StatefulWidget {
  const EncodingOnboardingScreen({super.key});

  @override
  State<EncodingOnboardingScreen> createState() =>
      _EncodingOnboardingScreenState();
}

class _EncodingOnboardingScreenState extends State<EncodingOnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _shapeCtrl;
  late final AnimationController _buddyWaveCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _startBtnCtrl;

  bool _demoCompleted = false;
  bool _catDropped    = false;
  bool _dropHovered   = false;

  @override
  void initState() {
    super.initState();
    _shapeCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 7))..repeat();
    _buddyWaveCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 950))
      ..repeat(reverse: true);
    _startBtnCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void dispose() {
    _shapeCtrl.dispose();
    _buddyWaveCtrl.dispose();
    _pulseCtrl.dispose();
    _startBtnCtrl.dispose();
    super.dispose();
  }

  void _handleCorrectDrop() {
    if (_demoCompleted) return;
    setState(() {
      _catDropped   = true;
      _demoCompleted = true;
      _dropHovered  = false;
    });
    _pulseCtrl.stop();
    _startBtnCtrl.forward();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              'Amazing! You did it!',
              style: GoogleFonts.nunito(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
        backgroundColor: _kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Animated background shapes
            _FloatingShapes(controller: _shapeCtrl),

            // Main content
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Buddy robot + speech bubble
                  _BuddySection(
                    waveCtrl: _buddyWaveCtrl,
                    glowGreen: _catDropped,
                  )
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .slideY(begin: -0.15, curve: Curves.easeOut),

                  const SizedBox(height: 16),

                  // Instruction subtitle
                  Text(
                    'Drag the word to the right box!',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF555577),
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

                  const SizedBox(height: 32),

                  // Demo drag-and-drop task
                  _DemoTaskCard(
                    pulseCtrl: _pulseCtrl,
                    catDropped: _catDropped,
                    dropHovered: _dropHovered,
                    onHover: (v) => setState(() => _dropHovered = v),
                    onCorrect: _handleCorrectDrop,
                  ).animate().fadeIn(delay: 750.ms).slideY(begin: 0.2),

                  const SizedBox(height: 40),

                  // Start button — elastic-pops in after demo complete
                  AnimatedBuilder(
                    animation: _startBtnCtrl,
                    builder: (_, __) {
                      final scale = CurvedAnimation(
                        parent: _startBtnCtrl,
                        curve: Curves.elasticOut,
                      ).value;
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: _startBtnCtrl.value.clamp(0.0, 1.0),
                          child: _demoCompleted
                              ? _StartButton(
                                  onTap: () => Navigator.pushReplacementNamed(
                                      context, '/home'),
                                )
                              : const SizedBox.shrink(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Floating background shapes ────────────────────────────────────────────────

class _FloatingShapes extends StatelessWidget {
  final AnimationController controller;
  const _FloatingShapes({required this.controller});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value * 2 * pi;
        return Stack(children: [
          _dot(left: 18,        top: 70  + 12 * sin(t),        size: 48, emoji: '⭐', color: _kPrimary.withOpacity(0.14)),
          _dot(right: 16,       top: 130 + 9  * sin(t + 1.2),  size: 38, emoji: '✨', color: _kSecondary.withOpacity(0.22)),
          _dot(left: sw * 0.55, top: 28  + 14 * sin(t + 2.0),  size: 32, emoji: '💫', color: _kAccent.withOpacity(0.16)),
          _dot(left: 10,        top: sh * 0.48 + 10 * sin(t + 0.8), size: 30, emoji: '🌟', color: _kSuccess.withOpacity(0.18)),
          _dot(right: 28,       top: sh * 0.42 + 11 * sin(t + 3.0), size: 42, emoji: '⭐', color: _kPrimary.withOpacity(0.10)),
          // Soft blurred orbs
          Positioned(
            right: -36, top: 180 + 16 * sin(t + 0.4),
            child: Container(width: 130, height: 130,
              decoration: BoxDecoration(color: _kPrimary.withOpacity(0.07), shape: BoxShape.circle)),
          ),
          Positioned(
            left: -44, bottom: 120 + 12 * sin(t + 2.6),
            child: Container(width: 110, height: 110,
              decoration: BoxDecoration(color: _kSecondary.withOpacity(0.09), shape: BoxShape.circle)),
          ),
        ]);
      },
    );
  }

  Widget _dot({double? left, double? right, double? top, double? bottom,
      required double size, required String emoji, required Color color}) {
    return Positioned(
      left: left, right: right, top: top, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.55))),
      ),
    );
  }
}

// ── Buddy section (robot + speech bubble) ─────────────────────────────────────

class _BuddySection extends StatelessWidget {
  final AnimationController waveCtrl;
  final bool glowGreen;
  const _BuddySection({required this.waveCtrl, required this.glowGreen});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Speech bubble
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withOpacity(0.14),
                blurRadius: 16, offset: const Offset(0, 5)),
            ],
          ),
          child: Text(
            "Hi! I am Buddy! Let's learn together! 👋",
            style: GoogleFonts.nunito(
              fontSize: 19, fontWeight: FontWeight.w800, color: _kText),
            textAlign: TextAlign.center,
          ),
        ),
        // Bubble tail
        CustomPaint(
          size: const Size(24, 11),
          painter: _BubbleTailPainter(),
        ),
        const SizedBox(height: 6),
        // Robot
        _BuddyRobot(waveCtrl: waveCtrl, glowGreen: glowGreen),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      Paint()..color = Colors.white,
    );
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Buddy robot widget ────────────────────────────────────────────────────────

class _BuddyRobot extends StatelessWidget {
  final AnimationController waveCtrl;
  final bool glowGreen;
  const _BuddyRobot({required this.waveCtrl, required this.glowGreen});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: waveCtrl,
      builder: (_, __) => SizedBox(
        width: 130, height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow halo
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 105, height: 105,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowGreen
                        ? _kPrimary.withOpacity(0.50)
                        : _kTeal.withOpacity(0.20),
                    blurRadius: glowGreen ? 32 : 16,
                    spreadRadius: glowGreen ? 10 : 2,
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(110, 155),
              painter: _RobotPainter(waveT: waveCtrl.value, glowGreen: glowGreen),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Robot CustomPainter ───────────────────────────────────────────────────────

class _RobotPainter extends CustomPainter {
  final double waveT;
  final bool glowGreen;
  const _RobotPainter({required this.waveT, required this.glowGreen});

  @override
  void paint(Canvas canvas, Size size) {
    final body  = Paint()..color = glowGreen ? _kPrimary : _kTeal;
    final dark  = Paint()..color = glowGreen ? const Color(0xFF1A8A48) : const Color(0xFF0096C7);
    final white = Paint()..color = Colors.white;
    final pupil = Paint()..color = _kText;
    final cx    = size.width / 2;

    // ── Antenna ──────────────────────────────────────────────────────────────
    canvas.drawLine(Offset(cx, 0), Offset(cx, 18),
        Paint()..color = const Color(0xFFB0EBF8)..strokeWidth = 3..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx, 0), 7, Paint()..color = _kSecondary);
    canvas.drawCircle(Offset(cx, 0), 3.5, Paint()..color = Colors.white.withOpacity(0.7));

    // ── Head ─────────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 28, 18, 56, 44), const Radius.circular(16)),
      body,
    );

    // Eyes (white + pupil + shine)
    for (final dx in [-12.0, 12.0]) {
      canvas.drawCircle(Offset(cx + dx, 38), 10, white);
      canvas.drawCircle(Offset(cx + dx, 39), 5.5, pupil);
      canvas.drawCircle(Offset(cx + dx + 2, 36), 2.2, white);
    }

    // Smile
    canvas.drawPath(
      Path()..moveTo(cx - 9, 56)..quadraticBezierTo(cx, 63, cx + 9, 56),
      Paint()..color = dark.color..style = PaintingStyle.stroke
        ..strokeWidth = 2.5..strokeCap = StrokeCap.round,
    );

    // ── Body ─────────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 32, 66, 64, 52), const Radius.circular(14)),
      body,
    );

    // Chest panel
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 19, 75, 38, 24), const Radius.circular(9)),
      dark,
    );
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(cx - 10 + i * 10.0, 87), 3.2, white);
    }

    // ── Left arm (static) ────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 50, 70, 18, 34), const Radius.circular(9)),
      body,
    );

    // ── Right arm (waving) ───────────────────────────────────────────────────
    canvas.save();
    canvas.translate(cx + 32, 72);
    canvas.rotate(-0.35 + waveT * 0.65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 18, 34), const Radius.circular(9)),
      body,
    );
    canvas.restore();

    // ── Legs ─────────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 24, 120, 18, 28), const Radius.circular(7)),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx + 6, 120, 18, 28), const Radius.circular(7)),
      body,
    );
  }

  @override
  bool shouldRepaint(covariant _RobotPainter old) =>
      old.waveT != waveT || old.glowGreen != glowGreen;
}

// ── Demo task card ────────────────────────────────────────────────────────────

class _DemoTaskCard extends StatelessWidget {
  final AnimationController pulseCtrl;
  final bool catDropped;
  final bool dropHovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onCorrect;

  const _DemoTaskCard({
    required this.pulseCtrl,
    required this.catDropped,
    required this.dropHovered,
    required this.onHover,
    required this.onCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.12),
            blurRadius: 22, offset: const Offset(0, 7)),
        ],
      ),
      child: Column(
        children: [
          Text(
            'What word is this?',
            style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: const Color(0xFF555577)),
          ),
          const SizedBox(height: 16),

          // Cat image card
          Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              color: _kSecondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _kSecondary.withOpacity(0.45), width: 2),
            ),
            child: const Center(child: Text('🐱', style: TextStyle(fontSize: 76))),
          ),

          const SizedBox(height: 28),

          // Draggable word + drop zone
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Draggable tile (hides once dropped)
              SizedBox(
                width: 100,
                child: catDropped
                    ? const SizedBox(height: 58)
                    : Draggable<String>(
                        data: 'CAT',
                        feedback: Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1.1,
                            child: const _WordTile(word: 'CAT', lifted: true),
                          ),
                        ),
                        childWhenDragging: const Opacity(
                          opacity: 0.3,
                          child: _WordTile(word: 'CAT'),
                        ),
                        child: const _WordTile(word: 'CAT'),
                      ),
              ),

              // Arrow hint
              Icon(
                Icons.arrow_forward_rounded,
                color: _kPrimary.withOpacity(0.5), size: 28),

              // Drop zone
              _DropZone(
                pulseCtrl: pulseCtrl,
                catDropped: catDropped,
                hovered: dropHovered,
                onHover: onHover,
                onAccept: onCorrect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Word tile ─────────────────────────────────────────────────────────────────

class _WordTile extends StatelessWidget {
  final String word;
  final bool lifted;
  const _WordTile({required this.word, this.lifted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96, height: 58,
      decoration: BoxDecoration(
        color: _kTeal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kTeal.withOpacity(lifted ? 0.65 : 0.32),
            blurRadius: lifted ? 18 : 8,
            offset: Offset(0, lifted ? 10 : 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          word,
          style: GoogleFonts.nunito(
            fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ),
    );
  }
}

// ── Drop zone ─────────────────────────────────────────────────────────────────

class _DropZone extends StatelessWidget {
  final AnimationController pulseCtrl;
  final bool catDropped;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback onAccept;

  const _DropZone({
    required this.pulseCtrl,
    required this.catDropped,
    required this.hovered,
    required this.onHover,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    // Filled state after correct drop
    if (catDropped) {
      return Container(
        width: 100, height: 62,
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPrimary, width: 2.5),
        ),
        child: Center(
          child: Text('CAT',
              style: GoogleFonts.nunito(
                fontSize: 24, fontWeight: FontWeight.w900, color: _kPrimary)),
        ),
      )
          .animate()
          .scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut)
          .fadeIn();
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (d) {
        onHover(true);
        return d.data == 'CAT';
      },
      onLeave: (_) => onHover(false),
      onAcceptWithDetails: (d) {
        onHover(false);
        if (d.data == 'CAT') onAccept();
      },
      builder: (_, candidates, __) {
        return AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, __) {
            final borderColor = hovered
                ? _kPrimary
                : Color.lerp(const Color(0xFFB0EBF8), _kTeal, pulseCtrl.value)!;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 100, height: 62,
              decoration: BoxDecoration(
                color: hovered ? _kPrimary.withOpacity(0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: CustomPaint(
                painter: _DashedBorderPainter(color: borderColor, radius: 16),
                child: Center(
                  child: Text(
                    'Drop\nhere!',
                    style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: hovered ? _kPrimary : const Color(0xFF90D5EA)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Dashed border painter ─────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const dashLen = 7.0;
    const gapLen  = 4.5;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );
    final metrics = (Path()..addRRect(rrect)).computeMetrics().first;
    var dist = 0.0;
    while (dist < metrics.length) {
      final end = (dist + dashLen).clamp(0.0, metrics.length);
      canvas.drawPath(metrics.extractPath(dist, end), paint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color;
}

// ── Start button ──────────────────────────────────────────────────────────────

class _StartButton extends StatefulWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) { _press.reverse(); widget.onTap(); },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - _press.value * 0.04, child: child),
        child: Container(
          width: double.infinity, height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimary, Color(0xFF27AE60)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withOpacity(0.50),
                blurRadius: 20, offset: const Offset(0, 9)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Let's Start!",
                style: GoogleFonts.nunito(
                  fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}
