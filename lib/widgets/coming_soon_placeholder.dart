import 'package:flutter/material.dart';
import '../models/app_colors.dart';

/// Minimal placeholder body used by screens whose implementation was
/// stripped out ahead of a rebuild. Keeps the screen's Scaffold/AppBar
/// so navigation into and out of it still works normally.
class ComingSoonPlaceholder extends StatelessWidget {
  final String title;
  final String emoji;
  final Color accent;
  final String? message;

  const ComingSoonPlaceholder({
    super.key,
    required this.title,
    this.emoji = '🚧',
    this.accent = AppColors.primary,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                message ?? 'Coming soon',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This section is being rebuilt.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
