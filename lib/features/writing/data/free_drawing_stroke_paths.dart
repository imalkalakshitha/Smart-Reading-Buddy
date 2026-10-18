import 'package:flutter/material.dart';
import 'package:smart_reading_buddy/features/writing/data/writing_data.dart' as guided_tracing;

/// Stroke-order paths for Free Drawing Recognition's Letter Level intro
/// animation. Reuses the normalized (0.0-1.0) stroke coordinates the
/// Guided Tracing feature already has for English uppercase letters
/// (read-only — writing_data.dart itself is untouched) rather than
/// duplicating ~700 lines of hand-authored coordinates.
///
/// No verified stroke data exists yet for English lowercase or the full
/// 43-character Sinhala set the model covers (Guided Tracing's own
/// Sinhala list only has 33, a different set than class_names.json's 43).
/// Returns null for those — the intro screen omits the animation section
/// when there's nothing to show, same empty-state convention used
/// elsewhere in the app.
List<List<Offset>>? getFreeDrawingStrokes(String character, {required bool isSinhala}) {
  if (isSinhala) return null;
  if (character.length != 1) return null;
  // Only look up already-uppercase input — matching a lowercase target
  // (e.g. 'a') against the uppercase-shaped 'A' path would show the wrong
  // letterform, which is worse than showing no animation at all.
  if (character != character.toUpperCase()) return null;
  return guided_tracing.letterPaths[character];
}
