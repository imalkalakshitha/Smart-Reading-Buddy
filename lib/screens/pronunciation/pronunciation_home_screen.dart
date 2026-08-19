import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/pronunciation_args.dart';
import '../../data/word_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../models/app_text.dart';
import '../../models/local_storage.dart';
import '../../router/app_router.dart';
import '../../services/practice_suggestion_service.dart';
import '../../widgets/level_progress_icon.dart';

// Same avatar → emoji mapping used at profile creation (create_profile_screen.dart)
// — reused here purely as a decorative mascot badge, no new image assets.
const _avatarEmoji = {
  'owl': '🦉', 'tiger': '🐯', 'frog': '🐸',
  'fox': '🦊', 'panda': '🐼', 'lion': '🦁',
};

class PronunciationHomeScreen extends StatefulWidget {
  const PronunciationHomeScreen({super.key});

  @override
  State<PronunciationHomeScreen> createState() => _PronunciationHomeScreenState();
}

class _PronunciationHomeScreenState extends State<PronunciationHomeScreen> {
  AssignedPractice? _assignedPractice;

  @override
  void initState() {
    super.initState();
    _loadAssignedPractice();
  }

  Future<void> _loadAssignedPractice() async {
    final assignment = await LocalStorage.getAssignedPractice(AppState.name);
    if (!mounted) return;
    setState(() => _assignedPractice = assignment);
  }

  void _startAssignedPractice() {
    final assignment = _assignedPractice;
    if (assignment == null) return;
    final words = PracticeSuggestionService.wordsForPhoneme(
      language: assignment.language,
      phoneme: assignment.phoneme,
    )..shuffle();
    if (words.isEmpty) return;
    Navigator.pushNamed(
      context,
      AppRouter.pronunciationSession,
      arguments: PronunciationSessionArgs(
        words: words,
        levelName: AppState.language == 'sinhala' ? 'විශේෂ අභ්‍යාසය' : 'Special Practice',
        levelKey: 'assigned_practice',
        isAssignedPractice: true,
        assignedPhoneme: assignment.phoneme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grade = AppState.grade;
    final levels = WordData.levels(grade);
    final isGrade4 = grade == 'grade4';

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pronunciation,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppText.pronunciation,
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.pronunciation.withOpacity(0.16),
                      AppColors.pronunciation.withOpacity(0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.pronunciation.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Text('🎤', style: TextStyle(fontSize: 48)),
                        Positioned(
                          bottom: -4,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Text(
                              _avatarEmoji[AppState.avatar] ?? '🦉',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppText.pronunciation,
                            style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppText.pronunciationDesc,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isGrade4 ? 'Grade 4' : 'Grade 3',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.pronunciation,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.2),

              if (_assignedPractice != null) ...[
                const SizedBox(height: 20),
                _AssignedPracticeBanner(
                  assignment: _assignedPractice!,
                  onTap: _startAssignedPractice,
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.2),
              ],

              const SizedBox(height: 28),
              Text(
                AppState.language == 'sinhala' ? 'මට්ටමක් තෝරන්න' : 'Choose a level',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ).animate(delay: 100.ms).fadeIn(),

              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: levels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final level = levels[i];
                    return _LevelCard(
                      level: level,
                      index: i,
                      onTap: () {
                        final words = WordData.forLevel(grade, level['key'] as String)
                          ..shuffle();
                        Navigator.pushNamed(
                          context,
                          AppRouter.pronunciationSession,
                          arguments: PronunciationSessionArgs(
                            words: words,
                            levelName: WordData.levelLabel(level),
                            levelKey: level['key'] as String,
                          ),
                        );
                      },
                    ).animate(delay: (150 + i * 80).ms)
                        .fadeIn()
                        .slideY(begin: 0.3)
                        .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Highlighted entry point shown only when a parent has assigned this
/// child a specific sound to practice (LocalStorage.getAssignedPractice).
/// Visually distinct from the regular level cards so it reads as a
/// special pick, not just another level.
class _AssignedPracticeBanner extends StatelessWidget {
  final AssignedPractice assignment;
  final VoidCallback onTap;

  const _AssignedPracticeBanner({required this.assignment, required this.onTap});

  String _displaySound() {
    if (assignment.language == 'si') {
      return PracticeSuggestionService.sinhalaScriptFor(assignment.phoneme) ??
          assignment.phoneme;
    }
    return assignment.phoneme.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isSinhala = AppState.language == 'sinhala';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            const Text('🌟', style: TextStyle(fontSize: 40))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.18, duration: 700.ms, curve: Curves.easeInOut),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSinhala ? 'ඔබ වෙනුවෙන් විශේෂ අභ්‍යාසයක්! 🌟' : 'Special practice picked for you! 🌟',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSinhala
                        ? "'${_displaySound()}' ශබ්දය පුහුණු කරන්න"
                        : "Practice the '${_displaySound()}' sound",
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    ).animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 2200.ms, delay: 600.ms, color: Colors.white.withOpacity(0.25));
  }
}

class _LevelCard extends StatefulWidget {
  final Map<String, dynamic> level;
  final int index;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.index,
    required this.onTap,
  });

  @override
  State<_LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<_LevelCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _shadowBlur;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(begin: 1.0, end: 0.96).animate(_ctrl);
    // Shadow softens/tightens on press, alongside the scale, for a more
    // tactile "pressed down" feel — purely visual, doesn't touch onTap.
    _shadowBlur = Tween(begin: 14.0, end: 6.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stars = widget.level['stars'] as int;
    final label = WordData.levelLabel(widget.level);
    final wordCount = WordData.forLevel(AppState.grade, widget.level['key'] as String).length;

    final colors = [
      AppColors.pronunciation,
      AppColors.wordBuilding,
      AppColors.reading,
      AppColors.writing,
    ];
    final accent = colors[widget.index % colors.length];

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: _shadowBlur.value,
                  offset: Offset(0, _shadowBlur.value * 0.4),
                ),
              ],
            ),
            child: child,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: LevelProgressIcon(levelIndex: widget.index, size: 36),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$wordCount ${AppState.language == 'sinhala' ? 'වචන' : 'words'}',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(
                        stars > 3 ? 3 : stars,
                        (_) => const Text('⭐', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: accent,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
