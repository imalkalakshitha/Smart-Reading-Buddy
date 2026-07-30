// ── EduPlay Grade 3 Basic — Lesson Data ──────────────────────────────────────

class DragDropWord {
  final String word;
  final List<String> letters; // shuffled letters to drag
  final String emoji;

  const DragDropWord({
    required this.word,
    required this.letters,
    required this.emoji,
  });
}

class SoundWord {
  final String word;
  final List<String> options;
  final String correctAnswer;
  final String emoji;

  const SoundWord({
    required this.word,
    required this.options,
    required this.correctAnswer,
    required this.emoji,
  });
}

class SpellingWord {
  final String fullWord;    // "CAT"
  final int blankIndex;     // 1 → "C _ T"
  final List<String> options;
  final String correctLetter;
  final String emoji;

  const SpellingWord({
    required this.fullWord,
    required this.blankIndex,
    required this.options,
    required this.correctLetter,
    required this.emoji,
  });

  String get displayWord {
    final chars = fullWord.split('');
    chars[blankIndex] = '_';
    return chars.join(' ');
  }
}

class SentenceItem {
  final String sentence;             // "The boy eats rice."
  final List<String> wordChoices;    // all draggable words (includes distractors)
  final List<String> correctOrder;  // ["The", "boy", "eats", "rice"]
  final String emoji;               // scene image

  const SentenceItem({
    required this.sentence,
    required this.wordChoices,
    required this.correctOrder,
    required this.emoji,
  });
}

class MeaningQuestion {
  final String sentence;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String emoji;

  const MeaningQuestion({
    required this.sentence,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.emoji,
  });
}

// ── Lesson 1: Drag and Drop Letters ──────────────────────────────────────────

const List<DragDropWord> lesson1Words = [
  DragDropWord(word: 'CAT', letters: ['A', 'T', 'C'],      emoji: '🐱'),
  DragDropWord(word: 'DOG', letters: ['D', 'O', 'G'],      emoji: '🐶'),
  DragDropWord(word: 'SUN', letters: ['N', 'S', 'U'],      emoji: '☀️'),
  DragDropWord(word: 'HAT', letters: ['H', 'T', 'A'],      emoji: '🎩'),
  DragDropWord(word: 'PIG', letters: ['P', 'I', 'G'],      emoji: '🐷'),
];

// ── Lesson 2: Word Sound Recognition ─────────────────────────────────────────

const List<SoundWord> lesson2Words = [
  SoundWord(
    word: 'Cat',
    options: ['Cat', 'Cut', 'Hat', 'Bat'],
    correctAnswer: 'Cat',
    emoji: '🐱',
  ),
  SoundWord(
    word: 'Dog',
    options: ['Fog', 'Dog', 'Log', 'Hog'],
    correctAnswer: 'Dog',
    emoji: '🐶',
  ),
  SoundWord(
    word: 'Sun',
    options: ['Fun', 'Run', 'Sun', 'Gun'],
    correctAnswer: 'Sun',
    emoji: '☀️',
  ),
  SoundWord(
    word: 'Pig',
    options: ['Big', 'Fig', 'Wig', 'Pig'],
    correctAnswer: 'Pig',
    emoji: '🐷',
  ),
  SoundWord(
    word: 'Hat',
    options: ['Hat', 'Mat', 'Bat', 'Rat'],
    correctAnswer: 'Hat',
    emoji: '🎩',
  ),
];

// ── Lesson 3: Missing Spelling Practice ──────────────────────────────────────

const List<SpellingWord> lesson3Words = [
  SpellingWord(
    fullWord: 'CAT',
    blankIndex: 1,
    options: ['O', 'A', 'E'],
    correctLetter: 'A',
    emoji: '🐱',
  ),
  SpellingWord(
    fullWord: 'DOG',
    blankIndex: 1,
    options: ['A', 'O', 'U'],
    correctLetter: 'O',
    emoji: '🐶',
  ),
  SpellingWord(
    fullWord: 'SUN',
    blankIndex: 0,
    options: ['B', 'S', 'R'],
    correctLetter: 'S',
    emoji: '☀️',
  ),
  SpellingWord(
    fullWord: 'PIG',
    blankIndex: 2,
    options: ['T', 'K', 'G'],
    correctLetter: 'G',
    emoji: '🐷',
  ),
  SpellingWord(
    fullWord: 'HAT',
    blankIndex: 1,
    options: ['E', 'A', 'I'],
    correctLetter: 'A',
    emoji: '🎩',
  ),
];

// ── Lesson 4: Sentence Drag and Drop ─────────────────────────────────────────

const List<SentenceItem> lesson4Sentences = [
  SentenceItem(
    sentence: 'The boy eats rice.',
    wordChoices: ['The', 'boy', 'eats', 'rice', 'runs', 'apple'],
    correctOrder: ['The', 'boy', 'eats', 'rice'],
    emoji: '🧒🍚',
  ),
  SentenceItem(
    sentence: 'The cat sits here.',
    wordChoices: ['The', 'cat', 'sits', 'here', 'jumps', 'dog'],
    correctOrder: ['The', 'cat', 'sits', 'here'],
    emoji: '🐱🛋️',
  ),
  SentenceItem(
    sentence: 'A dog runs fast.',
    wordChoices: ['A', 'dog', 'runs', 'fast', 'eats', 'bird'],
    correctOrder: ['A', 'dog', 'runs', 'fast'],
    emoji: '🐶💨',
  ),
];

// ── Lesson 5: Sentence Meaning Quiz ──────────────────────────────────────────

const List<MeaningQuestion> lesson5Questions = [
  MeaningQuestion(
    sentence: 'The boy eats rice.',
    question: 'Who eats rice?',
    options: ['Boy', 'Girl', 'Dog', 'Cat'],
    correctAnswer: 'Boy',
    emoji: '🧒🍚',
  ),
  MeaningQuestion(
    sentence: 'The cat sits on a mat.',
    question: 'Where does the cat sit?',
    options: ['Chair', 'Table', 'Mat', 'Bed'],
    correctAnswer: 'Mat',
    emoji: '🐱🛋️',
  ),
  MeaningQuestion(
    sentence: 'The sun is hot.',
    question: 'What is hot?',
    options: ['Moon', 'Star', 'Sun', 'Rain'],
    correctAnswer: 'Sun',
    emoji: '☀️🔥',
  ),
];

// ── Lesson Metadata ───────────────────────────────────────────────────────────

class LessonInfo {
  final int number;
  final String title;
  final String description;
  final String icon;

  const LessonInfo({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });
}

const List<LessonInfo> allLessons = [
  LessonInfo(
    number: 1,
    title: 'Drag and Drop Letters',
    description: 'Listen to a word and build it by dragging letters!',
    icon: '🔤',
  ),
  LessonInfo(
    number: 2,
    title: 'Word Sound Recognition',
    description: 'Listen carefully and choose the correct word.',
    icon: '👂',
  ),
  LessonInfo(
    number: 3,
    title: 'Missing Spelling Practice',
    description: 'Find the missing letter and complete the word!',
    icon: '✏️',
  ),
  LessonInfo(
    number: 4,
    title: 'Sentence Drag and Drop',
    description: 'Drag words to build sentences!',
    icon: '📝',
  ),
  LessonInfo(
    number: 5,
    title: 'Sentence Meaning Quiz',
    description: 'Listen and choose the correct meaning!',
    icon: '💡',
  ),
];
