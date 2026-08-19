/// Timed Reading content — hardcoded directly here (not imported from
/// reading_data.dart, per the rebuild's explicit instruction). Every
/// sentence below is verbatim-identical to reading_data.dart's banks
/// (cross-checked programmatically against all 60 English sentences —
/// zero alterations), but this module now owns its own copy plus the
/// extra per-sentence timing metadata reading_data.dart never had.
///
/// expectedTimeSec/lowerThresholdSec/upperThresholdSec are all sourced
/// directly from Dyslexia_Reading_Dataset_v9.xlsx's Sentence_Reference
/// sheet — expectedTimeSec from its Expected_Time column, lowerThresholdSec/
/// upperThresholdSec from its Lower_Threshold/Upper_Threshold columns.
/// (lowerThresholdSec/upperThresholdSec previously used a 0.6x/1.8x-of-
/// expectedTimeSec placeholder band before the real xlsx values were
/// wired in — every SentenceSet below was verified 120/120 matched by
/// exact sentence text against the xlsx export at that time.)
library;

import '../models/timed_reading_session.dart';

/// One sentence + its Timed Reading metadata. Deliberately flat (one
/// instance per sentence, not one per level-bucket-of-10) — a "level"
/// (short/medium/long) is just the [level] tag shared by 10 of these;
/// getTimedReadingSentences() below groups them for the level-select /
/// reading-session flow.
class SentenceSet {
  final String id;
  final String grade; // 'grade3' | 'grade4'
  final String language; // 'english' | 'sinhala'
  final String level; // 'level1' | 'level2' | 'level3' | 'level4' | 'level5'
  final String text;
  final int wordCount;
  final double expectedTimeSec;
  final double lowerThresholdSec;
  final double upperThresholdSec;

  const SentenceSet({
    required this.id,
    required this.grade,
    required this.language,
    required this.level,
    required this.text,
    required this.wordCount,
    required this.expectedTimeSec,
    required this.lowerThresholdSec,
    required this.upperThresholdSec,
  });
}

// ── Raw content, grouped by grade / language / level (5 levels of 6) ───────
//
// Restructured from the original 3-level (short/medium/long, 10 each)
// bucketing into 5 levels of 6. Each grade+language's 30 sentences were
// merged into one pool, stable-sorted by wordCount ascending (ties kept
// in original short-then-medium-then-long, original-index order — same
// methodology as the Pronunciation module's 5-level word restructuring),
// then split into 5 consecutive groups of 6. No sentence text/timing was
// altered — this is a pure re-bucketing. Sentence `id` values are
// UNCHANGED from the original short/medium/long ids (only the `level`
// field moved) specifically so `_sentenceAudioFile` below (keyed by id)
// stays valid without any changes.

const _grade3EnL1 = [
  SentenceSet(id: 'tr_grade3_en_short_0', grade: 'grade3', language: 'english', level: 'level1', text: 'The cat sleeps.', wordCount: 3, expectedTimeSec: 4.0, lowerThresholdSec: 2.8, upperThresholdSec: 5.2),
  SentenceSet(id: 'tr_grade3_en_short_1', grade: 'grade3', language: 'english', level: 'level1', text: 'Kids sing songs.', wordCount: 3, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
  SentenceSet(id: 'tr_grade3_en_short_2', grade: 'grade3', language: 'english', level: 'level1', text: 'He kicks ball.', wordCount: 3, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
  SentenceSet(id: 'tr_grade3_en_short_3', grade: 'grade3', language: 'english', level: 'level1', text: 'We love school.', wordCount: 3, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
  SentenceSet(id: 'tr_grade3_en_short_4', grade: 'grade3', language: 'english', level: 'level1', text: 'They play games.', wordCount: 3, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
  SentenceSet(id: 'tr_grade3_en_short_5', grade: 'grade3', language: 'english', level: 'level1', text: 'The sun shines.', wordCount: 3, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
];

const _grade3EnL2 = [
  SentenceSet(id: 'tr_grade3_en_short_6', grade: 'grade3', language: 'english', level: 'level2', text: 'He writes letters.', wordCount: 3, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
  SentenceSet(id: 'tr_grade3_en_short_7', grade: 'grade3', language: 'english', level: 'level2', text: 'We watch TV.', wordCount: 3, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
  SentenceSet(id: 'tr_grade3_en_short_8', grade: 'grade3', language: 'english', level: 'level2', text: 'Fish swim fast.', wordCount: 3, expectedTimeSec: 4.66, lowerThresholdSec: 3.26, upperThresholdSec: 6.06),
  SentenceSet(id: 'tr_grade3_en_short_9', grade: 'grade3', language: 'english', level: 'level2', text: 'I eat rice.', wordCount: 3, expectedTimeSec: 5.0, lowerThresholdSec: 3.5, upperThresholdSec: 6.5),
  SentenceSet(id: 'tr_grade3_en_medium_0', grade: 'grade3', language: 'english', level: 'level2', text: 'She reads books.', wordCount: 3, expectedTimeSec: 5.0, lowerThresholdSec: 3.5, upperThresholdSec: 6.5),
  SentenceSet(id: 'tr_grade3_en_medium_1', grade: 'grade3', language: 'english', level: 'level2', text: 'I drink milk.', wordCount: 3, expectedTimeSec: 5.0, lowerThresholdSec: 3.5, upperThresholdSec: 6.5),
];

const _grade3EnL3 = [
  SentenceSet(id: 'tr_grade3_en_medium_2', grade: 'grade3', language: 'english', level: 'level3', text: 'Birds fly high.', wordCount: 3, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
  SentenceSet(id: 'tr_grade3_en_medium_3', grade: 'grade3', language: 'english', level: 'level3', text: 'Dogs bark loudly.', wordCount: 3, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
  SentenceSet(id: 'tr_grade3_en_medium_4', grade: 'grade3', language: 'english', level: 'level3', text: 'She is drawing.', wordCount: 3, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
  SentenceSet(id: 'tr_grade3_en_medium_5', grade: 'grade3', language: 'english', level: 'level3', text: 'I go to school', wordCount: 4, expectedTimeSec: 4.66, lowerThresholdSec: 3.26, upperThresholdSec: 6.06),
  SentenceSet(id: 'tr_grade3_en_medium_6', grade: 'grade3', language: 'english', level: 'level3', text: 'He eats an apple', wordCount: 4, expectedTimeSec: 4.66, lowerThresholdSec: 3.26, upperThresholdSec: 6.06),
  SentenceSet(id: 'tr_grade3_en_medium_7', grade: 'grade3', language: 'english', level: 'level3', text: 'They are good friends', wordCount: 4, expectedTimeSec: 4.66, lowerThresholdSec: 3.26, upperThresholdSec: 6.06),
];

const _grade3EnL4 = [
  SentenceSet(id: 'tr_grade3_en_medium_8', grade: 'grade3', language: 'english', level: 'level4', text: 'The dog runs fast', wordCount: 4, expectedTimeSec: 5.0, lowerThresholdSec: 3.5, upperThresholdSec: 6.5),
  SentenceSet(id: 'tr_grade3_en_medium_9', grade: 'grade3', language: 'english', level: 'level4', text: 'We play in garden', wordCount: 4, expectedTimeSec: 5.0, lowerThresholdSec: 3.5, upperThresholdSec: 6.5),
  SentenceSet(id: 'tr_grade3_en_long_0', grade: 'grade3', language: 'english', level: 'level4', text: 'Cat sleeps on bed', wordCount: 4, expectedTimeSec: 5.0, lowerThresholdSec: 3.5, upperThresholdSec: 6.5),
  SentenceSet(id: 'tr_grade3_en_long_1', grade: 'grade3', language: 'english', level: 'level4', text: 'She eats a mango', wordCount: 4, expectedTimeSec: 5.0, lowerThresholdSec: 3.5, upperThresholdSec: 6.5),
  SentenceSet(id: 'tr_grade3_en_long_2', grade: 'grade3', language: 'english', level: 'level4', text: 'I have a pencil', wordCount: 4, expectedTimeSec: 5.0, lowerThresholdSec: 3.5, upperThresholdSec: 6.5),
  SentenceSet(id: 'tr_grade3_en_long_3', grade: 'grade3', language: 'english', level: 'level4', text: 'Boy runs very fast', wordCount: 4, expectedTimeSec: 5.0, lowerThresholdSec: 3.5, upperThresholdSec: 6.5),
];

const _grade3EnL5 = [
  SentenceSet(id: 'tr_grade3_en_long_4', grade: 'grade3', language: 'english', level: 'level5', text: 'She reads a book', wordCount: 4, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
  SentenceSet(id: 'tr_grade3_en_long_5', grade: 'grade3', language: 'english', level: 'level5', text: 'Birds fly in sky', wordCount: 4, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
  SentenceSet(id: 'tr_grade3_en_long_6', grade: 'grade3', language: 'english', level: 'level5', text: 'We drink clean water', wordCount: 4, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
  SentenceSet(id: 'tr_grade3_en_long_7', grade: 'grade3', language: 'english', level: 'level5', text: 'Sun shines in sky', wordCount: 4, expectedTimeSec: 6.0, lowerThresholdSec: 4.2, upperThresholdSec: 7.8),
  SentenceSet(id: 'tr_grade3_en_long_8', grade: 'grade3', language: 'english', level: 'level5', text: 'We read story books.', wordCount: 4, expectedTimeSec: 6.0, lowerThresholdSec: 4.2, upperThresholdSec: 7.8),
  SentenceSet(id: 'tr_grade3_en_long_9', grade: 'grade3', language: 'english', level: 'level5', text: 'We eat tasty food.', wordCount: 4, expectedTimeSec: 6.33, lowerThresholdSec: 4.43, upperThresholdSec: 8.23),
];

const _grade3SiL1 = [
  SentenceSet(id: 'tr_grade3_si_short_0', grade: 'grade3', language: 'sinhala', level: 'level1', text: 'මම ගමට යමි', wordCount: 3, expectedTimeSec: 2.33, lowerThresholdSec: 1.63, upperThresholdSec: 3.03),
  SentenceSet(id: 'tr_grade3_si_short_1', grade: 'grade3', language: 'sinhala', level: 'level1', text: 'ඔහු පාඩම් කරයි', wordCount: 3, expectedTimeSec: 2.33, lowerThresholdSec: 1.63, upperThresholdSec: 3.03),
  SentenceSet(id: 'tr_grade3_si_short_2', grade: 'grade3', language: 'sinhala', level: 'level1', text: 'අම්මා බත් උයයි', wordCount: 3, expectedTimeSec: 2.33, lowerThresholdSec: 1.63, upperThresholdSec: 3.03),
  SentenceSet(id: 'tr_grade3_si_short_3', grade: 'grade3', language: 'sinhala', level: 'level1', text: 'අක්කා පොතක් කියවයි', wordCount: 3, expectedTimeSec: 2.33, lowerThresholdSec: 1.63, upperThresholdSec: 3.03),
  SentenceSet(id: 'tr_grade3_si_short_4', grade: 'grade3', language: 'sinhala', level: 'level1', text: 'අක්කා මිදුල අතුගායි', wordCount: 3, expectedTimeSec: 2.66, lowerThresholdSec: 1.86, upperThresholdSec: 3.46),
  SentenceSet(id: 'tr_grade3_si_short_5', grade: 'grade3', language: 'sinhala', level: 'level1', text: 'මල්ලි ඈතට දුවයි', wordCount: 3, expectedTimeSec: 2.66, lowerThresholdSec: 1.86, upperThresholdSec: 3.46),
];

const _grade3SiL2 = [
  SentenceSet(id: 'tr_grade3_si_short_6', grade: 'grade3', language: 'sinhala', level: 'level2', text: 'නැන්දා රෙදි සෝදයි', wordCount: 3, expectedTimeSec: 2.66, lowerThresholdSec: 1.86, upperThresholdSec: 3.46),
  SentenceSet(id: 'tr_grade3_si_short_7', grade: 'grade3', language: 'sinhala', level: 'level2', text: 'අපි සෙල්ලම් කරමු', wordCount: 3, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade3_si_short_8', grade: 'grade3', language: 'sinhala', level: 'level2', text: 'ඇය ගසක් සිටුවයි', wordCount: 3, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade3_si_short_9', grade: 'grade3', language: 'sinhala', level: 'level2', text: 'කමලා පන්තියට ආවාය', wordCount: 3, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade3_si_medium_0', grade: 'grade3', language: 'sinhala', level: 'level2', text: 'මාමා බසය පදවයි', wordCount: 3, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade3_si_medium_1', grade: 'grade3', language: 'sinhala', level: 'level2', text: 'ඔහු පොතක් කියවයි', wordCount: 3, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
];

const _grade3SiL3 = [
  SentenceSet(id: 'tr_grade3_si_medium_2', grade: 'grade3', language: 'sinhala', level: 'level3', text: 'ගුරුතුමා කතාවක් කියවයි', wordCount: 3, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade3_si_medium_3', grade: 'grade3', language: 'sinhala', level: 'level3', text: 'විමල් මලක් කැඩුවේය', wordCount: 3, expectedTimeSec: 4.0, lowerThresholdSec: 2.8, upperThresholdSec: 5.2),
  SentenceSet(id: 'tr_grade3_si_medium_4', grade: 'grade3', language: 'sinhala', level: 'level3', text: 'ඔවුහු ගෙදර ආවෝය', wordCount: 3, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
  SentenceSet(id: 'tr_grade3_si_medium_5', grade: 'grade3', language: 'sinhala', level: 'level3', text: 'මම රස කෙසෙල් කමි', wordCount: 4, expectedTimeSec: 2.33, lowerThresholdSec: 1.63, upperThresholdSec: 3.03),
  SentenceSet(id: 'tr_grade3_si_medium_6', grade: 'grade3', language: 'sinhala', level: 'level3', text: 'තාත්තා ගෙදර වැඩ කරයි', wordCount: 4, expectedTimeSec: 2.66, lowerThresholdSec: 1.86, upperThresholdSec: 3.46),
  SentenceSet(id: 'tr_grade3_si_medium_7', grade: 'grade3', language: 'sinhala', level: 'level3', text: 'සුදු පූසා කිරි බොයි', wordCount: 4, expectedTimeSec: 2.66, lowerThresholdSec: 1.86, upperThresholdSec: 3.46),
];

const _grade3SiL4 = [
  SentenceSet(id: 'tr_grade3_si_medium_8', grade: 'grade3', language: 'sinhala', level: 'level4', text: 'අම්මා මට බත් කවයි', wordCount: 4, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade3_si_medium_9', grade: 'grade3', language: 'sinhala', level: 'level4', text: 'රෑට අහසේ තරු පායයි', wordCount: 4, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade3_si_long_0', grade: 'grade3', language: 'sinhala', level: 'level4', text: 'මල්ලි සෙල්ලම් බඩු ගනියි', wordCount: 4, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade3_si_long_1', grade: 'grade3', language: 'sinhala', level: 'level4', text: 'මම පාසල් යන්න කැමතියි', wordCount: 4, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade3_si_long_2', grade: 'grade3', language: 'sinhala', level: 'level4', text: 'අම්මා රසට කෑම උයයි', wordCount: 4, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade3_si_long_3', grade: 'grade3', language: 'sinhala', level: 'level4', text: 'ඇය වල් පැළ ගලවයි', wordCount: 4, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
];

const _grade3SiL5 = [
  SentenceSet(id: 'tr_grade3_si_long_4', grade: 'grade3', language: 'sinhala', level: 'level5', text: 'මම තනියම වැඩ කරමි', wordCount: 4, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade3_si_long_5', grade: 'grade3', language: 'sinhala', level: 'level5', text: 'කළු බල්ලා බුරමින් දුවයි', wordCount: 4, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade3_si_long_6', grade: 'grade3', language: 'sinhala', level: 'level5', text: 'ගඟේ මාළුන් පීනමින් සිටියි', wordCount: 4, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade3_si_long_7', grade: 'grade3', language: 'sinhala', level: 'level5', text: 'වැස්ස වෙලාවට කුඩය ගනිමි', wordCount: 4, expectedTimeSec: 4.0, lowerThresholdSec: 2.8, upperThresholdSec: 5.2),
  SentenceSet(id: 'tr_grade3_si_long_8', grade: 'grade3', language: 'sinhala', level: 'level5', text: 'අද උදේ කිරි බීවෙමි', wordCount: 4, expectedTimeSec: 4.0, lowerThresholdSec: 2.8, upperThresholdSec: 5.2),
  SentenceSet(id: 'tr_grade3_si_long_9', grade: 'grade3', language: 'sinhala', level: 'level5', text: 'හිරු උදේට පායමින් එයි', wordCount: 4, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
];

const _grade4EnL1 = [
  SentenceSet(id: 'tr_grade4_en_short_0', grade: 'grade4', language: 'english', level: 'level1', text: 'The teacher talks loudly.', wordCount: 4, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_en_short_1', grade: 'grade4', language: 'english', level: 'level1', text: 'I see a blue bird.', wordCount: 5, expectedTimeSec: 2.33, lowerThresholdSec: 1.63, upperThresholdSec: 3.03),
  SentenceSet(id: 'tr_grade4_en_short_2', grade: 'grade4', language: 'english', level: 'level1', text: 'She reads a small book.', wordCount: 5, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade4_en_short_3', grade: 'grade4', language: 'english', level: 'level1', text: 'The rat ran to hat.', wordCount: 5, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade4_en_short_4', grade: 'grade4', language: 'english', level: 'level1', text: 'The bell rings in well.', wordCount: 5, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade4_en_short_5', grade: 'grade4', language: 'english', level: 'level1', text: 'I like fresh green apples.', wordCount: 5, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
];

const _grade4EnL2 = [
  SentenceSet(id: 'tr_grade4_en_short_6', grade: 'grade4', language: 'english', level: 'level2', text: 'Birds fly in the sky.', wordCount: 5, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade4_en_short_7', grade: 'grade4', language: 'english', level: 'level2', text: 'Dad drives to the office.', wordCount: 5, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade4_en_short_8', grade: 'grade4', language: 'english', level: 'level2', text: 'We wash our hands daily.', wordCount: 5, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade4_en_short_9', grade: 'grade4', language: 'english', level: 'level2', text: 'I pack my school bag.', wordCount: 5, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade4_en_medium_0', grade: 'grade4', language: 'english', level: 'level2', text: 'We play in the garden.', wordCount: 5, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade4_en_medium_1', grade: 'grade4', language: 'english', level: 'level2', text: 'The boy plays with toy.', wordCount: 5, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
];

const _grade4EnL3 = [
  SentenceSet(id: 'tr_grade4_en_medium_2', grade: 'grade4', language: 'english', level: 'level3', text: 'She paints a beautiful picture.', wordCount: 5, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade4_en_medium_3', grade: 'grade4', language: 'english', level: 'level3', text: 'I read my book everyday', wordCount: 5, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade4_en_medium_4', grade: 'grade4', language: 'english', level: 'level3', text: 'The cat sat on mat.', wordCount: 5, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_en_medium_5', grade: 'grade4', language: 'english', level: 'level3', text: 'The frog jumps on log.', wordCount: 5, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_en_medium_6', grade: 'grade4', language: 'english', level: 'level3', text: 'The cat sleeps on sofa.', wordCount: 5, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_en_medium_7', grade: 'grade4', language: 'english', level: 'level3', text: 'The ball is under table.', wordCount: 5, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
];

const _grade4EnL4 = [
  SentenceSet(id: 'tr_grade4_en_medium_8', grade: 'grade4', language: 'english', level: 'level4', text: 'She does her homework daily', wordCount: 5, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_en_medium_9', grade: 'grade4', language: 'english', level: 'level4', text: 'The rain falls on trees.', wordCount: 5, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
  SentenceSet(id: 'tr_grade4_en_long_0', grade: 'grade4', language: 'english', level: 'level4', text: 'Mom cooks tasty rice today.', wordCount: 5, expectedTimeSec: 4.66, lowerThresholdSec: 3.26, upperThresholdSec: 6.06),
  SentenceSet(id: 'tr_grade4_en_long_1', grade: 'grade4', language: 'english', level: 'level4', text: 'He reads an interesting storybook.', wordCount: 5, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
  SentenceSet(id: 'tr_grade4_en_long_2', grade: 'grade4', language: 'english', level: 'level4', text: 'The sky is so clear today.', wordCount: 6, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade4_en_long_3', grade: 'grade4', language: 'english', level: 'level4', text: 'The rat ran near old hat.', wordCount: 6, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
];

const _grade4EnL5 = [
  SentenceSet(id: 'tr_grade4_en_long_4', grade: 'grade4', language: 'english', level: 'level5', text: 'The red apple is very sweet.', wordCount: 6, expectedTimeSec: 4.0, lowerThresholdSec: 2.8, upperThresholdSec: 5.2),
  SentenceSet(id: 'tr_grade4_en_long_5', grade: 'grade4', language: 'english', level: 'level5', text: 'The kite flies high in sky.', wordCount: 6, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
  SentenceSet(id: 'tr_grade4_en_long_6', grade: 'grade4', language: 'english', level: 'level5', text: 'The boy enjoys his new toy.', wordCount: 6, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
  SentenceSet(id: 'tr_grade4_en_long_7', grade: 'grade4', language: 'english', level: 'level5', text: 'The goat walks near wet boat.', wordCount: 6, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
  SentenceSet(id: 'tr_grade4_en_long_8', grade: 'grade4', language: 'english', level: 'level5', text: 'The bell rings near deep well.', wordCount: 6, expectedTimeSec: 5.66, lowerThresholdSec: 3.96, upperThresholdSec: 7.36),
  SentenceSet(id: 'tr_grade4_en_long_9', grade: 'grade4', language: 'english', level: 'level5', text: 'The duck swims across small luck.', wordCount: 6, expectedTimeSec: 7.0, lowerThresholdSec: 4.9, upperThresholdSec: 9.1),
];

const _grade4SiL1 = [
  SentenceSet(id: 'tr_grade4_si_short_0', grade: 'grade4', language: 'sinhala', level: 'level1', text: 'අයියා බයිසිකල් තරගයෙන් දිනුවේය', wordCount: 4, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_si_short_1', grade: 'grade4', language: 'sinhala', level: 'level1', text: 'අහසේ වලාකුළු අතරින් හඳ පෙනෙයි', wordCount: 5, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade4_si_short_2', grade: 'grade4', language: 'sinhala', level: 'level1', text: 'ඈත අහසේ ඉර පායාගෙන එයි', wordCount: 5, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade4_si_short_3', grade: 'grade4', language: 'sinhala', level: 'level1', text: 'යහළුවෝ පොහොය දිනයට පන්සල් යති', wordCount: 5, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade4_si_short_4', grade: 'grade4', language: 'sinhala', level: 'level1', text: 'ගුරුතුමිය අපට අලුත් පාඩම් කියාදෙයි', wordCount: 5, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_si_short_5', grade: 'grade4', language: 'sinhala', level: 'level1', text: 'කුඩා ළමයි මිදුලේ සතුටින් සෙල්ලම්කරති', wordCount: 5, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
];

const _grade4SiL2 = [
  SentenceSet(id: 'tr_grade4_si_short_6', grade: 'grade4', language: 'sinhala', level: 'level2', text: 'සැඩ සුළඟට ගස් වේගයෙන් සෙලවෙයි', wordCount: 5, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_si_short_7', grade: 'grade4', language: 'sinhala', level: 'level2', text: 'පොත් කියවීමෙන් මිනිසා සම්පුර්ණ වෙයි', wordCount: 5, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_si_short_8', grade: 'grade4', language: 'sinhala', level: 'level2', text: 'මම පාසල් ගොස් හොඳින් ඉගෙනගනිමි', wordCount: 5, expectedTimeSec: 4.0, lowerThresholdSec: 2.8, upperThresholdSec: 5.2),
  SentenceSet(id: 'tr_grade4_si_short_9', grade: 'grade4', language: 'sinhala', level: 'level2', text: 'අක්කගේ දුඹුරු පාට හැට්ටය ලස්සනයි', wordCount: 5, expectedTimeSec: 4.0, lowerThresholdSec: 2.8, upperThresholdSec: 5.2),
  SentenceSet(id: 'tr_grade4_si_medium_0', grade: 'grade4', language: 'sinhala', level: 'level2', text: 'උදෑසන අවදි වී දෙමාපියන් වඳින්නෙමි', wordCount: 5, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
  SentenceSet(id: 'tr_grade4_si_medium_1', grade: 'grade4', language: 'sinhala', level: 'level2', text: 'අපි ඉස්කෝලේ නිවාඩුවට ගමට ගියෙමු', wordCount: 5, expectedTimeSec: 4.33, lowerThresholdSec: 3.03, upperThresholdSec: 5.63),
];

const _grade4SiL3 = [
  SentenceSet(id: 'tr_grade4_si_medium_2', grade: 'grade4', language: 'sinhala', level: 'level3', text: 'අම්මා මට ලස්සන කතන්දර කියාදෙයි', wordCount: 5, expectedTimeSec: 4.66, lowerThresholdSec: 3.26, upperThresholdSec: 6.06),
  SentenceSet(id: 'tr_grade4_si_medium_3', grade: 'grade4', language: 'sinhala', level: 'level3', text: 'පොත් කියවීමෙන් අපේ දැනුම වැඩි වෙයි', wordCount: 6, expectedTimeSec: 3.0, lowerThresholdSec: 2.1, upperThresholdSec: 3.9),
  SentenceSet(id: 'tr_grade4_si_medium_4', grade: 'grade4', language: 'sinhala', level: 'level3', text: 'අපි පරිසරය පිරිසිදුව තබා ගත යුතුය', wordCount: 6, expectedTimeSec: 3.33, lowerThresholdSec: 2.33, upperThresholdSec: 4.33),
  SentenceSet(id: 'tr_grade4_si_medium_5', grade: 'grade4', language: 'sinhala', level: 'level3', text: 'වත්තේ ලස්සන රතු පාට මල් පිපෙයි', wordCount: 6, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_si_medium_6', grade: 'grade4', language: 'sinhala', level: 'level3', text: 'ගස උඩ සිටින කුරුල්ලා ගීත ගයයි', wordCount: 6, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_si_medium_7', grade: 'grade4', language: 'sinhala', level: 'level3', text: 'වැඩ අවසන් කර මම පොත් අසුරමි', wordCount: 6, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
];

const _grade4SiL4 = [
  SentenceSet(id: 'tr_grade4_si_medium_8', grade: 'grade4', language: 'sinhala', level: 'level4', text: 'කෑමට පෙර අත් සබන් දා සෝදන්න', wordCount: 6, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_si_medium_9', grade: 'grade4', language: 'sinhala', level: 'level4', text: 'නංගි පාට පැන්සල් වලින් ලස්සනට අඳියි', wordCount: 6, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_si_long_0', grade: 'grade4', language: 'sinhala', level: 'level4', text: 'අපි හැමෝම එකට එකතු වී වැඩකරමු', wordCount: 6, expectedTimeSec: 3.66, lowerThresholdSec: 2.56, upperThresholdSec: 4.76),
  SentenceSet(id: 'tr_grade4_si_long_1', grade: 'grade4', language: 'sinhala', level: 'level4', text: 'මම මගේ පාසල් නිල ඇඳුම අඳින්නෙමි', wordCount: 6, expectedTimeSec: 4.0, lowerThresholdSec: 2.8, upperThresholdSec: 5.2),
  SentenceSet(id: 'tr_grade4_si_long_2', grade: 'grade4', language: 'sinhala', level: 'level4', text: 'සේපාලිකා මල් රෑට පිපී සුවඳ හමයි', wordCount: 6, expectedTimeSec: 4.0, lowerThresholdSec: 2.8, upperThresholdSec: 5.2),
  SentenceSet(id: 'tr_grade4_si_long_3', grade: 'grade4', language: 'sinhala', level: 'level4', text: 'සඳ අහසේ තරුත් එක්ක ලස්සනට සිනාසෙයි', wordCount: 6, expectedTimeSec: 4.66, lowerThresholdSec: 3.26, upperThresholdSec: 6.06),
];

const _grade4SiL5 = [
  SentenceSet(id: 'tr_grade4_si_long_4', grade: 'grade4', language: 'sinhala', level: 'level5', text: 'අම්මා මට සිනි මුරුක්කු ගෙනත් දුන්නාය', wordCount: 6, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
  SentenceSet(id: 'tr_grade4_si_long_5', grade: 'grade4', language: 'sinhala', level: 'level5', text: 'පිළිහුඩුවා උස අත්තක නැගී වටපිට බලමින් සිටියි', wordCount: 7, expectedTimeSec: 4.66, lowerThresholdSec: 3.26, upperThresholdSec: 6.06),
  SentenceSet(id: 'tr_grade4_si_long_6', grade: 'grade4', language: 'sinhala', level: 'level5', text: 'කුරුල්ලෝ රංචුවක් සර සර ගාමින් ඉගිලී ගියෝය', wordCount: 7, expectedTimeSec: 5.0, lowerThresholdSec: 3.5, upperThresholdSec: 6.5),
  SentenceSet(id: 'tr_grade4_si_long_7', grade: 'grade4', language: 'sinhala', level: 'level5', text: 'තාත්තා මට දුන් ප්‍රහේලිකාව විසඳා අවසන් කලෙමි', wordCount: 7, expectedTimeSec: 5.66, lowerThresholdSec: 3.96, upperThresholdSec: 7.36),
  SentenceSet(id: 'tr_grade4_si_long_8', grade: 'grade4', language: 'sinhala', level: 'level5', text: 'ගමේ වැවේ ඕලු, නෙළුම්, මානෙල් පිපී හිනැහෙයි', wordCount: 7, expectedTimeSec: 6.0, lowerThresholdSec: 4.2, upperThresholdSec: 7.8),
  SentenceSet(id: 'tr_grade4_si_long_9', grade: 'grade4', language: 'sinhala', level: 'level5', text: 'වේගයෙන් එන මුහුදු රැල්ලක් ගලක හැපී විසිරී යයි', wordCount: 8, expectedTimeSec: 5.33, lowerThresholdSec: 3.73, upperThresholdSec: 6.93),
];

// ── Word-splitting helper — shared by miscue marking + word-diff, called
// once per unit and never duplicated inline. ────────────────────────────
List<String> splitWords(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

// ── Sentence-level report (Results Screen / Parent Dashboard) ──────────────

/// One sentence's display-ready report row: sentence-level expected vs.
/// actual time, plus the words within THAT sentence marked misread. This
/// is deliberately the finest granularity available — there is no
/// per-word timing anywhere in this app (ReadingScreen only ever
/// captures one Stopwatch reading per whole sentence), so this row must
/// never be rendered as if it implies one. See [buildSentenceReportRows].
class SentenceReportRow {
  final String text;
  final double expectedTimeSec;
  final double upperThresholdSec;
  final int actualMs;
  // Words from this sentence flagged as misread — framed as practice
  // targets throughout the UI (never "wrong"/"failed"/"mistake").
  final List<String> practiceWords;

  const SentenceReportRow({
    required this.text,
    required this.expectedTimeSec,
    required this.upperThresholdSec,
    required this.actualMs,
    required this.practiceWords,
  });
}

/// Builds one [SentenceReportRow] per sentence in [sentences], pairing
/// each with its recorded elapsed time (from [session.unitTimings], keyed
/// by unitIndex rather than assumed-ordered) and the subset of
/// [session.misreadWordIndexes] (a flat, whole-session word-index set)
/// that falls within that sentence's own word range. Whole-sentence
/// granularity in, whole-sentence granularity out — no word-level timing
/// is fabricated here.
List<SentenceReportRow> buildSentenceReportRows({
  required List<SentenceSet> sentences,
  required TimedReadingSession session,
}) {
  final elapsedByUnit = <int, int>{
    for (final t in session.unitTimings) t.unitIndex: t.elapsedMs,
  };

  var runningIndex = 0;
  final rows = <SentenceReportRow>[];
  for (var i = 0; i < sentences.length; i++) {
    final sentence = sentences[i];
    final words = splitWords(sentence.text);
    final base = runningIndex;
    runningIndex += words.length;

    final practiceWords = <String>[
      for (var w = 0; w < words.length; w++)
        if (session.misreadWordIndexes.contains(base + w)) words[w],
    ];

    rows.add(SentenceReportRow(
      text: sentence.text,
      expectedTimeSec: sentence.expectedTimeSec,
      upperThresholdSec: sentence.upperThresholdSec,
      actualMs: elapsedByUnit[i] ?? 0,
      practiceWords: practiceWords,
    ));
  }
  return rows;
}

// ── Public API ────────────────────────────────────────────────────────────

/// Returns the 6 sentences for one grade+language+level bucket, in a
/// fixed/stable order (the order they're declared above).
List<SentenceSet> getTimedReadingSentences({
  required String grade,
  required String language,
  required String level,
}) {
  final en = language == 'english';
  final pools = grade == 'grade3'
      ? (en
          ? [_grade3EnL1, _grade3EnL2, _grade3EnL3, _grade3EnL4, _grade3EnL5]
          : [_grade3SiL1, _grade3SiL2, _grade3SiL3, _grade3SiL4, _grade3SiL5])
      : (en
          ? [_grade4EnL1, _grade4EnL2, _grade4EnL3, _grade4EnL4, _grade4EnL5]
          : [_grade4SiL1, _grade4SiL2, _grade4SiL3, _grade4SiL4, _grade4SiL5]);
  const levelKeys = ['level1', 'level2', 'level3', 'level4', 'level5'];
  final index = levelKeys.indexOf(level);
  return List.unmodifiable(pools[index < 0 ? 0 : index]);
}

/// Looks up a single SentenceSet by its stable id, searching every grade/
/// language/level bucket. Used by "Practice These Again" to turn a
/// TimedReadingDao.getPendingPractice row's sentence_id back into a live
/// SentenceSet (current thresholds) rather than storing a full snapshot —
/// ids are stable across the catalog, so this always resolves for any id
/// ever assigned. Returns null only if a sentence was removed from the
/// catalog after being assigned (not expected in practice).
SentenceSet? findTimedReadingSentenceById(String id) {
  for (final grade in ['grade3', 'grade4']) {
    for (final language in ['english', 'sinhala']) {
      for (final level in ['level1', 'level2', 'level3', 'level4', 'level5']) {
        for (final s in getTimedReadingSentences(grade: grade, language: language, level: level)) {
          if (s.id == id) return s;
        }
      }
    }
  }
  return null;
}

// ── Sentence reference audio (🔊 Listen button) ─────────────────────────
//
// Reference audio sourced from the project's children's reading dataset
// (indeepa wav/), not independently-recorded adult speech — used here as
// sentence playback per product decision. Confirmed byte-for-byte
// identical to indeepa wav/ (MD5 + WAV header match across every sampled
// file) before this was wired up; assets/audio/sentences/ is the copy
// already declared in pubspec.yaml, so it's the one actually bundled.
//
// Keyed by SentenceSet.id -> exact filename in assets/audio/sentences/.
// English keys were matched by exact sentence text (minus its own
// trailing period, since filenames don't double it before ".wav").
// Sinhala keys were matched by transliteration + edit-distance against
// the filename list, with 6 low-confidence machine matches replaced by
// a manual cross-check against this project's own earlier full 120-file
// grouped audio report. All 120 sentences have a verified entry — see
// sentenceAudioAssetPath below for the accessor.
const Map<String, String> _sentenceAudioFile = {
  'tr_grade3_en_long_0': 'Cat sleeps on bed.wav',
  'tr_grade3_en_long_1': 'She eats a mango.wav',
  'tr_grade3_en_long_2': 'I have a pencil.wav',
  'tr_grade3_en_long_3': 'Boy runs very fast.wav',
  'tr_grade3_en_long_4': 'She reads a book.wav',
  'tr_grade3_en_long_5': 'Birds fly in sky.wav',
  'tr_grade3_en_long_6': 'We drink clean water.wav',
  'tr_grade3_en_long_7': 'Sun shines in sky.wav',
  'tr_grade3_en_long_8': 'We read story books.wav',
  'tr_grade3_en_long_9': 'We eat tasty food.wav',
  'tr_grade3_en_medium_0': 'She reads books.wav',
  'tr_grade3_en_medium_1': 'I drink milk.wav',
  'tr_grade3_en_medium_2': 'Birds fly high.wav',
  'tr_grade3_en_medium_3': 'Dogs bark loudly.wav',
  'tr_grade3_en_medium_4': 'She is drawing.wav',
  'tr_grade3_en_medium_5': 'I go to school.wav',
  'tr_grade3_en_medium_6': 'He eats an apple.wav',
  'tr_grade3_en_medium_7': 'They are good friends.wav',
  'tr_grade3_en_medium_8': 'The dog runs fast.wav',
  'tr_grade3_en_medium_9': 'We play in garden.wav',
  'tr_grade3_en_short_0': 'The cat sleeps.wav',
  'tr_grade3_en_short_1': 'Kids sing songs.wav',
  'tr_grade3_en_short_2': 'He kicks ball.wav',
  'tr_grade3_en_short_3': 'We love school.wav',
  'tr_grade3_en_short_4': 'They play games.wav',
  'tr_grade3_en_short_5': 'The sun shines.wav',
  'tr_grade3_en_short_6': 'He writes letters.wav',
  'tr_grade3_en_short_7': 'We watch TV.wav',
  'tr_grade3_en_short_8': 'Fish swim fast.wav',
  'tr_grade3_en_short_9': 'I eat rice.wav',
  'tr_grade3_si_long_0': 'malli_sellam_badu_ganiyi.wav',
  'tr_grade3_si_long_1': 'mama_pasal_yanna_kemathiyi.wav',
  'tr_grade3_si_long_2': 'amma_rasata_kaema_uyayi.wav',
  'tr_grade3_si_long_3': 'aya_wal_pela_galawayi.wav',
  'tr_grade3_si_long_4': 'mama_thaniyama_wada_karami.wav',
  'tr_grade3_si_long_5': 'kalu_ballaa_buramin_duwayi.wav',
  'tr_grade3_si_long_6': 'gange_malun_peenamin_sitiyi.wav',
  'tr_grade3_si_long_7': 'wessa_welawata_kudaya_ganimi.wav',
  'tr_grade3_si_long_8': 'ada_udae_kiri_beewemi.wav',
  'tr_grade3_si_long_9': 'hiru_udeta_paayamin_eyi.wav',
  'tr_grade3_si_medium_0': 'maama_basaya_padawayi.wav',
  'tr_grade3_si_medium_1': 'ohu_pothak_kiyawayi.wav',
  'tr_grade3_si_medium_2': 'guruthuma_kathawak_kiyawayi.wav',
  'tr_grade3_si_medium_3': 'wimal_malak_keduweya.wav',
  'tr_grade3_si_medium_4': 'owuhu_gedara_awoya.wav',
  'tr_grade3_si_medium_5': 'mama_rasa_kesel_kami.wav',
  'tr_grade3_si_medium_6': 'thaththa_gedara_wada_karayi.wav',
  'tr_grade3_si_medium_7': 'sudu_poosa_kiri_boyi.wav',
  'tr_grade3_si_medium_8': 'amma_mata_bath_kawayi.wav',
  'tr_grade3_si_medium_9': 'raeta_ahase_tharu_paayayi.wav',
  'tr_grade3_si_short_0': 'mama_gamata_yami.wav',
  'tr_grade3_si_short_1': 'ohu_paadam_karayi.wav',
  'tr_grade3_si_short_2': 'amma_bath_uyayi.wav',
  'tr_grade3_si_short_3': 'akka_pothak_kiyawayi.wav',
  'tr_grade3_si_short_4': 'akka_midula_athugayi.wav',
  'tr_grade3_si_short_5': 'malli_aethata_duwayi.wav',
  'tr_grade3_si_short_6': 'nenda_redi_sodayi.wav',
  'tr_grade3_si_short_7': 'api_sellam_karamu.wav',
  'tr_grade3_si_short_8': 'aya_gasak_situwai.wav',
  'tr_grade3_si_short_9': 'kamala_panthiyata_awaya.wav',
  'tr_grade4_en_long_0': 'Mom cooks tasty rice today.wav',
  'tr_grade4_en_long_1': 'He reads an interesting storybook.wav',
  'tr_grade4_en_long_2': 'The sky is so clear today.wav',
  'tr_grade4_en_long_3': 'The rat ran near old hat.wav',
  'tr_grade4_en_long_4': 'The red apple is very sweet.wav',
  'tr_grade4_en_long_5': 'The kite flies high in sky.wav',
  'tr_grade4_en_long_6': 'The boy enjoys his new toy.wav',
  'tr_grade4_en_long_7': 'The goat walks near wet boat.wav',
  'tr_grade4_en_long_8': 'The bell rings near deep well.wav',
  'tr_grade4_en_long_9': 'The duck swims across small luck.wav',
  'tr_grade4_en_medium_0': 'We play in the garden.wav',
  'tr_grade4_en_medium_1': 'The boy plays with toy.wav',
  'tr_grade4_en_medium_2': 'She paints a beautiful picture.wav',
  'tr_grade4_en_medium_3': 'I read my book everyday.wav',
  'tr_grade4_en_medium_4': 'The cat sat on mat.wav',
  'tr_grade4_en_medium_5': 'The frog jumps on log.wav',
  'tr_grade4_en_medium_6': 'The cat sleeps on sofa.wav',
  'tr_grade4_en_medium_7': 'The ball is under table.wav',
  'tr_grade4_en_medium_8': 'She does her homework daily.wav',
  'tr_grade4_en_medium_9': 'The rain falls on trees.wav',
  'tr_grade4_en_short_0': 'The teacher talks loudly.wav',
  'tr_grade4_en_short_1': 'I see a blue bird.wav',
  'tr_grade4_en_short_2': 'She reads a small book.wav',
  'tr_grade4_en_short_3': 'The rat ran to hat.wav',
  'tr_grade4_en_short_4': 'The bell rings in well.wav',
  'tr_grade4_en_short_5': 'I like fresh green apples.wav',
  'tr_grade4_en_short_6': 'Birds fly in the sky.wav',
  'tr_grade4_en_short_7': 'Dad drives to the office.wav',
  'tr_grade4_en_short_8': 'We wash our hands daily.wav',
  'tr_grade4_en_short_9': 'I pack my school bag.wav',
  'tr_grade4_si_long_0': 'api_haemoma_ekata_ekathu_wee_wadakaramu.wav',
  'tr_grade4_si_long_1': 'mama_mage_pasal_nila_anduma_andinnemi.wav',
  'tr_grade4_si_long_2': 'sepalika_mal_raeta_pipee_suwanda_hamayi.wav',
  'tr_grade4_si_long_3': 'sanda_ahase_tharuth_ekka_lassanata_sinaaseyi.wav',
  'tr_grade4_si_long_4': 'amma_mata_sini_murukku_genath_dunnaya.wav',
  'tr_grade4_si_long_5': 'pilihuduwa_usa_aththaka_nagee_watapita_balamIn_sitiyi.wav',
  'tr_grade4_si_long_6': 'kurullo_ranchuwak_sara_sara_gaamin_igilee_giyoya.wav',
  'tr_grade4_si_long_7': 'thaththa_mata_dun_prahelikawa_wisada_awasan_kalemi.wav',
  'tr_grade4_si_long_8': 'game_wawe_olu_nelum_maanel_pipee_hinaheyi.wav',
  'tr_grade4_si_long_9': 'wegayen_ena_muhudu_raellak_galaka_haepi_wisiree_yayi.wav',
  'tr_grade4_si_medium_0': 'udaesana_awadi_wee_demapiyan_wandinemi.wav',
  'tr_grade4_si_medium_1': 'api_iskole_niwaduwata_gamata_giyemu.wav',
  'tr_grade4_si_medium_2': 'amma_mata_lassana_kathandara_kiyadei.wav',
  'tr_grade4_si_medium_3': 'poth_kiyawimen_ape_daenum_wadi_weyi.wav',
  'tr_grade4_si_medium_4': 'api_parisaraya_pirisiduwa_thaba_gatha_yuthuya.wav',
  'tr_grade4_si_medium_5': 'watthe_lassana_rathu_paata_mal_pipei.wav',
  'tr_grade4_si_medium_6': 'gasa_uda_sitina_kurulla_geetha_gayai.wav',
  'tr_grade4_si_medium_7': 'wada_awasan_kara_mama_poth_asurami.wav',
  'tr_grade4_si_medium_8': 'kaemata_pera_ath_saban_daa_sodanna.wav',
  'tr_grade4_si_medium_9': 'nangi_paata_pansal_walin_lassanata_andiyi.wav',
  'tr_grade4_si_short_0': 'ayiya_baisikal_tharagayen_dinuweya.wav',
  'tr_grade4_si_short_1': 'ahase_walakulu_atharin_handa_peneyi.wav',
  'tr_grade4_si_short_2': 'aetha_ahase_ira_paayaagena_eyi.wav',
  'tr_grade4_si_short_3': 'yahaluwo_pohoya_dinayata_pansal_yathi.wav',
  'tr_grade4_si_short_4': 'guruthumiya_apata_aluth_paadam_kiyadei.wav',
  'tr_grade4_si_short_5': 'kuda_lamai_midule_sathutin_sellamkarathi.wav',
  'tr_grade4_si_short_6': 'seda_sulangata_gas_wegayen_selaweyi.wav',
  'tr_grade4_si_short_7': 'poth_kiyawimen_minisa_sampurna_weyi.wav',
  'tr_grade4_si_short_8': 'mama_pasal_gos_hondin_igenaganimi.wav',
  'tr_grade4_si_short_9': 'akkage_dumburu_paata_haettaya_lassanai.wav',
};

/// Asset path (audioplayers' AssetSource convention — no leading
/// "assets/") for [sentence]'s reference recording, or null if this
/// sentence has no matching file (shouldn't happen — all 120 are
/// mapped — but callers must still treat null as "hide the button",
/// never crash).
String? sentenceAudioAssetPath(SentenceSet sentence) {
  final filename = _sentenceAudioFile[sentence.id];
  if (filename == null) return null;
  return 'audio/sentences/$filename';
}

String timedReadingLevelTitle(String level, bool isSinhala) {
  const levelKeys = ['level1', 'level2', 'level3', 'level4', 'level5'];
  final n = levelKeys.indexOf(level) + 1;
  final num = n < 1 ? 1 : n;
  return isSinhala ? 'මට්ටම $num' : 'Level $num';
}

// ── Navigation arg classes ───────────────────────────────────────────────

class ReadingScreenArgs {
  final String grade;
  final String language;
  final String level;
  final List<SentenceSet> sentences;
  final int? attemptNumber;
  final int? previousWpm;

  const ReadingScreenArgs({
    required this.grade,
    required this.language,
    required this.level,
    required this.sentences,
    this.attemptNumber,
    this.previousWpm,
  });
}

class MiscueMarkingArgs {
  final List<SentenceSet> sentences;
  final TimedReadingSession session;
  final int? attemptNumber;
  final int? previousWpm;
  // True when this session was launched from the "Practice These Again"
  // banner (ReadingScreenArgs.level == 'assigned_practice') — its
  // sentences come from several different real levels/content sets, so
  // _saveSession can't derive level from sentences.first.level the way
  // every other session does. Also tells it to call
  // TimedReadingDao.markPracticeCompleted on save.
  final bool isAssignedPractice;

  const MiscueMarkingArgs({
    required this.sentences,
    required this.session,
    this.attemptNumber,
    this.previousWpm,
    this.isAssignedPractice = false,
  });
}

class ResultsScreenArgs {
  final List<SentenceSet> sentences;
  final TimedReadingSession session;
  final int? previousWpm;
  // Row id this session was saved as in timed_reading_sessions (null if
  // the DB write failed) — used to exclude this just-finished session
  // from ResultsScreen's own "previous best" query.
  final int? sessionId;

  const ResultsScreenArgs({
    required this.sentences,
    required this.session,
    this.previousWpm,
    this.sessionId,
  });
}

/// contentSetId shared by every SentenceSet in one grade+language+level
/// bucket — there's no single Dart const id per bucket (SentenceSet.id is
/// per-sentence), so this is synthesized the same way for both saving a
/// session and querying its history.
String timedReadingContentSetId({required String grade, required String language, required String level}) =>
    '${grade}_${language}_$level';

class ChallengeScreenArgs {
  final String grade;
  final String language;
  final String level;
  final List<SentenceSet> sentences;

  const ChallengeScreenArgs({
    required this.grade,
    required this.language,
    required this.level,
    required this.sentences,
  });
}
