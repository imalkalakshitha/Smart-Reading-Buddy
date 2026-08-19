import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/app_colors.dart';
import 'models/local_storage.dart';
import 'router/app_router.dart';
import 'services/timed_reading_speech_bridge.dart';
import 'eduplay/eduplay_database.dart';
import 'eduplay/eduplay_profile_mapper.dart';
import 'eduplay/task_repository.dart';
import 'eduplay/eduplay_engine_holder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Defensive startup sweeps for orphaned Timed Reading audio — one for
  // in-progress temp recordings (see cleanupStaleFiles doc), one for
  // Parent Dashboard review storage (see cleanupStaleReviewFiles doc).
  // Both fire-and-forget, must never delay app startup.
  // ignore: unawaited_futures
  TimedReadingAudioRecorder.cleanupStaleFiles();
  // ignore: unawaited_futures
  TimedReadingAudioRecorder.cleanupStaleReviewFiles();
  // EduPlay — task bank + engine (RF model) must be ready before any
  // EduPlay screen can be reached, so these are awaited (unlike the
  // fire-and-forget sweeps above).
  await TaskRepository.initialize();
  await EduPlayEngineHolder.initialize();
  // One-time backfill for profiles created before EduPlay's profile row
  // was wired up at profile-creation time (see create_profile_screen.dart)
  // — without this, children created before this fix would be
  // permanently stuck on EduPlay's cold-start English/Grade 4 defaults.
  // Awaited (not fire-and-forget): it must finish before the child could
  // possibly reach an EduPlay screen, and it's a handful of profiles at
  // most, so the delay is negligible.
  await _backfillEduPlayProfiles();
  runApp(const SmartReadingBuddy());
}

Future<void> _backfillEduPlayProfiles() async {
  final profiles = await LocalStorage.getAllProfiles();
  for (final profile in profiles) {
    final existing = await EduPlayDatabase.getChildProfile(profile.name);
    if (existing == null) {
      await EduPlayDatabase.upsertChildProfile({
        'child_id': profile.name,
        'grade': EduPlayProfileMapper.mapGrade(profile.grade),
        'language': EduPlayProfileMapper.mapLanguage(profile.language),
        'starting_level': 'Basic',
        'support_need_level': 'Medium',
        'main_focus_area': 'letter_order',
        'baseline_accuracy': 66.8,
        'baseline_response_time_sec': 41.2,
        'total_completed_activities': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }
}

class SmartReadingBuddy extends StatelessWidget {
  const SmartReadingBuddy({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Reading Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        textTheme: GoogleFonts.nunitoTextTheme(),
        scaffoldBackgroundColor: AppColors.pageBg,
        useMaterial3: true,
      ),
      // Splash is always the entry point — it handles the routing logic
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
