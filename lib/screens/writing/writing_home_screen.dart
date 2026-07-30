import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

class WritingHomeScreen extends StatelessWidget {
  const WritingHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Writing Practice',
      emoji: '✏️',
      accent: AppColors.writing,
    );
  }
}
