import 'package:flutter/material.dart';

const kWBPurple  = Color(0xFF7B61FF);
const kWBOrange  = Color(0xFFFF6B35);
const kWBRed     = Color(0xFFFF5252);
const kWBTeal    = Color(0xFF00B894);
const kWBYellow  = Color(0xFFFFD600);

class WBRecommendation {
  final String title;
  final String priority;
  final Color priorityColor;
  final String reason;
  final String description;
  final String icon;

  const WBRecommendation({
    required this.title,
    required this.priority,
    required this.priorityColor,
    required this.reason,
    required this.description,
    required this.icon,
  });
}

const wbRecommendations = [
  WBRecommendation(
    title: 'Sentence Meaning Quiz',
    priority: 'High Priority',
    priorityColor: kWBRed,
    reason: 'meaning_mismatch',
    description:
        'Ayan often changes or misunderstands the sentence meaning.',
    icon: '🧩',
  ),
  WBRecommendation(
    title: 'Missing Spelling Practice',
    priority: 'Medium',
    priorityColor: kWBOrange,
    reason: 'missing_letter',
    description:
        'Ayan sometimes misses letters when completing words.',
    icon: '🔤',
  ),
  WBRecommendation(
    title: 'Sentence Drag and Drop',
    priority: 'Medium',
    priorityColor: kWBOrange,
    reason: 'wrong_order',
    description:
        'Ayan needs more practice arranging sentence words in the correct order.',
    icon: '🔀',
  ),
];
