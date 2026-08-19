import 'package:audioplayers/audioplayers.dart';

/// Thin audio wrapper for EduPlay task audio (word/sentence clips already
/// bundled via pubspec.yaml's dataset/ and indeepa wav/ asset entries).
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
  /// (e.g. "dataset/en/grade3/cat/child_04.wav" or "indeepa wav/...wav").
  /// Silently no-ops if null (audio_available == false for that task).
  Future<void> playTask(String? audioPath) async {
    if (audioPath == null) return;
    await stop();
    try {
      await _player.play(AssetSource(audioPath));
    } catch (_) {
      // Best-effort — a missing/corrupt asset shouldn't crash the activity.
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
