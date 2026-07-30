import 'package:flutter/material.dart';
import '../../data/timed_reading_data.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

class TimedReadingScreen extends StatelessWidget {
  final TimedReadingArgs args;
  const TimedReadingScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Timed Reading',
      emoji: '⏱️',
      accent: AppColors.reading,
    );
  }
}
