// EduPlay enums/constants shared across the engine — see
// eduplay_dart_engine_prompt.txt for the source spec.

import 'package:flutter/material.dart';

// Per-lesson accent colors for the Duolingo-style redesign. Wrong-answer
// feedback always stays amber regardless of these — see activity_screen.dart.
const Map<String, Color> kLessonColors = {
  'letter_drag_drop': Color(0xFFFF6B6B),
  'word_recognition': Color(0xFF14B8A6),
  'fill_blanks_word': Color(0xFFF59E0B),
  'sentence_drag_drop': Color(0xFF8B5CF6),
  'sentence_quiz': Color(0xFF3B82F6),
};

const Map<String, Color> kLessonBgTints = {
  'letter_drag_drop': Color(0xFFFFF1F0),
  'word_recognition': Color(0xFFEEFBF9),
  'fill_blanks_word': Color(0xFFFFF8EB),
  'sentence_drag_drop': Color(0xFFF5F0FF),
  'sentence_quiz': Color(0xFFEEF4FF),
};

const Map<String, String> kLessonDescriptions = {
  'letter_drag_drop': 'Listen to a word and build it with letters!',
  'word_recognition': 'Listen carefully and choose the right word.',
  'fill_blanks_word': 'Find the missing letter or word.',
  'sentence_drag_drop': 'Put the words in the right order.',
  'sentence_quiz': 'Listen to a sentence and answer the question.',
};

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

// Tasks drawn per session for the 5 EduPlay activities. Not previously
// defined anywhere in the codebase — added here as part of the session
// rotation fix (getTasksFor now caps + shuffles by attempt count).
const int kSessionLength = 8;
