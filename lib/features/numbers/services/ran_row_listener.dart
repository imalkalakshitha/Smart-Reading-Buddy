import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:smart_reading_buddy/features/numbers/services/ran_row_tracker.dart';

/// Listens to one Rapid Digit Naming row with speech_to_text and ends it on
/// its own — the child never has to tap Done.
///
/// Android's recogniser often ends a session after a few words even in
/// dictation mode. When that happens mid-row, listening restarts at once
/// and the new text is appended (see [RanRowTracker]); the row clock keeps
/// running across restarts.
///
/// speech_to_text is a process-wide singleton whose status/error listeners
/// belong to whoever called initialize() first (usually the Pronunciation
/// scorer). This class swaps in its own listeners only while a row is
/// running and puts the previous ones back afterwards — it never calls
/// initialize() with its own callbacks.
class RanRowListener {
  final RanRowTracker tracker;
  final int Function() now;
  final VoidCallback onChanged;
  final void Function(RanRowEnd reason) onEnded;

  RanRowListener({
    required this.tracker,
    required this.now,
    required this.onChanged,
    required this.onEnded,
  });

  static const _listenFor = Duration(seconds: 30);
  static const _pauseFor = Duration(seconds: 3);
  // After stop(), the recogniser can still deliver the final text.
  static const _finalGrace = Duration(milliseconds: 400);

  final SpeechToText _stt = SpeechToText();
  SpeechStatusListener? _prevStatus;
  SpeechErrorListener? _prevError;
  Timer? _ticker;
  bool _active = false; // restarting allowed
  bool _accepting = false; // results still counted (incl. the stop grace)
  bool _restartPending = false;
  bool _ended = false;
  int restarts = 0;

  Future<void> start() async {
    _prevStatus = _stt.statusListener;
    _prevError = _stt.errorListener;
    _stt.statusListener = _onStatus;
    _stt.errorListener = _onError;
    _active = true;
    _accepting = true;
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final end = tracker.check(now());
      if (end != null) stop(end);
    });
    await _listen();
  }

  Future<void> _listen() async {
    if (!_active) return;
    try {
      await _stt.listen(
        onResult: (r) {
          if (!_accepting) return;
          tracker.onResult(r.recognizedWords, isFinal: r.finalResult, nowMs: now(), timing: _active);
          onChanged();
        },
        onSoundLevelChange: (level) {
          if (_active) tracker.onSoundLevel(level, now());
        },
        listenFor: _listenFor,
        pauseFor: _pauseFor,
        localeId: 'en_US',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      debugPrint('[RAN] listen failed: $e');
      _scheduleRestart();
    }
  }

  void _onStatus(String status) {
    // 'done' comes after the session's final result, so its text is safe
    // to commit; 'notListening' can arrive before it.
    if (!_active || status != SpeechToText.doneStatus) return;
    tracker.commit();
    _scheduleRestart();
  }

  void _onError(SpeechRecognitionError e) {
    if (!_active) return;
    debugPrint('[RAN] STT error ${e.errorMsg} (permanent=${e.permanent})');
    tracker.commit();
    if (e.errorMsg == 'error_permission' || e.errorMsg == 'error_insufficient_permissions') {
      stop(RanRowEnd.timeout);
      return;
    }
    _scheduleRestart();
  }

  void _scheduleRestart() {
    if (!_active || _restartPending) return;
    _restartPending = true;
    Future.delayed(const Duration(milliseconds: 60), () async {
      _restartPending = false;
      if (!_active || _stt.isListening) return;
      restarts++;
      debugPrint('[RAN] recogniser stopped early — restart #$restarts');
      await _listen();
    });
  }

  /// Ends the row: stops the mic, waits briefly for the final text, then
  /// reports [reason]. Safe to call more than once.
  Future<void> stop(RanRowEnd reason) async {
    if (!_active) return;
    _active = false;
    _ticker?.cancel();
    try {
      await _stt.stop();
    } catch (_) {}
    await Future.delayed(_finalGrace);
    _accepting = false;
    tracker.commit();
    _restoreListeners();
    if (!_ended) {
      _ended = true;
      onEnded(reason);
    }
  }

  /// For screen disposal: stop without reporting.
  void cancel() {
    _ended = true;
    _active = false;
    _accepting = false;
    _ticker?.cancel();
    _stt.cancel();
    _restoreListeners();
  }

  void _restoreListeners() {
    _stt.statusListener = _prevStatus;
    _stt.errorListener = _prevError;
  }
}
