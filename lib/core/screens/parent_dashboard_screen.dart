import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_text.dart';
import 'package:smart_reading_buddy/features/eduplay_encoding/screens/eduplay/eduplay_parent_journey_screen.dart';
import 'package:smart_reading_buddy/features/parent/screens/parent_pronunciation_analytics_screen.dart';
import 'package:smart_reading_buddy/features/parent/screens/parent_reading_analytics_screen.dart';
import 'package:smart_reading_buddy/features/parent/screens/parent_writing_analytics_screen.dart';
import 'package:smart_reading_buddy/features/parent/screens/parent_timed_reading_analytics_screen.dart';
import 'package:smart_reading_buddy/features/parent/screens/parent_numbers_analytics_screen.dart';
import 'package:smart_reading_buddy/features/parent/services/numbers_summary.dart';

/// Parent dashboard landing screen — reached after the PIN gate.
/// One card per learning module; only Pronunciation and Timed Reading
/// have real analytics wired up so far. The other two belong to
/// teammates and are left as placeholders until they wire up their own
/// data.
class ParentDashboardScreen extends StatefulWidget {
  final String profileName;

  const ParentDashboardScreen({super.key, required this.profileName});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

// Calm, muted, professional accent colors for this parent-facing screen —
// deliberately distinct from the playful child-facing EduPlay lesson
// colors (kLessonColors in eduplay_constants.dart).
const _kPronunciationAccent = Color(0xFF6366F1);
const _kPronunciationTint = Color(0xFFEEF0FE);
const _kWritingAccent = Color(0xFFEC4899);
const _kWritingTint = Color(0xFFFDF0F7);
const _kTimedReadingAccent = Color(0xFF14B8A6);
const _kTimedReadingTint = Color(0xFFEEFBF9);
const _kJourneyAccent = AppColors.primary; // #2ECC71 — app green, matches EduPlay's own accent
const _kJourneyTint = Color(0xFFEAFBF1);

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  // The "Reading" card (ParentReadingAnalyticsScreen) is a teammate's
  // module that's still just a ComingSoonPlaceholder stub — hidden here
  // rather than deleted, since it may get properly implemented later.
  // Flip to true (or just remove this flag/guard) once that module has
  // real content. parent_reading_analytics_screen.dart itself is
  // untouched — this only stops the grid from linking to it.
  static const bool _showPlaceholderReadingCard = false;

  String get profileName => widget.profileName;

  // Numbers card summary — loaded once on open and again after returning
  // from the Numbers analytics screen.
  NumbersSummary? _numbers;
  bool _numbersLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNumbers();
  }

  Future<void> _loadNumbers() async {
    try {
      final s = await NumbersSummaryLoader.load(profileName);
      if (mounted) {
        setState(() {
          _numbers = s;
          _numbersLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('[ParentDashboard] Numbers summary failed: $e');
      if (mounted) setState(() => _numbersLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleCard(
        icon: Icons.multitrack_audio_rounded,
        label: AppText.pronunciation,
        accent: _kPronunciationAccent,
        accentTint: _kPronunciationTint,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParentPronunciationAnalyticsScreen(
              profileName: profileName,
            ),
          ),
        ),
      ),
      if (_showPlaceholderReadingCard)
        _ModuleCard(
          icon: Icons.menu_book_rounded,
          label: AppText.reading,
          accent: AppColors.reading,
          accentTint: AppColors.reading.withValues(alpha: 0.12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ParentReadingAnalyticsScreen(),
            ),
          ),
        ),
      _ModuleCard(
        icon: Icons.edit_rounded,
        label: AppText.writing,
        accent: _kWritingAccent,
        accentTint: _kWritingTint,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParentWritingAnalyticsScreen(profileName: profileName),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.timer_rounded,
        label: 'Timed Reading',
        accent: _kTimedReadingAccent,
        accentTint: _kTimedReadingTint,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ParentTimedReadingAnalyticsScreen(),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.route_rounded,
        label: 'Learning Journey',
        accent: _kJourneyAccent,
        accentTint: _kJourneyTint,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EduPlayParentJourneyScreen(childId: profileName),
          ),
        ),
      ),
      _NumbersModuleCard(
        summary: _numbers,
        loaded: _numbersLoaded,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ParentNumbersAnalyticsScreen(profileName: profileName),
            ),
          );
          _loadNumbers();
        },
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          AppText.parentDashboard,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              profileName,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.95,
          ),
          itemCount: modules.length,
          itemBuilder: (_, i) =>
              modules[i].animate(delay: (i * 80).ms).fadeIn().slideY(begin: 0.15),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final Color accentTint;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.accentTint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Card shell matches parent_word_building_analytics_screen.dart's
    // _SessionRow pattern (white bg, border-only, no shadow) — the closest
    // existing precedent to "border 1px #E5E7EB"; that screen actually
    // uses AppColors.divider (#E8F5E9) and radius 18/14 depending on the
    // element, not literally #E5E7EB/radius 20, so this reuses the real
    // color/radius values already established there instead of inventing
    // new ones.
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Numbers card — same shell as [_ModuleCard] (white, bordered,
/// tinted icon circle), with a slightly smaller icon so a three-line
/// summary fits the same grid cell: levels passed, overall accuracy and
/// the latest Rapid Digit Naming speed.
class _NumbersModuleCard extends StatelessWidget {
  final NumbersSummary? summary;
  final bool loaded;
  final VoidCallback onTap;

  const _NumbersModuleCard({required this.summary, required this.loaded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final lines = <String>[
      if (!loaded) '…'
      else if (s == null || !s.hasData) 'Not started yet'
      else ...[
        'Basic ${s.basicPassed}/${s.basicTotal} · Advanced ${s.advancedPassed}/${s.advancedTotal}',
        if (s.overall.rate != null) '${(s.overall.rate! * 100).round()}% accuracy',
        if (s.latestRan != null) 'RAN ${s.latestRan!.digitsPerSecond.toStringAsFixed(1)} digits/s',
      ],
    ];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          // Scales down on very narrow phones instead of overflowing the
          // grid cell (the other cards have less text).
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: kNumbersTint, shape: BoxShape.circle),
                child: const Icon(Icons.pin_rounded, color: kNumbersAccent, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                'Numbers',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              for (final line in lines)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    line,
                    style: GoogleFonts.nunito(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}
