import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData build() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.verdeSecundario,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.verdePrincipal,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.buenoSoft,
          onPrimaryContainer: AppColors.verdePrincipal,
          secondary: AppColors.acentoNatural,
          onSecondary: AppColors.verdePrincipal,
          secondaryContainer: AppColors.heladaSoft,
          tertiary: AppColors.tecnologia,
          onTertiary: AppColors.white,
          surface: AppColors.white,
          onSurface: AppColors.ink,
          surfaceContainerHighest: AppColors.fondoSuave,
          error: AppColors.alerta,
          outlineVariant: AppColors.line,
          shadow: const Color(0x1A14532D),
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.fondoSuave,
      textTheme: AppTypography.textTheme,
      visualDensity: VisualDensity.standard,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    );

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.ink,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: AppTypography.textTheme,
      primaryTextTheme: AppTypography.textTheme,
      cardTheme: CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.line, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.verdePrincipal,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.line,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: buttonShape,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.verdePrincipal,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          side: const BorderSide(color: AppColors.line, width: 1.4),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.verdePrincipal,
          textStyle: const TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.verdePrincipal,
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: Colors.transparent,
        modalElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.verdePrincipal,
        contentTextStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
          color: AppColors.white,
          height: 1.4,
        ),
        actionTextColor: AppColors.acentoNatural,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        elevation: 6,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.verdeSecundario,
        linearTrackColor: AppColors.buenoSoft,
        circularTrackColor: AppColors.buenoSoft,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: AppColors.verdeSecundario,
        inactiveTrackColor: AppColors.buenoSoft,
        thumbColor: AppColors.white,
        overlayColor: AppColors.verdeSecundario.withValues(alpha: 0.14),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 11,
          elevation: 4,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        trackShape: const RoundedRectSliderTrackShape(),
        showValueIndicator: ShowValueIndicator.never,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          return AppColors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.verdeSecundario;
          }
          return AppColors.line;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        trackOutlineWidth: WidgetStateProperty.all(0),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.buenoSoft,
        side: const BorderSide(color: AppColors.line),
        labelStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.inkSoft,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          fontFamily: AppFonts.body,
          color: AppColors.inkFaint,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(
            color: AppColors.verdeSecundario,
            width: 1.6,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SoftPageTransitionBuilder(),
          TargetPlatform.iOS: _SoftPageTransitionBuilder(),
          TargetPlatform.macOS: _SoftPageTransitionBuilder(),
          TargetPlatform.windows: _SoftPageTransitionBuilder(),
          TargetPlatform.linux: _SoftPageTransitionBuilder(),
          TargetPlatform.fuchsia: _SoftPageTransitionBuilder(),
        },
      ),
    );
  }
}

class _SoftPageTransitionBuilder extends PageTransitionsBuilder {
  const _SoftPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
