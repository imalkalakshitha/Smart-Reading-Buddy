import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

class TimedReadingLevelScreen extends StatelessWidget {
  const TimedReadingLevelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Timed Reading',
      emoji: '⏱️',
      accent: AppColors.reading,
    );
  }
}
