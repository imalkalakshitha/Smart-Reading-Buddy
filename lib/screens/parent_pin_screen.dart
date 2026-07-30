import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_colors.dart';
import '../models/app_state.dart';
import '../models/app_text.dart';
import 'parent/pepa_dashboard_screen.dart';
import 'parent/writing_progress_dashboard_screen.dart';
import 'parent/wb_dashboard_screen.dart';

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

  void _validate(String entered) {
    if (entered == _parentPin) {
      if (!mounted) return;
      Navigator.pop(context);
      _showParentDashboard();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _wrong = true;
        _pin = '';
      });
      _shakeCtrl.forward();
    }
  }

  void _showParentDashboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ParentDashboard(),
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

// ── Parent dashboard sheet ────────────────────────────────────────────────────

class _ParentDashboard extends StatelessWidget {
  const _ParentDashboard();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.swap_horiz_rounded, AppText.switchProfile),
      (Icons.language_rounded, AppText.changeLanguage),
      (Icons.multitrack_audio_rounded, AppText.parentDashboard),
      (Icons.edit_rounded, 'Writing Progress'),
      (Icons.auto_stories_rounded, 'Word Building Journey'),
      (Icons.settings_rounded, AppText.settings),
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
            const SizedBox(height: 8),
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
                            color: AppColors.primary, size: 22),
                      ),
                      title: Text(
                        item.$2,
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        final nav = Navigator.of(context);
                        nav.pop();
                        if (i == 2) {
                          nav.push(MaterialPageRoute(
                            builder: (_) => PEPADashboardScreen(
                              profileName: AppState.name,
                            ),
                          ));
                        } else if (i == 3) {
                          nav.push(MaterialPageRoute(
                            builder: (_) => const WritingProgressDashboard(),
                          ));
                        } else if (i == 4) {
                          nav.push(MaterialPageRoute(
                            builder: (_) => const WBDashboardScreen(),
                          ));
                        }
                      },
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
