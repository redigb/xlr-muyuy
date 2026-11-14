import 'dart:math' as math;

import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/demo_data.dart';
import '../../data/soil_profiles.dart';
import '../../models/models.dart';
import '../../models/soil_analysis.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/data_widgets.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';
import '../soil/soil_vision_screen.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  final Set<String> _expanded = {};
  bool _touched = false;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final paquete = state.paquete;
    final options = state.rotacionesOrdenadas;
    final visible = _showAll ? options : options.take(3).toList();
    final lastSoil = state.lastSoil;
    final hasSoil = lastSoil != null && lastSoil.zonaId == (state.zona?.id ?? '');
    final soilProfile = hasSoil ? soilProfileFor(lastSoil.effectiveIndex) : null;

    return PageBody(
      children: [
        PageTopBar(
          title: 'Mis opciones',
          subtitle: state.zona == null
              ? 'Sin zona elegida'
              : prettyZoneName(state.zona!.nombre),
          trailing: Pill(
            label: '${options.length} opciones',
            icon: Icons.layers_rounded,
            color: AppColors.verdePrincipal,
            background: AppColors.buenoSoft,
            compact: true,
          ),
        ),
        const SizedBox(height: 16),
        if (paquete == null || options.isEmpty)
          _OptionsEmpty(onNavigate: widget.onNavigate)
        else ...[
          _RankingHeader(
            state: state,
            options: options,
            onEdit: () => widget.onNavigate(1),
          ),
          const SizedBox(height: 12),
          if (soilProfile != null && lastSoil != null)
            _SoilNoteCard(
              profile: soilProfile,
              record: lastSoil,
              onOpen: () => _openSoil(context, state),
            )
          else
            _SoilPromptCard(onOpen: () => _openSoil(context, state)),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.025),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Column(
              key: ValueKey(
                '${visible.map((item) => item.id).join('|')}-$_showAll',
              ),
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  _RotationCard(
                        rotation: visible[i],
                        rank: i,
                        score: state.puntaje(visible[i]),
                        soilNote: soilProfile != null
                            ? soilRotationNote(soilProfile, visible[i], paquete)
                            : null,
                        expanded:
                            _expanded.contains(visible[i].id) ||
                            (!_touched && i == 0),
                        onToggle: () {
                          setState(() {
                            _touched = true;
                            if (_expanded.contains(visible[i].id)) {
                              _expanded.remove(visible[i].id);
                            } else {
                              _expanded.add(visible[i].id);
                            }
                          });
                        },
                      )
                      .animate()
                      .fadeIn(duration: 380.ms, delay: (i * 80).ms)
                      .slideY(begin: 0.04),
                  if (i < visible.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          if (options.length > 3) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(
                _showAll
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(
                _showAll
                    ? 'Ver solo las 3 mejores'
                    : 'Ver las ${options.length} opciones',
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.swap_vert_rounded,
                  size: 18,
                  color: AppColors.verdeSecundario,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'El orden cambia según tus prioridades. Ajusta las tuyas '
                    'cuando quieras.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate(1),
                  child: const Text('Ajustar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Compartir mi paquete',
            icon: Icons.ios_share_rounded,
            onPressed: () => widget.onNavigate(4),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'La IA explica. Tú decides. Confirma siempre con un experto local.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  void _openSoil(BuildContext context, AppState state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SoilVisionScreen(state: state)),
    );
  }
}

class _SoilNoteCard extends StatelessWidget {
  const _SoilNoteCard({
    required this.profile,
    required this.record,
    required this.onOpen,
  });

  final SoilProfile profile;
  final SoilRecord record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: onOpen,
      borderColor: AppColors.verdeSecundario.withValues(alpha: 0.35),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.buenoSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.eco_rounded,
              size: 19,
              color: AppColors.verdePrincipal,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tu suelo: ${profile.label}',
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (record.corrected)
                      const Pill(
                        label: 'Corregido',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.verdePrincipal,
                        background: AppColors.buenoSoft,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  profile.summary,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: AppColors.inkFaint,
          ),
        ],
      ),
    );
  }
}

class _SoilPromptCard extends StatelessWidget {
  const _SoilPromptCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: AppColors.gradientTech,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 19,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajusta las opciones a tu suelo',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  'Toma una foto y afina las rotaciones según tu tipo de tierra.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: AppColors.inkFaint,
          ),
        ],
      ),
    );
  }
}

class _RankingHeader extends StatelessWidget {
  const _RankingHeader({
    required this.state,
    required this.options,
    required this.onEdit,
  });

  final AppState state;
  final List<Rotacion> options;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final topScore = state.puntaje(options.first);

    return SoftCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F3D23), Color(0xFF14532D), Color(0xFF1B6B3A)],
      ),
      borderColor: AppColors.verdePrincipal,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 20,
                color: AppColors.acentoNatural,
              ),
              const SizedBox(width: 8),
              Text(
                'TU MEJOR OPCIÓN HOY',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 1.3,
                  color: AppColors.white.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              Pill(
                label: '${(topScore * 100).round()}/100',
                icon: Icons.trending_up_rounded,
                color: AppColors.verdePrincipal,
                background: AppColors.acentoNatural,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            options.first.secuencia.map(cropName).join(' → '),
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.16,
              letterSpacing: -0.4,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${Scoring.etiqueta(topScore)} para tus prioridades actuales.',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 12,
              color: AppColors.white.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (state.cultivoInicial != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.acentoNatural.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppColors.acentoNatural.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '${cropEmoji(state.cultivoInicial!)} '
                    '${cropName(state.cultivoInicial!)}',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.acentoNatural,
                    ),
                  ),
                ),
              for (final factor in state.prioridades)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    '${priorityEmoji(factor)} ${priorityTitle(factor)}',
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppColors.white,
                    ),
                  ),
                ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.acentoNatural.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppColors.acentoNatural.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'Cambiar',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.acentoNatural,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RotationCard extends StatelessWidget {
  const _RotationCard({
    required this.rotation,
    required this.rank,
    required this.score,
    required this.expanded,
    required this.onToggle,
    this.soilNote,
  });

  final Rotacion rotation;
  final int rank;
  final double score;
  final bool expanded;
  final VoidCallback onToggle;
  final String? soilNote;

  Color get _rankColor {
    switch (rank) {
      case 0:
        return AppColors.verdeSecundario;
      case 1:
        return AppColors.tecnologia;
      default:
        return AppColors.tierra;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      borderColor: rank == 0
          ? AppColors.verdeSecundario.withValues(alpha: 0.5)
          : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _rankColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${rank + 1}',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (rank == 0)
                          Pill(
                            label: 'Recomendada',
                            icon: Icons.auto_awesome_rounded,
                            color: AppColors.verdePrincipal,
                            background: AppColors.buenoSoft,
                            compact: true,
                          ),
                        if (rotation.esActual)
                          const Pill(
                            label: 'Práctica común',
                            icon: Icons.place_rounded,
                            color: AppColors.tierra,
                            background: AppColors.secoSoft,
                            compact: true,
                          ),
                      ],
                    ),
                    if (rank == 0 || rotation.esActual)
                      const SizedBox(height: 6),
                    CropSequence(sequence: rotation.secuencia, compact: true),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ScoreRing(value: score),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 15, color: _rankColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${Scoring.etiqueta(score)} · prioridades aplicadas',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 260),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.inkFaint,
                ),
              ),
            ],
          ),
          if (soilNote != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.landscape_rounded,
                  size: 14,
                  color: AppColors.tierra,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    soilNote!,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppColors.tierra,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (expanded) ...[
            const SizedBox(height: 14),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth > 520 ? 4 : 2;
                      const spacing = 14.0;
                      final width =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      const factors = ['agua', 'suelo', 'ingresos', 'riesgo'];
                      return Wrap(
                        spacing: spacing,
                        runSpacing: 12,
                        children: [
                          for (final factor in factors)
                            SizedBox(
                              width: width,
                              child: ScoreBar(
                                factor: factor,
                                value: rotation.puntajes[factor] ?? 0,
                                compact: true,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final entry in rotation.confianza.entries)
                        ConfidenceChip(factor: entry.key, level: entry.value),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF1FBF4), AppColors.fondoSuave],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.verdeSecundario.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 14,
                                color: AppColors.verdePrincipal,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'EXPLICACIÓN SIMPLE',
                              style: AppTypography.kicker.copyWith(
                                fontSize: 9.5,
                                color: AppColors.verdePrincipal,
                              ),
                            ),
                            const Spacer(),
                            Pill(
                              label: 'Groq',
                              icon: Icons.bolt_rounded,
                              color: AppColors.tierra,
                              background: AppColors.secoSoft,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          rotation.explicacion,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.ink, height: 1.55),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.secoSoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.tierra.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 17,
                          color: AppColors.tierra,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CONFIRMA CON UN EXPERTO',
                                style: TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                  letterSpacing: 0.9,
                                  color: AppColors.tierra,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rotation.validarConExperto,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.tierra),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onToggle,
            icon: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.visibility_outlined,
              size: 17,
            ),
            label: Text(expanded ? 'Ocultar detalle' : 'Ver detalle'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animated, child) {
        return SizedBox(
          width: 58,
          height: 58,
          child: CustomPaint(
            painter: _RingPainter(value: animated),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(animated * 100).round()}',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      height: 1,
                      letterSpacing: -0.5,
                      color: AppColors.ink,
                    ),
                  ),
                  const Text(
                    'score',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w500,
                      fontSize: 8,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.line,
    );

    if (value <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [AppColors.verdeSecundario, AppColors.acentoNatural],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _OptionsEmpty extends StatelessWidget {
  const _OptionsEmpty({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.layers_rounded,
            size: 44,
            color: AppColors.verdeSecundario,
          ),
          const SizedBox(height: 12),
          Text(
            'Aún no hay rotaciones',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Elige tu zona y descarga su paquete para ver las opciones.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Ir a Inicio',
            icon: Icons.home_rounded,
            onPressed: () => onNavigate(0),
          ),
        ],
      ),
    );
  }
}
