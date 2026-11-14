import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

class TerrainScene extends StatefulWidget {
  const TerrainScene({
    super.key,
    required this.calendario,
    required this.month,
    required this.onMonthChanged,
    this.showSlider = true,
  });

  final List<CalendarioMes> calendario;
  final int month;
  final ValueChanged<int> onMonthChanged;
  final bool showSlider;

  @override
  State<TerrainScene> createState() => _TerrainSceneState();
}

class _TerrainSceneState extends State<TerrainScene>
    with TickerProviderStateMixin {
  late final AnimationController _drift;
  late final AnimationController _transition;
  late double _from;
  late double _to;

  @override
  void initState() {
    super.initState();
    _from = widget.month.toDouble();
    _to = _from;
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant TerrainScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.month != widget.month) {
      _from = _currentMonth;
      _to = widget.month.toDouble();
      _transition.forward(from: 0);
    }
  }

  double get _currentMonth {
    final curved = Curves.easeInOutCubic.transform(_transition.value);
    return _from + (_to - _from) * curved;
  }

  @override
  void dispose() {
    _drift.dispose();
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.calendario.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.48,
            child: AnimatedBuilder(
              animation: Listenable.merge([_drift, _transition]),
              builder: (context, _) {
                final monthIndex = _currentMonth;
                final climate = _climateAt(widget.calendario, monthIndex);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _TerrainPainter(
                          calendario: widget.calendario,
                          monthIndex: monthIndex,
                          phase: _drift.value,
                          climate: climate,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: _SceneBadge(
                        month: widget.month,
                        estado: climate.estado,
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 14,
                      child: _FrostBadge(probHelada: climate.probHelada),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Row(
                        children: [
                          _SceneStat(
                            icon: Icons.water_drop_rounded,
                            value: '${climate.lluviaMm.round()} mm',
                            label: 'lluvia',
                          ),
                          const SizedBox(width: 8),
                          _SceneStat(
                            icon: Icons.thermostat_rounded,
                            value: '${climate.etMm.round()} mm',
                            label: 'evap.',
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.verdePrincipal.withValues(
                                alpha: 0.82,
                              ),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _balanceLabel(climate.balanceHidricoMm),
                              style: const TextStyle(
                                fontFamily: AppFonts.body,
                                fontWeight: FontWeight.w600,
                                fontSize: 10.5,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (widget.showSlider)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Column(
                children: [
                  Slider(
                    value: (widget.month - 1).toDouble(),
                    min: 0,
                    max: (widget.calendario.length - 1).toDouble(),
                    divisions: widget.calendario.length - 1,
                    label: monthName(widget.month),
                    onChanged: (value) {
                      widget.onMonthChanged(value.round() + 1);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ene', style: AppTypography.dataLabel),
                        Text(
                          'Desliza para recorrer el año',
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontWeight: FontWeight.w500,
                            fontSize: 10.5,
                            color: AppColors.inkFaint,
                          ),
                        ),
                        Text('Dic', style: AppTypography.dataLabel),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _balanceLabel(double balance) {
    if (balance >= 0) return 'Balance +${balance.round()} mm';
    return 'Déficit ${balance.round()} mm';
  }
}

class _SceneBadge extends StatelessWidget {
  const _SceneBadge({required this.month, required this.estado});

  final int month;
  final MesEstado estado;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.estadoColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Text(
              monthName(month),
              key: ValueKey(month),
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.ink,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _estadoLabel(estado),
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _estadoLabel(MesEstado estado) {
    switch (estado) {
      case MesEstado.helada:
        return 'helada';
      case MesEstado.seco:
        return 'seco';
      case MesEstado.bueno:
        return 'bueno';
    }
  }
}

class _FrostBadge extends StatelessWidget {
  const _FrostBadge({required this.probHelada});

  final double probHelada;

  @override
  Widget build(BuildContext context) {
    final isFrost = probHelada >= 0.5;
    final color = isFrost ? AppColors.helada : AppColors.verdeSecundario;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFrost ? Icons.ac_unit_rounded : Icons.wb_sunny_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            '${(probHelada * 100).round()}%',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneStat extends StatelessWidget {
  const _SceneStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.inkSoft),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClimateSample {
  const _ClimateSample({
    required this.probHelada,
    required this.lluviaMm,
    required this.etMm,
    required this.balanceHidricoMm,
    required this.estresCalor,
  });

  final double probHelada;
  final double lluviaMm;
  final double etMm;
  final double balanceHidricoMm;
  final double estresCalor;

  MesEstado get estado {
    if (probHelada >= 0.5) return MesEstado.helada;
    if (balanceHidricoMm < -40) return MesEstado.seco;
    return MesEstado.bueno;
  }
}

_ClimateSample _climateAt(List<CalendarioMes> calendario, double monthIndex) {
  final ordered = List<CalendarioMes>.of(calendario)
    ..sort((a, b) => a.mes.compareTo(b.mes));
  if (ordered.isEmpty) {
    return const _ClimateSample(
      probHelada: 0,
      lluviaMm: 0,
      etMm: 0,
      balanceHidricoMm: 0,
      estresCalor: 0,
    );
  }
  final wrapped = (monthIndex - 1) % ordered.length;
  final normalized = wrapped < 0 ? wrapped + ordered.length : wrapped;
  final lower = normalized.floor();
  final upper = (lower + 1) % ordered.length;
  final t = normalized - lower;
  final a = ordered[lower.clamp(0, ordered.length - 1)];
  final b = ordered[upper];

  double lerp(num from, num to) => from + (to - from) * t;

  return _ClimateSample(
    probHelada: lerp(a.probHelada, b.probHelada),
    lluviaMm: lerp(a.lluviaMm, b.lluviaMm),
    etMm: lerp(a.etMm, b.etMm),
    balanceHidricoMm: lerp(a.balanceHidricoMm, b.balanceHidricoMm),
    estresCalor: lerp(a.estresCalor, b.estresCalor),
  );
}

class _TerrainPainter extends CustomPainter {
  _TerrainPainter({
    required this.calendario,
    required this.monthIndex,
    required this.phase,
    required this.climate,
  });

  final List<CalendarioMes> calendario;
  final double monthIndex;
  final double phase;
  final _ClimateSample climate;

  @override
  void paint(Canvas canvas, Size size) {
    final frost = climate.probHelada.clamp(0.0, 1.0);
    final dry = ((-climate.balanceHidricoMm) / 95).clamp(0.0, 1.0);
    final heat = climate.estresCalor.clamp(0.0, 1.0);
    final rain = (climate.lluviaMm / 95).clamp(0.0, 1.0);

    final goodTop = const Color(0xFFDDF6E6);
    final frostTop = const Color(0xFFD7EFFA);
    final dryTop = const Color(0xFFFCE9BD);

    var skyTop = Color.lerp(goodTop, dryTop, dry)!;
    skyTop = Color.lerp(skyTop, frostTop, frost * 0.85)!;

    var skyBottom = Color.lerp(
      const Color(0xFFF2FBF5),
      const Color(0xFFFFF6DD),
      dry,
    )!;
    skyBottom = Color.lerp(skyBottom, const Color(0xFFF1FAFE), frost * 0.8)!;

    final skyRect = Offset.zero & size;
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyTop, skyBottom],
        ).createShader(skyRect),
    );

    final sunX = size.width * (0.18 + 0.64 * ((monthIndex - 1) / 11));
    final sunY = size.height * (0.24 + 0.03 * math.sin(monthIndex * 0.9));
    final sunColor = Color.lerp(
      const Color(0xFFFFD166),
      const Color(0xFFBFE7FF),
      frost,
    )!;
    canvas.drawCircle(
      Offset(sunX, sunY),
      size.width * 0.16,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                sunColor.withValues(alpha: 0.55),
                sunColor.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(sunX, sunY),
                radius: size.width * 0.16,
              ),
            ),
    );
    canvas.drawCircle(
      Offset(sunX, sunY),
      size.width * 0.045,
      Paint()..color = sunColor,
    );

    _drawClouds(canvas, size, rain, frost);

    _drawMountains(canvas, size, frost, dry);
    _drawFields(canvas, size, frost, dry, heat);
    _drawParticles(canvas, size, frost, rain, heat, dry);

    final vignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppColors.verdePrincipal.withValues(alpha: 0.12),
        ],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, vignette);
  }

  void _drawClouds(Canvas canvas, Size size, double rain, double frost) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.55 + rain * 0.2);

    for (var i = 0; i < 3; i++) {
      final drift = (phase * (0.22 + i * 0.04) + i * 0.31) % 1.2 - 0.1;
      final x = size.width * drift;
      final y = size.height * (0.11 + i * 0.075);
      final width = size.width * (0.2 + i * 0.035);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y),
            width: width,
            height: size.height * 0.055,
          ),
          Radius.circular(size.height * 0.03),
        ),
        paint,
      );
      canvas.drawCircle(
        Offset(x - width * 0.2, y - size.height * 0.015),
        size.height * 0.035,
        paint,
      );
      if (frost > 0.45) {
        canvas.drawCircle(
          Offset(x + width * 0.22, y + size.height * 0.004),
          size.height * 0.028,
          paint,
        );
      }
    }
  }

  void _drawMountains(Canvas canvas, Size size, double frost, double dry) {
    final back = Path()
      ..moveTo(0, size.height * 0.68)
      ..lineTo(size.width * 0.14, size.height * 0.46)
      ..lineTo(size.width * 0.26, size.height * 0.58)
      ..lineTo(size.width * 0.38, size.height * 0.4)
      ..lineTo(size.width * 0.52, size.height * 0.6)
      ..lineTo(size.width * 0.66, size.height * 0.47)
      ..lineTo(size.width * 0.82, size.height * 0.62)
      ..lineTo(size.width, size.height * 0.52)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      back,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              const Color(0xFF2C7A4B),
              const Color(0xFF8A9C6B),
              dry * 0.5,
            )!,
            const Color(0xFF1C5C38),
          ],
        ).createShader(Offset.zero & size),
    );

    if (frost > 0.3) {
      final snowPaint = Paint()
        ..color = AppColors.white.withValues(
          alpha: (frost - 0.25).clamp(0, 0.9),
        );
      final caps = Path()
        ..moveTo(size.width * 0.38, size.height * 0.4)
        ..lineTo(size.width * 0.43, size.height * 0.5)
        ..lineTo(size.width * 0.38, size.height * 0.47)
        ..lineTo(size.width * 0.33, size.height * 0.51)
        ..close()
        ..moveTo(size.width * 0.66, size.height * 0.47)
        ..lineTo(size.width * 0.7, size.height * 0.55)
        ..lineTo(size.width * 0.66, size.height * 0.52)
        ..lineTo(size.width * 0.62, size.height * 0.55)
        ..close();
      canvas.drawPath(caps, snowPaint);
    }

    final mid = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.6,
        size.width * 0.36,
        size.height * 0.73,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.58,
        size.width * 0.7,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.86,
        size.height * 0.64,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      mid,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2F8A55), Color(0xFF17663D)],
        ).createShader(Offset.zero & size),
    );
  }

  void _drawFields(
    Canvas canvas,
    Size size,
    double frost,
    double dry,
    double heat,
  ) {
    final field = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height * 0.72,
        size.width * 0.62,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.85,
        size.width,
        size.height * 0.77,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fieldTop = Color.lerp(
      const Color(0xFF64C76B),
      const Color(0xFFC9B36A),
      dry * 0.65,
    )!;
    canvas.drawPath(
      field,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fieldTop, Color.lerp(fieldTop, AppColors.tierra, 0.35)!],
        ).createShader(Offset.zero & size),
    );

    final furrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.verdePrincipal.withValues(alpha: 0.24);

    for (var i = 0; i < 6; i++) {
      final y = size.height * (0.86 + i * 0.026);
      final path = Path()
        ..moveTo(-10, y)
        ..quadraticBezierTo(
          size.width * 0.5,
          y - 8 - i * 2,
          size.width + 10,
          y + 2,
        );
      canvas.drawPath(path, furrow);
    }

    final cropPaint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.verdePrincipal.withValues(alpha: 0.32);
    for (var i = 0; i < 18; i++) {
      final x = size.width * (0.03 + (i % 9) * 0.105 + (i ~/ 9) * 0.035);
      final y = size.height * (0.86 + (i ~/ 9) * 0.075);
      canvas.drawLine(Offset(x, y), Offset(x + 3, y - 6), cropPaint);
    }

    final houseX = size.width * 0.79;
    final houseY = size.height * 0.7;
    final houseW = size.width * 0.055;
    final houseH = size.height * 0.065;
    canvas.drawRect(
      Rect.fromLTWH(houseX, houseY, houseW, houseH),
      Paint()..color = const Color(0xFFF7F2E6),
    );
    final roof = Path()
      ..moveTo(houseX - houseW * 0.2, houseY)
      ..lineTo(houseX + houseW * 0.5, houseY - houseH * 0.62)
      ..lineTo(houseX + houseW * 1.2, houseY)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF8C4A2F));
    canvas.drawRect(
      Rect.fromLTWH(
        houseX + houseW * 0.38,
        houseY + houseH * 0.35,
        houseW * 0.24,
        houseH * 0.3,
      ),
      Paint()..color = const Color(0xFFFFC857),
    );

    if (heat > 0.25) {
      final haze = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.white.withValues(alpha: heat * 0.4);
      for (var i = 0; i < 3; i++) {
        final path = Path();
        final baseY = size.height * (0.72 + i * 0.03);
        for (var x = 0.0; x <= size.width; x += 12) {
          final y =
              baseY + math.sin(x * 0.06 + phase * 6 + i) * (1.5 + heat * 2.5);
          if (x == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, haze);
      }
    }
  }

  void _drawParticles(
    Canvas canvas,
    Size size,
    double frost,
    double rain,
    double heat,
    double dry,
  ) {
    final count = 26;
    for (var i = 0; i < count; i++) {
      final seed = (i * 0.6180339887) % 1;
      final speed = 0.18 + (i % 5) * 0.04;
      final x =
          (seed * size.width +
              math.sin(phase * math.pi * 2 + i) * 8 +
              size.width) %
          size.width;
      final progress = (seed * 3.1 + phase * speed * 3) % 1;
      final y = size.height * (0.12 + progress * 0.78);

      if (frost > 0.5) {
        canvas.drawCircle(
          Offset(x, y),
          1.5 + (i % 3) * 0.7,
          Paint()..color = AppColors.white.withValues(alpha: 0.75),
        );
      } else if (rain > 0.55) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x - 2, y + 7),
          Paint()
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round
            ..color = AppColors.tecnologia.withValues(alpha: 0.55),
        );
      } else if (dry > 0.5) {
        canvas.drawCircle(
          Offset(x, y),
          1.1,
          Paint()..color = AppColors.tierra.withValues(alpha: 0.35),
        );
      } else {
        canvas.drawCircle(
          Offset(x, y),
          1.4,
          Paint()
            ..color = AppColors.acentoNatural.withValues(
              alpha: 0.4 + (i % 3) * 0.12,
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TerrainPainter oldDelegate) {
    return oldDelegate.monthIndex != monthIndex ||
        oldDelegate.phase != phase ||
        oldDelegate.climate.balanceHidricoMm != climate.balanceHidricoMm ||
        oldDelegate.climate.probHelada != climate.probHelada;
  }
}
