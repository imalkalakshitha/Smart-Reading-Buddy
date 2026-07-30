import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

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
