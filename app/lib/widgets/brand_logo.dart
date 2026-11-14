import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 40,
    this.white = false,
    this.markOnly = false,
    this.animateIn = false,
  });

  final double height;
  final bool white;
  final bool markOnly;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final asset = markOnly
        ? (white
              ? 'assets/images/logo_mark_white.png'
              : 'assets/images/logo_mark.png')
        : (white
              ? 'assets/images/logo_muyuy_white_trim.png'
              : 'assets/images/logo_muyuy_trim.png');

    Widget image = Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'MUYUY',
    );

    if (animateIn) {
      image = image
          .animate()
          .fadeIn(duration: 620.ms, curve: Curves.easeOut)
          .scale(
            begin: const Offset(0.94, 0.94),
            end: const Offset(1, 1),
            duration: 720.ms,
            curve: Curves.easeOutBack,
          );
    }

    return image;
  }
}
