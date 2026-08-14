import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_colors.dart';
import '../models/app_state.dart';
import '../models/app_text.dart';
import '../models/local_storage.dart';
import 'parent/parent_dashboard_screen.dart';

const _parentPin = '1234';

class ParentPinScreen extends StatefulWidget {
  const ParentPinScreen({super.key});

  @override
  State<ParentPinScreen> createState() => _ParentPinScreenState();
}

class _ParentPinScreenState extends State<ParentPinScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _wrong = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

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
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
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
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _validate(String entered) async {
    if (entered == _parentPin) {
      // AppState.name is only set once a child's own PIN has been
      // validated (see child_pin_screen.dart) — this parent flow can be
      // reached without that ever happening (profile-select screen's
      // "Parent" button skips straight here), so it can't be trusted as
      // the child to show analytics for. Resolve explicitly instead.
      if (!mounted) return;
      final profileName = await _resolveProfileName();
      if (profileName == null || !mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentDashboardScreen(profileName: profileName),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _wrong = true;
        _pin = '';
      });
      _shakeCtrl.forward();
    }
  }

  /// Returns the child profile to show analytics for, or null if there's
  /// none to pick (caller should bail out without navigating).
  Future<String?> _resolveProfileName() async {
    if (AppState.name.isNotEmpty) return AppState.name;

    final profiles = await LocalStorage.getAllProfiles();
    if (!mounted) return null;

    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No child profiles yet')),
      );
      return null;
    }
    if (profiles.length == 1) return profiles.first.name;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              'View progress for which child?',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final p in profiles)
              ListTile(
                title: Text(p.name, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                subtitle: Text(p.grade),
                onTap: () => Navigator.of(context).pop(p.name),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          AppText.parent,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              const Text('👨‍👩‍👧', style: TextStyle(fontSize: 80))
                  .animate()
                  .scale(curve: Curves.elasticOut, duration: 600.ms),
              const SizedBox(height: 20),
              Text(
                AppText.parentDashboard,
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                AppText.enterPin,
                style: GoogleFonts.nunito(
                    fontSize: 16, color: AppColors.textSecondary),
              ).animate(delay: 250.ms).fadeIn(),
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
                        border: _wrong || filled
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
                    color: _pressed ? Colors.white : AppColors.textSecondary)
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

