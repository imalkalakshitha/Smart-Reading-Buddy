import 'package:flutter/material.dart';
import '../../data/reading_data.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

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
