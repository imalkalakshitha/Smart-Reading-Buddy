import 'package:flutter/material.dart';
import '../../data/writing_data.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

class LetterTracingScreen extends StatelessWidget {
  final WritingArgs args;
  const LetterTracingScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Letter Tracing',
      emoji: '🔤',
      accent: AppColors.writing,
    );
  }
}
