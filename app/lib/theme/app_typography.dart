import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

class AppFonts {
  AppFonts._();

  static const display = 'Poppins';
  static const body = 'Inter';
}

class AppTypography {
  AppTypography._();

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w800,
      fontSize: 46,
      height: 1.04,
      letterSpacing: -1.4,
      color: AppColors.ink,
    ),
    displayMedium: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w800,
      fontSize: 38,
      height: 1.06,
      letterSpacing: -1.1,
      color: AppColors.ink,
    ),
    displaySmall: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
      fontSize: 30,
      height: 1.1,
      letterSpacing: -0.8,
      color: AppColors.ink,
    ),
    headlineLarge: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 1.14,
      letterSpacing: -0.6,
      color: AppColors.ink,
    ),
    headlineMedium: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
      fontSize: 24,
      height: 1.18,
      letterSpacing: -0.4,
      color: AppColors.ink,
    ),
    headlineSmall: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w600,
      fontSize: 20,
      height: 1.2,
      letterSpacing: -0.2,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 1.25,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w600,
      fontSize: 16,
      height: 1.3,
      color: AppColors.ink,
    ),
    titleSmall: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 1.3,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(
      fontFamily: AppFonts.body,
      fontWeight: FontWeight.w400,
      fontSize: 16,
      height: 1.5,
      color: AppColors.ink,
    ),
    bodyMedium: TextStyle(
      fontFamily: AppFonts.body,
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 1.45,
      color: AppColors.inkSoft,
    ),
    bodySmall: TextStyle(
      fontFamily: AppFonts.body,
      fontWeight: FontWeight.w400,
      fontSize: 13,
      height: 1.4,
      color: AppColors.inkSoft,
    ),
    labelLarge: TextStyle(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 1.2,
      letterSpacing: 0.1,
      color: AppColors.ink,
    ),
    labelMedium: TextStyle(
      fontFamily: AppFonts.body,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1.2,
      letterSpacing: 0.2,
      color: AppColors.inkSoft,
    ),
    labelSmall: TextStyle(
      fontFamily: AppFonts.body,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1.2,
      letterSpacing: 0.3,
      color: AppColors.inkFaint,
    ),
  );

  static TextStyle get kicker => const TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w700,
    fontSize: 12,
    letterSpacing: 1.2,
    color: AppColors.verdeSecundario,
  );

  static TextStyle get dataValue => const TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.1,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  static TextStyle get dataLabel => const TextStyle(
    fontFamily: AppFonts.body,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    letterSpacing: 0.2,
    color: AppColors.inkFaint,
  );
}
