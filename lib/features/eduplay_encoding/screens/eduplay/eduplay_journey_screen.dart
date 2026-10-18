import 'package:flutter/material.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/widgets/coming_soon_placeholder.dart';

class EduPlayJourneyScreen extends StatelessWidget {
  const EduPlayJourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'EduPlay',
      emoji: '🎮',
      accent: AppColors.wordBuilding,
    );
  }
}
