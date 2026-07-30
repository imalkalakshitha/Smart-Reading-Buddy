import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/pronunciation_args.dart';
import '../../data/word_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../models/app_text.dart';
import '../../router/app_router.dart';

class PronunciationHomeScreen extends StatelessWidget {
  const PronunciationHomeScreen({super.key});

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
                  color: AppColors.pronunciation.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.pronunciation.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🎤', style: TextStyle(fontSize: 48)),
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
                    ).animate(delay: (150 + i * 80).ms).fadeIn().slideY(begin: 0.3);
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(begin: 1.0, end: 0.96).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stars = widget.level['stars'] as int;
    final emoji = widget.level['emoji'] as String;
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
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider, width: 0.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
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
                  child: Text(emoji, style: const TextStyle(fontSize: 32)),
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
