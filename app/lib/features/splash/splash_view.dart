import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/organic_background.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.verdePrincipal,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.gradientHero),
            ),
          ),
          const Positioned.fill(child: OrganicBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(),
                  const BrandLogo(white: true, height: 74, animateIn: true),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('splash.tagline'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: AppColors.white.withValues(alpha: 0.78),
                      height: 1.5,
                    ),
                  ).animate().fadeIn(delay: 220.ms, duration: 520.ms),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: const LinearProgressIndicator(
                        minHeight: 4,
                        color: AppColors.acentoNatural,
                        backgroundColor: Color(0x33FFFFFF),
                      ),
                    ),
                  ).animate().fadeIn(delay: 360.ms, duration: 420.ms),
                  const Spacer(),
                  Text(
                    'NASA SPACE APPS CHALLENGE 2026',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 1.4,
                      color: AppColors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Huánuco, Perú',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 11,
                      color: AppColors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
