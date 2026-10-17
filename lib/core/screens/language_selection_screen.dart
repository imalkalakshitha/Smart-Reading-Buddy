import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/core/models/local_storage.dart';
import 'package:smart_reading_buddy/core/router/app_router.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selected;

  Future<void> _onContinue() async {
    if (_selected == null) return;
    AppState.setLanguage(_selected!);
    await LocalStorage.saveLanguage(_selected!);
    if (!mounted) return;

    // Reached via the "Add Child" button (profile_select_screen) with
    // arguments: true → this pick is for the NEW profile about to be
    // created, so go straight into profile creation with it.
    // Reached via splash (first-ever launch) or the "Change Language"
    // menu item on an existing profile's home screen → no arguments →
    // keep the original behaviour of landing on the profile list.
    final forNewProfile = ModalRoute.of(context)?.settings.arguments == true;
    Navigator.pushReplacementNamed(
      context,
      forNewProfile ? AppRouter.createProfile : AppRouter.profiles,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              // Mascot
              const Text('🦉', style: TextStyle(fontSize: 120))
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut, duration: 700.ms),
              const SizedBox(height: 16),
              // Title
              Text(
                'Smart Reading Buddy',
                style: GoogleFonts.nunito(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3),
              const SizedBox(height: 8),
              Text(
                'Choose your language / භාෂාව තෝරන්න',
                style: GoogleFonts.nunito(fontSize: 16, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ).animate(delay: 300.ms).fadeIn(),
              const SizedBox(height: 32),
              // Language cards
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LanguageCard(
                    flag: '🇱🇰',
                    primary: 'සිංහල',
                    secondary: 'Sinhala',
                    value: 'sinhala',
                    selected: _selected == 'sinhala',
                    onTap: () => setState(() => _selected = 'sinhala'),
                  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.5, curve: Curves.easeOut),
                  const SizedBox(width: 20),
                  _LanguageCard(
                    flag: '🇬🇧',
                    primary: 'English',
                    secondary: 'ඉංග්‍රීසි',
                    value: 'english',
                    selected: _selected == 'english',
                    onTap: () => setState(() => _selected = 'english'),
                  ).animate(delay: 550.ms).fadeIn().slideY(begin: 0.5, curve: Curves.easeOut),
                ],
              ),
              const Spacer(),
              // Continue button
              AnimatedOpacity(
                opacity: _selected != null ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: _GreenButton(
                  label: 'Continue →',
                  onTap: _selected != null ? _onContinue : null,
                ),
              ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.3),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatefulWidget {
  final String flag;
  final String primary;
  final String secondary;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.flag,
    required this.primary,
    required this.secondary,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.95).animate(_ctrl);
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
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 160,
          // FIX: minHeight constraint instead of fixed height — lets card
          // grow on devices with large text scaling, never clips content
          constraints: const BoxConstraints(minHeight: 180),
          decoration: BoxDecoration(
            color: widget.selected ? AppColors.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected ? AppColors.primary : AppColors.divider,
              width: widget.selected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.selected
                    ? AppColors.primary.withOpacity(0.25)
                    : Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // FIX: padding-based layout — Column stays mainAxisSize.min
          // so it never fights a fixed height constraint
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FIX: reduced from 60 → 48px so emoji fits on small screens
                Text(widget.flag, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                Text(
                  widget.primary,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.secondary,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: widget.selected ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _GreenButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 62,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.primary : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(30),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
