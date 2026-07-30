import 'dart:math' show pi, sin, cos;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../router/app_router.dart';

class ReadingSessionCompleteScreen extends StatelessWidget {
  final ReadingCompleteArgs args;
  const ReadingSessionCompleteScreen({super.key, required this.args});

  bool get _isSi => AppState.language == 'sinhala';

  // ── Derived stats ──────────────────────────────────────────────────────────

  int get _totalSentences => args.results.length;

  int get _totalWords => args.results.fold(
        0,
        (s, r) => s + r.sentence.split(' ').length,
      );

  int get _totalMs =>
      args.results.fold(0, (s, r) => s + r.timeTakenMs);

  int get _avgMs =>
      _totalSentences > 0 ? _totalMs ~/ _totalSentences : 0;

  int get _fastestMs => args.results.isEmpty
      ? 0
      : args.results.map((r) => r.timeTakenMs).reduce((a, b) => a < b ? a : b);

  int get _buddyTotal =>
      args.results.fold(0, (s, r) => s + r.buddyPromptsCount);

  double get _wpm =>
      _totalMs > 0 ? (_totalWords / _totalMs) * 60000 : 0;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Celebration stars burst
              _buildCelebration(),

              const SizedBox(height: 8),

              // Title
              Text(
                _isSi ? 'ජය ගත්තා! 🎉' : 'Session Complete! 🎉',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

              const SizedBox(height: 4),

              Text(
                args.levelName,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 24),

              // WPM highlight card
              _WpmCard(wpm: _wpm, isSi: _isSi)
                  .animate()
                  .fadeIn(delay: 550.ms)
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 16),

              // Stats grid
              _buildStatsGrid(context)
                  .animate()
                  .fadeIn(delay: 650.ms)
                  .slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Sentence breakdown
              _buildBreakdown()
                  .animate()
                  .fadeIn(delay: 750.ms),

              const SizedBox(height: 32),

              // Action buttons
              _buildButtons(context)
                  .animate()
                  .fadeIn(delay: 850.ms)
                  .slideY(begin: 0.1),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Celebration ────────────────────────────────────────────────────────────

  Widget _buildCelebration() {
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring of stars
          ...List.generate(8, (i) {
            final angle = (i / 8) * 2 * pi;
            final r = 46.0 + (i % 2) * 12;
            return Positioned(
              left: 60 + r * (0.9 + 0.1 * sin(angle)),
              top: 30 + r * (0.5 + 0.5 * cos(angle)),
              child: Text(
                ['⭐', '✨', '🌟', '💫'][i % 4],
                style: TextStyle(fontSize: 14 + (i % 3) * 4.0),
              )
                  .animate(delay: Duration(milliseconds: 100 + i * 80))
                  .scale(
                    begin: const Offset(0, 0),
                    curve: Curves.elasticOut,
                    duration: 600.ms,
                  )
                  .fadeIn(),
            );
          }),

          // Central trophy
          Text('🏆', style: const TextStyle(fontSize: 64))
              .animate()
              .scale(
                begin: const Offset(0.3, 0.3),
                curve: Curves.elasticOut,
                duration: 700.ms,
              )
              .fadeIn(),
        ],
      ),
    );
  }

  // ── Stats grid ─────────────────────────────────────────────────────────────

  Widget _buildStatsGrid(BuildContext context) {
    String ms2s(int ms) => '${(ms / 1000).toStringAsFixed(1)}s';
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatTile(
          label: _isSi ? 'මුළු වාක්‍ය' : 'Total Sentences',
          value: '$_totalSentences',
          icon: Icons.format_list_numbered_rounded,
          color: AppColors.reading,
        ),
        _StatTile(
          label: _isSi ? 'සාමාන්‍ය කාලය' : 'Avg Time',
          value: ms2s(_avgMs),
          icon: Icons.timer_outlined,
          color: AppColors.primary,
        ),
        _StatTile(
          label: _isSi ? 'වේගම කාලය' : 'Fastest',
          value: ms2s(_fastestMs),
          icon: Icons.flash_on_rounded,
          color: const Color(0xFFF39C12),
        ),
        _StatTile(
          label: _isSi ? 'බඩී ඉඟි' : 'Buddy Prompts',
          value: '$_buddyTotal',
          icon: Icons.bluetooth_rounded,
          color: const Color(0xFF9B59B6),
        ),
      ],
    );
  }

  // ── Sentence breakdown ─────────────────────────────────────────────────────

  Widget _buildBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSi ? 'වාක්‍ය සාරාංශය' : 'Sentence Breakdown',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...args.results.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            final secs = (r.timeTakenMs / 1000).toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: r.wasFast
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.divider,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: r.wasFast
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.sentence,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (r.wasFast)
                    const Text('⭐', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '${secs}s',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: r.wasFast
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Buttons ────────────────────────────────────────────────────────────────

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        // Try Again
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(
            context,
            AppRouter.readingSession,
            arguments: ReadingSessionArgs(
              grade: args.grade,
              level: args.level,
              levelName: args.levelName,
              sentences: args.sentences,
            ),
          ),
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _isSi ? '🔁 නැවත උත්සාහ කරන්න' : '🔁 Try Again',
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Home
        GestureDetector(
          onTap: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.home,
            (_) => false,
          ),
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              _isSi ? '🏠 නිවසට යන්න' : '🏠 Go Home',
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── WPM card ──────────────────────────────────────────────────────────────────

class _WpmCard extends StatelessWidget {
  final double wpm;
  final bool isSi;
  const _WpmCard({required this.wpm, required this.isSi});

  @override
  Widget build(BuildContext context) {
    final wpmStr = wpm.toStringAsFixed(1);
    final (label, color) = wpm >= 80
        ? (isSi ? 'ඉතා හොඳයි! 🔥' : 'Excellent! 🔥', AppColors.primary)
        : wpm >= 50
            ? (isSi ? 'හොඳයි! 👍' : 'Good job! 👍', const Color(0xFF3498DB))
            : (isSi ? 'දිගටම පුහුණු වෙන්න!' : 'Keep practicing!', const Color(0xFFF39C12));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                wpmStr,
                style: GoogleFonts.nunito(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              Text(
                isSi ? 'වචන/මිනිත්තු' : 'words / min',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
