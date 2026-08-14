import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/pronunciation_args.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../models/app_text.dart';
import '../../models/local_storage.dart';
import '../../router/app_router.dart';

class SessionCompleteScreen extends StatefulWidget {
  final SessionCompleteArgs args;

  const SessionCompleteScreen({super.key, required this.args});

  @override
  State<SessionCompleteScreen> createState() => _SessionCompleteScreenState();
}

class _SessionCompleteScreenState extends State<SessionCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    // Special assigned-practice sessions clear their flag on completion so
    // the home screen banner doesn't reappear until the parent assigns a
    // new one. Regular sessions never set this flag, so this is a no-op
    // for the existing flow.
    if (widget.args.isAssignedPractice) {
      LocalStorage.clearAssignedPractice(AppState.name);
    }
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  int get _total => widget.args.correct + widget.args.almost + widget.args.wrong;
  double get _accuracy => _total == 0 ? 0 : (widget.args.correct + widget.args.almost * 0.5) / _total;

  String get _grade {
    if (_accuracy >= 0.85) return 'A';
    if (_accuracy >= 0.70) return 'B';
    if (_accuracy >= 0.50) return 'C';
    return 'D';
  }

  String get _gradeEmoji {
    if (_accuracy >= 0.85) return '🏆';
    if (_accuracy >= 0.70) return '🌟';
    if (_accuracy >= 0.50) return '👍';
    return '💪';
  }

  Color get _gradeColor {
    if (_accuracy >= 0.85) return AppColors.pronunciation;
    if (_accuracy >= 0.70) return AppColors.wordBuilding;
    if (_accuracy >= 0.50) return AppColors.reading;
    return AppColors.writing;
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Stack(
          children: [
            _buildConfetti(),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Trophy
                  Text(
                    _gradeEmoji,
                    style: const TextStyle(fontSize: 88),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.3, 0.3),
                        curve: Curves.elasticOut,
                        duration: 800.ms,
                      )
                      .fadeIn(),

                  const SizedBox(height: 12),
                  Text(
                    AppState.language == 'sinhala' ? 'අපූරුයි!' : 'Well Done!',
                    style: GoogleFonts.nunito(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3),

                  Text(
                    args.levelName,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ).animate(delay: 400.ms).fadeIn(),

                  const SizedBox(height: 28),

                  // Grade circle
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: _gradeColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: _gradeColor, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        _grade,
                        style: GoogleFonts.nunito(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: _gradeColor,
                        ),
                      ),
                    ),
                  ).animate(delay: 500.ms).fadeIn().scale(begin: const Offset(0.6, 0.6)),

                  const SizedBox(height: 24),

                  // Stats card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _StatChip(
                              emoji: '✅',
                              label: AppState.language == 'sinhala' ? 'නිවැරදි' : 'Correct',
                              value: '${args.correct}',
                              color: AppColors.success,
                            ),
                            _StatChip(
                              emoji: '👍',
                              label: AppState.language == 'sinhala' ? 'ආසන්න' : 'Almost',
                              value: '${args.almost}',
                              color: AppColors.almost,
                            ),
                            _StatChip(
                              emoji: '❌',
                              label: AppState.language == 'sinhala' ? 'වැරදි' : 'Wrong',
                              value: '${args.wrong}',
                              color: AppColors.wrong,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppColors.divider),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _InfoTile(
                              icon: '⭐',
                              label: 'XP',
                              value: '+${args.xpEarned}',
                            ),
                            _InfoTile(
                              icon: '⏱️',
                              label: AppState.language == 'sinhala' ? 'කාලය' : 'Time',
                              value: _formatDuration(args.durationSeconds),
                            ),
                            _InfoTile(
                              icon: '🎯',
                              label: AppState.language == 'sinhala' ? 'නිරවද්‍යතා' : 'Accuracy',
                              value: '${(_accuracy * 100).round()}%',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.2),

                  // PEPA hard phonemes
                  if (args.hardPhonemes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.wrong.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppState.language == 'sinhala'
                                ? '💡 වැඩිදියුණු කළ හැකි ශබ්ද:'
                                : '💡 Phonemes to practice:',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.wrong,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: args.hardPhonemes.map((p) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.wrong.withOpacity(0.4)),
                              ),
                              child: Text(
                                '/$p/',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.wrong,
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                    ).animate(delay: 700.ms).fadeIn(),
                  ],

                  const SizedBox(height: 32),

                  // Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context), // back to pronunciation home
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pronunciation,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        AppState.language == 'sinhala'
                            ? 'නැවත කරන්න 🔄'
                            : 'Practice Again 🔄',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ).animate(delay: 800.ms).fadeIn().slideY(begin: 0.2),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRouter.home,
                        (r) => false,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.pronunciation, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        AppText.home,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.pronunciation,
                        ),
                      ),
                    ),
                  ).animate(delay: 900.ms).fadeIn().slideY(begin: 0.2),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfetti() {
    return AnimatedBuilder(
      animation: _confettiCtrl,
      builder: (context, _) {
        if (_confettiCtrl.value > 0.8) return const SizedBox.shrink();
        final rng = Random(42);
        return Stack(
          children: List.generate(18, (i) {
            final x = rng.nextDouble();
            final delay = rng.nextDouble() * 0.4;
            final progress = (_confettiCtrl.value - delay).clamp(0.0, 1.0);
            final colors = [
              AppColors.pronunciation,
              AppColors.wordBuilding,
              AppColors.reading,
              AppColors.writing,
            ];
            return Positioned(
              left: MediaQuery.of(context).size.width * x,
              top: MediaQuery.of(context).size.height * progress * 0.7,
              child: Opacity(
                opacity: (1 - progress).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: progress * 6.28,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
