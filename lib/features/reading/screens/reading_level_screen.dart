import 'package:flutter/material.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/widgets/coming_soon_placeholder.dart';

class ReadingLevelScreen extends StatelessWidget {
  const ReadingLevelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Reading',
      emoji: '📖',
      accent: AppColors.reading,
    );
  }
}
