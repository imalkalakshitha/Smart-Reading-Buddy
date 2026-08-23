import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Bundled, filtered subset of the CMU Pronouncing Dictionary — covers only
/// the English words present in word_data.dart's Grade 3/4 curriculum (see
/// assets/cmu_phonemes_subset.json for provenance/regeneration notes).
/// Fully offline: loaded once from the asset bundle, no network/API calls.
class CmuPhonemeLookup {
  CmuPhonemeLookup._();

  static Map<String, List<String>>? _dict;

  static Future<void> _ensureLoaded() async {
    if (_dict != null) return;
    final raw = await rootBundle.loadString('assets/cmu_phonemes_subset.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _dict = {
      for (final entry in json.entries)
        if (entry.key != '_comment')
          entry.key: (entry.value as List).cast<String>(),
    };
  }

  /// Returns the ARPABET phoneme sequence for [word] (case-insensitive),
  /// or null if it isn't in the bundled subset.
  static Future<List<String>?> lookup(String word) async {
    await _ensureLoaded();
    return _dict![word.toLowerCase().trim()];
  }

  /// Synchronous lookup — only returns a result once [lookup] (or any
  /// other call) has triggered the initial load; returns null beforehand.
  /// Used by callers that already know the dictionary is warm.
  static List<String>? lookupSync(String word) => _dict?[word.toLowerCase().trim()];

  /// Preloads the dictionary so subsequent [lookupSync] calls succeed.
  static Future<void> preload() => _ensureLoaded();
}
