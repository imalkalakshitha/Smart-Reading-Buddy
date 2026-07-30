import 'package:flutter/material.dart';
import '../../data/writing_data.dart';
import '../../models/app_colors.dart';
import '../../widgets/coming_soon_placeholder.dart';

class WordTracingScreen extends StatelessWidget {
  final WritingArgs args;
  const WordTracingScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPlaceholder(
      title: 'Word Tracing',
      emoji: '📝',
      accent: AppColors.writing,
    );
  }
}
