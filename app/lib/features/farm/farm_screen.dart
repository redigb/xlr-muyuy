import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

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

class _PriorityOption {
  const _PriorityOption({
    required this.factor,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final String factor;
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
}

const _priorityOptions = <_PriorityOption>[
  _PriorityOption(
    factor: 'riesgo',
    emoji: '🍲',
    title: 'Comida',
    subtitle: 'Cosecha segura',
    description: 'Menos riesgo de perder la cosecha.',
  ),
  _PriorityOption(
    factor: 'ingresos',
    emoji: '💰',
    title: 'Ingresos',
    subtitle: 'Vender mejor',
    description: 'Mayor retorno económico.',
  ),
  _PriorityOption(
    factor: 'suelo',
    emoji: '🌱',
    title: 'Suelo',
    subtitle: 'Tierra sana',
    description: 'Recuperar nutrientes cada campaña.',
  ),
  _PriorityOption(
    factor: 'agua',
    emoji: '💧',
    title: 'Agua',
    subtitle: 'Ahorrar agua',
    description: 'Adaptarse a los meses secos.',
  ),
];

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
          title: 'Mi chacra',
          subtitle: zona?.nombre ?? 'Sin zona elegida',
          trailing: Pill(
            label: state.online ? 'En línea' : 'Offline',
            icon: state.online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: state.online ? AppColors.verdePrincipal : AppColors.tierra,
            background: state.online ? AppColors.buenoSoft : AppColors.secoSoft,
            compact: true,
          ),
        ),
        const SizedBox(height: 18),
        if (paquete == null || zona == null)
          _NoFarmState(onNavigate: onNavigate)
        else ...[
          _ZoneSummary(
            zona: zona,
            originLabel: state.origin?.shortLabel ?? 'Local',
          ),
          const SizedBox(height: 16),
          _CropSelector(state: state),
          const SizedBox(height: 16),
          _CurrentRotationCard(
            state: state,
            onOpenCalendar: () => onNavigate(2),
          ),
          const SizedBox(height: 24),
          _IrrigationCard(state: state),
          const SizedBox(height: 24),
          _SoilVisionCard(onOpen: () => _openSoilVision(context, state)),
          if (state.lastSoil != null && state.lastSoil!.zonaId == zona.id) ...[
            const SizedBox(height: 12),
            _LastSoilCard(
              record: state.lastSoil!,
              onOpen: () => _openSoilVision(context, state),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeader(
            kicker: 'Elige 2',
            title: '¿Qué es lo más importante?',
            subtitle: 'Tus prioridades cambian el orden de las rotaciones al instante.',
            trailing: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: state.canContinue
                    ? AppColors.buenoSoft
                    : AppColors.pendienteSoft,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${state.prioridades.length}/2',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: state.canContinue
                      ? AppColors.verdePrincipal
                      : AppColors.inkFaint,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PriorityGrid(state: state),
          const SizedBox(height: 14),
          _WinnerPreview(state: state),
          if (!state.canContinue) ...[
            const SizedBox(height: 12),
            const InfoBanner(
              message:
                  'Elige una prioridad más para calcular tu recomendación.',
              icon: Icons.touch_app_rounded,
              color: AppColors.tierra,
              background: AppColors.secoSoft,
            ),
          ],
          const SizedBox(height: 22),
          GradientButton(
            label: 'Ver mis opciones',
            icon: Icons.auto_awesome_rounded,
            onPressed: state.canContinue ? () => onNavigate(3) : null,
          ),
        ],
      ],
    );
  }

  void _openSoilVision(BuildContext context, AppState state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SoilVisionScreen(state: state)),
    );
  }
}

class _NoFarmState extends StatelessWidget {
  const _NoFarmState({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.agriculture_rounded,
            size: 44,
            color: AppColors.verdeSecundario,
          ),
          const SizedBox(height: 12),
          Text(
            'Primero elige tu zona',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Así podemos mostrarte el calendario y las rotaciones de tu chacra.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Elegir mi zona',
            icon: Icons.travel_explore_rounded,
            onPressed: () => onNavigate(0),
          ),
        ],
      ),
    );
  }
}

class _ZoneSummary extends StatelessWidget {
  const _ZoneSummary({required this.zona, required this.originLabel});

  final Zona zona;
  final String originLabel;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      gradient: AppColors.gradientSoft,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(
              Icons.landscape_rounded,
              color: AppColors.verdePrincipal,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prettyZoneName(zona.nombre),
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${zona.coordenadas} · ${zona.elevacionM.round()} m',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Pill(
            label: originLabel,
            icon: Icons.offline_pin_rounded,
            color: AppColors.verdePrincipal,
            background: AppColors.buenoSoft,
            compact: true,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.04);
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.buenoSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.agriculture_rounded,
                  size: 18,
                  color: AppColors.verdePrincipal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Qué cultivas hoy?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Las opciones se filtran por tu cultivo actual.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Pill(
                label: cropName(state.cultivoInicial ?? ''),
                icon: Icons.filter_alt_rounded,
                color: AppColors.verdePrincipal,
                background: AppColors.buenoSoft,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
    ).animate().fadeIn(duration: 380.ms, delay: 60.ms);
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 230),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              Text(cropEmoji(id), style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                cropName(id),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: selected ? AppColors.white : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoilVisionCard extends StatelessWidget {
  const _SoilVisionCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.gradientTech,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: AppColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SoilVision AI',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 6),
                    const Pill(
                      label: 'TFLite',
                      icon: Icons.memory_rounded,
                      color: AppColors.tecnologia,
                      background: AppColors.heladaSoft,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Analiza la apariencia del suelo con una foto. '
                  'No mide pH ni fertilidad.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13,
            color: AppColors.inkFaint,
          ),
        ],
      ),
    );
  }
}

class _LastSoilCard extends StatelessWidget {
  const _LastSoilCard({required this.record, required this.onOpen});

  final SoilRecord record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final profile = soilProfileFor(record.effectiveIndex);
    return SoftCard(
      padding: const EdgeInsets.all(16),
      onTap: onOpen,
      borderColor: AppColors.verdeSecundario.withValues(alpha: 0.35),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.buenoSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: AppColors.verdePrincipal,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tu suelo: ${profile.label}',
                        style: Theme.of(context).textTheme.titleMedium,
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
                  'Confianza ${(record.confidence * 100).round()}% · '
                  '${formatVersion(record.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
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
            size: 13,
            color: AppColors.inkFaint,
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                rotacion.esPracticaComun ? 'PRÁCTICA COMÚN' : 'ROTACIÓN ACTUAL',
                style: AppTypography.kicker,
              ),
              const Spacer(),
              Pill(
                label: rotacion.esPracticaComun
                    ? 'Tradición de la zona'
                    : 'Tu chacra hoy',
                icon: Icons.place_rounded,
                color: AppColors.tierra,
                background: AppColors.secoSoft,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          CropSequence(sequence: rotacion.secuencia),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.inkFaint,
              ),
              const SizedBox(width: 6),
              Text(
                'Ciclo aproximado · $cycle meses',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              TextButton(
                onPressed: onOpenCalendar,
                child: const Text('Ver calendario'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.fondoSuave,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 17,
                  color: AppColors.tierra,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.riego
                        ? 'Con riego puedes ajustar siembras a los meses con '
                              'menos lluvia. Revisa el balance hídrico mes a mes.'
                        : 'Sin riego, las lluvias mandan. Revisa los meses secos '
                              'antes de planificar la siembra.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 420.ms, delay: 80.ms).slideY(begin: 0.05);
  }
}

class _IrrigationCard extends StatelessWidget {
  const _IrrigationCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.water_drop_rounded,
                size: 18,
                color: AppColors.tecnologia,
              ),
              const SizedBox(width: 8),
              Text(
                '¿Tienes riego?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Nos ayuda a afinar el consejo sobre agua.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _IrrigationOption(
                  selected: state.riego,
                  icon: Icons.water_drop_rounded,
                  title: 'Sí, tengo riego',
                  color: AppColors.tecnologia,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.setRiego(true);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IrrigationOption(
                  selected: !state.riego,
                  icon: Icons.cloud_rounded,
                  title: 'Solo lluvia',
                  color: AppColors.tierra,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.setRiego(false);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IrrigationOption extends StatelessWidget {
  const _IrrigationOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.09) : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? color : AppColors.inkFaint,
                size: 22,
              ),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: selected ? color : AppColors.inkSoft,
                ),
              ),
            ],
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
        final width = constraints.maxWidth > 560
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final option in _priorityOptions)
              SizedBox(
                width: width,
                child: _PriorityTile(
                  option: option,
                  selected: state.prioridades.contains(option.factor),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    state.togglePrioridad(option.factor);
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
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PriorityOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: option.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? AppColors.buenoSoft : AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? AppColors.verdeSecundario : AppColors.line,
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected ? AppShadows.soft : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.08 : 1,
                      duration: const Duration(milliseconds: 240),
                      child: Text(
                        option.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.verdeSecundario
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? AppColors.verdeSecundario
                              : AppColors.line,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: AppColors.white,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  option.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  option.subtitle,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    color: selected
                        ? AppColors.verdePrincipal
                        : AppColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  option.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WinnerPreview extends StatelessWidget {
  const _WinnerPreview({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final options = state.rotacionesOrdenadas;
    if (options.isEmpty) return const SizedBox.shrink();
    final winner = options.first;
    final score = state.puntaje(winner);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey('${winner.id}-${state.prioridades.join('-')}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F3D23), AppColors.verdePrincipal],
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 19,
                color: AppColors.acentoNatural,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Con tus prioridades, hoy gana',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w600,
                      fontSize: 9.5,
                      letterSpacing: 0.6,
                      color: AppColors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    winner.secuencia.map(cropName).join(' → '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(score * 100).round()}',
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: AppColors.acentoNatural,
                height: 1,
              ),
            ),
            Text(
              '/100',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontWeight: FontWeight.w600,
                fontSize: 9,
                color: AppColors.white.withValues(alpha: 0.54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
