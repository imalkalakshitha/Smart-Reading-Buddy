import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

/// Placeholder — Word Building analytics belongs to a teammate's module.
class ParentWordBuildingAnalyticsScreen extends StatelessWidget {
  const ParentWordBuildingAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Word Building Progress',
      emoji: '🔤',
      accent: AppColors.wordBuilding,
    );
  }
}
