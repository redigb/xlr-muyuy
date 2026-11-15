import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/soil_profiles.dart';
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

const _priorityFactors = ['riesgo', 'ingresos', 'suelo', 'agua'];

class FarmScreen extends StatelessWidget {
  const FarmScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final paquete = state.paquete;
    final zona = state.zona;
    return PageBody(
      children: [
        PageTopBar(
          title: context.tr('farm.title'),
          subtitle: zona == null
              ? context.tr('common.noZone')
              : prettyZoneName(zona.nombre),
        ),
        const SizedBox(height: AppSpacing.base),
        const ZoneWarning(),
        if (paquete == null || zona == null)
          EmptyCard(
            icon: Icons.agriculture_rounded,
            color: AppColors.verdePrincipal,
            titleKey: 'farm.noZone.t',
            bodyKey: 'farm.noZone.s',
            actionKey: 'home.chooseZone',
            actionIcon: Icons.travel_explore_rounded,
            onAction: () => onNavigate(0),
          )
        else ...[
          _CropSelector(state: state),
          const SizedBox(height: AppSpacing.base),
          _CurrentRotationCard(
            state: state,
            onOpenCalendar: () => onNavigate(2),
          ),
          const SizedBox(height: AppSpacing.base),
          _IrrigationCard(state: state),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            title: context.tr('farm.prio.t'),
            trailing: Text(
              '${state.prioridades.length}/2',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _PriorityGrid(state: state),
          if (!state.canContinue) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBanner(
              message: context.tr('farm.prio.pickOne'),
              icon: Icons.touch_app_rounded,
              color: const Color(0xFF854D0E),
              background: const Color(0xFFFEF9C3),
            ),
          ],
          const SizedBox(height: AppSpacing.base),
          _SoilCard(
            record: state.lastSoil != null && state.lastSoil!.zonaId == zona.id
                ? state.lastSoil
                : null,
            onOpen: () => _openSoilVision(context, state),
          ),
          if (state.paquete?.imagenSatelital case final foto?) ...[
            const SizedBox(height: AppSpacing.sm),
            SoftCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.xs,
              ),
              child: DetailsSection(
                title: context.tr('farm.sat.t'),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.memory(
                        foto,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.tr('farm.sat.src'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SoftCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.xs,
            ),
            child: DetailsSection(
              children: [
                Text(
                  '${prettyZoneName(zona.nombre)} · ${zona.coordenadas} · '
                  '${zona.elevacionM.round()} m',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (state.origin != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OriginPill(origin: state.origin!),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GradientButton(
            label: context.tr('farm.seeOptions'),
            icon: Icons.auto_awesome_rounded,
            onPressed: state.canContinue ? () => onNavigate(3) : null,
          ),
        ],
      ],
    );
  }

  void _openSoilVision(BuildContext context, AppState state) {
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

class _CropSelector extends StatelessWidget {
  const _CropSelector({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final crops = state.cultivosIniciales;
    if (crops.isEmpty) return const SizedBox.shrink();

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('farm.crop.t'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final id in crops)
                _CropChoice(
                  id: id,
                  selected: state.cultivoInicial == id,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.setCultivoInicial(id);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CropChoice extends StatelessWidget {
  const _CropChoice({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          decoration: BoxDecoration(
            color: selected ? AppColors.verdePrincipal : AppColors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? AppColors.verdePrincipal : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cropEmoji(id), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                cropName(context, id),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: selected ? AppColors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Análisis de suelo: un solo renglón (el último resultado o la invitación).
class _SoilCard extends StatelessWidget {
  const _SoilCard({required this.record, required this.onOpen});

  final SoilRecord? record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final record = this.record;
    final profile = record == null
        ? null
        : soilProfileFor(record.effectiveIndex);
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      onTap: onOpen,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile == null
                      ? context.tr('soil.title')
                      : context.tr('farm.soil.yours', {'label': profile.label}),
                  style: textTheme.titleMedium,
                ),
                Text(
                  record == null
                      ? context.tr('farm.soil.s')
                      : context.tr('farm.soil.conf', {
                          'n': (record.confidence * 100).round(),
                          'date': formatVersion(record.createdAt),
                        }),
                  style: textTheme.bodySmall,
                ),
                if (record != null && record.corrected) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Pill(
                    label: context.tr('farm.soil.corrected'),
                    icon: Icons.check_circle_rounded,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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

class _CurrentRotationCard extends StatelessWidget {
  const _CurrentRotationCard({
    required this.state,
    required this.onOpenCalendar,
  });

  final AppState state;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final rotacion = state.rotacionActual;
    final paquete = state.paquete;
    if (rotacion == null || paquete == null) return const SizedBox.shrink();

    final cycle = rotacion.secuencia.fold<int>(0, (sum, id) {
      return sum + (paquete.cultivoPorId(id)?.cicloMeses ?? 0);
    });

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.tr(
                  rotacion.esPracticaComun
                      ? 'farm.rot.kickerCommon'
                      : 'farm.rot.kickerCurrent',
                ),
                style: AppTypography.kicker,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CropSequence(sequence: rotacion.secuencia),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr('farm.rot.cycle', {'n': cycle}),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: onOpenCalendar,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(context.tr('farm.rot.seeCal')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IrrigationCard extends StatelessWidget {
  const _IrrigationCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('farm.irr.t'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _IrrigationOption(
                  selected: state.riego,
                  title: context.tr('farm.irr.yes'),
                  color: const Color(0xFF075985),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.setRiego(true);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _IrrigationOption(
                  selected: !state.riego,
                  title: context.tr('farm.irr.no'),
                  color: const Color(0xFF92400E),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.setRiego(false);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr(state.riego ? 'farm.rot.tipIrrig' : 'farm.rot.tipRain'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _IrrigationOption extends StatelessWidget {
  const _IrrigationOption({
    required this.selected,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.1) : AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? color : AppColors.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: selected ? color : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityGrid extends StatelessWidget {
  const _PriorityGrid({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final factor in _priorityFactors)
              SizedBox(
                width: width,
                child: _PriorityTile(
                  factor: factor,
                  selected: state.prioridades.contains(factor),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.togglePrioridad(factor);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PriorityTile extends StatelessWidget {
  const _PriorityTile({
    required this.factor,
    required this.selected,
    required this.onTap,
  });

  final String factor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = context.tr('prio.$factor');
    return Semantics(
      selected: selected,
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? AppColors.buenoSoft : AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? AppColors.verdeSecundario : AppColors.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      priorityEmoji(factor),
                      style: const TextStyle(fontSize: 28),
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 24,
                      color: selected
                          ? AppColors.verdePrincipal
                          : AppColors.inkFaint,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  context.tr('prio.$factor.sub'),
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: AppColors.verdePrincipal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
