import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/organic_background.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  static const logoAsset = 'assets/images/logo_muyuy_white_trim.png';

  /// true si main() retuvo el primer cuadro; el splash lo libera una sola vez.
  static bool firstFrameDeferred = false;

  static void releaseFirstFrame() {
    if (!firstFrameDeferred) return;
    firstFrameDeferred = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Máximo 1 s de espera: nunca dejar la app trabada en el splash nativo.
    Future.any([
      precacheImage(const AssetImage(SplashView.logoAsset), context),
      Future<void>.delayed(const Duration(seconds: 1)),
    ]).whenComplete(SplashView.releaseFirstFrame);
  }

  @override
  void dispose() {
    SplashView.releaseFirstFrame();
    super.dispose();
  }

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
                  const BrandLogo(white: true, height: 74),
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
                  ),
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
