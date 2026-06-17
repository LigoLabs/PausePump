import 'package:flutter/material.dart';

/// Palette reprise de la version web (thème sombre salle de sport).
abstract final class AppColors {
  static const bg = Color(0xFF0F1219);
  static const bgElev = Color(0xFF171B26);
  static const bgElev2 = Color(0xFF1F2533);
  static const accent = Color(0xFF22D3A7); // pause / teal
  static const accentPress = Color(0xFF1BB892);
  static const effort = Color(0xFFF59E0B); // amber
  static const danger = Color(0xFFEF4444);
  static const text = Color(0xFFE9F0F5);
  static const textDim = Color(0xFF93A0B0);
  static const track = Color(0xFF2A3142);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.effort,
      surface: AppColors.bgElev,
      error: AppColors.danger,
      onPrimary: Color(0xFF04130F),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );
}
