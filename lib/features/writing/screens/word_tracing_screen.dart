import 'package:flutter/material.dart';
import 'package:smart_reading_buddy/features/writing/data/writing_data.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/widgets/coming_soon_placeholder.dart';

class WordTracingScreen extends StatelessWidget {
  final WritingArgs args;
  const WordTracingScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Word Tracing',
      emoji: '📝',
      accent: AppColors.writing,
    );
  }
}
