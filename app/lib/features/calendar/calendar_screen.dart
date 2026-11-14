import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/terrain_scene.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final paquete = state.paquete;
    final calendario = paquete?.calendario ?? const <CalendarioMes>[];
    final available = calendario.map((m) => m.mes).toSet();
    final month = available.contains(_month)
        ? _month
        : (calendario.isEmpty ? 1 : calendario.first.mes);
    final climate = paquete?.mes(month);

    return PageBody(
      children: [
        PageTopBar(
          title: 'Mi calendario',
          subtitle: state.zona == null
              ? 'Sin zona elegida'
              : prettyZoneName(state.zona!.nombre),
          trailing: Pill(
            label: state.online ? 'En vivo' : 'Offline',
            icon: state.online
                ? Icons.satellite_alt_rounded
                : Icons.wifi_off_rounded,
            color: state.online ? AppColors.verdePrincipal : AppColors.tierra,
            background: state.online ? AppColors.buenoSoft : AppColors.secoSoft,
            compact: true,
          ),
        ),
        const SizedBox(height: 16),
        if (paquete == null || calendario.isEmpty)
          _CalendarEmpty(onNavigate: widget.onNavigate)
        else ...[
          TerrainScene(
            calendario: calendario,
            month: month,
            onMonthChanged: (value) => setState(() => _month = value),
          ).animate().fadeIn(duration: 420.ms).slideY(begin: 0.04),
          const SizedBox(height: 12),
          const Row(
            children: [
              _LegendDot(color: AppColors.helada, label: 'Helada'),
              SizedBox(width: 14),
              _LegendDot(color: AppColors.seco, label: 'Seco'),
              SizedBox(width: 14),
              _LegendDot(color: AppColors.bueno, label: 'Bueno'),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader(
            kicker: '12 meses',
            title: 'Tu año en un vistazo',
            subtitle: 'Toca un mes para ver helada, lluvia y balance hídrico.',
            trailing: Pill(
              label: '${calendario.length} meses',
              icon: Icons.calendar_month_rounded,
              background: AppColors.white,
              color: AppColors.inkSoft,
              compact: true,
            ),
          ),
          const SizedBox(height: 14),
          _MonthGrid(
            calendario: calendario,
            selected: month,
            onSelected: (value) => setState(() => _month = value),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: climate == null
                ? const SizedBox.shrink()
                : _MonthDetail(
                    key: ValueKey('detail-${climate.mes}'),
                    month: climate.mes,
                    climate: climate,
                  ),
          ),
          const SizedBox(height: 18),
          _SeasonWindows(calendario: calendario),
          const SizedBox(height: 16),
          _SourceCard(paquete: paquete),
          const SizedBox(height: 22),
          GradientButton(
            label: 'Ver mis rotaciones',
            icon: Icons.auto_awesome_rounded,
            onPressed: () => widget.onNavigate(3),
          ),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: AppColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.calendario,
    required this.selected,
    required this.onSelected,
  });

  final List<CalendarioMes> calendario;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ordered = List<CalendarioMes>.of(calendario)
      ..sort((a, b) => a.mes.compareTo(b.mes));

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 6 : 4;
        const spacing = 9.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final mes in ordered)
              SizedBox(
                width: width,
                child: _MonthCell(
                  mes: mes,
                  selected: mes.mes == selected,
                  onTap: () => onSelected(mes.mes),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.mes,
    required this.selected,
    required this.onTap,
  });

  final CalendarioMes mes;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (mes.estado) {
      case MesEstado.helada:
        return Icons.ac_unit_rounded;
      case MesEstado.seco:
        return Icons.wb_sunny_rounded;
      case MesEstado.bueno:
        return Icons.eco_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoColor = AppColors.estadoColor(mes.estado);

    return Semantics(
      selected: selected,
      button: true,
      label: '${monthName(mes.mes)}, ${mes.estado.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              gradient: selected ? AppColors.gradientHero : null,
              color: selected ? null : AppColors.estadoSoft(mes.estado),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected
                    ? AppColors.verdePrincipal
                    : estadoColor.withValues(alpha: 0.18),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _icon,
                  size: 15,
                  color: selected ? AppColors.white : estadoColor,
                ),
                const SizedBox(height: 5),
                Text(
                  monthShortName(mes.mes),
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: selected ? AppColors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(mes.probHelada * 100).round()}%',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w500,
                    fontSize: 9,
                    color: selected
                        ? AppColors.white.withValues(alpha: 0.7)
                        : AppColors.inkFaint,
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

class _MonthDetail extends StatelessWidget {
  const _MonthDetail({super.key, required this.month, required this.climate});

  final int month;
  final CalendarioMes climate;

  @override
  Widget build(BuildContext context) {
    final estadoColor = AppColors.estadoColor(climate.estado);
    final estadoText = switch (climate.estado) {
      MesEstado.helada => 'Helada probable',
      MesEstado.seco => 'Mes seco',
      MesEstado.bueno => 'Ventana buena',
    };

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthName(month),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Pill(
                label: estadoText,
                icon: climate.estado == MesEstado.helada
                    ? Icons.ac_unit_rounded
                    : climate.estado == MesEstado.seco
                    ? Icons.wb_sunny_rounded
                    : Icons.eco_rounded,
                color: estadoColor,
                background: AppColors.estadoSoft(climate.estado),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            climate.estado == MesEstado.helada
                ? 'Hay helada en ${climate.mesesHeladaLabel}.'
                : climate.estado == MesEstado.seco
                ? 'Las plantas consumen más agua de la que cae en el mes.'
                : 'Clima favorable para el crecimiento del cultivo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 520 ? 4 : 2;
              const spacing = 10.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: width,
                    child: _StatTile(
                      icon: Icons.ac_unit_rounded,
                      label: 'Prob. helada',
                      value: '${(climate.probHelada * 100).round()}%',
                      color: AppColors.helada,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _StatTile(
                      icon: Icons.water_drop_rounded,
                      label: 'Lluvia',
                      value: '${climate.lluviaMm.round()} mm',
                      color: AppColors.tecnologia,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _StatTile(
                      icon: Icons.thermostat_rounded,
                      label: 'Evapotransp.',
                      value: '${climate.etMm.round()} mm',
                      color: AppColors.tierra,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _StatTile(
                      icon: Icons.balance_rounded,
                      label: 'Balance',
                      value:
                          '${climate.balanceHidricoMm > 0 ? '+' : ''}${climate.balanceHidricoMm.round()} mm',
                      color: climate.balanceHidricoMm < -40
                          ? AppColors.seco
                          : AppColors.verdeSecundario,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _StatTile(
                      icon: Icons.thermostat_rounded,
                      label: 'Temp. mín – máx',
                      value: climate.temperaturaLabel,
                      color: AppColors.tecnologia,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _StatTile(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Estrés calor',
                      value: '${(climate.estresCalor * 100).round()}%',
                      color: climate.estresCalor > 0.25
                          ? AppColors.alerta
                          : AppColors.tierra,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _WaterBalanceBar(climate: climate),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.estadoSoft(climate.estado),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  climate.estado == MesEstado.bueno
                      ? Icons.thumb_up_alt_rounded
                      : Icons.info_rounded,
                  size: 17,
                  color: estadoColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    switch (climate.estado) {
                      MesEstado.helada =>
                        'Prioriza cultivos tolerantes al frío y protege el suelo. '
                            'Con ${(climate.probHelada * 10).round()} de cada 10 años '
                            'con helada, conviene tener un plan B.',
                      MesEstado.seco =>
                        'Planifica riego o cultivos de bajo consumo. El déficit '
                            'hídrico del mes es de ${climate.balanceHidricoMm.abs().round()} mm.',
                      MesEstado.bueno =>
                        'Aprovecha para sembrar o dar mantenimiento. Es uno de '
                            'los mejores meses para el crecimiento del cultivo.',
                    },
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      height: 1.45,
                      color: estadoColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: -0.3,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w500,
              fontSize: 9.5,
              color: AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterBalanceBar extends StatelessWidget {
  const _WaterBalanceBar({required this.climate});

  final CalendarioMes climate;

  @override
  Widget build(BuildContext context) {
    final total = climate.lluviaMm + climate.etMm;
    final rainRatio = total == 0 ? 0.0 : climate.lluviaMm / total;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (rainRatio * 1000).round().clamp(1, 999).toInt(),
                  child: Container(color: AppColors.tecnologia),
                ),
                Expanded(
                  flex: ((1 - rainRatio) * 1000).round().clamp(1, 999).toInt(),
                  child: Container(
                    color: AppColors.tierra.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const _LegendDot(color: AppColors.tecnologia, label: 'Lluvia'),
            const Spacer(),
            const _LegendDot(
              color: AppColors.tierra,
              label: 'Evapotranspiración',
            ),
          ],
        ),
      ],
    );
  }
}

class _SeasonWindows extends StatelessWidget {
  const _SeasonWindows({required this.calendario});

  final List<CalendarioMes> calendario;

  @override
  Widget build(BuildContext context) {
    final frost = calendario.where((m) => m.probHelada >= 0.5).toList()
      ..sort((a, b) => a.mes.compareTo(b.mes));
    final dry = calendario.where((m) => m.balanceHidricoMm < -40).toList()
      ..sort((a, b) => a.mes.compareTo(b.mes));
    final good = calendario.where((m) => m.estado == MesEstado.bueno).toList()
      ..sort((a, b) => a.mes.compareTo(b.mes));

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.fondoSuave,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  size: 17,
                  color: AppColors.verdePrincipal,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Ventanas de la temporada',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WindowRow(
            label: 'Helada probable',
            months: frost,
            color: AppColors.helada,
          ),
          const SizedBox(height: 10),
          _WindowRow(label: 'Meses secos', months: dry, color: AppColors.seco),
          const SizedBox(height: 10),
          _WindowRow(
            label: 'Meses buenos',
            months: good,
            color: AppColors.bueno,
          ),
        ],
      ),
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({
    required this.label,
    required this.months,
    required this.color,
  });

  final String label;
  final List<CalendarioMes> months;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: months.isEmpty
                ? [
                    Text(
                      'Sin meses',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]
                : [
                    for (final mes in months)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          monthShortName(mes.mes),
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                            color: color,
                          ),
                        ),
                      ),
                  ],
          ),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.paquete});

  final Paquete paquete;

  @override
  Widget build(BuildContext context) {
    final validity = paquete.meta.secciones['calendario'];
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_rounded,
                size: 18,
                color: AppColors.tecnologia,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fuente y validez',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Pill(
                label: paquete.versionLabel,
                icon: Icons.tag_rounded,
                color: AppColors.inkSoft,
                background: AppColors.white,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Clima: ${paquete.fuenteClima}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                label: paquete.validadaLocalmente
                    ? 'Validada localmente'
                    : 'No validada localmente',
                icon: Icons.place_rounded,
                color: paquete.validadaLocalmente
                    ? AppColors.verdePrincipal
                    : AppColors.tierra,
                background: paquete.validadaLocalmente
                    ? AppColors.buenoSoft
                    : AppColors.secoSoft,
                compact: true,
              ),
              Pill(
                label: paquete.verified ? 'Hash verificado' : 'Sin verificar',
                icon: paquete.verified
                    ? Icons.verified_user_rounded
                    : Icons.gpp_maybe_rounded,
                color: paquete.verified
                    ? AppColors.verdePrincipal
                    : AppColors.tierra,
                background: paquete.verified
                    ? AppColors.buenoSoft
                    : AppColors.secoSoft,
                compact: true,
              ),
              Pill(
                label: paquete.meta.origen == 'zona_oficial'
                    ? 'Zona oficial'
                    : paquete.meta.origen,
                icon: Icons.public_rounded,
                color: AppColors.tecnologia,
                background: AppColors.heladaSoft,
                compact: true,
              ),
            ],
          ),
          if (validity != null && validity.validoHasta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Calendario actualizado ${validity.actualizado} · '
              'válido hasta ${validity.validoHasta}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
          if (!paquete.validadaLocalmente) ...[
            const SizedBox(height: 10),
            const InfoBanner(
              message:
                  'Este paquete no está validado en campo. Úsalo como '
                  'orientación y confirma con un técnico local.',
              icon: Icons.info_outline_rounded,
              color: AppColors.tierra,
              background: AppColors.secoSoft,
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarEmpty extends StatelessWidget {
  const _CalendarEmpty({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 44,
            color: AppColors.tecnologia,
          ),
          const SizedBox(height: 12),
          Text(
            'Aún no hay calendario',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Elige una zona en Inicio para cargar sus 12 meses de clima.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
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
