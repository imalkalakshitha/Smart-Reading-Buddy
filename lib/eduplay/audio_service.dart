import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Thin audio wrapper for EduPlay task audio — word/sentence clips bundled
/// via pubspec.yaml's assets/eduplay/audio/words/ and
/// assets/eduplay/audio/sentences/ entries (a flat, space-free copy made
/// by eduplay_audio_bundle.py; see that script's docstring for why the
/// original dataset/ and "indeepa wav/" folders couldn't be used directly
/// — a nested-folder bundling gap and a space-in-path asset-lookup bug).
///
/// Uses audioplayers, not just_audio — just_audio isn't in this project's
/// pubspec.yaml (audioplayers is, and is already used everywhere else:
/// Pronunciation, Timed Reading, Parent Dashboard playback). Adding a
/// second audio package for one module isn't worth the footprint when an
/// equivalent one is already the app-wide convention.
class EduPlayAudioService {
  EduPlayAudioService._();
  static final EduPlayAudioService instance = EduPlayAudioService._();

  final AudioPlayer _player = AudioPlayer();

  /// [audioPath] is the full relative asset path from task['audio_path']
  /// (e.g. "eduplay/audio/words/cat_child_04.wav" or
  /// "eduplay/audio/sentences/amma_bath_uyayi.wav").
  /// Silently no-ops if null (audio_available == false for that task).
  Future<void> playTask(String? audioPath) async {
    if (audioPath == null) return;
    await stop();
    try {
      await _player.play(AssetSource(audioPath));
    } catch (e, st) {
      debugPrint('EduPlayAudioService: failed to play "$audioPath": $e');
      debugPrint('$st');
      // Do not rethrow — a missing/failed audio file should not crash
      // the activity screen. The child simply won't hear the prompt.
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}
