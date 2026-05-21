import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF7B2FF7);       // Deep purple
  static const Color secondary = Color(0xFFD946EF);     // Pink/magenta
  static const Color background = Color(0xFFFAF8FF);    // Off-white with purple tint
  static const Color surface = Color(0xFFFFFFFF);       // White
  static const Color surfaceLight = Color(0xFFF3EEFF);  // Very light purple
  static const Color textPrimary = Color(0xFF1A1A2E);   // Dark navy
  static const Color textSecondary = Color(0xFF8B8FA8); // Muted gray
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color border = Color(0xFFEDE9FE);        // Light purple border

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7B2FF7), Color(0xFFD946EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFF3EEFF), Color(0xFFEDE9FE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
