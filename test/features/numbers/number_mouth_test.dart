import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/data/numbers_data.dart';
import 'package:smart_reading_buddy/core/widgets/phoneme_image_widget.dart';
import 'package:smart_reading_buddy/features/numbers/screens/number_word_session_screen.dart';
import 'package:smart_reading_buddy/features/numbers/screens/widgets/number_mouth_strip.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_mouth.dart';

const _mouth = 'assets/images/mouth/';
const _closed = '${_mouth}mouth_closed.png';
const _teethLip = '${_mouth}mouth_teeth_lip.png';
const _openWide = '${_mouth}mouth_open_wide.png';
const _rounded = '${_mouth}mouth_rounded.png';
const _teethClose = '${_mouth}mouth_teeth_close.png';
const _tongueUp = '${_mouth}mouth_tongue_up.png';
const _tongueBetween = '${_mouth}mouth_tongue_between.png';
const _openMid = '${_mouth}mouth_open_mid.png';

/// Number Words mouth shapes: CMU phonemes → the shared mouth pictures,
/// syllables with the stressed one marked, and the playback stepping.
void main() {
  final numberWordItems = {
    for (final l in NumbersData.levels) ...NumbersData.forLevel(l['key'] as String).map((i) => i.value),
  };

  group('mouth sequence for every Number Words number', () {
    test('every number has pictures, one label per syllable', () {
      expect(numberWordItems, isNotEmpty);
      for (final n in numberWordItems) {
        final m = NumberMouth.forNumber(n);
        expect(m, isNotNull, reason: '$n');
        expect(m!.steps, isNotEmpty);
        for (final s in m.steps) {
          expect(s.image, startsWith(_mouth), reason: '$n ${s.phoneme}');
          expect(s.syllable, inInclusiveRange(0, m.syllables.length - 1));
        }
        // Every syllable has at least one sound.
        expect(m.steps.map((s) => s.syllable).toSet().length, m.syllables.length, reason: '$n');
        expect(m.syllables.join().replaceAll(' ', ''), m.word.replaceAll(RegExp(r'[ -]'), ''),
            reason: 'labels spell the word ($n)');
      }
    });

    test('-teen stresses the end, -ty the start (fif-TEEN vs FIF-ty)', () {
      for (var n = 13; n <= 19; n++) {
        final m = NumberMouth.forNumber(n)!;
        expect(m.stressedSyllable, m.syllables.length - 1, reason: '$n ${m.syllables}');
        expect(m.syllables.last, 'teen');
      }
      for (var n = 30; n <= 90; n += 10) {
        final m = NumberMouth.forNumber(n)!;
        expect(m.stressedSyllable, 0, reason: '$n ${m.syllables}');
        expect(m.syllables.last, 'ty');
      }
      final fifteen = NumberMouth.forNumber(15)!;
      expect(fifteen.syllables, ['fif', 'teen']);
      expect([for (final s in fifteen.steps) if (s.stressed) s.phoneme], ['T', 'IY', 'N']);
      final fifty = NumberMouth.forNumber(50)!;
      expect(fifty.syllables, ['fif', 'ty']);
      expect([for (final s in fifty.steps) if (s.stressed) s.phoneme], ['F', 'IH', 'F']);
    });

    test('seventeen: sev-en-TEEN; one hundred: HUN is stressed; one-syllable words have none', () {
      final seventeen = NumberMouth.forNumber(17)!;
      expect(seventeen.syllables, ['sev', 'en', 'teen']);
      expect(seventeen.stressedSyllable, 2);
      final hundred = NumberMouth.forNumber(100)!;
      expect(hundred.syllables, ['one', 'hun', 'dred']);
      expect(hundred.stressedSyllable, 1);
      final five = NumberMouth.forNumber(5)!;
      expect(five.stressedSyllable, isNull);
      expect(five.steps.any((s) => s.stressed), isFalse);
    });
  });

  group('CMU → mouth picture', () {
    test('the three sounds the shared mapping gets wrong are right here', () {
      expect(NumberMouth.imageFor('AO1'), _rounded, reason: 'four');
      expect(NumberMouth.imageFor('DH'), _tongueBetween);
      expect(NumberMouth.imageFor('W'), _rounded, reason: 'one, twelve, twenty');
    });

    test('other sounds', () {
      expect(NumberMouth.imageFor('M'), _closed);
      expect(NumberMouth.imageFor('F'), _teethLip);
      expect(NumberMouth.imageFor('V'), _teethLip);
      expect(NumberMouth.imageFor('TH'), _tongueBetween);
      expect(NumberMouth.imageFor('AY1'), _openWide);
      expect(NumberMouth.imageFor('UW1'), _rounded);
      expect(NumberMouth.imageFor('OW0'), _rounded);
      expect(NumberMouth.imageFor('S'), _teethClose);
      expect(NumberMouth.imageFor('T'), _teethClose);
      expect(NumberMouth.imageFor('L'), _tongueUp);
      expect(NumberMouth.imageFor('R'), _tongueUp);
      expect(NumberMouth.imageFor('IY1'), _openMid);
      expect(NumberMouth.imageFor('K'), _openMid);
    });
  });

  test('shared PhonemeImageWidget mapping is unchanged by the move (Pronunciation inputs)', () {
    // Letters, digraphs and IPA as Pronunciation passes them.
    const expected = {
      'm': _closed, 'b': _closed, 'p': _closed,
      'f': _teethLip, 'v': _teethLip,
      'a': _openWide, 'æ': _openWide, 'ɑː': _openWide,
      'u': _rounded, 'o': _rounded, 'uː': _rounded, 'ɔː': _rounded,
      's': _teethClose, 't': _teethClose, 'sh': _teethClose, 'ʃ': _teethClose,
      'l': _tongueUp, 'r': _tongueUp,
      'th': _tongueBetween, 'θ': _tongueBetween, 'ð': _tongueBetween,
      'k': _openMid, 'e': _openMid, 'i': _openMid, 'ng': _openMid, 'w': _openMid, 'ch': _openMid,
      // 'ð' only matches as a whole symbol; 'ðə' falls through to open-mid.
      'kæt': _openMid, 'ðə': _openMid, '/sh/': _teethClose, '': _openMid,
    };
    expected.forEach((input, image) {
      expect(PhonemeImageWidget.getImageForPhoneme(input), image, reason: "'$input'");
    });
  });

  group('MouthPlayer', () {
    testWidgets('steps through the sounds (stressed ones longer), holds, then rests after finish', (tester) async {
      final m = NumberMouth.forNumber(15)!; // F IH F | T IY N — T IY N stressed
      final p = MouthPlayer();
      addTearDown(p.dispose);
      p.play(m);
      expect(p.index, isNull);
      await tester.pump(MouthPlayer.startDelay);
      expect(p.index, 0);
      await tester.pump(const Duration(milliseconds: MouthPlayer.stepMs * 3));
      expect(p.index, 3, reason: 'first stressed sound');
      await tester.pump(const Duration(milliseconds: MouthPlayer.stressedStepMs));
      expect(p.index, 4);
      await tester.pump(const Duration(milliseconds: MouthPlayer.stressedStepMs * 3));
      expect(p.index, 5, reason: 'holds the last shape until speech finishes');
      p.finish();
      expect(p.index, 5);
      await tester.pump(const Duration(milliseconds: 500));
      expect(p.index, isNull);
    });

    testWidgets('finish early jumps to the last shape; stop rests at once', (tester) async {
      final m = NumberMouth.forNumber(50)!;
      final p = MouthPlayer();
      addTearDown(p.dispose);
      p.play(m);
      await tester.pump(MouthPlayer.startDelay);
      p.finish();
      expect(p.index, m.steps.length - 1);
      p.play(m);
      await tester.pump(MouthPlayer.startDelay);
      p.stop();
      expect(p.index, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(p.index, isNull);
    });
  });

  group('fits at ~410 px', () {
    setUpAll(() {
      GoogleFonts.config.allowRuntimeFetching = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (_) async => 1);
    });

    testWidgets('Number Words: digit, mouth strip and mic button on screen; the contrast fits too', (tester) async {
      tester.view.physicalSize = const Size(410, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: NumberWordSessionScreen(levelKey: NumbersData.levelConfusable, levelName: 'Teen or Ty?'),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      tester.takeException(); // font fetch in tests

      expect(find.byType(NumberMouthStrip), findsOneWidget);
      final mic = tester.getRect(find.text('Tap to speak'));
      final scroll = tester.getRect(find.byType(SingleChildScrollView));
      final strip = tester.getSize(find.byType(NumberMouthStrip));
      expect(mic.bottom, lessThanOrEqualTo(scroll.bottom), reason: 'mic button visible without scrolling');

      // The -teen/-ty contrast replaces the strip inside the same card.
      final key = GlobalKey();
      final hp = MouthPlayer(), tp = MouthPlayer();
      addTearDown(hp.dispose);
      addTearDown(tp.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            // Card content width: 410 − 2 × 20 screen padding − 2 × 20 card padding.
            child: SizedBox(
              width: 330,
              child: MouthContrast(
                key: key,
                heard: 50,
                target: 15,
                heardMouth: NumberMouth.forNumber(50)!,
                targetMouth: NumberMouth.forNumber(15)!,
                heardPlayer: hp,
                targetPlayer: tp,
                onReplay: () {},
              ),
            ),
          ),
        ),
      ));
      tester.takeException();
      final contrast = tester.getSize(find.byKey(key));
      // After a mix-up "Attempt 2/3" (~20 px) also shows; the hint line
      // is hidden then (the contrast shows the word).
      final extra = contrast.height - strip.height + 24;
      debugPrint('strip ${strip.height.round()} px, contrast ${contrast.height.round()} px, '
          'mic bottom ${mic.bottom.round()} of ${scroll.bottom.round()} px');
      expect(mic.bottom + extra, lessThanOrEqualTo(scroll.bottom), reason: 'mic still visible with the contrast');
      expect(find.text('You said 50'), findsOneWidget);
      expect(find.text('Say 15'), findsOneWidget);
      expect(find.text('TEEN'), findsOneWidget);
      expect(find.text('FIF'), findsOneWidget, reason: 'FIF-ty: the stressed start');
    });
  });
}
