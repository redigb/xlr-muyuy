import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';

class CalendarLandscape extends StatefulWidget {
  const CalendarLandscape({super.key, required this.climate});

  final CalendarioMes climate;

  @override
  State<CalendarLandscape> createState() => _CalendarLandscapeState();
}

class _CalendarLandscapeState extends State<CalendarLandscape>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  bool? _playOverride;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    final play = _playOverride ?? !MediaQuery.disableAnimationsOf(context);
    if (play && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!play) {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _LandscapePainter(widget.climate, _motion),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      Positioned(
        right: 12,
        top: 58,
        child: Material(
          color: const Color(0xEFFFFFFF),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: context.tr(
              _motion.isAnimating ? 'cal.scene.pause' : 'cal.scene.play',
            ),
            icon: Icon(
              _motion.isAnimating
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: const Color(0xFF14532D),
            ),
            onPressed: () => setState(() {
              _playOverride = !_motion.isAnimating;
              _syncMotion();
            }),
          ),
        ),
      ),
    ],
  );
}

class _LandscapePainter extends CustomPainter {
  _LandscapePainter(this.climate, this.motion) : super(repaint: motion);

  final CalendarioMes climate;
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final frost = climate.estado == MesEstado.helada;
    final dry = climate.estado == MesEstado.seco;
    final wetness = (climate.lluviaMm / 140).clamp(0.0, 1.0);
    final phase = motion.value;
    final overcast = wetness >= 0.55;
    final ink = Paint();
    final scene = Offset.zero & size;

    canvas.save();
    canvas.scale(size.width / 400, size.height / 270);
    final sky = frost
        ? const [Color(0xFF829BB3), Color(0xFFE6F1F6)]
        : dry
        ? const [Color(0xFFF3CE90), Color(0xFFFFF1CD)]
        : [
            Color.lerp(
              const Color(0xFFDAEDCE),
              const Color(0xFFA8BEC6),
              wetness,
            )!,
            const Color(0xFFEDF5DF),
          ];
    const bounds = Rect.fromLTWH(0, 0, 400, 270);
    ink.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: sky,
    ).createShader(bounds);
    canvas.drawRect(bounds, ink);
    ink.shader = null;

    if (!frost && !overcast) {
      const sun = Offset(306, 65);
      final glowRadius = 54 + 7 * math.sin(phase * math.pi * 2);
      ink.shader = RadialGradient(
        colors: [
          const Color(0xFFF6C75E).withValues(alpha: 0.42 - wetness * 0.22),
          const Color(0x00F6C75E),
        ],
      ).createShader(Rect.fromCircle(center: sun, radius: glowRadius));
      canvas.drawCircle(sun, glowRadius, ink);
      ink.shader = null;
      canvas.drawCircle(
        sun,
        17,
        ink
          ..color = const Color(0xFFF5C357)
              .withValues(alpha: 0.9 - wetness * 0.48),
      );
    }

    final cloudColor = overcast
        ? const Color(0xD5D9E4E9)
        : frost
        ? const Color(0xA9F1F8FD)
        : const Color(0xA8FFFFFF);
    final cloudCount = frost || overcast
        ? 5
        : dry
        ? 2
        : 3;
    for (var i = 0; i < cloudCount; i++) {
      final drift = 15 * math.sin(phase * math.pi * 2 + i);
      final x = 24.0 + 82 * i + drift;
      final y = 59.0 + (i % 3) * 17;
      ink.color = cloudColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 69, 10),
          const Radius.circular(8),
        ),
        ink,
      );
      canvas.drawOval(Rect.fromLTWH(x + 13, y - 7, 24, 16), ink);
      if (overcast || frost) {
        canvas.drawOval(Rect.fromLTWH(x + 28, y - 10, 30, 19), ink);
      }
    }

    void ridge(List<Offset> points, Color color) {
      canvas.drawPath(Path()..addPolygon(points, true), ink..color = color);
    }

    ridge(
      const [
        Offset(0, 180),
        Offset(54, 122),
        Offset(101, 151),
        Offset(151, 105),
        Offset(206, 160),
        Offset(262, 123),
        Offset(326, 163),
        Offset(400, 137),
        Offset(400, 270),
        Offset(0, 270),
      ],
      frost
          ? const Color(0xFF4A6877)
          : dry
          ? const Color(0xFF68794D)
          : const Color(0xFF2C634B),
    );

    final hill = Path()
      ..moveTo(0, 189)
      ..cubicTo(66, 152, 120, 197, 185, 180)
      ..cubicTo(267, 157, 322, 214, 400, 179)
      ..lineTo(400, 270)
      ..lineTo(0, 270)
      ..close();
    canvas.drawPath(
      hill,
      ink
        ..color = frost
            ? const Color(0xFF648C93)
            : dry
            ? const Color(0xFF858950)
            : const Color(0xFF236348),
    );

    final field = Path()
      ..moveTo(0, 210)
      ..cubicTo(144, 170, 252, 232, 400, 206)
      ..lineTo(400, 270)
      ..lineTo(0, 270)
      ..close();
    ink.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: frost
          ? const [Color(0xFFD5E9E7), Color(0xFFA8C9CB)]
          : dry
          ? const [Color(0xFFCCAF60), Color(0xFFA9803F)]
          : const [Color(0xFFA6BC64), Color(0xFF6E943D)],
    ).createShader(const Rect.fromLTWH(0, 190, 400, 80));
    canvas.drawPath(field, ink);
    ink.shader = null;
    canvas.save();
    canvas.clipPath(field);
    ink
      ..color = const Color(0x3B355235)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 9; i++) {
      final y = 205.0 + i * 8;
      canvas.drawPath(
        Path()
          ..moveTo(0, y + 10)
          ..quadraticBezierTo(190, y - 4, 400, y + 7),
        ink,
      );
    }
    canvas.restore();
    ink.style = PaintingStyle.fill;

    canvas.drawRect(
      const Rect.fromLTWH(313, 185, 23, 20),
      ink..color = const Color(0xFFFFE5AC),
    );
    ridge(const [
      Offset(309, 186),
      Offset(324, 173),
      Offset(340, 186),
    ], const Color(0xFFA24E35));
    canvas.drawRect(
      const Rect.fromLTWH(322, 193, 6, 12),
      ink..color = const Color(0xFFA47750),
    );

    if (frost) {
      canvas.save();
      canvas.clipPath(field);
      _paintFrost(canvas, ink, phase);
      canvas.restore();
    } else if (wetness > 0) {
      _paintRain(canvas, ink, field, wetness, phase);
    } else if (dry) {
      _paintHeat(canvas, ink, phase);
    }
    canvas.restore();
    ink.shader = const LinearGradient(
      begin: Alignment.center,
      end: Alignment.bottomCenter,
      colors: [Color(0x00172B20), Color(0x36172B20)],
    ).createShader(scene);
    canvas.drawRect(scene, ink);
  }

  void _paintRain(
    Canvas canvas,
    Paint ink,
    Path field,
    double wetness,
    double phase,
  ) {
    // Keep low monthly totals visibly light while allowing dense rain at the high end.
    final intensity = wetness * wetness;
    final drops = 2 + (82 * intensity).round();
    ink.strokeCap = StrokeCap.round;
    for (var i = 0; i < drops; i++) {
      final foreground = i.isEven;
      final speed = foreground ? 14 : 9;
      final progress = (i * 0.618 + phase * speed) % 1;
      final x = (i * 73.7 % 420) - 10 - progress * 18;
      final y = -22 + progress * 310;
      final length = (foreground ? 10.0 : 6.0) + wetness * 7;
      ink
        ..color = foreground ? const Color(0xCE98DEF4) : const Color(0xA65D9FC7)
        ..strokeWidth = foreground ? 1.8 : 1.1;
      canvas.drawLine(Offset(x, y), Offset(x - 5, y + length), ink);
    }

    canvas.save();
    canvas.clipPath(field);
    ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    final ripples = (12 * intensity).round();
    for (var i = 0; i < ripples; i++) {
      final ripple = (phase * 17 + i * 0.381) % 1;
      final center = Offset(22 + i * 71.7 % 358, 210 + i * 13.9 % 48);
      ink.color = const Color(0xFFE0F9FF)
          .withValues(alpha: (1 - ripple) * 0.75);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: 4 + ripple * 24,
          height: 1 + ripple * 7,
        ),
        ink,
      );
    }
    ink.style = PaintingStyle.fill;
    canvas.restore();
  }

  void _paintFrost(Canvas canvas, Paint ink, double phase) {
    ink.strokeWidth = 1.3;
    for (var i = 0; i < 19; i++) {
      final x = 12 + i * 67.3 % 376;
      final y = 208 + i * 13.9 % 50;
      final glint = (1 + math.sin((phase * 4 + i * 0.37) * math.pi * 2)) / 2;
      final radius = 1 + glint * 3;
      ink.color = const Color(0xFFF3FDFF).withValues(alpha: glint * 0.9);
      canvas.drawLine(Offset(x - radius, y), Offset(x + radius, y), ink);
      canvas.drawLine(Offset(x, y - radius), Offset(x, y + radius), ink);
    }
  }

  void _paintHeat(Canvas canvas, Paint ink, double phase) {
    ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < 5; i++) {
      final rise = (phase * 4 + i * 0.247) % 1;
      final x = 45.0 + i * 75;
      final y = 217 - rise * 57;
      ink.color = const Color(0xFFFFE8AB)
          .withValues(alpha: math.sin(rise * math.pi) * 0.7);
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..cubicTo(x + 12, y - 9, x - 10, y - 19, x + 3, y - 30),
        ink,
      );
    }
    ink.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(_LandscapePainter oldDelegate) =>
      climate != oldDelegate.climate || motion != oldDelegate.motion;
}
