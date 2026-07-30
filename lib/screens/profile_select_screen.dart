import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_colors.dart';
import '../models/app_text.dart';
import '../models/local_storage.dart';
import '../router/app_router.dart';

const _avatarMap = {
  'owl': '🦉', 'tiger': '🐯', 'frog': '🐸',
  'fox': '🦊', 'panda': '🐼', 'lion': '🦁',
};

class ProfileSelectScreen extends StatefulWidget {
  const ProfileSelectScreen({super.key});

  @override
  State<ProfileSelectScreen> createState() => _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends State<ProfileSelectScreen> {
  List<UserProfile> _profiles = [];
  bool _loading = true;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await LocalStorage.getAllProfiles();
    if (mounted) setState(() { _profiles = p; _loading = false; });
  }

  void _onProfileTap(UserProfile profile) {
    if (_editMode) {
      setState(() => _editMode = false);
      return;
    }
    Navigator.pushNamed(context, AppRouter.pin, arguments: profile);
  }

  void _onLongPress(UserProfile profile) {
    setState(() => _editMode = true);
    _showDeleteSheet(profile);
  }

  Future<void> _showDeleteSheet(UserProfile profile) async {
    final emoji = _avatarMap[profile.avatar] ?? '🦉';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeleteSheet(
        emoji: emoji,
        name: profile.name,
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      await LocalStorage.deleteProfile(profile.name);
      setState(() => _editMode = false);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppText.profileDeleted,
              style: GoogleFonts.nunito(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() => _editMode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Exit edit mode when tapping outside cards
      onTap: _editMode ? () => setState(() => _editMode = false) : null,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            AppText.whoIsLearning,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRouter.parentPin),
              child: Text(
                AppText.parent,
                style: GoogleFonts.nunito(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _profiles.isEmpty
                ? _EmptyState(onAdd: () async {
                    await Navigator.pushNamed(context, AppRouter.language,
                        arguments: true);
                    _load();
                  })
                : _ProfileGrid(
                    profiles: _profiles,
                    editMode: _editMode,
                    onTap: _onProfileTap,
                    onLongPress: _onLongPress,
                    onAdd: () async {
                      if (_editMode) {
                        setState(() => _editMode = false);
                        return;
                      }
                      await Navigator.pushNamed(
                          context, AppRouter.language,
                          arguments: true);
                      _load();
                    },
                  ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Text(
            AppText.version,
            textAlign: TextAlign.center,
            style:
                GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ── Delete bottom sheet ───────────────────────────────────────────────────────

class _DeleteSheet extends StatelessWidget {
  final String emoji;
  final String name;

  const _DeleteSheet({required this.emoji, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Avatar
              Text(emoji, style: const TextStyle(fontSize: 64))
                  .animate()
                  .scale(curve: Curves.elasticOut, duration: 500.ms),
              const SizedBox(height: 12),

              // Name
              Text(
                name,
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Warning text
              Text(
                AppText.deleteWarning(name),
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Buttons
              Row(
                children: [
                  // Cancel — outlined green
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        AppText.cancelBtn,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Delete — filled red
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: Text(
                        AppText.deleteConfirmBtn,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile grid ──────────────────────────────────────────────────────────────

class _ProfileGrid extends StatelessWidget {
  final List<UserProfile> profiles;
  final bool editMode;
  final void Function(UserProfile) onTap;
  final void Function(UserProfile) onLongPress;
  final VoidCallback onAdd;

  const _ProfileGrid({
    required this.profiles,
    required this.editMode,
    required this.onTap,
    required this.onLongPress,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final items = [...profiles, null]; // null = add card
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 160 / 185,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final delay = (i * 80).ms;
          if (items[i] == null) {
            return _AddCard(onTap: onAdd)
                .animate(delay: delay)
                .fadeIn()
                .slideY(begin: 0.3, curve: Curves.easeOut);
          }
          final profile = items[i]!;
          return _ProfileCard(
            profile: profile,
            editMode: editMode,
            onTap: () => onTap(profile),
            onLongPress: () => onLongPress(profile),
            onDeleteTap: () => onLongPress(profile),
          ).animate(delay: delay).fadeIn().slideY(begin: 0.3, curve: Curves.easeOut);
        },
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatefulWidget {
  final UserProfile profile;
  final bool editMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDeleteTap;

  const _ProfileCard({
    required this.profile,
    required this.editMode,
    required this.onTap,
    required this.onLongPress,
    required this.onDeleteTap,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard>
    with TickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late AnimationController _wobbleCtrl;
  late Animation<double> _scale;
  late Animation<double> _wobble;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _wobbleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _scale = Tween(begin: 1.0, end: 0.95).animate(_pressCtrl);
    _wobble =
        Tween(begin: -0.04, end: 0.04).animate(_wobbleCtrl);
  }

  @override
  void didUpdateWidget(_ProfileCard old) {
    super.didUpdateWidget(old);
    if (widget.editMode && !old.editMode) {
      _wobbleCtrl.repeat(reverse: true);
    } else if (!widget.editMode && old.editMode) {
      _wobbleCtrl.stop();
      _wobbleCtrl.reset();
    }
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _wobbleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _avatarMap[widget.profile.avatar] ?? '🦉';
    return GestureDetector(
      onTapDown: widget.editMode ? null : (_) => _pressCtrl.forward(),
      onTapUp: widget.editMode
          ? null
          : (_) {
              _pressCtrl.reverse();
              widget.onTap();
            },
      onTapCancel:
          widget.editMode ? null : () => _pressCtrl.reverse(),
      onTap: widget.editMode ? widget.onTap : null,
      onLongPress: widget.editMode ? null : widget.onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scale, _wobble]),
        builder: (_, child) => Transform.rotate(
          angle: widget.editMode ? _wobble.value : 0,
          child: Transform.scale(
              scale: _scale.value, child: child),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      widget.profile.name,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppText.gradeLabel(widget.profile.grade),
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Delete X icon — only visible in edit mode
            if (widget.editMode)
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: widget.onDeleteTap,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppColors.errorRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ).animate().scale(
                    curve: Curves.elasticOut, duration: 300.ms),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Add card ──────────────────────────────────────────────────────────────────

class _AddCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryLight,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 12),
            Text(
              AppText.addChild,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👨‍👩‍👧', style: TextStyle(fontSize: 80))
                .animate()
                .scale(curve: Curves.elasticOut, duration: 600.ms),
            const SizedBox(height: 24),
            Text(
              AppText.noProfilesYet,
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppText.addChildToStart,
              style: GoogleFonts.nunito(
                  fontSize: 17, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 220,
              height: 62,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  AppText.addChild,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
