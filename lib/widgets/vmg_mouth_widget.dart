import 'package:flutter/material.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum VMGType {
  mouthClosed,
  mouthOpen,
  mouthOpenWide,
  lipsRounded,
  teethLip,
  tongueUp,
  tongueBack,
  tongueBetween,
  teethClose,
  lipsTogether,
}

// ─── Animation State ──────────────────────────────────────────────────────────

class VMGAnimationState {
  final double jawOpenAmount;   // 0.0=closed, 1.0=wide open
  final double lipRoundAmount;  // 0.0=normal, 1.0=fully pursed
  final double tongueTipRaise;  // 0.0=flat, 1.0=touching upper palate
  final double tongueBackRaise; // 0.0=flat, 1.0=back raised (K,G)
  final double tongueForward;   // 0.0=back, 1.0=between teeth (TH)
  final double lowerLipUp;      // 0.0=normal, 1.0=touching upper teeth (F,V)
  final double teethVisible;    // 0.0=hidden, 1.0=fully visible

  const VMGAnimationState({
    this.jawOpenAmount = 0.0,
    this.lipRoundAmount = 0.0,
    this.tongueTipRaise = 0.0,
    this.tongueBackRaise = 0.0,
    this.tongueForward = 0.0,
    this.lowerLipUp = 0.0,
    this.teethVisible = 0.0,
  });
}

// ─── Main Widget ──────────────────────────────────────────────────────────────

class VMGMouthWidget extends StatefulWidget {
  final VMGType vmgType;
  final double size;
  final bool animate;
  final bool showPhonemeLabel;

  const VMGMouthWidget({
    super.key,
    required this.vmgType,
    this.size = 200,
    this.animate = true,
    this.showPhonemeLabel = false,
  });

  // ── Target states ──────────────────────────────────────────────────────────

  static VMGAnimationState targetState(VMGType type) {
    switch (type) {
      case VMGType.mouthClosed:
        return const VMGAnimationState(jawOpenAmount: 0.0);
      case VMGType.mouthOpen:
        return const VMGAnimationState(jawOpenAmount: 0.4, teethVisible: 0.8);
      case VMGType.mouthOpenWide:
        return const VMGAnimationState(jawOpenAmount: 0.85, teethVisible: 1.0);
      case VMGType.lipsRounded:
        return const VMGAnimationState(jawOpenAmount: 0.2, lipRoundAmount: 0.9);
      case VMGType.teethLip:
        return const VMGAnimationState(
            jawOpenAmount: 0.15, lowerLipUp: 0.8, teethVisible: 0.9);
      case VMGType.tongueUp:
        return const VMGAnimationState(
            jawOpenAmount: 0.25, tongueTipRaise: 0.9, teethVisible: 0.5);
      case VMGType.tongueBack:
        return const VMGAnimationState(
            jawOpenAmount: 0.3, tongueBackRaise: 0.85, teethVisible: 0.4);
      case VMGType.tongueBetween:
        return const VMGAnimationState(
            jawOpenAmount: 0.3, tongueForward: 0.9, teethVisible: 0.7);
      case VMGType.teethClose:
        return const VMGAnimationState(jawOpenAmount: 0.05, teethVisible: 1.0);
      case VMGType.lipsTogether:
        return const VMGAnimationState(jawOpenAmount: 0.0, lipRoundAmount: 0.1);
    }
  }

  // ── Phoneme → VMG mapping ──────────────────────────────────────────────────

  static VMGType phonemeToVMG(String phoneme) {
    switch (phoneme.toUpperCase()) {
      case 'M':
      case 'B':
      case 'P':
        return VMGType.lipsTogether;
      case 'F':
      case 'V':
        return VMGType.teethLip;
      case 'TH':
        return VMGType.tongueBetween;
      case 'T':
      case 'D':
      case 'N':
      case 'L':
        return VMGType.tongueUp;
      case 'K':
      case 'G':
      case 'NG':
        return VMGType.tongueBack;
      case 'S':
      case 'Z':
      case 'SH':
      case 'ZH':
        return VMGType.teethClose;
      case 'A':
      case 'AE':
        return VMGType.mouthOpen;
      case 'AA':
        return VMGType.mouthOpenWide;
      case 'U':
      case 'UW':
      case 'OW':
        return VMGType.lipsRounded;
      // Sinhala
      case 'අ':
      case 'ආ':
        return VMGType.mouthOpenWide;
      case 'උ':
      case 'ඌ':
        return VMGType.lipsRounded;
      case 'ල':
      case 'ළ':
      case 'ත':
      case 'ද':
      case 'න':
        return VMGType.tongueUp;
      case 'ක':
      case 'ග':
        return VMGType.tongueBack;
      case 'ම':
      case 'බ':
      case 'ප':
        return VMGType.lipsTogether;
      case 'ව':
      case 'ෆ':
        return VMGType.teethLip;
      case 'ස':
      case 'ශ':
        return VMGType.teethClose;
      default:
        return VMGType.mouthOpen;
    }
  }

  @override
  State<VMGMouthWidget> createState() => _VMGMouthWidgetState();
}

// ─── State ────────────────────────────────────────────────────────────────────

class _VMGMouthWidgetState extends State<VMGMouthWidget>
    with TickerProviderStateMixin {
  late AnimationController _jawCtrl;
  late AnimationController _lipRoundCtrl;
  late AnimationController _tongueTipCtrl;
  late AnimationController _tongueBackCtrl;
  late AnimationController _tongueForwardCtrl;
  late AnimationController _lowerLipCtrl;

  // Idle breath pulse
  late AnimationController _idleCtrl;
  late Animation<double> _idlePulse;

  @override
  void initState() {
    super.initState();

    _jawCtrl = AnimationController(vsync: this, value: 0);
    _lipRoundCtrl = AnimationController(vsync: this, value: 0);
    _tongueTipCtrl = AnimationController(vsync: this, value: 0);
    _tongueBackCtrl = AnimationController(vsync: this, value: 0);
    _tongueForwardCtrl = AnimationController(vsync: this, value: 0);
    _lowerLipCtrl = AnimationController(vsync: this, value: 0);

    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _idlePulse = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut),
    );
    if (widget.animate) _idleCtrl.repeat(reverse: true);

    _animateToType(widget.vmgType, immediately: true);
  }

  @override
  void didUpdateWidget(VMGMouthWidget old) {
    super.didUpdateWidget(old);
    if (old.vmgType != widget.vmgType) _animateToType(widget.vmgType);
    if (widget.animate && !_idleCtrl.isAnimating) {
      _idleCtrl.repeat(reverse: true);
    }
    if (!widget.animate) _idleCtrl.stop();
  }

  @override
  void dispose() {
    _jawCtrl.dispose();
    _lipRoundCtrl.dispose();
    _tongueTipCtrl.dispose();
    _tongueBackCtrl.dispose();
    _tongueForwardCtrl.dispose();
    _lowerLipCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  void _animateToType(VMGType type, {bool immediately = false}) {
    final t = VMGMouthWidget.targetState(type);
    final dur = immediately ? Duration.zero : const Duration(milliseconds: 220);
    final curve = Curves.easeInOut;

    _jawCtrl.animateTo(t.jawOpenAmount,
        duration: dur, curve: curve);
    _lipRoundCtrl.animateTo(t.lipRoundAmount,
        duration: immediately ? Duration.zero : const Duration(milliseconds: 200),
        curve: curve);
    _tongueTipCtrl.animateTo(t.tongueTipRaise,
        duration: immediately ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeIn);
    _tongueBackCtrl.animateTo(t.tongueBackRaise,
        duration: immediately ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeIn);
    _tongueForwardCtrl.animateTo(t.tongueForward,
        duration: immediately ? Duration.zero : const Duration(milliseconds: 250),
        curve: curve);
    _lowerLipCtrl.animateTo(t.lowerLipUp,
        duration: immediately ? Duration.zero : const Duration(milliseconds: 150),
        curve: Curves.easeIn);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _jawCtrl,
        _lipRoundCtrl,
        _tongueTipCtrl,
        _tongueBackCtrl,
        _tongueForwardCtrl,
        _lowerLipCtrl,
        _idlePulse,
      ]),
      builder: (context, child) {
        final state = VMGAnimationState(
          jawOpenAmount: _jawCtrl.value,
          lipRoundAmount: _lipRoundCtrl.value,
          tongueTipRaise: _tongueTipCtrl.value,
          tongueBackRaise: _tongueBackCtrl.value,
          tongueForward: _tongueForwardCtrl.value,
          lowerLipUp: _lowerLipCtrl.value,
          teethVisible: VMGMouthWidget.targetState(widget.vmgType).teethVisible,
        );

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _MouthPainter(
              state: state,
              idlePulse: _idlePulse.value,
            ),
          ),
        );
      },
    );
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _MouthPainter extends CustomPainter {
  final VMGAnimationState state;
  final double idlePulse;

  _MouthPainter({required this.state, required this.idlePulse});

  // Small idle breathing offset
  double get _breathY => idlePulse * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + _breathY;

    _drawFace(canvas, size, cx, cy);
    _drawFaceDetails(canvas, cx, cy);
    _drawInnerMouth(canvas, cx, cy, size);
    if (state.jawOpenAmount > 0.08) {
      _drawUpperTeeth(canvas, cx, cy, size);
      _drawLowerTeeth(canvas, cx, cy, size);
      _drawTongue(canvas, cx, cy, size);
    }
    _drawLowerLip(canvas, cx, cy, size);
    _drawUpperLip(canvas, cx, cy, size);
    _drawLipLine(canvas, cx, cy, size);
  }

  // ── Face oval ───────────────────────────────────────────────────────────────

  void _drawFace(Canvas canvas, Size size, double cx, double cy) {
    final paint = Paint()
      ..color = const Color(0xFFF4C2A1)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFFD4956A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.86,
        height: size.height * 0.90);
    canvas.drawOval(rect, paint);
    canvas.drawOval(rect, stroke);
  }

  // ── Eyes, brows, nose hint ─────────────────────────────────────────────────

  void _drawFaceDetails(Canvas canvas, double cx, double cy) {
    final eyePaint = Paint()..color = const Color(0xFF3D2B1F);
    final shinePaint = Paint()..color = Colors.white;
    final browPaint = Paint()
      ..color = const Color(0xFF7B5138)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final nosePaint = Paint()
      ..color = const Color(0xFFD4956A)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Eyes
    final eyeY = cy - 32;
    for (final ex in [cx - 22.0, cx + 22.0]) {
      canvas.drawCircle(Offset(ex, eyeY), 5.5, eyePaint);
      canvas.drawCircle(Offset(ex + 1.5, eyeY - 1.5), 1.5, shinePaint);
    }

    // Eyebrows
    canvas.drawLine(Offset(cx - 30, eyeY - 11), Offset(cx - 13, eyeY - 9), browPaint);
    canvas.drawLine(Offset(cx + 13, eyeY - 9), Offset(cx + 30, eyeY - 11), browPaint);

    // Nose hint
    final nosePath = Path()
      ..moveTo(cx - 6, cy - 12)
      ..quadraticBezierTo(cx - 9, cy - 4, cx - 5, cy - 2)
      ..moveTo(cx + 6, cy - 12)
      ..quadraticBezierTo(cx + 9, cy - 4, cx + 5, cy - 2);
    canvas.drawPath(nosePath, nosePaint);
  }

  // ── Inner mouth darkness ───────────────────────────────────────────────────

  void _drawInnerMouth(Canvas canvas, double cx, double cy, Size size) {
    final jaw = state.jawOpenAmount;
    if (jaw < 0.01) return;

    final openH = jaw * size.height * 0.30;
    final openW = _mouthWidth(size) * (0.7 + jaw * 0.3);
    final mouthY = _mouthCenterY(cy, size);

    final paint = Paint()
      ..color = const Color(0xFF1A0A0A)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.addOval(
        Rect.fromCenter(center: Offset(cx, mouthY), width: openW, height: openH + 4));
    canvas.drawPath(path, paint);

    // Uvula hint when very wide open
    if (jaw > 0.65) {
      final uvulaPaint = Paint()
        ..color = const Color(0xFFCC4444)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, mouthY - openH / 2 + 6),
              width: 6,
              height: 10),
          uvulaPaint);
    }
  }

  // ── Upper teeth (8 teeth) ─────────────────────────────────────────────────

  void _drawUpperTeeth(Canvas canvas, double cx, double cy, Size size) {
    final jaw = state.jawOpenAmount;
    if (jaw < 0.08) return;

    final mouthY = _mouthCenterY(cy, size);
    final teethY = mouthY - (jaw * size.height * 0.14) - 7;
    final teethW = _mouthWidth(size) * 0.78;
    const count = 8;
    final toothW = teethW / count;
    final toothH = 12.0 + jaw * 4;

    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFFD8D8D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < count; i++) {
      final x = cx - teethW / 2 + i * toothW;
      final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 0.6, teethY, toothW - 1.2, toothH),
          const Radius.circular(2));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, border);
    }
  }

  // ── Lower teeth (6 teeth) ─────────────────────────────────────────────────

  void _drawLowerTeeth(Canvas canvas, double cx, double cy, Size size) {
    final jaw = state.jawOpenAmount;
    if (jaw < 0.08) return;

    final mouthY = _mouthCenterY(cy, size);
    final teethY = mouthY + (jaw * size.height * 0.12);
    final teethW = _mouthWidth(size) * 0.64;
    const count = 6;
    final toothW = teethW / count;
    const toothH = 10.0;

    final fill = Paint()
      ..color = const Color(0xFFF2F2F2)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFFD0D0D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < count; i++) {
      final x = cx - teethW / 2 + i * toothW;
      final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 0.6, teethY - toothH, toothW - 1.2, toothH),
          const Radius.circular(2));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, border);
    }
  }

  // ── Tongue ────────────────────────────────────────────────────────────────

  void _drawTongue(Canvas canvas, double cx, double cy, Size size) {
    final jaw = state.jawOpenAmount;
    if (jaw < 0.06) return;

    final mouthY = _mouthCenterY(cy, size);
    final forward = state.tongueForward;
    final tipRaise = state.tongueTipRaise;
    final backRaise = state.tongueBackRaise;

    final bodyPaint = Paint()
      ..color = const Color(0xFFD94040)
      ..style = PaintingStyle.fill;
    final tipPaint = Paint()
      ..color = const Color(0xFFE86060)
      ..style = PaintingStyle.fill;
    final midlinePaint = Paint()
      ..color = const Color(0xFFBB3030)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final tongueW = _mouthWidth(size) * 0.55;

    // Base Y: rests at bottom of mouth, rises with tip/back raise
    final baseY = mouthY + jaw * size.height * 0.08 - backRaise * 14;

    // Tongue body path
    final path = Path();
    final bodyH = 16.0 + backRaise * 10;
    final bodyLeft = cx - tongueW / 2;
    final bodyRight = cx + tongueW / 2;
    final bodyTop = baseY - bodyH / 2;
    final bodyBottom = baseY + bodyH / 2;

    path.moveTo(bodyLeft + 6, bodyBottom);
    path.quadraticBezierTo(cx, bodyBottom + 4, bodyRight - 6, bodyBottom);
    path.lineTo(bodyRight - 2, bodyTop);
    path.quadraticBezierTo(cx, bodyTop - (backRaise * 12), bodyLeft + 2, bodyTop);
    path.close();
    canvas.drawPath(path, bodyPaint);

    // Midline groove
    canvas.drawLine(Offset(cx, bodyTop + 2), Offset(cx, bodyBottom), midlinePaint);

    // Tongue tip
    final tipOffsetX = cx + forward * (tongueW / 2 - 4);
    final tipOffsetY = baseY - bodyH / 2 - tipRaise * 18 + forward * 4;

    final tipPath = Path();
    tipPath.addOval(Rect.fromCenter(
        center: Offset(tipOffsetX, tipOffsetY),
        width: tongueW * 0.42,
        height: 12 + tipRaise * 4));
    canvas.drawPath(tipPath, tipPaint);
  }

  // ── Upper lip (Cupid's bow) ────────────────────────────────────────────────

  void _drawUpperLip(Canvas canvas, double cx, double cy, Size size) {
    final round = state.lipRoundAmount;
    final jaw = state.jawOpenAmount;
    final mouthY = _mouthCenterY(cy, size);

    final lipW = _mouthWidth(size) * (0.5 - round * 0.15);
    final lipH = 10.0 + round * 4;
    final lipTop = mouthY - jaw * size.height * 0.14 - lipH;

    final paint = Paint()
      ..color = const Color(0xFFE8729A)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = const Color(0xFFBF4A72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final path = Path();
    if (round > 0.4) {
      // Rounded: simple arc
      path.addOval(Rect.fromCenter(
          center: Offset(cx, lipTop + lipH / 2),
          width: lipW * 2 * (1 - round * 0.3),
          height: lipH * 1.2));
    } else {
      // Cupid's bow
      path.moveTo(cx - lipW, lipTop + lipH);
      path.quadraticBezierTo(cx - lipW * 0.55, lipTop - 2, cx, lipTop + lipH * 0.3);
      path.quadraticBezierTo(cx + lipW * 0.55, lipTop - 2, cx + lipW, lipTop + lipH);
      path.quadraticBezierTo(cx, lipTop + lipH * 1.8, cx - lipW, lipTop + lipH);
      path.close();
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, outline);

    // Highlight
    final hlPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    final hlPath = Path();
    hlPath.addOval(Rect.fromCenter(
        center: Offset(cx, lipTop + lipH * 0.35),
        width: lipW * 0.9,
        height: lipH * 0.35));
    canvas.drawPath(hlPath, hlPaint);
  }

  // ── Lower lip ─────────────────────────────────────────────────────────────

  void _drawLowerLip(Canvas canvas, double cx, double cy, Size size) {
    final jaw = state.jawOpenAmount;
    final round = state.lipRoundAmount;
    final lipUp = state.lowerLipUp;
    final mouthY = _mouthCenterY(cy, size);

    final lipW = _mouthWidth(size) * (0.52 - round * 0.15);
    final lipH = (13.0 - lipUp * 6) * (1 - round * 0.2);
    // Lower lip moves down with jaw, or up for F/V
    final lipY = mouthY + jaw * size.height * 0.14 - lipUp * 10;

    final paint = Paint()
      ..color = const Color(0xFFE8729A)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = const Color(0xFFBF4A72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final path = Path();
    if (round > 0.4) {
      path.addOval(Rect.fromCenter(
          center: Offset(cx, lipY + lipH / 2),
          width: lipW * 2 * (1 - round * 0.3),
          height: lipH * 1.4));
    } else {
      path.moveTo(cx - lipW, lipY);
      path.quadraticBezierTo(cx, lipY + lipH * 1.4, cx + lipW, lipY);
      path.quadraticBezierTo(cx, lipY + lipH * 0.4, cx - lipW, lipY);
      path.close();
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, outline);

    // Highlight
    final hlPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final hlPath = Path();
    hlPath.addOval(Rect.fromCenter(
        center: Offset(cx, lipY + lipH * 0.5),
        width: lipW * 0.85,
        height: lipH * 0.35));
    canvas.drawPath(hlPath, hlPaint);
  }

  // ── Lip line (philtrum seam) ───────────────────────────────────────────────

  void _drawLipLine(Canvas canvas, double cx, double cy, Size size) {
    final jaw = state.jawOpenAmount;
    if (jaw > 0.12) return; // visible only when almost closed

    final mouthY = _mouthCenterY(cy, size);
    final lipW = _mouthWidth(size) * 0.48 * (1 - jaw * 2);

    final paint = Paint()
      ..color = const Color(0xFFC0392B).withValues(alpha: (1 - jaw * 6).clamp(0.0, 1.0))
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(cx - lipW, mouthY);
    path.quadraticBezierTo(cx, mouthY + 2, cx + lipW, mouthY);
    canvas.drawPath(path, paint);

    // Corner dimples
    final dimplePaint = Paint()
      ..color = const Color(0xFFD4956A).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - lipW - 1, mouthY), 2, dimplePaint);
    canvas.drawCircle(Offset(cx + lipW + 1, mouthY), 2, dimplePaint);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _mouthCenterY(double cy, Size size) => cy + size.height * 0.16;

  double _mouthWidth(Size size) => size.width * 0.48;

  @override
  bool shouldRepaint(_MouthPainter old) =>
      old.state.jawOpenAmount != state.jawOpenAmount ||
      old.state.lipRoundAmount != state.lipRoundAmount ||
      old.state.tongueTipRaise != state.tongueTipRaise ||
      old.state.tongueBackRaise != state.tongueBackRaise ||
      old.state.tongueForward != state.tongueForward ||
      old.state.lowerLipUp != state.lowerLipUp ||
      old.idlePulse != idlePulse;
}
