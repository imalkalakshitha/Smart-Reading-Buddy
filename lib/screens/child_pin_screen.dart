import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_colors.dart';
import '../models/app_state.dart';
import '../models/app_text.dart';
import '../models/local_storage.dart';
import '../router/app_router.dart';

const _avatarEmoji = {
  'owl': '🦉', 'tiger': '🐯', 'frog': '🐸',
  'fox': '🦊', 'panda': '🐼', 'lion': '🦁',
};

class ChildPinScreen extends StatefulWidget {
  final UserProfile profile;
  const ChildPinScreen({super.key, required this.profile});

  @override
  State<ChildPinScreen> createState() => _ChildPinScreenState();
}

class _ChildPinScreenState extends State<ChildPinScreen>
    with TickerProviderStateMixin {
  String _pin = '';
  bool _wrong = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _bounceCtrl;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
    _shakeCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _wrong = false);
        _shakeCtrl.reset();
      }
    });
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _bounceCtrl.forward();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    HapticFeedback.lightImpact();
    if (_pin.length >= 4) return;
    final next = _pin + d;
    setState(() => _pin = next);
    if (next.length == 4) _validate(next);
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_pin.isNotEmpty)
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _validate(String entered) async {
    if (entered == widget.profile.pin) {
      AppState.name = widget.profile.name;
      AppState.grade = widget.profile.grade;
      AppState.avatar = widget.profile.avatar;
      AppState.pin = widget.profile.pin;
      AppState.setLanguage(widget.profile.language);
      await LocalStorage.saveLanguage(widget.profile.language);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRouter.home, (r) => false);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _wrong = true;
        _pin = '';
      });
      _shakeCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _avatarEmoji[widget.profile.avatar] ?? '🦉';
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: CurvedAnimation(
                    parent: _bounceCtrl, curve: Curves.elasticOut),
                child: Text(emoji, style: const TextStyle(fontSize: 100)),
              ),
              const SizedBox(height: 16),
              Text(
                AppText.hiName(widget.profile.name),
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                AppText.enterPin,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ).animate(delay: 300.ms).fadeIn(),
              const SizedBox(height: 32),
              // PIN dots
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0), child: child),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _wrong
                            ? AppColors.wrong
                            : filled
                                ? AppColors.pinFilled
                                : AppColors.pinEmpty,
                        border: _wrong
                            ? null
                            : filled
                                ? null
                                : Border.all(
                                    color: AppColors.primaryLight, width: 1.5),
                      ),
                    );
                  }),
                ),
              ),
              if (_wrong) ...[
                const SizedBox(height: 12),
                Text(
                  AppText.wrongPin,
                  style: GoogleFonts.nunito(
                    color: AppColors.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().shakeX(amount: 4),
              ],
              const Spacer(),
              _NumPad(onDigit: _onDigit, onBackspace: _onBackspace),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Number pad ────────────────────────────────────────────────────────────────

class _NumPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _NumPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final k = keys[i];
        if (k.isEmpty) return const SizedBox();
        return _NumKey(
          label: k,
          onTap: k == '⌫' ? onBackspace : () => onDigit(k),
          isBackspace: k == '⌫',
        );
      },
    );
  }
}

class _NumKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isBackspace;

  const _NumKey(
      {required this.label, required this.onTap, this.isBackspace = false});

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween(begin: 1.0, end: 0.88).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _ctrl.forward();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        _ctrl.reverse();
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        _ctrl.reverse();
        setState(() => _pressed = false);
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.primary : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: widget.isBackspace
                ? Icon(Icons.backspace_outlined,
                    size: 28,
                    color: _pressed
                        ? Colors.white
                        : AppColors.textSecondary)
                : Text(
                    widget.label,
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _pressed ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
