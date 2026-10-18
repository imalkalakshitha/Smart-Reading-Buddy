/// Picture-cue content for Free Drawing Recognition's Letter Level intro
/// step ("A -> apple"), kept as its own lookup so cue words/emoji are easy
/// to edit without touching screen code. Keyed by the literal character
/// string as it appears in assets/models/class_names.json — never by
/// index, since that ordering is defined entirely by that file.
///
/// Sinhala entries are intentionally left empty for now: cue words need to
/// be exact, verified Sinhala text (this project's established rule is to
/// never hand-type/retype Sinhala Unicode — see other *_si_text.dart files
/// for the verified transcription pipeline used instead), and the real
/// Sinhala class list isn't known here until class_names.json is in place.
/// The Letter Level intro screen simply omits the cue section when a
/// character has no entry, matching the app's existing empty-state
/// convention elsewhere. Fill these in once the real class names are
/// confirmed.
class FreeDrawingCue {
  final String word;
  final String emoji;
  const FreeDrawingCue(this.word, this.emoji);
}

const Map<String, FreeDrawingCue> freeDrawingCues = {
  'A': FreeDrawingCue('Apple', '🍎'),
  'B': FreeDrawingCue('Ball', '⚽'),
  'C': FreeDrawingCue('Cat', '🐱'),
  'D': FreeDrawingCue('Dog', '🐶'),
  'E': FreeDrawingCue('Egg', '🥚'),
  'F': FreeDrawingCue('Fish', '🐟'),
  'G': FreeDrawingCue('Grapes', '🍇'),
  'H': FreeDrawingCue('Hat', '🎩'),
  'I': FreeDrawingCue('Ice cream', '🍦'),
  'J': FreeDrawingCue('Jug', '🫙'),
  'K': FreeDrawingCue('Kite', '🪁'),
  'L': FreeDrawingCue('Lion', '🦁'),
  'M': FreeDrawingCue('Moon', '🌙'),
  'N': FreeDrawingCue('Nest', '🪺'),
  'O': FreeDrawingCue('Orange', '🍊'),
  'P': FreeDrawingCue('Pig', '🐷'),
  'Q': FreeDrawingCue('Queen', '👸'),
  'R': FreeDrawingCue('Rain', '🌧️'),
  'S': FreeDrawingCue('Sun', '☀️'),
  'T': FreeDrawingCue('Tree', '🌳'),
  'U': FreeDrawingCue('Umbrella', '☂️'),
  'V': FreeDrawingCue('Van', '🚐'),
  'W': FreeDrawingCue('Watch', '⌚'),
  'X': FreeDrawingCue('X-ray', '🩻'),
  'Y': FreeDrawingCue('Yo-yo', '🪀'),
  'Z': FreeDrawingCue('Zebra', '🦓'),
};

/// Looks up a cue for [character], trying the uppercase form first (the
/// map above is uppercase-only — same cue word works for 'a' as for 'A').
/// Returns null when there's no cue yet (e.g. Sinhala) — callers must
/// treat that as "omit this section", not an error.
FreeDrawingCue? cueFor(String character) => freeDrawingCues[character.toUpperCase()];
