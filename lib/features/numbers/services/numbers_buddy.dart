import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:smart_reading_buddy/core/services/ble_command_service.dart';

/// Smart Buddy reactions used by the Numbers feature, highest priority
/// first. Numbers is English only, so every command is sent as ":EN" —
/// never bare. Only the firmware's existing keywords are used, never
/// on-screen text. Nothing is sent when a session starts (the buddy plays
/// WELCOME on connect).
enum BuddyReaction {
  sessionEnd('SESSION_END'),
  praise('PRAISE'),
  encourage('ENCOURAGE'),
  retry('RETRY'),
  louder('LOUDER');

  const BuddyReaction(this.keyword);

  final String keyword;

  String get command => '$keyword:EN';

  /// Lower index = higher priority.
  bool outranks(BuddyReaction other) => index < other.index;
}

/// Every 3rd first-try correct answer in a row earns a PRAISE. A wrong try
/// resets the run; a correct answer after a wrong try doesn't count.
class PraiseStreak {
  static const every = 3;

  int _run = 0;

  int get run => _run;

  /// Records a correct answer; true when it completes a run of [every].
  bool correct({required bool firstTry}) {
    if (!firstTry) {
      _run = 0;
      return false;
    }
    _run++;
    return _run % every == 0;
  }

  void miss() => _run = 0;
}

/// When to send what (pure logic — no timers, no Bluetooth; times are
/// milliseconds on the caller's clock).
///
/// The firmware has no queue or cooldown, interrupts whatever clip is
/// playing and reports nothing back, so:
/// - One reaction in flight: after a send, the next [window] is closed.
///   Requests arriving then are dropped — except essential ones
///   (SESSION_END, and an end-of-session ENCOURAGE), which wait for the
///   window and are then sent.
/// - Requests made together collapse to the highest priority
///   (SESSION_END > PRAISE > ENCOURAGE > RETRY > LOUDER).
/// - Never while a microphone is listening: an ordinary reaction is
///   dropped, an essential one waits for the mic to go off.
/// - Only once the app has finished speaking: an ordinary reaction waits up
///   to [speechWait] for the voice to finish and is dropped if it's still
///   speaking; an essential one waits up to [essentialSpeechWait], then
///   goes anyway so it's never lost to a voice that never reports
///   finishing.
/// - [micClearance]: how long a screen must still wait before starting its
///   mic, so the buddy's clip isn't transcribed.
class BuddyDispatcher {
  final int window;
  final int speechWait;
  final int essentialSpeechWait;
  final int micGuard;

  BuddyDispatcher({
    this.window = 2500,
    this.speechWait = 3000,
    this.essentialSpeechWait = 10000,
    this.micGuard = 2000,
  });

  int? _lastSentAt;
  BuddyReaction? _lastSent;
  BuddyReaction? _pending;
  bool _pendingEssential = false;
  int _pendingSince = 0;

  BuddyReaction? get pending => _pending;
  bool get hasPending => _pending != null;

  bool _windowOpen(int now) => _lastSentAt == null || now - _lastSentAt! >= window;

  /// Asks for [r]. SESSION_END is always essential.
  void request(BuddyReaction r, int now, {bool essential = false}) {
    final isEssential = essential || r == BuddyReaction.sessionEnd;
    final p = _pending;
    if (isEssential) {
      // Never send the same end-of-session reaction twice in a row.
      if (p == r && _pendingEssential) return;
      if (_lastSent == r && !_windowOpen(now)) return;
      if (p != null && _pendingEssential && p.outranks(r)) return;
      _pending = r;
      _pendingEssential = true;
      _pendingSince = now;
      return;
    }
    if (p != null && _pendingEssential) return; // an essential one is waiting
    if (!_windowOpen(now)) return; // one in flight — drop extras
    if (p == null || r.outranks(p)) {
      _pending = r;
      _pendingEssential = false;
      _pendingSince = now;
    }
  }

  /// Decides whether to send now. Returns the reaction to send (and
  /// records it as in flight), or null.
  BuddyReaction? tick(int now, {required bool connected, required bool speaking, required bool micOn}) {
    final p = _pending;
    if (p == null) return null;
    if (!connected) {
      _clear(); // not connected → nothing, silently
      return null;
    }
    if (_pendingEssential) {
      if (!_windowOpen(now) || micOn) return null;
      if (speaking && now - _pendingSince < essentialSpeechWait) return null;
      return _send(p, now);
    }
    if (!_windowOpen(now) || micOn) {
      _clear();
      return null;
    }
    if (speaking) {
      if (now - _pendingSince >= speechWait) _clear();
      return null;
    }
    return _send(p, now);
  }

  /// Milliseconds until the last sent clip has finished playing ([window]
  /// is also the clip length estimate), or 0.
  int clipRemaining(int now) {
    final t = _lastSentAt;
    if (t == null) return 0;
    final left = t + window - now;
    return left > 0 ? left : 0;
  }

  /// Milliseconds a screen must still wait before starting its mic.
  int micClearance(int now) {
    final t = _lastSentAt;
    if (t == null) return 0;
    final left = t + micGuard - now;
    return left > 0 ? left : 0;
  }

  BuddyReaction _send(BuddyReaction r, int now) {
    _lastSentAt = now;
    _lastSent = r;
    _clear();
    return r;
  }

  void _clear() {
    _pending = null;
    _pendingEssential = false;
  }
}

/// Where reactions go — the shared BLE service at runtime, a fake in tests.
abstract class BuddyLink {
  bool get isConnected;
  void send(String command);
}

class _BleLink implements BuddyLink {
  @override
  bool get isConnected => BleCommandService.instance.isConnected;

  // Fire-and-forget: send() never throws, and nothing waits for the write.
  @override
  void send(String command) => unawaited(BleCommandService.instance.send(command));
}

/// The one Smart Buddy helper for every Numbers screen (Number Words, RAN,
/// Number Learning's 8 activity types, Spell Number Words, Number Match,
/// Read & Answer). Fire-and-forget: [react] returns at once and never
/// blocks the UI; when the buddy isn't connected nothing happens.
///
/// The screen in front attaches its voice ("is speaking", which flips back
/// when TTS reports it finished) and mic ("is listening") flags so the
/// dispatcher can respect them.
class NumbersBuddy {
  NumbersBuddy({
    BuddyLink? link,
    int Function()? clock,
    BuddyDispatcher? dispatcher,
    Future<void> Function(Duration)? delay,
  })  : _link = link ?? _BleLink(),
        _clock = clock ?? _monotonicMs,
        _d = dispatcher ?? BuddyDispatcher(),
        _delay = delay ?? Future<void>.delayed;

  final Future<void> Function(Duration) _delay;

  /// How long [waitForClip] waits for a pending reaction to be sent or
  /// dropped (a little over the dispatcher's voice wait).
  static const maxPendingWait = Duration(milliseconds: 3500);

  /// True when the next question should wait for the buddy: a reaction is
  /// still pending, or a sent clip is still playing. Always false when the
  /// buddy isn't connected (nothing is ever pending or sent), so screens
  /// keep their exact timing then.
  bool get hasClipToWaitFor => _d.hasPending || _d.clipRemaining(_clock()) > 0;

  /// Waits until the buddy's clip has finished: first for a pending
  /// reaction to be sent or dropped (up to [maxPendingWait]), then — if a
  /// clip was sent — until ~2.5 s after the send. Screens call this before
  /// showing / speaking the next question so the app doesn't talk over
  /// the buddy.
  Future<void> waitForClip() async {
    final deadline = _clock() + maxPendingWait.inMilliseconds;
    while (_d.hasPending && _clock() < deadline) {
      await _delay(const Duration(milliseconds: 50));
      tickNow();
    }
    final left = _d.clipRemaining(_clock());
    if (left > 0) await _delay(Duration(milliseconds: left));
  }

  static final NumbersBuddy instance = NumbersBuddy();

  static final Stopwatch _sw = Stopwatch()..start();
  static int _monotonicMs() => _sw.elapsedMilliseconds;

  final BuddyLink _link;
  final int Function() _clock;
  final BuddyDispatcher _d;
  Timer? _ticker;
  ValueListenable<bool>? _speaking;
  ValueListenable<bool>? _mic;
  Object? _owner;

  /// Attaches the current screen's voice / mic flags. Changes to either
  /// re-check a waiting reaction straight away (so "finished speaking"
  /// sends it without waiting for the next timer tick).
  void attach(Object owner, {ValueListenable<bool>? speaking, ValueListenable<bool>? mic}) {
    _detachListeners();
    _owner = owner;
    _speaking = speaking;
    _mic = mic;
    _speaking?.addListener(tickNow);
    _mic?.addListener(tickNow);
  }

  /// Detaches [owner]'s flags (only if it's still the attached screen).
  /// A waiting essential reaction still goes out afterwards.
  void detach(Object owner) {
    if (_owner != owner) return;
    _detachListeners();
    _owner = null;
    _speaking = null;
    _mic = null;
  }

  void _detachListeners() {
    _speaking?.removeListener(tickNow);
    _mic?.removeListener(tickNow);
  }

  bool _tickScheduled = false;

  void react(BuddyReaction r, {bool essential = false}) {
    if (!_link.isConnected) return;
    _d.request(r, _clock(), essential: essential);
    // Checked one microtask later, so reactions raised by the same event
    // (e.g. RETRY + ENCOURAGE on a third miss) collapse to the highest
    // priority instead of the first one winning.
    if (_tickScheduled) return;
    _tickScheduled = true;
    scheduleMicrotask(() {
      _tickScheduled = false;
      tickNow();
    });
  }

  /// End of a session: SESSION_END when the level was passed (or the set /
  /// grid finished), otherwise ENCOURAGE. Both are essential.
  void sessionEnded({required bool passed}) =>
      react(passed ? BuddyReaction.sessionEnd : BuddyReaction.encourage, essential: true);

  /// How long the caller must still wait before starting its microphone.
  Duration micClearance() => Duration(milliseconds: _d.micClearance(_clock()));

  @visibleForTesting
  void tickNow() {
    final out = _d.tick(
      _clock(),
      connected: _link.isConnected,
      speaking: _speaking?.value ?? false,
      micOn: _mic?.value ?? false,
    );
    if (out != null) {
      debugPrint('[NumbersBuddy] → ${out.command}');
      _link.send(out.command);
    }
    if (_d.hasPending) {
      _ticker ??= Timer.periodic(const Duration(milliseconds: 100), (_) => tickNow());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }
}
