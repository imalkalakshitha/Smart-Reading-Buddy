import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/services/numbers/level_config.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/build_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/calculation_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/counting_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/formation_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/ordering_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/pattern_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/place_value_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/read_answer_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/recognition_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/activities/spell_word_activity.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/choice_options.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/digit_tile_board.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_question.dart';
import 'package:smart_reading_buddy/features/numbers/services/question_generator.dart';

/// Answer feedback in Number Learning / hub practice: the message shows
/// inside the question's picture card, and the tapped option is marked
/// (✓ + pop when right, 🔄 + shake when wrong, a softer green when the
/// answer is revealed).
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Read & Answer speaks as it appears — no TTS engine in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (_) async => 1);
  });

  /// Pumps [child] at phone width; the font fetch failure (no network /
  /// bundled Nunito in tests) is ignored — the test font is used instead.
  Future<void> pump(WidgetTester tester, Widget child, {FeedbackMessage? message}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FeedbackScope(message: message, child: child),
        ),
      ),
    ));
    tester.takeException();
  }

  group('feedback inside the picture card', () {
    testWidgets('shows the message in the card, with confetti for a right answer', (tester) async {
      await pump(
        tester,
        const VisualCard(child: Text('🍎')),
        message: const FeedbackMessage(1, '🎉', 'Great job!', FeedbackTone.good),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.text('Great job! 🎉'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(VisualCard), matching: find.text('Great job! 🎉')),
        findsOneWidget,
        reason: 'inside the card, not a separate pill',
      );
      expect(find.byType(ConfettiBurst), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      tester.takeException();
    });

    testWidgets('try again and the revealed answer: no confetti', (tester) async {
      await pump(
        tester,
        const VisualCard(child: Text('🍎')),
        message: const FeedbackMessage(1, '💪', "Let's try again!", FeedbackTone.tryAgain),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.text("Let's try again! 💪"), findsOneWidget);
      expect(find.byType(ConfettiBurst), findsNothing);

      await pump(
        tester,
        const VisualCard(child: Text('🍎')),
        message: const FeedbackMessage(2, '', 'The answer is 4', FeedbackTone.revealed),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.text('The answer is 4'), findsOneWidget);
      expect(find.byType(ConfettiBurst), findsNothing);
    });

    testWidgets('no message: just the picture', (tester) async {
      await pump(tester, const VisualCard(child: Text('🍎')));
      expect(find.text('🍎'), findsOneWidget);
      expect(find.byType(ConfettiBurst), findsNothing);
    });
  });

  group('the tapped option is marked', () {
    Widget options({required SubmitAnswer onSubmit, bool revealed = false}) => ChoiceOptions(
          options: const [3, 4, 5, 6],
          answer: 4,
          onSubmit: onSubmit,
          enabled: !revealed,
          revealed: revealed,
        );

    testWidgets('wrong: 🔄 on that option for the full 1.5 s, then it resets', (tester) async {
      await pump(tester, options(onSubmit: (r) => r == 4));
      await tester.tap(find.text('3'));
      await tester.pump();
      tester.takeException();
      expect(find.byType(RetryBadge), findsOneWidget);
      expect(
        find.ancestor(of: find.text('3'), matching: find.byType(Stack)),
        findsWidgets,
        reason: 'the badge sits on the tapped option',
      );
      await tester.pump(kWrongResetDelay - const Duration(milliseconds: 100));
      expect(find.byType(RetryBadge), findsOneWidget, reason: 'still marked while "try again" shows');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(RetryBadge), findsNothing, reason: 'reset for another try');
    });

    testWidgets('right: ✓ on that option', (tester) async {
      await pump(tester, options(onSubmit: (r) => r == 4));
      await tester.tap(find.text('4'));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(CorrectBadge), findsOneWidget);
      expect(find.byType(RetryBadge), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      tester.takeException();
    });

    testWidgets('revealed: the answer is a soft green, with no badge', (tester) async {
      await pump(tester, options(onSubmit: (_) => false, revealed: true));
      expect(find.byType(CorrectBadge), findsNothing);
      final looks = tester.widgetList<BigNumberButton>(find.byType(BigNumberButton)).map((b) => b.look);
      expect(looks.where((l) => l == OptionLook.revealed).length, 1);
    });

    testWidgets('a wrong Check keeps its mark for the full 1.5 s, even if a slot is tapped', (tester) async {
      await pump(
        tester,
        TileBoard(tiles: const ['1', '2'], slotCount: 2, onSubmit: (_) => false, enabled: true),
      );
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('1').last);
      await tester.pump();
      await tester.tap(find.text('Check ✓'));
      await tester.pump();
      tester.takeException();
      expect(find.byType(RetryBadge), findsOneWidget);
      // Tapping a slot during the mark used to clear it early, leaving
      // "Let's try again!" with nothing marked.
      await tester.tap(find.text('2').first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RetryBadge), findsOneWidget);
      await tester.pump(kWrongResetDelay);
      expect(find.byType(RetryBadge), findsNothing);
    });
  });

  group('fits at phone width', () {
    // A ~410 × 915 phone: the space under the app bar, status bar and the
    // progress row, less the block's own padding.
    const width = 410.0;
    const blockHeight = 915.0 - 24 - 56 - 26 - kBlockGap - 20;

    Widget activity(NumberQuestion q, NumberSpeaker speaker) {
      bool submit(Object _) => false;
      return switch (q) {
        RecognitionQuestion() => RecognitionActivity(question: q, onSubmit: submit, enabled: true, revealed: false),
        BuildQuestion() => BuildActivity(question: q, onSubmit: submit, enabled: true, revealed: false),
        OrderingQuestion() => OrderingActivity(question: q, onSubmit: submit, enabled: true, revealed: false),
        PatternQuestion() => PatternActivity(question: q, onSubmit: submit, enabled: true, revealed: false),
        CountingQuestion() => CountingActivity(question: q, onSubmit: submit, enabled: true, revealed: false),
        FormationQuestion() => FormationActivity(question: q, onSubmit: submit, enabled: true, revealed: false),
        CalculationQuestion() => CalculationActivity(question: q, onSubmit: submit, enabled: true, revealed: false),
        PlaceValueQuestion() => PlaceValueActivity(question: q, onSubmit: submit, enabled: true, revealed: false),
        ComparisonQuestion() => ComparisonActivity(question: q, onSubmit: submit, enabled: true, revealed: false),
        SpellWordQuestion() => SpellWordActivity(question: q, onSubmit: submit, enabled: true, revealed: false),
        ReadAnswerQuestion() => ReadAnswerActivity(
            question: q,
            onSubmit: submit,
            enabled: true,
            revealed: false,
            speaker: speaker,
            replaySignal: ValueNotifier(0)),
      };
    }

    testWidgets('instruction + picture card + options fit without scrolling, for every level', (tester) async {
      tester.view.physicalSize = const Size(width, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final levels = [
        ...LevelRepository.parse(File('assets/numbers/levels.json').readAsStringSync()),
        ...LevelRepository.parse(File('assets/numbers/practice_activities.json').readAsStringSync()),
      ].where((l) => QuestionGenerator.supports(l.activityType));
      final speaker = NumberSpeaker();
      var tallest = 0.0;
      var tallestWhat = '';
      for (final level in levels) {
        for (final q in QuestionGenerator(Random(1)).generateSession(level, count: 4)) {
          final key = GlobalKey();
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  key: key,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InstructionBar(prompt: q.prompt, onReplay: () {}),
                    const SizedBox(height: kBlockGap),
                    activity(q, speaker),
                  ],
                ),
              ),
            ),
          ));
          tester.takeException();
          final h = tester.getSize(find.byKey(key)).height;
          if (h > tallest) {
            tallest = h;
            tallestWhat = '${level.id} ${q.key}';
          }
          expect(h, lessThanOrEqualTo(blockHeight), reason: '${level.id} ${q.key} is ${h.round()} px tall');
        }
      }
      debugPrint('tallest block: ${tallest.round()} px ($tallestWhat), room ${blockHeight.round()} px');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      tester.takeException();
    });
  });
}
