import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../data/writing_data.dart';
import '../../router/app_router.dart';
import '../../services/writing_session_logger.dart';

class WritingHomeScreen extends StatefulWidget {
  const WritingHomeScreen({super.key});
  @override
  State<WritingHomeScreen> createState() => _WritingHomeScreenState();
}

class _WritingHomeScreenState extends State<WritingHomeScreen> {
  String _language = AppState.language == 'sinhala' ? 'si' : 'en';
  int _grade = AppState.grade == 'grade4' ? 4 : 3;

  bool get _isSi => _language == 'si';

  void _toggleLanguage() => setState(() => _language = _isSi ? 'en' : 'si');

  Future<void> _goLetter() async {
    final mastery =
        await WritingSessionLogger.getLetterMastery(0, _language);
    if (!mounted) return;
    final levels = letterLevels[_language] ?? [];

    // Determine which levels are unlocked
    final unlocked = <int>{0};
    for (int i = 1; i < levels.length; i++) {
      final prev = levels[i - 1];
      final allMastered = prev.every((letter) {
        final m = mastery.firstWhere(
          (m) => m.letter == letter,
          orElse: () => const LetterMastery(
            letter: '',
            averageAccuracy: 0,
            sessionCount: 0,
            avgAttemptsToPass: 1,
            avgCompletionSecs: 0,
          ),
        );
        return m.averageAccuracy >= 70 && m.sessionCount >= 3;
      });
      if (allMastered) {
        unlocked.add(i);
      } else {
        break;
      }
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _LevelPickerSheet(
        language: _language,
        grade: _grade,
        levels: levels,
        mastery: mastery,
        unlockedLevels: unlocked,
        isSi: _isSi,
      ),
    );
  }

  void _goWord() => Navigator.pushNamed(
        context,
        AppRouter.writingWord,
        arguments: WritingArgs(language: _language, grade: _grade, profileId: 0),
      );

  void _goProgress() => Navigator.pushNamed(
        context,
        AppRouter.writingProgress,
        arguments: WritingArgs(language: _language, grade: _grade, profileId: 0),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.writing,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isSi ? 'ලිවීම් පුහුණුව' : 'Writing Practice',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white),
        ),
        actions: [
          // Language toggle
          GestureDetector(
            onTap: _toggleLanguage,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: Text(
                _isSi ? 'EN' : 'සිං',
                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            onPressed: _goProgress,
            tooltip: _isSi ? 'ප්‍රගතිය' : 'Progress',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grade selector
                _GradeSelector(
                  selected: _grade,
                  isSi: _isSi,
                  onChanged: (g) => setState(() => _grade = g),
                ).animate().fadeIn(delay: 50.ms).slideY(begin: -0.2),

                const SizedBox(height: 28),

                Text(
                  _isSi ? 'අභ්‍යාස වර්ගය තෝරන්න' : 'Choose Practice Type',
                  style: GoogleFonts.nunito(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 16),

                // Letter Tracing card
                _PracticeCard(
                  icon: '🔤',
                  title: _isSi ? 'අකුරු ලිවීම' : 'Letter Tracing',
                  subtitle: _isSi
                      ? 'ඇඟිලිෙයන් අකුරු ලියන්න'
                      : 'Trace individual letters with your finger',
                  gradientColors: const [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                  onTap: _goLetter,
                  delay: 150,
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.3, curve: Curves.easeOut),

                const SizedBox(height: 16),

                // Word Tracing card
                _PracticeCard(
                  icon: '📝',
                  title: _isSi ? 'වචන ලිවීම' : 'Word Tracing',
                  subtitle: _isSi
                      ? 'සම්පූර්ණ වචන ලිවීමට උත්සාහ කරන්න'
                      : 'Trace full words letter by letter',
                  gradientColors: const [Color(0xFF6C3483), Color(0xFF9B59B6)],
                  onTap: _goWord,
                  delay: 250,
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.3, curve: Curves.easeOut),

                const SizedBox(height: 32),

                // Tips card
                _TipsCard(isSi: _isSi)
                    .animate().fadeIn(delay: 350.ms),
              ],
            ),
          ),

          // Buddy mascot bottom-right
          Positioned(
            bottom: 24,
            right: 16,
            child: _BuddyBubble(isSi: _isSi)
                .animate().fadeIn(delay: 500.ms).slideX(begin: 0.4),
          ),
        ],
      ),
    );
  }
}

// ── Grade selector ────────────────────────────────────────────────────────────

class _GradeSelector extends StatelessWidget {
  final int selected;
  final bool isSi;
  final ValueChanged<int> onChanged;
  const _GradeSelector({required this.selected, required this.isSi, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [3, 4].map((g) {
          final sel = selected == g;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  color: sel ? AppColors.writing : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    isSi ? 'ශ්‍රේණිය $g' : 'Grade $g',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: sel ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Practice card ─────────────────────────────────────────────────────────────

class _PracticeCard extends StatefulWidget {
  final String icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final int delay;
  const _PracticeCard({
    required this.icon, required this.title, required this.subtitle,
    required this.gradientColors, required this.onTap, required this.delay,
  });
  @override
  State<_PracticeCard> createState() => _PracticeCardState();
}

class _PracticeCardState extends State<_PracticeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: widget.gradientColors[0].withOpacity(0.38), blurRadius: 16, offset: const Offset(0, 7))],
          ),
          child: Row(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(18)),
                child: Center(child: Text(widget.icon, style: const TextStyle(fontSize: 32))),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(widget.subtitle, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.85)), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Start →', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tips card ─────────────────────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  final bool isSi;
  const _TipsCard({required this.isSi});

  @override
  Widget build(BuildContext context) {
    final tips = isSi
        ? ['천천히 ලියන්න', 'ලප රේඛා අනුගමනය කරන්න', 'ඔබේ ඇඟිලිය දියාරු නොකරන්න']
        : ['Trace slowly and carefully', 'Follow the dotted guide lines', 'Lift your finger between strokes'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isSi ? '💡 ඉඟි' : '💡 Tips', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.writing)),
          const SizedBox(height: 10),
          ...tips.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.writing, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Level picker bottom sheet ─────────────────────────────────────────────────

class _LevelPickerSheet extends StatelessWidget {
  final String language;
  final int grade;
  final List<List<String>> levels;
  final List<LetterMastery> mastery;
  final Set<int> unlockedLevels;
  final bool isSi;

  const _LevelPickerSheet({
    required this.language,
    required this.grade,
    required this.levels,
    required this.mastery,
    required this.unlockedLevels,
    required this.isSi,
  });

  int _masteredInLevel(List<String> letters) => letters.where((letter) {
        final m = mastery.firstWhere(
          (m) => m.letter == letter,
          orElse: () => const LetterMastery(
            letter: '',
            averageAccuracy: 0,
            sessionCount: 0,
            avgAttemptsToPass: 1,
            avgCompletionSecs: 0,
          ),
        );
        return m.averageAccuracy >= 70 && m.sessionCount >= 3;
      }).length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSi ? 'මට්ටමක් තෝරන්න' : 'Choose a Level',
              style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              isSi
                  ? 'පෙර මට්ටම ප්‍රාවීණ කළ පසු ඊළඟ මට්ටම අගුළු ඇරේ'
                  : 'Complete a level to unlock the next one',
              style: GoogleFonts.nunito(
                  fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...levels.asMap().entries.map((entry) {
              final idx = entry.key;
              final letters = entry.value;
              final unlocked = unlockedLevels.contains(idx);
              final mastered = _masteredInLevel(letters);
              final allDone = mastered == letters.length;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    if (!unlocked) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                          isSi
                              ? 'පෙර මට්ටම ප්‍රාවීණ කරන්න!'
                              : 'Complete Level $idx first!',
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700),
                        ),
                        backgroundColor: AppColors.writing,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ));
                      return;
                    }
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      AppRouter.writingLetter,
                      arguments: WritingArgs(
                        language: language,
                        grade: grade,
                        profileId: 0,
                        levelLetters: letters,
                        levelNumber: idx + 1,
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: unlocked
                          ? (allDone
                              ? AppColors.success.withOpacity(0.08)
                              : AppColors.writing.withOpacity(0.07))
                          : AppColors.divider.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: unlocked
                            ? (allDone
                                ? AppColors.success.withOpacity(0.4)
                                : AppColors.writing.withOpacity(0.35))
                            : AppColors.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          allDone ? '✅' : (unlocked ? '🔓' : '🔒'),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSi
                                    ? 'මට්ටම ${idx + 1}'
                                    : 'Level ${idx + 1}',
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: unlocked
                                      ? AppColors.textPrimary
                                      : AppColors.textHint,
                                ),
                              ),
                              Text(
                                letters.join(' · '),
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$mastered/${letters.length}',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: allDone
                                ? AppColors.success
                                : AppColors.writing,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: unlocked
                              ? AppColors.writing
                              : AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Buddy bubble ──────────────────────────────────────────────────────────────

class _BuddyBubble extends StatelessWidget {
  final bool isSi;
  const _BuddyBubble({required this.isSi});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16),
            ),
            boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Text(
            isSi ? 'ලිවීම් පුහුණු කරමු! ✏️' : "Let's practice writing! ✏️",
            style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: AppColors.writing, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.writing.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
          child: const Center(child: Text('🦉', style: TextStyle(fontSize: 28))),
        ),
      ],
    );
  }
}
