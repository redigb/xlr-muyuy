import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/soil_profiles.dart';
import '../../models/models.dart';
import '../../models/soil_analysis.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/data_widgets.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/status_widgets.dart';
import '../soil/soil_vision_screen.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  final Set<String> _expanded = {};
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final paquete = state.paquete;
    final all = state.rotacionesTodas;
    final visible = _showAll ? all : state.rotacionesRecomendadas;
    final currentId = state.rotacionActual?.id;
    final lastSoil = state.lastSoil;
    final hasSoil =
        lastSoil != null && lastSoil.zonaId == (state.zona?.id ?? '');
    final soilProfile = hasSoil
        ? soilProfileFor(lastSoil.effectiveIndex, state.lang)
        : null;

    return PageBody(
      children: [
        PageTopBar(
          title: context.tr('opt.title'),
          subtitle: state.zona == null
              ? context.tr('common.noZone')
              : prettyZoneName(state.zona!.nombre),
        ),
        const SizedBox(height: AppSpacing.base),
        const ZoneWarning(),
        if (paquete == null || all.isEmpty)
          EmptyCard(
            icon: Icons.layers_rounded,
            color: AppColors.verdePrincipal,
            titleKey: 'opt.empty.t',
            bodyKey: 'opt.empty.s',
            onAction: () => widget.onNavigate(0),
          )
        else
          SectionFreshness(
            section: 'condiciones',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RankingHeader(
                  state: state,
                  best: all.first,
                  onEdit: () => widget.onNavigate(1),
                ),
                const SizedBox(height: AppSpacing.md),
                if (soilProfile != null && lastSoil != null)
                  _SoilNoteCard(
                    profile: soilProfile,
                    record: lastSoil,
                    onOpen: () => _openSoil(context, state),
                  )
                else
                  _SoilPromptCard(onOpen: () => _openSoil(context, state)),
                const SizedBox(height: AppSpacing.base),
                for (var i = 0; i < visible.length; i++) ...[
                  _RotationCard(
                    rotation: visible[i],
                    rank: i,
                    score: state.puntaje(visible[i]),
                    isBest: visible[i].id == all.first.id,
                    isCurrent: visible[i].id == currentId,
                    isChosen:
                        state.rotacionElegidaPorUsuario &&
                        visible[i].id == state.rotacionElegida?.id,
                    onChoose: () => _choose(context, state, visible[i]),
                    soilNote: soilProfile != null
                        ? _soilNote(context, soilProfile, visible[i], paquete)
                        : null,
                    expanded: _expanded.contains(visible[i].id) || false,
                    onToggle: () {
                      setState(() {
                        final id = visible[i].id;
                        if (!_expanded.remove(id)) _expanded.add(id);
                      });
                    },
                  ),
                  if (i < visible.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
                if (all.length > visible.length || _showAll) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    icon: Icon(
                      _showAll
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    label: Text(
                      _showAll
                          ? context.tr('opt.showTop')
                          : context.tr('opt.showAll', {'n': all.length}),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _soilNote(
    BuildContext context,
    SoilProfile profile,
    Rotacion rotation,
    Paquete paquete,
  ) {
    final affinity = soilAffinity(profile, rotation, paquete);
    final level = affinity >= 0.7
        ? 'alta'
        : affinity >= 0.5
        ? 'media'
        : 'baja';
    return context.tr('opt.soilFit', {
      'label': profile.label,
      'fit': confidenceLabel(context, level),
    });
  }

  void _choose(BuildContext context, AppState state, Rotacion rotation) {
    state.elegirRotacion(rotation.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.tr('rot.saved')),
          action: SnackBarAction(
            label: context.tr('rot.seeFarm'),
            onPressed: () => widget.onNavigate(1),
          ),
        ),
      );
  }

  void _openSoil(BuildContext context, AppState state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppScope(
          state: state,
          child: SoilVisionScreen(state: state),
        ),
      ),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onOpen,
      borderColor: AppColors.verdeSecundario.withValues(alpha: 0.5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('farm.soil.yours', {'label': profile.label}),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (record.corrected)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Pill(
                      label: context.tr('farm.soil.corrected'),
                      icon: Icons.check_circle_rounded,
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.inkSoft,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onOpen,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('opt.soil.prompt.t'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.inkSoft,
          ),
        ],
      ),
    );
  }
}

class _RankingHeader extends StatelessWidget {
  const _RankingHeader({
    required this.state,
    required this.best,
    required this.onEdit,
  });

  final AppState state;
  final Rotacion best;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final topScore = state.puntaje(best);

    return SoftCard(
      gradient: AppColors.gradientHero,
      borderColor: AppColors.verdePrincipal,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 22,
                color: AppColors.acentoNatural,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('opt.best'),
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Text(
                '${(topScore * 100).round()}',
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                  height: 1,
                  color: AppColors.acentoNatural,
                ),
              ),
              Text(
                context.tr('opt.points'),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12,
                  color: AppColors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            best.secuencia.map((id) => cropName(context, id)).join(' → '),
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.2,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.tr('opt.forPrio', {'label': scoreLabel(context, topScore)}),
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 14,
              color: AppColors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.acentoNatural,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
              ),
              child: Text(context.tr('common.change')),
            ),
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
    required this.isBest,
    required this.isCurrent,
    required this.isChosen,
    required this.onChoose,
    required this.expanded,
    required this.onToggle,
    this.soilNote,
  });

  final Rotacion rotation;
  final int rank;
  final double score;
  final bool isBest;
  final bool isCurrent;
  final bool isChosen;
  final VoidCallback onChoose;
  final bool expanded;
  final VoidCallback onToggle;
  final String? soilNote;

  @override
  Widget build(BuildContext context) {
    const factors = ['agua', 'suelo', 'ingresos', 'riesgo'];
    final textTheme = Theme.of(context).textTheme;

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      borderColor: isChosen
          ? AppColors.verdePrincipal
          : isBest
          ? AppColors.verdeSecundario.withValues(alpha: 0.7)
          : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCurrent || isChosen)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (isChosen)
                              Pill(
                                label: context.tr('rot.chosen'),
                                icon: Icons.check_circle_rounded,
                                color: AppColors.white,
                                background: AppColors.verdePrincipal,
                                compact: true,
                              ),
                            if (isCurrent)
                              Pill(
                                label: context.tr('opt.current'),
                                icon: Icons.place_rounded,
                                color: AppColors.tierra,
                                background: AppColors.secoSoft,
                                compact: true,
                              ),
                          ],
                        ),
                      ),
                    CropSequence(sequence: rotation.secuencia, compact: true),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.tr('opt.applied', {
                        'label': scoreLabel(context, score),
                      }),
                      style: textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ScoreRing(value: score),
            ],
          ),
          if (!isChosen) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onChoose,
                icon: const Icon(Icons.check_rounded),
                label: Text(context.tr('rot.choose')),
              ),
            ),
          ],
          if (soilNote != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.landscape_rounded,
                  size: 18,
                  color: AppColors.tierra,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    soilNote!,
                    style: textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (expanded) ...[
            const SizedBox(height: AppSpacing.base),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppSpacing.base;
                final width = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: AppSpacing.md,
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
            const SizedBox(height: AppSpacing.base),
            Text(context.tr('opt.confidence'), style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in rotation.confianza.entries)
                  ConfidenceChip(factor: entry.key, level: entry.value),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: AppColors.fondoSuave,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: AppColors.verdePrincipal,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        context.tr('opt.explain'),
                        style: AppTypography.kicker.copyWith(
                          color: AppColors.verdePrincipal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    rotation.explicacion,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: const Color(0xFFEAB308)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 20,
                  color: Color(0xFF854D0E),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('opt.expertTitle'),
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.6,
                          color: Color(0xFF854D0E),
                        ),
                      ),
                      if (rotation.validarConExperto.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          rotation.validarConExperto,
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF713F12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onToggle,
              icon: Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(
                context.tr(expanded ? 'opt.hideDetail' : 'opt.showDetail'),
              ),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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
    final clamped = value.clamp(0.0, 1.0);
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _RingPainter(value: clamped),
        child: Center(
          child: Text(
            '${(clamped * 100).round()}',
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              height: 1,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
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

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.verdeSecundario,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
