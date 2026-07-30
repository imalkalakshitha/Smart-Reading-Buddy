import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_colors.dart';
import '../models/app_state.dart';
import '../models/app_text.dart';
import '../models/local_storage.dart';
import '../router/app_router.dart';

const _avatars = ['owl', 'tiger', 'frog', 'fox', 'panda', 'lion'];
const _avatarEmoji = {
  'owl': '🦉', 'tiger': '🐯', 'frog': '🐸',
  'fox': '🦊', 'panda': '🐼', 'lion': '🦁',
};

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  String _avatar = 'owl';
  final _nameCtrl = TextEditingController();
  String _grade = 'grade3';
  String _pin = '';
  String _confirmPin = '';
  bool _pinStep = false; // false = first entry, true = confirm
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onNumPad(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      if (!_pinStep) {
        if (_pin.length < 4) _pin += digit;
        if (_pin.length == 4) _pinStep = true;
      } else {
        if (_confirmPin.length < 4) _confirmPin += digit;
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      if (_pinStep) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _pinStep = false;
        }
      } else {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _onSave() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _pin.length < 4 || _confirmPin.length < 4) {
      setState(() => _error = AppText.fillAllFields);
      return;
    }
    if (_pin != _confirmPin) {
      setState(() {
        _error = AppText.pinMismatch;
        _confirmPin = '';
        _pinStep = false;
      });
      return;
    }
    AppState.name = name;
    AppState.grade = _grade;
    AppState.avatar = _avatar;
    AppState.pin = _pin;
    await LocalStorage.saveProfile();
    if (!mounted) return;
    // Voice setup (calibration) step skipped — go straight to what it
    // used to hand off to.
    Navigator.pushNamedAndRemoveUntil(
        context, AppRouter.home, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          AppText.newProfile,
          style: GoogleFonts.nunito(
              fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar picker
              _SectionLabel(AppText.pickAvatar),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _avatars.length,
                  itemBuilder: (_, i) {
                    final a = _avatars[i];
                    final selected = _avatar == a;
                    return GestureDetector(
                      onTap: () => setState(() => _avatar = a),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 12),
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? AppColors.primarySurface : AppColors.cardBg,
                          border: Border.all(
                            color: selected ? AppColors.primary : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: selected
                              ? [BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 10)]
                              : [],
                        ),
                        child: Center(
                          child: AnimatedScale(
                            scale: selected ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Text(_avatarEmoji[a]!,
                                style: const TextStyle(fontSize: 44)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 24),

              // Name field
              _SectionLabel(AppText.yourName),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                autocorrect: false,
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: AppText.yourNameHint,
                  hintStyle: GoogleFonts.nunito(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 24),

              // Grade
              _SectionLabel(AppText.yourGrade),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _GradeToggle(
                      label: AppText.grade3,
                      selected: _grade == 'grade3',
                      onTap: () => setState(() => _grade = 'grade3'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _GradeToggle(
                      label: AppText.grade4,
                      selected: _grade == 'grade4',
                      onTap: () => setState(() => _grade = 'grade4'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 28),

              // PIN entry
              _SectionLabel(
                _pinStep ? AppText.confirmPin : AppText.createPin,
              ),
              const SizedBox(height: 16),
              _PinDots(
                length: _pinStep ? _confirmPin.length : _pin.length,
              ).animate().fadeIn(delay: 250.ms),
              const SizedBox(height: 20),
              if (_error != null)
                Center(
                  child: Text(
                    _error!,
                    style: GoogleFonts.nunito(
                        color: AppColors.danger,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 8),
              _NumPad(onDigit: _onNumPad, onBackspace: _onBackspace),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 62,
                child: ElevatedButton(
                  onPressed: (_pin.length == 4 && _confirmPin.length == 4)
                      ? _onSave
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                  ),
                  child: Text(
                    AppText.createProfile,
                    style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      );
}

class _GradeToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GradeToggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 62,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.primaryLight,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int length;
  const _PinDots({required this.length});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.pinFilled : AppColors.pinEmpty,
            border: filled ? null : Border.all(color: AppColors.primaryLight, width: 1.5),
          ),
        );
      }),
    );
  }
}

class _NumPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _NumPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final keys = ['1','2','3','4','5','6','7','8','9','','0','⌫'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
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

  const _NumKey({required this.label, required this.onTap, this.isBackspace = false});

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween(begin: 1.0, end: 0.88).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Center(
            child: widget.isBackspace
                ? const Icon(Icons.backspace_outlined,
                    size: 28, color: AppColors.textSecondary)
                : Text(
                    widget.label,
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
