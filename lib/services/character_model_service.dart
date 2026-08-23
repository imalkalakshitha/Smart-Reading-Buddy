import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Loads the offline "Free Drawing Recognition" CNN (character_model.tflite,
/// [1,128,128,1] float32 in -> [1,95] softmax out) and its class-name list.
///
/// Class order is defined entirely by assets/models/class_names.json (index
/// 0-25 English upper, 26-51 English lower, 52-94 Sinhala) — that file is
/// the only source of truth for what index N means, so it is loaded at
/// runtime and never hard-coded here.
class CharacterModelService {
  CharacterModelService._();
  static final CharacterModelService instance = CharacterModelService._();

  static const String _modelAsset = 'assets/models/character_model.tflite';
  static const String _classNamesAsset = 'assets/models/class_names.json';

  Interpreter? _interpreter;
  List<String>? _classNames;

  bool get isLoaded => _interpreter != null && _classNames != null;
  List<String> get classNames => List.unmodifiable(_classNames!);

  Future<void> load() async {
    if (isLoaded) return;
    _interpreter = await Interpreter.fromAsset(_modelAsset);
    final raw = await rootBundle.loadString(_classNamesAsset);
    final decoded = jsonDecode(raw) as List<dynamic>;
    _classNames = decoded.map((e) => e.toString()).toList();
  }

  /// Runs inference on already-preprocessed input: 128*128 float32 values
  /// (0.0-1.0), row-major, no channel dim yet — reshaped to [1,128,128,1]
  /// here. Returns the raw 95-way softmax output untouched (no filtering,
  /// no renormalisation — that's FreeDrawingRecognizer's job).
  List<double> predictRaw(Float32List flatInput) {
    if (!isLoaded) {
      throw StateError('CharacterModelService.load() must complete before predictRaw()');
    }
    final inputTensor = flatInput.reshape([1, 128, 128, 1]);
    final output = List.generate(1, (_) => List.filled(_classNames!.length, 0.0));
    _interpreter!.run(inputTensor, output);
    return output[0];
  }
}
