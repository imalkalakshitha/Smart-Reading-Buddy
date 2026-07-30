import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

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
