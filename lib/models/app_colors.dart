import 'package:flutter/material.dart';

class AppColors {
  // Primary Green
  static const Color primary        = Color(0xFF2ECC71);
  static const Color primaryDark    = Color(0xFF27AE60);
  static const Color primaryLight   = Color(0xFFA9DFBF);
  static const Color primarySurface = Color(0xFFF0FBF4);

  // Backgrounds
  static const Color background     = Color(0xFFFFFFFF); // kept for compat
  static const Color cardBg         = Color(0xFFF0FBF4);
  static const Color pageBg         = Color(0xFFF7FEF9);

  // Text
  static const Color textPrimary    = Color(0xFF1A1A2E);
  static const Color textSecondary  = Color(0xFF555555);
  static const Color textHint       = Color(0xFF999999);

  // Module Accent Colors
  static const Color pronunciation  = Color(0xFF2ECC71); // green
  static const Color wordBuilding   = Color(0xFFF9CA24); // yellow
  static const Color reading        = Color(0xFF3498DB); // blue
  static const Color writing        = Color(0xFF9B59B6); // purple

  // Feedback Colors
  static const Color success        = Color(0xFF2ECC71);
  static const Color almost         = Color(0xFFF9CA24);
  static const Color wrong          = Color(0xFFE74C3C);

  // UI Elements
  static const Color divider        = Color(0xFFE8F5E9);
  static const Color shadow         = Color(0x1A27AE60);
  static const Color buddyOnline    = Color(0xFF2ECC71);
  static const Color buddyOffline   = Color(0xFFBBBBBB);

  // Bottom Nav
  static const Color navSelected    = Color(0xFF27AE60);
  static const Color navUnselected  = Color(0xFFAAAAAA);
  static const Color navBg          = Color(0xFFFFFFFF);

  // PIN dots
  static const Color pinFilled      = Color(0xFF2ECC71);
  static const Color pinEmpty       = Color(0xFFE0E0E0);

  // Danger
  static const Color danger         = Color(0xFFE74C3C);
  static const Color dangerLight    = Color(0xFFFDECEA);

  // Legacy aliases — kept so old references still compile during migration
  static const Color white          = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFF0FBF4);
  static const Color errorRed       = Color(0xFFE74C3C);
  static const Color accentYellow   = Color(0xFFF9CA24);
  static const Color accentOrange   = Color(0xFFF9CA24);
  static const Color accentBlue     = Color(0xFF3498DB);
  static const Color accentPurple   = Color(0xFF9B59B6);
}
