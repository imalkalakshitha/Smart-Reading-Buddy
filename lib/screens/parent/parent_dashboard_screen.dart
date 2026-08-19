import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_colors.dart';
import '../../models/app_text.dart';
import '../../eduplay/eduplay_database.dart';
import '../../eduplay/eduplay_engine_holder.dart';
import '../../eduplay/screens/parent_recommendation_screen.dart';
import 'parent_pronunciation_analytics_screen.dart';
import 'parent_reading_analytics_screen.dart';
import 'parent_word_building_analytics_screen.dart';
import 'parent_writing_analytics_screen.dart';
import 'parent_timed_reading_analytics_screen.dart';

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

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  // The "Reading" card (ParentReadingAnalyticsScreen) is a teammate's
  // module that's still just a ComingSoonPlaceholder stub — hidden here
  // rather than deleted, since it may get properly implemented later.
  // Flip to true (or just remove this flag/guard) once that module has
  // real content. parent_reading_analytics_screen.dart itself is
  // untouched — this only stops the grid from linking to it.
  static const bool _showPlaceholderReadingCard = false;

  String get profileName => widget.profileName;

  bool _hasPendingEduPlayRecommendation = false;

  @override
  void initState() {
    super.initState();
    _checkPendingRecommendation();
  }

  Future<void> _checkPendingRecommendation() async {
    final rec = await EduPlayDatabase.getPendingRecommendation(profileName);
    if (!mounted) return;
    setState(() => _hasPendingEduPlayRecommendation = rec != null);
  }

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleCard(
        icon: Icons.multitrack_audio_rounded,
        label: AppText.pronunciation,
        accent: AppColors.pronunciation,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParentPronunciationAnalyticsScreen(
              profileName: profileName,
            ),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.auto_stories_rounded,
        label: AppText.wordBuilding,
        accent: AppColors.wordBuilding,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParentWordBuildingAnalyticsScreen(childId: profileName),
          ),
        ),
      ),
      if (_showPlaceholderReadingCard)
        _ModuleCard(
          icon: Icons.menu_book_rounded,
          label: AppText.reading,
          accent: AppColors.reading,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ParentReadingAnalyticsScreen(),
            ),
          ),
        ),
      _ModuleCard(
        icon: Icons.edit_rounded,
        label: AppText.writing,
        accent: AppColors.writing,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ParentWritingAnalyticsScreen(),
          ),
        ),
      ),
      _ModuleCard(
        icon: Icons.timer_rounded,
        label: 'Timed Reading',
        accent: AppColors.timedReading,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ParentTimedReadingAnalyticsScreen(),
          ),
        ),
      ),
      if (_hasPendingEduPlayRecommendation)
        _ModuleCard(
          icon: Icons.games_rounded,
          label: 'EduPlay Recommendation',
          accent: AppColors.wordBuilding,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ParentRecommendationScreen(
                childId: profileName,
                engine: EduPlayEngineHolder.instance,
              ),
            ),
          ),
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
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
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
