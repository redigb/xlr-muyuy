import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

class OrganicBackground extends StatefulWidget {
  const OrganicBackground({super.key, this.child, this.animate = true});

  final Widget? child;
  final bool animate;

  @override
  State<OrganicBackground> createState() => _OrganicBackgroundState();
}

class _OrganicBackgroundState extends State<OrganicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    );
    if (widget.animate) {
      _controller.repeat();
    } else {
      _controller.value = 0.2;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(painter: _OrganicPainter(_controller.value));
              },
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _OrganicPainter extends CustomPainter {
  _OrganicPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;
    final rect = Offset.zero & size;

    void blob(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    blob(
      Offset(
        size.width * (0.82 + 0.04 * math.sin(t)),
        size.height * (0.08 + 0.02 * math.cos(t)),
      ),
      size.width * 0.55,
      AppColors.verdeSecundario,
    );
    blob(
      Offset(
        size.width * (0.08 + 0.03 * math.cos(t)),
        size.height * (0.36 + 0.03 * math.sin(t * 0.8)),
      ),
      size.width * 0.48,
      AppColors.acentoNatural,
    );
    blob(
      Offset(
        size.width * (0.72 + 0.03 * math.cos(t * 1.2)),
        size.height * 0.82,
      ),
      size.width * 0.45,
      AppColors.tecnologia.withValues(alpha: 0.32),
    );

    final contour = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = AppColors.verdePrincipal.withValues(alpha: 0.055);

    for (var line = 0; line < 5; line++) {
      final path = Path();
      final baseY = size.height * (0.72 + line * 0.045);
      path.moveTo(-20, baseY);
      for (var x = -20.0; x <= size.width + 20; x += 18) {
        final y =
            baseY +
            math.sin((x / size.width) * math.pi * 2.2 + line * 0.7 + t * 0.15) *
                12;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, contour);
    }

    final leafPaint = Paint()
      ..color = AppColors.verdePrincipal.withValues(alpha: 0.12);
    for (var i = 0; i < 7; i++) {
      final phase = t * (0.25 + i * 0.02) + i * 1.3;
      final x = size.width * (0.08 + 0.84 * ((i * 0.137 + 0.05) % 1));
      final y =
          size.height * (0.12 + 0.72 * ((i * 0.219 + 0.11) % 1)) +
          math.sin(phase) * 10;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(phase * 0.35);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 5.5, height: 11),
        leafPaint,
      );
      canvas.restore();
    }

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.fondoSuave.withValues(alpha: 0.2),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _OrganicPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
