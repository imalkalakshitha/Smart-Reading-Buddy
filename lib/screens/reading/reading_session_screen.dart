import 'package:flutter/material.dart';
import '../../data/reading_data.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

class ReadingSessionScreen extends StatelessWidget {
  final ReadingSessionArgs args;
  const ReadingSessionScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Reading Session',
      emoji: '📖',
      accent: AppColors.reading,
    );
  }
}
