import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/features/numbers/data/numbers_data.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/features/numbers/services/level_config.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/number_learning_screen.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/number_level_list_screen.dart';
import 'package:smart_reading_buddy/features/numbers/screens/number_word_session_screen.dart';
import 'package:smart_reading_buddy/features/numbers/screens/rapid_digit_naming_screen.dart';

/// Numbers — a shared, cross-module feature reached only from the Home
/// screen (AppRouter.numbers). ENGLISH ONLY. Sections: Pronunciation,
/// Number Learning, EduPlay + Encoding (Spell Number Words, Number Match)
/// and Reading (Read & Answer).
class NumbersHubScreen extends StatelessWidget {
  const NumbersHubScreen({super.key});

  static const _accent = Color(0xFFF39C12);
  static const _eduPlayColor = Color(0xFF7B61FF);
  static const _readingColor = Color(0xFF16A085);

  /// Opens one practice activity's level list (practice_activities.json).
  static Future<void> _openPractice(BuildContext context, String track, String title) async {
    final all = await LevelRepository.loadPractice();
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NumberLevelListScreen(
        grade: 0,
        track: track,
        levels: LevelRepository.forTrack(all, 0, track),
        trackUnlocked: true,
        title: title,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isSinhala = AppState.language == 'sinhala';
    const levelColors = [
      AppColors.pronunciation,
      AppColors.wordBuilding,
      AppColors.reading,
      AppColors.writing,
    ];

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: _accent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Numbers',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            if (isSinhala) ...[
              const EnglishOnlyNote(),
              const SizedBox(height: 16),
            ],
            // ── Pronunciation ──────────────────────────────────────────
            const _SectionHeader(
              emoji: '🎤',
              title: 'Pronunciation',
              color: AppColors.pronunciation,
            ).animate(delay: 50.ms).fadeIn(),
            const SizedBox(height: 8),
            const _SubHeading('Number Words').animate(delay: 70.ms).fadeIn(),
            const SizedBox(height: 10),
            for (var i = 0; i < NumbersData.levels.length; i++) ...[
              _NumbersCard(
                emoji: NumbersData.levels[i]['emoji'] as String,
                title: NumbersData.levels[i]['label'] as String,
                subtitle:
                    '${NumbersData.forLevel(NumbersData.levels[i]['key'] as String).length} numbers',
                stars: NumbersData.levels[i]['stars'] as int,
                accent: levelColors[i % levelColors.length],
                onTap: () {
                  final level = NumbersData.levels[i];
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => NumberWordSessionScreen(
                      levelKey: level['key'] as String,
                      levelName: level['label'] as String,
                    ),
                  ));
                },
              ).animate(delay: (100 + i * 70).ms).fadeIn().slideY(begin: 0.3),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 4),
            const _SubHeading('Speed game').animate(delay: 400.ms).fadeIn(),
            const SizedBox(height: 10),
            _NumbersCard(
              emoji: '⚡',
              title: 'Rapid Digit Naming',
              subtitle: 'Read 50 digits as fast as you can',
              stars: 3,
              accent: AppColors.primaryDark,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const RapidDigitNamingScreen(),
              )),
            ).animate(delay: 450.ms).fadeIn().slideY(begin: 0.3),

            // ── Number Learning ────────────────────────────────────────
            const SizedBox(height: 28),
            const _SectionHeader(
              emoji: '🧮',
              title: 'Number Learning',
              color: _accent,
            ).animate(delay: 470.ms).fadeIn(),
            const SizedBox(height: 10),
            _NumbersCard(
              emoji: '🎯',
              title: 'Number Learning',
              subtitle: 'Find, build, order and spot patterns',
              stars: 2,
              accent: _accent,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const NumberLearningScreen(),
              )),
            ).animate(delay: 490.ms).fadeIn().slideY(begin: 0.3),

            // ── EduPlay + Encoding ─────────────────────────────────────
            const SizedBox(height: 28),
            const _SectionHeader(
              emoji: '🎮',
              title: 'EduPlay + Encoding',
              color: _eduPlayColor,
            ).animate(delay: 500.ms).fadeIn(),
            const SizedBox(height: 10),
            _NumbersCard(
              emoji: '🔤',
              title: 'Spell Number Words',
              subtitle: 'Build the word with letter tiles',
              stars: 2,
              accent: _eduPlayColor,
              onTap: () => _openPractice(context, PracticeTrack.spellWords, 'Spell Number Words'),
            ).animate(delay: 520.ms).fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 14),
            _NumbersCard(
              emoji: '🃏',
              title: 'Number Match',
              subtitle: 'Match 7 ↔ seven ↔ 7 apples',
              stars: 2,
              accent: _eduPlayColor,
              onTap: () => _openPractice(context, PracticeTrack.numberMatch, 'Number Match'),
            ).animate(delay: 560.ms).fadeIn().slideY(begin: 0.3),

            // ── Reading ────────────────────────────────────────────────
            const SizedBox(height: 28),
            const _SectionHeader(
              emoji: '📖',
              title: 'Reading',
              color: _readingColor,
            ).animate(delay: 600.ms).fadeIn(),
            const SizedBox(height: 10),
            _NumbersCard(
              emoji: '🗣️',
              title: 'Read & Answer',
              subtitle: 'Listen, read along, answer',
              stars: 2,
              accent: _readingColor,
              onTap: () => _openPractice(context, PracticeTrack.readAnswer, 'Read & Answer'),
            ).animate(delay: 620.ms).fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final Color color;

  const _SectionHeader({required this.emoji, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SubHeading extends StatelessWidget {
  final String text;

  const _SubHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Short note shown when the app language is Sinhala — the Numbers
/// feature stays visible but is English only. Kept in English on purpose:
/// Sinhala text is never hand-typed in this project.
class EnglishOnlyNote extends StatelessWidget {
  const EnglishOnlyNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.reading.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.reading.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Text('🇬🇧', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'English only — say the numbers in English.',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumbersCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final int stars;
  final Color accent;
  final VoidCallback onTap;

  const _NumbersCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.stars,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider, width: 0.5),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                      stars,
                      (_) => const Text('⭐', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 20),
          ],
        ),
      ),
    );
  }
}
