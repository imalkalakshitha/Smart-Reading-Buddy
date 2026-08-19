// EduPlay enums/constants shared across the engine — see
// eduplay_dart_engine_prompt.txt for the source spec.

const List<String> kActivityTypes = [
  'letter_drag_drop',
  'word_recognition',
  'fill_blanks_word',
  'sentence_drag_drop',
  'sentence_quiz',
];

const Map<String, String> kActivityDisplayNames = {
  'letter_drag_drop': 'Letter Drag & Drop',
  'word_recognition': 'Word Recognition',
  'fill_blanks_word': 'Fill in the Blanks',
  'sentence_drag_drop': 'Sentence Drag & Drop',
  'sentence_quiz': 'Sentence Quiz',
};

const List<String> kSkillAreas = [
  'letter_order',
  'meaning_understanding',
  'sentence_order',
  'sound_recognition',
  'spelling_gap',
];

const Map<String, String> kSkillDisplayNames = {
  'letter_order': 'Letter Order',
  'meaning_understanding': 'Meaning Understanding',
  'sentence_order': 'Sentence Order',
  'sound_recognition': 'Sound Recognition',
  'spelling_gap': 'Spelling',
};

const List<String> kMistakeTypes = [
  'none',
  'letter_order_error',
  'meaning_error',
  'missing_letter',
  'sentence_order_error',
  'sound_confusion',
  'wrong_action',
  'wrong_object',
  'wrong_subject',
];

const int kMinSessionsBeforeML = 3; // cold-start threshold
