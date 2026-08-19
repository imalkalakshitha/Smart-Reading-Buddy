import 'eduplay_engine.dart';

/// Static holder for the single EduPlayEngine instance created once at app
/// startup (see main.dart) — same singleton-holder pattern already used
/// throughout this app (AppState, LocalStorage) rather than introducing a
/// new state-management package or an InheritedWidget just for one engine
/// reference.
class EduPlayEngineHolder {
  EduPlayEngineHolder._();
  static EduPlayEngine? _instance;

  static EduPlayEngine get instance {
    final engine = _instance;
    if (engine == null) {
      throw StateError(
          'EduPlayEngineHolder.instance accessed before initialize() completed');
    }
    return engine;
  }

  static Future<void> initialize() async {
    _instance = await EduPlayEngine.create();
  }
}
