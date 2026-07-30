// Writing module data: letter paths (normalized 0.0–1.0 coords), word lists, WritingArgs.

import 'package:flutter/material.dart';

// ── Args ──────────────────────────────────────────────────────────────────────

class WritingArgs {
  final String language; // 'en' or 'si'
  final int grade;       // 3 or 4
  final int profileId;
  final List<String>? levelLetters; // null = all letters
  final int levelNumber;            // 0 = all, 1-based for display

  const WritingArgs({
    required this.language,
    required this.grade,
    required this.profileId,
    this.levelLetters,
    this.levelNumber = 0,
  });

  bool get isSinhala => language == 'si';
}

// ── Word lists ─────────────────────────────────────────────────────────────────

const Map<String, List<String>> writingWords = {
  'en_3': ['Cat', 'Dog', 'Pig', 'Sun', 'Pen', 'Fish', 'Jump', 'Rock', 'Rain', 'Ship'],
  'en_4': ['Table', 'Mother', 'River', 'Weather', 'Paper', 'Window', 'Green', 'Beach'],
  'si_3': ['ගම', 'එක', 'ඇය', 'කෙසෙල්', 'මුහුද', 'තීන්ත', 'පැන්සල්'],
  'si_4': ['ගම', 'එක', 'ඇය', 'කෙසෙල්', 'මුහුද', 'තීන්ත', 'පැන්සල්'],
};

List<String> getWritingWords(String language, int grade) =>
    writingWords['${language}_$grade'] ?? writingWords['en_3']!;

// ── English uppercase letter paths (normalized 0.0–1.0) ──────────────────────
// Each letter: list of strokes. Each stroke: list of waypoints.
// x=0 left, x=1 right, y=0 top, y=1 bottom.

const Map<String, List<List<Offset>>> letterPaths = {
  'A': [
    [Offset(0.50, 0.05), Offset(0.20, 0.95)],
    [Offset(0.50, 0.05), Offset(0.80, 0.95)],
    [Offset(0.32, 0.55), Offset(0.68, 0.55)],
  ],
  'B': [
    [Offset(0.28, 0.05), Offset(0.28, 0.95)],
    [Offset(0.28, 0.05), Offset(0.62, 0.05), Offset(0.75, 0.18), Offset(0.75, 0.38), Offset(0.62, 0.50), Offset(0.28, 0.50)],
    [Offset(0.28, 0.50), Offset(0.68, 0.50), Offset(0.80, 0.62), Offset(0.80, 0.82), Offset(0.68, 0.95), Offset(0.28, 0.95)],
  ],
  'C': [
    [Offset(0.78, 0.22), Offset(0.60, 0.08), Offset(0.40, 0.08), Offset(0.22, 0.20), Offset(0.15, 0.40), Offset(0.15, 0.60), Offset(0.22, 0.80), Offset(0.40, 0.92), Offset(0.60, 0.92), Offset(0.78, 0.78)],
  ],
  'D': [
    [Offset(0.28, 0.05), Offset(0.28, 0.95)],
    [Offset(0.28, 0.05), Offset(0.58, 0.05), Offset(0.80, 0.20), Offset(0.82, 0.50), Offset(0.80, 0.80), Offset(0.58, 0.95), Offset(0.28, 0.95)],
  ],
  'E': [
    [Offset(0.28, 0.05), Offset(0.28, 0.95)],
    [Offset(0.28, 0.05), Offset(0.72, 0.05)],
    [Offset(0.28, 0.50), Offset(0.62, 0.50)],
    [Offset(0.28, 0.95), Offset(0.72, 0.95)],
  ],
  'F': [
    [Offset(0.28, 0.05), Offset(0.28, 0.95)],
    [Offset(0.28, 0.05), Offset(0.72, 0.05)],
    [Offset(0.28, 0.50), Offset(0.62, 0.50)],
  ],
  'G': [
    [Offset(0.78, 0.22), Offset(0.60, 0.08), Offset(0.40, 0.08), Offset(0.22, 0.20), Offset(0.15, 0.40), Offset(0.15, 0.60), Offset(0.22, 0.80), Offset(0.40, 0.92), Offset(0.60, 0.92), Offset(0.78, 0.80), Offset(0.78, 0.55), Offset(0.55, 0.55)],
  ],
  'H': [
    [Offset(0.28, 0.05), Offset(0.28, 0.95)],
    [Offset(0.72, 0.05), Offset(0.72, 0.95)],
    [Offset(0.28, 0.50), Offset(0.72, 0.50)],
  ],
  'I': [
    [Offset(0.30, 0.05), Offset(0.70, 0.05)],
    [Offset(0.50, 0.05), Offset(0.50, 0.95)],
    [Offset(0.30, 0.95), Offset(0.70, 0.95)],
  ],
  'J': [
    [Offset(0.40, 0.05), Offset(0.70, 0.05)],
    [Offset(0.60, 0.05), Offset(0.60, 0.78), Offset(0.50, 0.92), Offset(0.35, 0.88), Offset(0.28, 0.75)],
  ],
  'K': [
    [Offset(0.28, 0.05), Offset(0.28, 0.95)],
    [Offset(0.72, 0.05), Offset(0.28, 0.52)],
    [Offset(0.28, 0.52), Offset(0.75, 0.95)],
  ],
  'L': [
    [Offset(0.28, 0.05), Offset(0.28, 0.95)],
    [Offset(0.28, 0.95), Offset(0.72, 0.95)],
  ],
  'M': [
    [Offset(0.18, 0.05), Offset(0.18, 0.95)],
    [Offset(0.18, 0.05), Offset(0.50, 0.52)],
    [Offset(0.50, 0.52), Offset(0.82, 0.05)],
    [Offset(0.82, 0.05), Offset(0.82, 0.95)],
  ],
  'N': [
    [Offset(0.25, 0.05), Offset(0.25, 0.95)],
    [Offset(0.25, 0.05), Offset(0.75, 0.95)],
    [Offset(0.75, 0.05), Offset(0.75, 0.95)],
  ],
  'O': [
    [Offset(0.50, 0.05), Offset(0.72, 0.10), Offset(0.85, 0.28), Offset(0.85, 0.50), Offset(0.85, 0.72), Offset(0.72, 0.90), Offset(0.50, 0.95), Offset(0.28, 0.90), Offset(0.15, 0.72), Offset(0.15, 0.50), Offset(0.15, 0.28), Offset(0.28, 0.10), Offset(0.50, 0.05)],
  ],
  'P': [
    [Offset(0.28, 0.05), Offset(0.28, 0.95)],
    [Offset(0.28, 0.05), Offset(0.62, 0.05), Offset(0.75, 0.18), Offset(0.75, 0.40), Offset(0.62, 0.52), Offset(0.28, 0.52)],
  ],
  'Q': [
    [Offset(0.50, 0.05), Offset(0.72, 0.10), Offset(0.85, 0.28), Offset(0.85, 0.50), Offset(0.85, 0.72), Offset(0.72, 0.90), Offset(0.50, 0.95), Offset(0.28, 0.90), Offset(0.15, 0.72), Offset(0.15, 0.50), Offset(0.15, 0.28), Offset(0.28, 0.10), Offset(0.50, 0.05)],
    [Offset(0.58, 0.72), Offset(0.82, 0.95)],
  ],
  'R': [
    [Offset(0.28, 0.05), Offset(0.28, 0.95)],
    [Offset(0.28, 0.05), Offset(0.62, 0.05), Offset(0.75, 0.18), Offset(0.75, 0.40), Offset(0.62, 0.52), Offset(0.28, 0.52)],
    [Offset(0.48, 0.52), Offset(0.78, 0.95)],
  ],
  'S': [
    [Offset(0.72, 0.18), Offset(0.58, 0.08), Offset(0.38, 0.08), Offset(0.22, 0.20), Offset(0.22, 0.35), Offset(0.38, 0.48), Offset(0.62, 0.52), Offset(0.78, 0.65), Offset(0.78, 0.80), Offset(0.62, 0.92), Offset(0.42, 0.92), Offset(0.28, 0.82)],
  ],
  'T': [
    [Offset(0.18, 0.08), Offset(0.82, 0.08)],
    [Offset(0.50, 0.08), Offset(0.50, 0.95)],
  ],
  'U': [
    [Offset(0.25, 0.05), Offset(0.25, 0.72), Offset(0.32, 0.88), Offset(0.50, 0.95), Offset(0.68, 0.88), Offset(0.75, 0.72), Offset(0.75, 0.05)],
  ],
  'V': [
    [Offset(0.20, 0.05), Offset(0.50, 0.95)],
    [Offset(0.50, 0.95), Offset(0.80, 0.05)],
  ],
  'W': [
    [Offset(0.12, 0.05), Offset(0.28, 0.95), Offset(0.50, 0.58), Offset(0.72, 0.95), Offset(0.88, 0.05)],
  ],
  'X': [
    [Offset(0.20, 0.05), Offset(0.80, 0.95)],
    [Offset(0.80, 0.05), Offset(0.20, 0.95)],
  ],
  'Y': [
    [Offset(0.20, 0.05), Offset(0.50, 0.50)],
    [Offset(0.80, 0.05), Offset(0.50, 0.50)],
    [Offset(0.50, 0.50), Offset(0.50, 0.95)],
  ],
  'Z': [
    [Offset(0.20, 0.05), Offset(0.80, 0.05)],
    [Offset(0.80, 0.05), Offset(0.20, 0.95)],
    [Offset(0.20, 0.95), Offset(0.80, 0.95)],
  ],
};

// ── Sinhala letter paths (single-stroke simplified curves) ────────────────────

const Map<String, List<List<Offset>>> sinhalaLetterPaths = {
  'අ': [
    [Offset(0.50,0.15),Offset(0.68,0.22),Offset(0.72,0.38),Offset(0.65,0.52),Offset(0.50,0.58),Offset(0.35,0.52),Offset(0.28,0.38),Offset(0.35,0.22),Offset(0.50,0.15),Offset(0.58,0.65),Offset(0.55,0.82),Offset(0.48,0.92)],
  ],
  'ආ': [
    [Offset(0.42,0.12),Offset(0.58,0.18),Offset(0.65,0.32),Offset(0.60,0.48),Offset(0.45,0.55),Offset(0.30,0.48),Offset(0.25,0.32),Offset(0.32,0.18),Offset(0.42,0.12),Offset(0.50,0.62),Offset(0.58,0.78),Offset(0.62,0.92),Offset(0.50,0.95),Offset(0.38,0.90)],
  ],
  'ඇ': [
    [Offset(0.50,0.15),Offset(0.65,0.22),Offset(0.70,0.35),Offset(0.62,0.48),Offset(0.48,0.52),Offset(0.35,0.45),Offset(0.30,0.32),Offset(0.38,0.20),Offset(0.50,0.15),Offset(0.55,0.58),Offset(0.52,0.72),Offset(0.45,0.88)],
  ],
  'ඉ': [
    [Offset(0.35,0.10),Offset(0.35,0.62),Offset(0.42,0.78),Offset(0.52,0.86),Offset(0.64,0.80),Offset(0.68,0.65),Offset(0.62,0.50),Offset(0.50,0.45)],
  ],
  'ඊ': [
    [Offset(0.32,0.10),Offset(0.32,0.58),Offset(0.40,0.75),Offset(0.52,0.85),Offset(0.65,0.78),Offset(0.70,0.62),Offset(0.62,0.48),Offset(0.48,0.42),Offset(0.58,0.15),Offset(0.70,0.10)],
  ],
  'උ': [
    [Offset(0.30,0.18),Offset(0.48,0.12),Offset(0.65,0.18),Offset(0.72,0.35),Offset(0.65,0.52),Offset(0.48,0.58),Offset(0.35,0.68),Offset(0.38,0.82),Offset(0.52,0.90),Offset(0.65,0.82)],
  ],
  'ඌ': [
    [Offset(0.28,0.18),Offset(0.45,0.10),Offset(0.62,0.18),Offset(0.68,0.35),Offset(0.60,0.50),Offset(0.45,0.55),Offset(0.32,0.65),Offset(0.35,0.80),Offset(0.50,0.90),Offset(0.65,0.82),Offset(0.72,0.68)],
  ],
  'එ': [
    [Offset(0.72,0.25),Offset(0.55,0.15),Offset(0.38,0.18),Offset(0.25,0.32),Offset(0.22,0.50),Offset(0.30,0.68),Offset(0.48,0.75),Offset(0.65,0.68),Offset(0.72,0.50),Offset(0.55,0.50)],
  ],
  'ඒ': [
    [Offset(0.72,0.22),Offset(0.55,0.12),Offset(0.38,0.15),Offset(0.25,0.28),Offset(0.20,0.48),Offset(0.28,0.68),Offset(0.48,0.78),Offset(0.68,0.70),Offset(0.75,0.52),Offset(0.58,0.50),Offset(0.65,0.85),Offset(0.55,0.95)],
  ],
  'ඔ': [
    [Offset(0.50,0.12),Offset(0.68,0.20),Offset(0.75,0.38),Offset(0.68,0.55),Offset(0.50,0.60),Offset(0.32,0.55),Offset(0.25,0.38),Offset(0.32,0.20),Offset(0.50,0.12),Offset(0.58,0.68),Offset(0.72,0.80),Offset(0.68,0.92)],
  ],
  'ඕ': [
    [Offset(0.48,0.10),Offset(0.65,0.18),Offset(0.72,0.35),Offset(0.65,0.52),Offset(0.48,0.58),Offset(0.30,0.52),Offset(0.22,0.35),Offset(0.30,0.18),Offset(0.48,0.10),Offset(0.55,0.65),Offset(0.70,0.78),Offset(0.65,0.90),Offset(0.50,0.95),Offset(0.35,0.88)],
  ],
  'ක': [
    [Offset(0.35,0.10),Offset(0.35,0.90),Offset(0.50,0.50),Offset(0.65,0.22),Offset(0.72,0.40),Offset(0.68,0.60),Offset(0.55,0.72),Offset(0.65,0.88)],
  ],
  'ඛ': [
    [Offset(0.35,0.12),Offset(0.35,0.88),Offset(0.52,0.48),Offset(0.68,0.20),Offset(0.75,0.38),Offset(0.70,0.58),Offset(0.58,0.70),Offset(0.68,0.88),Offset(0.55,0.95)],
  ],
  'ග': [
    [Offset(0.72,0.28),Offset(0.55,0.15),Offset(0.38,0.18),Offset(0.25,0.32),Offset(0.22,0.52),Offset(0.32,0.70),Offset(0.50,0.78),Offset(0.65,0.70),Offset(0.70,0.52),Offset(0.55,0.52),Offset(0.48,0.65),Offset(0.55,0.82),Offset(0.45,0.92)],
  ],
  'ගඝ': [
    [Offset(0.50,0.12),Offset(0.50,0.88)],
  ],
  'ඝ': [
    [Offset(0.70,0.25),Offset(0.52,0.12),Offset(0.35,0.18),Offset(0.25,0.35),Offset(0.25,0.55),Offset(0.38,0.72),Offset(0.55,0.78),Offset(0.70,0.68),Offset(0.75,0.48),Offset(0.58,0.48),Offset(0.52,0.62),Offset(0.60,0.82),Offset(0.72,0.90)],
  ],
  'ච': [
    [Offset(0.68,0.22),Offset(0.52,0.12),Offset(0.35,0.18),Offset(0.25,0.35),Offset(0.25,0.55),Offset(0.35,0.72),Offset(0.52,0.80),Offset(0.65,0.72),Offset(0.68,0.55),Offset(0.55,0.52)],
  ],
  'ජ': [
    [Offset(0.55,0.12),Offset(0.55,0.68),Offset(0.45,0.82),Offset(0.32,0.78),Offset(0.25,0.65),Offset(0.30,0.50),Offset(0.45,0.45)],
  ],
  'ට': [
    [Offset(0.22,0.25),Offset(0.78,0.25)],
    [Offset(0.50,0.25),Offset(0.50,0.88),Offset(0.42,0.95),Offset(0.32,0.90)],
  ],
  'ඩ': [
    [Offset(0.30,0.12),Offset(0.30,0.88)],
    [Offset(0.30,0.12),Offset(0.58,0.12),Offset(0.78,0.30),Offset(0.80,0.52),Offset(0.78,0.72),Offset(0.58,0.88),Offset(0.30,0.88)],
  ],
  'ත': [
    [Offset(0.25,0.25),Offset(0.75,0.25)],
    [Offset(0.50,0.25),Offset(0.50,0.72),Offset(0.42,0.85),Offset(0.55,0.92),Offset(0.68,0.85)],
  ],
  'ද': [
    [Offset(0.68,0.20),Offset(0.50,0.12),Offset(0.32,0.20),Offset(0.25,0.38),Offset(0.28,0.58),Offset(0.45,0.72),Offset(0.62,0.65),Offset(0.68,0.48),Offset(0.55,0.48),Offset(0.48,0.62),Offset(0.55,0.80),Offset(0.45,0.92)],
  ],
  'න': [
    [Offset(0.28,0.20),Offset(0.28,0.80)],
    [Offset(0.28,0.20),Offset(0.55,0.20),Offset(0.72,0.35),Offset(0.72,0.65),Offset(0.55,0.80),Offset(0.28,0.80)],
  ],
  'ප': [
    [Offset(0.32,0.12),Offset(0.32,0.88)],
    [Offset(0.32,0.12),Offset(0.60,0.12),Offset(0.72,0.25),Offset(0.72,0.45),Offset(0.60,0.55),Offset(0.32,0.55)],
  ],
  'බ': [
    [Offset(0.30,0.12),Offset(0.30,0.88)],
    [Offset(0.30,0.12),Offset(0.58,0.12),Offset(0.72,0.25),Offset(0.72,0.42),Offset(0.58,0.52),Offset(0.30,0.52)],
    [Offset(0.30,0.52),Offset(0.62,0.52),Offset(0.75,0.65),Offset(0.75,0.78),Offset(0.62,0.88),Offset(0.30,0.88)],
  ],
  'ම': [
    [Offset(0.50,0.15),Offset(0.68,0.22),Offset(0.75,0.40),Offset(0.68,0.58),Offset(0.50,0.65),Offset(0.32,0.58),Offset(0.25,0.40),Offset(0.32,0.22),Offset(0.50,0.15),Offset(0.50,0.72),Offset(0.50,0.90)],
  ],
  'ය': [
    [Offset(0.28,0.20),Offset(0.50,0.20),Offset(0.68,0.30),Offset(0.72,0.50),Offset(0.62,0.68),Offset(0.45,0.75),Offset(0.35,0.65),Offset(0.38,0.50),Offset(0.50,0.45),Offset(0.48,0.60),Offset(0.42,0.80),Offset(0.38,0.92)],
  ],
  'ර': [
    [Offset(0.38,0.15),Offset(0.55,0.12),Offset(0.68,0.22),Offset(0.70,0.40),Offset(0.58,0.52),Offset(0.42,0.52),Offset(0.35,0.65),Offset(0.42,0.80),Offset(0.55,0.88),Offset(0.65,0.80)],
  ],
  'ල': [
    [Offset(0.35,0.12),Offset(0.35,0.72),Offset(0.42,0.85),Offset(0.55,0.92),Offset(0.68,0.85),Offset(0.72,0.70),Offset(0.65,0.55)],
  ],
  'ව': [
    [Offset(0.30,0.20),Offset(0.50,0.15),Offset(0.70,0.22),Offset(0.75,0.40),Offset(0.65,0.58),Offset(0.50,0.65),Offset(0.35,0.58),Offset(0.28,0.42),Offset(0.35,0.28)],
  ],
  'ස': [
    [Offset(0.72,0.22),Offset(0.55,0.12),Offset(0.35,0.15),Offset(0.22,0.30),Offset(0.25,0.48),Offset(0.42,0.55),Offset(0.62,0.52),Offset(0.72,0.65),Offset(0.68,0.80),Offset(0.50,0.90),Offset(0.32,0.85),Offset(0.25,0.72)],
  ],
  'හ': [
    [Offset(0.30,0.15),Offset(0.30,0.85)],
    [Offset(0.70,0.15),Offset(0.70,0.85)],
    [Offset(0.30,0.50),Offset(0.50,0.42),Offset(0.70,0.50)],
  ],
  'ළ': [
    [Offset(0.35,0.12),Offset(0.35,0.68),Offset(0.42,0.82),Offset(0.55,0.90),Offset(0.68,0.82),Offset(0.72,0.68),Offset(0.65,0.52),Offset(0.58,0.52)],
  ],
  'ෆ': [
    [Offset(0.50,0.12),Offset(0.65,0.20),Offset(0.70,0.38),Offset(0.62,0.55),Offset(0.45,0.60),Offset(0.30,0.52),Offset(0.25,0.35),Offset(0.35,0.20),Offset(0.50,0.15),Offset(0.50,0.68),Offset(0.45,0.85),Offset(0.32,0.92)],
  ],
};

// ── Letter lists ───────────────────────────────────────────────────────────────

const List<String> englishLetters = [
  'A','B','C','D','E','F','G','H','I','J','K','L','M',
  'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
];

const List<String> sinhalaLetters = [
  'අ','ආ','ඇ','ඉ','ඊ','උ','ඌ','එ','ඒ','ඔ','ඕ',
  'ක','ඛ','ග','ඝ','ච','ජ','ට','ඩ','ත','ද','න',
  'ප','බ','ම','ය','ර','ල','ව','ස','හ','ළ','ෆ',
];

List<String> getLetterList(String language) =>
    language == 'si' ? sinhalaLetters : englishLetters;

List<List<Offset>>? getLetterStrokes(String letter, bool isSinhala) {
  if (isSinhala) return sinhalaLetterPaths[letter];
  return letterPaths[letter.toUpperCase()];
}

// ── XP helper ─────────────────────────────────────────────────────────────────

int xpForAccuracy(double accuracy) {
  if (accuracy >= 90) return 15;
  if (accuracy >= 70) return 10;
  if (accuracy >= 50) return 5;
  return 0;
}

int starsForAccuracy(double accuracy) {
  if (accuracy >= 90) return 3;
  if (accuracy >= 70) return 2;
  if (accuracy >= 50) return 1;
  return 0;
}

// ── Letter level groups for progression-based unlocking ───────────────────────

const Map<String, List<List<String>>> letterLevels = {
  'en': [
    ['A', 'B', 'C', 'D', 'E'],
    ['F', 'G', 'H', 'I', 'J'],
    ['K', 'L', 'M', 'N', 'O'],
    ['P', 'Q', 'R', 'S', 'T'],
    ['U', 'V', 'W', 'X', 'Y', 'Z'],
  ],
  'si': [
    ['අ', 'ආ', 'ඇ', 'ඉ', 'ඊ'],
    ['උ', 'ඌ', 'එ', 'ඒ', 'ඔ', 'ඕ'],
    ['ක', 'ඛ', 'ග', 'ඝ', 'ච'],
    ['ජ', 'ට', 'ඩ', 'ත', 'ද', 'න'],
    ['ප', 'බ', 'ම', 'ය', 'ර'],
    ['ල', 'ව', 'ස', 'හ', 'ළ', 'ෆ'],
  ],
};
