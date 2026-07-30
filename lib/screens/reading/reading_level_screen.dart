import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../router/app_router.dart';

class ReadingLevelScreen extends StatelessWidget {
  const ReadingLevelScreen({super.key});

  bool get _isSi => AppState.language == 'sinhala';
  String get _grade => AppState.grade.isNotEmpty ? AppState.grade : 'grade3';

  String get _gradeLabel {
    if (_isSi) return _grade == 'grade3' ? '3 ශ්‍රේණිය' : '4 ශ්‍රේණිය';
    return _grade == 'grade3' ? 'Grade 3' : 'Grade 4';
  }

  static const _levels = [
    _LevelInfo(
      level: 1,
      emoji: '😊',
      color: Color(0xFF2ECC71),
      titleEn: 'Short Sentences',
      titleSi: 'කෙටි වාක්‍ය',
      descEn: 'Simple, easy words to build confidence',
      descSi: 'සරල, පහසු වචන',
    ),
    _LevelInfo(
      level: 2,
      emoji: '📖',
      color: Color(0xFF3498DB),
      titleEn: 'Medium Sentences',
      titleSi: 'මධ්‍යම වාක්‍ය',
      descEn: 'A bit longer — keep going!',
      descSi: 'ටිකක් දිගු — දිගටම යන්න!',
    ),
    _LevelInfo(
      level: 3,
      emoji: '🎯',
      color: Color(0xFFF39C12),
      titleEn: 'Long Sentences',
      titleSi: 'දිගු වාක්‍ය',
      descEn: 'Coming soon — master Level 2 first!',
      descSi: 'ළඟදීම — Level 2 කරන්න!',
      locked: true,
    ),
  ];

  void _startLevel(BuildContext context, _LevelInfo info) {
    final sentences = getReadingSentences(_grade, info.level);
    Navigator.pushNamed(
      context,
      AppRouter.readingSession,
      arguments: ReadingSessionArgs(
        grade: _grade,
        level: info.level,
        levelName: '$_gradeLabel · ${_isSi ? info.titleSi : info.titleEn}',
        sentences: sentences,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.reading,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isSi ? 'කියවීම් පුහුණුව' : 'Reading Practice',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grade chip — informational, not a selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.reading.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: AppColors.reading.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_rounded,
                        color: AppColors.reading, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _gradeLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.reading,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 20),

              Text(
                _isSi ? 'මට්ටම තෝරන්න' : 'Choose your level',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 12),

              ...List.generate(_levels.length, (i) {
                final info = _levels[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _LevelCard(
                    info: info,
                    isSi: _isSi,
                    onTap: info.locked ? null : () => _startLevel(context, info),
                  ),
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 150 + i * 80))
                    .slideY(begin: 0.15, curve: Curves.easeOut);
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Level card ────────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final _LevelInfo info;
  final bool isSi;
  final VoidCallback? onTap;

  const _LevelCard({
    required this.info,
    required this.isSi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = info.locked;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: locked ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  locked ? '🔒' : info.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),

              const SizedBox(width: 14),

              // Text — Flexible so it never overflows
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isSi ? info.titleSi : info.titleEn,
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: locked
                                  ? AppColors.textHint
                                  : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!locked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: info.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isSi ? 'වාක්‍ය 15' : '15',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: info.color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSi ? info.descSi : info.descEn,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: locked ? AppColors.textHint : info.color,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _LevelInfo {
  final int level;
  final String emoji;
  final Color color;
  final String titleEn;
  final String titleSi;
  final String descEn;
  final String descSi;
  final bool locked;

  const _LevelInfo({
    required this.level,
    required this.emoji,
    required this.color,
    required this.titleEn,
    required this.titleSi,
    required this.descEn,
    required this.descSi,
    this.locked = false,
  });
}
