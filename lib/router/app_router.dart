import 'package:flutter/material.dart';
import '../screens/eduplay/eduplay_journey_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/language_selection_screen.dart';
import '../screens/profile_select_screen.dart';
import '../screens/create_profile_screen.dart';
import '../screens/child_pin_screen.dart';
import '../screens/home_screen.dart';
import '../screens/parent_pin_screen.dart';
import '../screens/pronunciation/pronunciation_home_screen.dart';
import '../screens/pronunciation/pronunciation_session_screen.dart';
import '../screens/pronunciation/session_complete_screen.dart';
import '../screens/reading/reading_level_screen.dart';
import '../screens/reading/reading_session_screen.dart';
import '../screens/reading/session_complete_screen.dart' as rc;
import '../screens/encoding/onboarding_screen.dart';
import '../screens/encoding/word_building_screen.dart';
import '../screens/encoding/sentence_building_screen.dart';
import '../screens/writing/letter_tracing_screen.dart';
import '../screens/writing/word_tracing_screen.dart';
import '../screens/writing/writing_progress_screen.dart';
import '../screens/writing/free_drawing_letter_picker_screen.dart';
import '../screens/writing/free_drawing_letter_level_screen.dart';
import '../screens/calibration/calibration_screen.dart';
import '../screens/timed_reading/timed_reading_home_screen.dart';
import '../screens/timed_reading/reading_screen.dart';
import '../screens/timed_reading/miscue_marking_screen.dart';
import '../screens/timed_reading/results_screen.dart';
import '../screens/timed_reading/repeated_reading_challenge_screen.dart';
import '../models/local_storage.dart';
import '../data/pronunciation_args.dart';
import '../data/reading_data.dart';
import '../data/encoding_data.dart';
import '../data/writing_data.dart';
import '../data/timed_reading_data.dart';
import '../eduplay/eduplay_engine.dart';
import '../eduplay/screens/eduplay_child_dashboard.dart';
import '../eduplay/screens/activity_level_select.dart';
import '../eduplay/screens/activity_screen.dart';
import '../eduplay/screens/session_result_screen.dart';
import '../eduplay/screens/parent_recommendation_screen.dart';
import '../eduplay/feature_builder.dart';

class AppRouter {
  static const splash               = '/';
  static const language             = '/language';
  static const profiles             = '/profiles';
  static const createProfile        = '/create-profile';
  static const pin                  = '/pin';
  static const home                 = '/home';
  static const parentPin            = '/parent-pin';
  static const pronunciation        = '/pronunciation';
  static const pronunciationSession = '/pronunciation/session';
  static const pronunciationComplete = '/pronunciation/complete';
  static const reading              = '/reading';
  static const readingSession       = '/reading/session';
  static const readingComplete      = '/reading/complete';
  static const encodingOnboarding  = '/encoding/onboarding';
  static const encodingHome        = '/encoding/home';
  static const wordBuilding        = '/encoding/word-building';
  static const sentenceBuilding    = '/encoding/sentence-building';
  static const writing             = '/writing';
  static const writingLetter       = '/writing/letter';
  static const writingWord         = '/writing/word';
  static const writingProgress     = '/writing/progress';
  static const freeDrawingLetterLevel = '/writing/free-drawing/letter-level';
  static const calibration         = '/calibration';
  static const eduplay             = '/eduplay';
  static const eduplayDashboard      = '/eduplay/dashboard';
  static const eduplayLevelSelect    = '/eduplay/level-select';
  static const eduplayActivity       = '/eduplay/activity';
  static const eduplayResult         = '/eduplay/result';
  static const eduplayParentRecommendation = '/eduplay/parent/recommendation';
  static const timedReading           = '/timed-reading';
  static const timedReadingSession    = '/timed-reading/session';
  static const timedReadingMiscue     = '/timed-reading/miscue';
  static const timedReadingResults    = '/timed-reading/results';
  static const timedReadingChallenge  = '/timed-reading/challenge';

  static Map<String, WidgetBuilder> get routes => {
        splash:        (_) => const SplashScreen(),
        language:      (_) => const LanguageSelectionScreen(),
        profiles:      (_) => const ProfileSelectScreen(),
        createProfile: (_) => const CreateProfileScreen(),
        home:          (_) => const HomeScreen(),
        parentPin:     (_) => const ParentPinScreen(),
        pronunciation: (_) => const PronunciationHomeScreen(),
        reading:            (_) => const ReadingLevelScreen(),
        encodingOnboarding: (_) => const EncodingOnboardingScreen(),
        writing:            (_) => const FreeDrawingLetterPickerScreen(),
        calibration:        (_) => const CalibrationScreen(),
        eduplay:            (_) => const EduPlayJourneyScreen(),
        timedReading:       (_) => const TimedReadingHomeScreen(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case pin:
        final profile = settings.arguments as UserProfile;
        return _slide(ChildPinScreen(profile: profile));

      case pronunciationSession:
        final args = settings.arguments as PronunciationSessionArgs;
        return _slide(PronunciationSessionScreen(args: args));

      case pronunciationComplete:
        final args = settings.arguments as SessionCompleteArgs;
        return _fade(SessionCompleteScreen(args: args));

      case readingSession:
        final args = settings.arguments as ReadingSessionArgs;
        return _slide(ReadingSessionScreen(args: args));

      case readingComplete:
        final args = settings.arguments as ReadingCompleteArgs;
        return _fade(rc.ReadingSessionCompleteScreen(args: args));

      case wordBuilding:
        final args = settings.arguments as EncodingArgs;
        return _slide(WordBuildingScreen(args: args));

      case sentenceBuilding:
        final args = settings.arguments as EncodingArgs;
        return _slide(SentenceBuildingScreen(args: args));

      case writingLetter:
        final args = settings.arguments as WritingArgs;
        return _slide(LetterTracingScreen(args: args));

      case writingWord:
        final args = settings.arguments as WritingArgs;
        return _slide(WordTracingScreen(args: args));

      case writingProgress:
        final args = settings.arguments as WritingArgs;
        return _slide(WritingProgressScreen(args: args));

      case freeDrawingLetterLevel:
        final target = settings.arguments as String;
        return _slide(FreeDrawingLetterLevelScreen(initialTarget: target));

      case timedReadingSession:
        final args = settings.arguments as ReadingScreenArgs;
        return _slide(ReadingScreen(args: args));

      case timedReadingMiscue:
        final args = settings.arguments as MiscueMarkingArgs;
        return _slide(MiscueMarkingScreen(args: args));

      case timedReadingResults:
        final args = settings.arguments as ResultsScreenArgs;
        return _fade(ResultsScreen(args: args));

      case timedReadingChallenge:
        final args = settings.arguments as ChallengeScreenArgs;
        return _slide(RepeatedReadingChallengeScreen(args: args));

      case eduplayDashboard:
        final childId = settings.arguments as String;
        return _slide(EduPlayChildDashboard(childId: childId));

      case eduplayLevelSelect:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(ActivityLevelSelectScreen(
          childId: args['childId'] as String,
          activityType: args['activityType'] as String,
          grade: args['grade'] as String,
          language: args['language'] as String,
        ));

      case eduplayActivity:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(ActivityScreen(
          childId: args['childId'] as String,
          activityType: args['activityType'] as String,
          level: args['level'] as String,
          grade: args['grade'] as String,
          language: args['language'] as String,
        ));

      case eduplayResult:
        final result = settings.arguments as EduPlaySessionResult;
        return _fade(SessionResultScreen(result: result));

      case eduplayParentRecommendation:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(ParentRecommendationScreen(
          childId: args['childId'] as String,
          engine: args['engine'] as EduPlayEngine,
        ));
    }
    return null;
  }

  static PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeInOut)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      );

  static PageRouteBuilder _fade(Widget page) => PageRouteBuilder(
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      );
}
