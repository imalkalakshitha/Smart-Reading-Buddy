import 'package:flutter/material.dart';
import 'package:smart_reading_buddy/features/reading/data/reading_data.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/widgets/coming_soon_placeholder.dart';

class ReadingSessionCompleteScreen extends StatelessWidget {
  final ReadingCompleteArgs args;
  const ReadingSessionCompleteScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Session Complete',
      emoji: '🎉',
      accent: AppColors.reading,
    );
  }
}
