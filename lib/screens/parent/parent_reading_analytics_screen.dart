import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

/// Placeholder — Reading analytics belongs to a teammate's module.
class ParentReadingAnalyticsScreen extends StatelessWidget {
  const ParentReadingAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Reading Progress',
      emoji: '📖',
      accent: AppColors.reading,
    );
  }
}
