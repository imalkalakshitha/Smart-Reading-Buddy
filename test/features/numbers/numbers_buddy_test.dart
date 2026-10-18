import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reading_buddy/features/numbers/services/numbers_buddy.dart';

class _FakeLink implements BuddyLink {
  bool connected = true;
  final sent = <String>[];

  @override
  bool get isConnected => connected;

  @override
  void send(String command) => sent.add(command);
}

void main() {
  group('BuddyReaction', () {
    test('every command is KEYWORD:EN, from the firmware list only', () {
      expect(BuddyReaction.values.map((r) => r.command), [
        'SESSION_END:EN',
        'PRAISE:EN',
        'ENCOURAGE:EN',
        'RETRY:EN',
        'LOUDER:EN',
      ]);
      const firmware = {'WELCOME', 'PRAISE', 'ENCOURAGE', 'RETRY', 'LOUDER', 'SESSION_END'};
      expect(BuddyReaction.values.every((r) => firmware.contains(r.keyword)), isTrue);
    });

    test('priority: SESSION_END > PRAISE > ENCOURAGE > RETRY > LOUDER', () {
      expect(BuddyReaction.sessionEnd.outranks(BuddyReaction.praise), isTrue);
      expect(BuddyReaction.praise.outranks(BuddyReaction.encourage), isTrue);
      expect(BuddyReaction.encourage.outranks(BuddyReaction.retry), isTrue);
      expect(BuddyReaction.retry.outranks(BuddyReaction.louder), isTrue);
      expect(BuddyReaction.louder.outranks(BuddyReaction.retry), isFalse);
    });
  });

  group('PraiseStreak', () {
    test('every 3rd first-try correct in a row', () {
      final s = PraiseStreak();
      expect([for (var i = 0; i < 7; i++) s.correct(firstTry: true)],
          [false, false, true, false, false, true, false]);
    });

    test('a wrong try resets the run; a correct-after-wrong does not count', () {
      final s = PraiseStreak();
      s.correct(firstTry: true);
      s.correct(firstTry: true);
      s.miss();
      expect(s.run, 0);
      expect(s.correct(firstTry: false), isFalse);
      expect(s.run, 0);
      expect([s.correct(firstTry: true), s.correct(firstTry: true), s.correct(firstTry: true)],
          [false, false, true]);
    });
  });

  group('BuddyDispatcher', () {
    BuddyReaction? tick(BuddyDispatcher d, int now, {bool connected = true, bool speaking = false, bool mic = false}) =>
        d.tick(now, connected: connected, speaking: speaking, micOn: mic);

    test('sends a request straight away when idle', () {
      final d = BuddyDispatcher();
      d.request(BuddyReaction.retry, 0);
      expect(tick(d, 0), BuddyReaction.retry);
      expect(d.hasPending, isFalse);
    });

    test('requests made together collapse to the highest priority', () {
      final d = BuddyDispatcher();
      d.request(BuddyReaction.louder, 0);
      d.request(BuddyReaction.retry, 0);
      d.request(BuddyReaction.encourage, 0);
      d.request(BuddyReaction.retry, 0);
      expect(tick(d, 0), BuddyReaction.encourage);
      expect(tick(d, 0), isNull);
    });

    test('one reaction in flight: extras inside the 2.5 s window are dropped', () {
      final d = BuddyDispatcher();
      d.request(BuddyReaction.retry, 0);
      expect(tick(d, 0), BuddyReaction.retry);
      d.request(BuddyReaction.praise, 1000);
      expect(d.hasPending, isFalse, reason: 'dropped, not queued');
      expect(tick(d, 2600), isNull, reason: 'nothing sent later either');
      d.request(BuddyReaction.louder, 2500);
      expect(tick(d, 2500), BuddyReaction.louder, reason: 'window open again at 2.5 s');
    });

    test('SESSION_END is never dropped: it waits for the window, then goes', () {
      final d = BuddyDispatcher();
      d.request(BuddyReaction.praise, 0);
      expect(tick(d, 0), BuddyReaction.praise);
      d.request(BuddyReaction.sessionEnd, 500);
      expect(tick(d, 1000), isNull);
      expect(tick(d, 2499), isNull);
      expect(tick(d, 2500), BuddyReaction.sessionEnd);
    });

    test('a waiting SESSION_END blocks lower reactions, and is sent only once', () {
      final d = BuddyDispatcher();
      d.request(BuddyReaction.retry, 0);
      tick(d, 0);
      d.request(BuddyReaction.sessionEnd, 100);
      d.request(BuddyReaction.praise, 200);
      d.request(BuddyReaction.sessionEnd, 300); // e.g. "passed" and "unlocked" together
      expect(d.pending, BuddyReaction.sessionEnd);
      expect(tick(d, 2500), BuddyReaction.sessionEnd);
      d.request(BuddyReaction.sessionEnd, 2600);
      expect(d.hasPending, isFalse, reason: 'no second SESSION_END right after the first');
    });

    test('an essential end-of-session ENCOURAGE also waits; SESSION_END would replace it', () {
      final d = BuddyDispatcher();
      d.request(BuddyReaction.retry, 0);
      tick(d, 0);
      d.request(BuddyReaction.encourage, 100, essential: true);
      d.request(BuddyReaction.louder, 200);
      expect(d.pending, BuddyReaction.encourage);
      expect(tick(d, 2500), BuddyReaction.encourage);

      final d2 = BuddyDispatcher();
      d2.request(BuddyReaction.encourage, 0, essential: true);
      d2.request(BuddyReaction.sessionEnd, 0);
      expect(tick(d2, 0), BuddyReaction.sessionEnd);
    });

    test('never while the mic listens: ordinary dropped, SESSION_END waits for mic off', () {
      final d = BuddyDispatcher();
      d.request(BuddyReaction.praise, 0);
      expect(tick(d, 0, mic: true), isNull);
      expect(d.hasPending, isFalse);

      d.request(BuddyReaction.sessionEnd, 100);
      expect(tick(d, 100, mic: true), isNull);
      expect(tick(d, 5000, mic: true), isNull);
      expect(tick(d, 5100), BuddyReaction.sessionEnd);
    });

    test('only after the app voice finishes; dropped if it is still speaking after 3 s', () {
      final d = BuddyDispatcher();
      d.request(BuddyReaction.praise, 0);
      expect(tick(d, 500, speaking: true), isNull);
      expect(d.hasPending, isTrue, reason: 'waiting for "finished speaking"');
      expect(tick(d, 1200), BuddyReaction.praise, reason: 'voice finished → sent');

      final d2 = BuddyDispatcher();
      d2.request(BuddyReaction.retry, 0);
      expect(tick(d2, 2999, speaking: true), isNull);
      expect(tick(d2, 3000, speaking: true), isNull);
      expect(d2.hasPending, isFalse, reason: 'still speaking → skipped');
    });

    test('SESSION_END waits for the voice, but goes after 10 s so it is never lost', () {
      final d = BuddyDispatcher();
      d.request(BuddyReaction.sessionEnd, 0);
      expect(tick(d, 9999, speaking: true), isNull);
      expect(tick(d, 10000, speaking: true), BuddyReaction.sessionEnd);
    });

    test('not connected: nothing is sent and nothing waits', () {
      final d = BuddyDispatcher();
      d.request(BuddyReaction.sessionEnd, 0);
      expect(tick(d, 0, connected: false), isNull);
      expect(d.hasPending, isFalse);
    });

    test('mic guard: the mic must wait ~2 s after a reaction was sent', () {
      final d = BuddyDispatcher();
      expect(d.micClearance(0), 0);
      d.request(BuddyReaction.retry, 1000);
      tick(d, 1000);
      expect(d.micClearance(1000), 2000);
      expect(d.micClearance(2500), 500);
      expect(d.micClearance(3000), 0);
    });
  });

  group('waiting for the clip before the next question', () {
    test('clipRemaining counts down 2.5 s from the send', () {
      final d = BuddyDispatcher();
      expect(d.clipRemaining(0), 0);
      d.request(BuddyReaction.praise, 1000);
      d.tick(1000, connected: true, speaking: false, micOn: false);
      expect(d.clipRemaining(1000), 2500);
      expect(d.clipRemaining(3000), 500);
      expect(d.clipRemaining(3500), 0);
    });

    // A fake clock whose delay() advances it — so waits are exact.
    late _FakeLink link;
    late int now;
    late ValueNotifier<bool> speaking;
    late NumbersBuddy buddy;
    final screen = Object();

    setUp(() {
      link = _FakeLink();
      now = 0;
      speaking = ValueNotifier(false);
      buddy = NumbersBuddy(
        link: link,
        clock: () => now,
        delay: (d) async {
          now += d.inMilliseconds;
          if (now >= 800 && speaking.value) speaking.value = false; // "Great job!" ends at 0.8 s
        },
      );
      buddy.attach(screen, speaking: speaking);
    });

    test('not connected: nothing to wait for — the next question keeps its timing', () async {
      link.connected = false;
      buddy.react(BuddyReaction.praise);
      await Future<void>.delayed(Duration.zero);
      expect(buddy.hasClipToWaitFor, isFalse);
      await buddy.waitForClip();
      expect(now, 0);
    });

    test('a sent clip: the next question waits until 2.5 s after the send', () async {
      buddy.react(BuddyReaction.praise);
      await Future<void>.delayed(Duration.zero);
      expect(link.sent, ['PRAISE:EN']);
      now = 1500; // the session's usual 1.5 s advance
      expect(buddy.hasClipToWaitFor, isTrue);
      await buddy.waitForClip();
      expect(now, 2500, reason: 'clip sent at 0 s plays until 2.5 s');
      expect(buddy.hasClipToWaitFor, isFalse);
    });

    test('a reaction still waiting for the app voice: wait for its send, then its clip', () async {
      speaking.value = true; // "Great job!" still being spoken
      buddy.react(BuddyReaction.praise);
      await Future<void>.delayed(Duration.zero);
      expect(link.sent, isEmpty);
      expect(buddy.hasClipToWaitFor, isTrue);
      await buddy.waitForClip();
      expect(link.sent, ['PRAISE:EN'], reason: 'sent once the voice finished');
      expect(now, 800 + 2500, reason: 'sent at 0.8 s, clip done at 3.3 s');
    });

    test('a reaction that gets dropped (voice never finishes): no clip to wait out', () async {
      speaking.value = true;
      final stuck = NumbersBuddy(link: link, clock: () => now, delay: (d) async => now += d.inMilliseconds);
      stuck.attach(screen, speaking: speaking);
      stuck.react(BuddyReaction.retry);
      await Future<void>.delayed(Duration.zero);
      await stuck.waitForClip();
      expect(link.sent, isEmpty);
      expect(now, lessThanOrEqualTo(NumbersBuddy.maxPendingWait.inMilliseconds));
      expect(stuck.hasClipToWaitFor, isFalse);
    });
  });

  group('NumbersBuddy (runtime wrapper)', () {
    late _FakeLink link;
    late int now;
    late NumbersBuddy buddy;
    final screen = Object();
    final oldScreen = Object();

    setUp(() {
      link = _FakeLink();
      now = 0;
      buddy = NumbersBuddy(link: link, clock: () => now);
    });

    test('same-event reactions collapse after a microtask; sends KEYWORD:EN', () async {
      buddy.react(BuddyReaction.retry);
      buddy.react(BuddyReaction.encourage);
      expect(link.sent, isEmpty, reason: 'react() never sends synchronously');
      await Future<void>.delayed(Duration.zero);
      expect(link.sent, ['ENCOURAGE:EN']);
    });

    test('waits for the attached voice to finish, then sends', () async {
      final speaking = ValueNotifier<bool>(true);
      buddy.attach(screen, speaking: speaking);
      buddy.react(BuddyReaction.praise);
      await Future<void>.delayed(Duration.zero);
      expect(link.sent, isEmpty);
      now = 800;
      speaking.value = false; // "finished speaking" re-checks at once
      expect(link.sent, ['PRAISE:EN']);
      buddy.detach(screen);
    });

    test('not connected: react does nothing at all', () async {
      link.connected = false;
      buddy.sessionEnded(passed: true);
      await Future<void>.delayed(Duration.zero);
      expect(link.sent, isEmpty);
      expect(buddy.micClearance(), Duration.zero);
    });

    test('sessionEnded: SESSION_END when passed, ENCOURAGE otherwise', () async {
      buddy.sessionEnded(passed: false);
      await Future<void>.delayed(Duration.zero);
      now = 3000;
      buddy.sessionEnded(passed: true);
      await Future<void>.delayed(Duration.zero);
      expect(link.sent, ['ENCOURAGE:EN', 'SESSION_END:EN']);
    });

    test('detach only removes the screen that attached (Play again replaces it)', () async {
      final mic = ValueNotifier<bool>(true);
      final newScreen = Object();
      buddy.attach(newScreen, mic: mic);
      buddy.detach(oldScreen); // the old screen disposing afterwards
      buddy.react(BuddyReaction.praise);
      await Future<void>.delayed(Duration.zero);
      expect(link.sent, isEmpty, reason: "the new screen's mic is still listening");
    });
  });
}
