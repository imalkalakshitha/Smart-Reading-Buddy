import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

/// Placeholder — Writing analytics belongs to a teammate's module.
class ParentWritingAnalyticsScreen extends StatelessWidget {
  const ParentWritingAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Writing Progress',
      emoji: '✍️',
      accent: AppColors.writing,
    );
  }
}
