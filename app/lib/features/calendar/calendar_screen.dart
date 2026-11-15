import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/status_widgets.dart';
import 'calendar_landscape.dart';

IconData _estadoIcon(MesEstado estado) {
  switch (estado) {
    case MesEstado.helada:
      return Icons.ac_unit_rounded;
    case MesEstado.seco:
      return Icons.wb_sunny_rounded;
    case MesEstado.bueno:
      return Icons.eco_rounded;
  }
}

String _estadoKey(MesEstado estado) {
  switch (estado) {
    case MesEstado.helada:
      return 'frost';
    case MesEstado.seco:
      return 'dry';
    case MesEstado.bueno:
      return 'good';
  }
}

/// Colores de texto con contraste suficiente sobre el fondo suave de cada estado.
Color _estadoInk(MesEstado estado) {
  switch (estado) {
    case MesEstado.helada:
      return const Color(0xFF075985);
    case MesEstado.seco:
      return const Color(0xFF92400E);
    case MesEstado.bueno:
      return AppColors.verdePrincipal;
  }
}

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
    final months = available.toList()..sort();
    final month = available.contains(_month)
        ? _month
        : (calendario.isEmpty ? 1 : calendario.first.mes);
    final climate = paquete?.mes(month);

    return PageBody(
      children: [
        PageTopBar(
          title: context.tr('cal.title'),
          subtitle: state.zona == null
              ? context.tr('common.noZone')
              : prettyZoneName(state.zona!.nombre),
        ),
        const SizedBox(height: AppSpacing.base),
        const ZoneWarning(),
        if (paquete == null || calendario.isEmpty)
          EmptyCard(
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFF075985),
            titleKey: 'cal.empty.t',
            bodyKey: 'cal.empty.s',
            onAction: () => widget.onNavigate(0),
          )
        else
          SectionFreshness(
            section: 'calendario',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (climate != null) ...[
                  _CalendarScene(
                    climate: climate,
                    months: months,
                    onSelected: (value) => setState(() => _month = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const _Legend(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  context.tr('cal.scene.year'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.tr('cal.scene.gridHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                _MonthGrid(
                  calendario: calendario,
                  selected: month,
                  onSelected: (value) => setState(() => _month = value),
                ),
                const SizedBox(height: AppSpacing.base),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: climate == null
                      ? const SizedBox.shrink()
                      : _MonthDetail(
                          key: ValueKey('detail-${climate.mes}'),
                          climate: climate,
                        ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SoftCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.xs,
                  ),
                  child: DetailsSection(
                    children: [
                      if (climate != null) ...[
                        _MonthExtra(climate: climate),
                        const SizedBox(height: AppSpacing.base),
                      ],
                      _SeasonWindows(calendario: calendario),
                      const SizedBox(height: AppSpacing.base),
                      _SourceCard(paquete: paquete),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GradientButton(
                  label: context.tr('cal.seeRot'),
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () => widget.onNavigate(3),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Leyenda de colores: 🔵 helada, 🟠 seco, 🟢 bueno.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.base,
      runSpacing: AppSpacing.sm,
      children: [
        for (final estado in MesEstado.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.estadoColor(estado),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                context.tr('cal.legend.${_estadoKey(estado)}'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
      ],
    );
  }
}

class _CalendarScene extends StatelessWidget {
  const _CalendarScene({
    required this.climate,
    required this.months,
    required this.onSelected,
  });

  final CalendarioMes climate;
  final List<int> months;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final month = monthName(context, climate.mes);
    final state = context.tr('cal.state.${_estadoKey(climate.estado)}');
    final color = _estadoInk(climate.estado);
    final frost = '${(climate.probHelada * 100).round()}%';
    final balance = climate.balanceHidricoMm.round();
    final balanceValue = '${balance > 0 ? '+' : ''}$balance mm';
    final theme = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: (constraints.maxWidth * 0.68).clamp(245.0, 310.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CalendarLandscape(climate: climate),
                    Positioned(
                      top: 14,
                      left: 12,
                      right: 12,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Pill(
                            label: '$month · $state',
                            icon: _estadoIcon(climate.estado),
                            color: color,
                            background: AppColors.white,
                            compact: true,
                          ),
                          Tooltip(
                            message: context.tr('cal.stat.frost'),
                            child: Pill(
                              label: frost,
                              icon: Icons.ac_unit_rounded,
                              color: color,
                              background: AppColors.white,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _SceneMetric(
                            icon: Icons.water_drop_outlined,
                            label: context.tr('cal.stat.rain'),
                            value: '${climate.lluviaMm.round()} mm',
                          ),
                          _SceneMetric(
                            icon: Icons.thermostat_rounded,
                            label: context.tr('cal.stat.et'),
                            value: '${climate.etMm.round()} mm',
                          ),
                          _SceneMetric(
                            icon: Icons.water_outlined,
                            label: context.tr('cal.stat.balance'),
                            value: balanceValue,
                            dark: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (months.length > 1)
              Slider(
                value: months.indexOf(climate.mes).toDouble(),
                max: (months.length - 1).toDouble(),
                divisions: months.length - 1,
                activeColor: AppColors.verdePrincipal,
                inactiveColor: AppColors.buenoSoft,
                label: month,
                semanticFormatterCallback: (value) =>
                    monthName(context, months[value.round()]),
                onChanged: (value) => onSelected(months[value.round()]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  if (months.length > 1)
                    Text(
                      monthShortName(context, months.first),
                      style: theme.labelSmall,
                    ),
                  Expanded(
                    child: Text(
                      context.tr(
                        months.length > 1
                            ? 'cal.scene.slider'
                            : 'cal.scene.illustration',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.labelSmall,
                    ),
                  ),
                  if (months.length > 1)
                    Text(
                      monthShortName(context, months.last),
                      style: theme.labelSmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneMetric extends StatelessWidget {
  const _SceneMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.dark = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Pill(
      label: value,
      icon: icon,
      color: dark ? AppColors.white : AppColors.ink,
      background: dark ? AppColors.verdePrincipal : const Color(0xF5F4FAEE),
      compact: true,
    ),
  );
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
        final columns = constraints.maxWidth >= 480 ? 6 : 4;
        const spacing = AppSpacing.sm;
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

  @override
  Widget build(BuildContext context) {
    final color = AppColors.estadoColor(mes.estado);
    final ink = _estadoInk(mes.estado);

    return Semantics(
      selected: selected,
      button: true,
      label:
          '${monthName(context, mes.mes)}, '
          '${context.tr('cal.legend.${_estadoKey(mes.estado)}')}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.verdePrincipal
                  : AppColors.estadoSoft(mes.estado),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected
                    ? AppColors.verdePrincipal
                    : color.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _estadoIcon(mes.estado),
                  size: 18,
                  color: selected ? AppColors.white : ink,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  monthShortName(context, mes.mes),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: selected ? AppColors.white : AppColors.ink,
                  ),
                ),
                Text(
                  '${(mes.probHelada * 100).round()}%',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: selected ? const Color(0xFFDBEFDF) : ink,
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
  const _MonthDetail({super.key, required this.climate});

  final CalendarioMes climate;

  @override
  Widget build(BuildContext context) {
    final estado = climate.estado;
    final ink = _estadoInk(estado);
    final key = _estadoKey(estado);
    final frostN = (climate.probHelada * 10).round();
    final balance = climate.balanceHidricoMm;

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthName(context, climate.mes),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Pill(
                label: context.tr('cal.state.$key'),
                icon: _estadoIcon(estado),
                color: ink,
                background: AppColors.estadoSoft(estado),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = AppSpacing.sm;
              final width = (constraints.maxWidth - spacing * 2) / 3;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _StatTile(
                    width: width,
                    label: context.tr('cal.stat.frost'),
                    value: '${(climate.probHelada * 100).round()}%',
                    color: const Color(0xFF075985),
                  ),
                  _StatTile(
                    width: width,
                    label: context.tr('cal.stat.rain'),
                    value: '${climate.lluviaMm.round()} mm',
                    color: const Color(0xFF075985),
                  ),
                  _StatTile(
                    width: width,
                    label: context.tr('cal.stat.balance'),
                    value: '${balance > 0 ? '+' : ''}${balance.round()} mm',
                    color: balance < -40
                        ? const Color(0xFF92400E)
                        : AppColors.verdePrincipal,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.base),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.estadoSoft(estado),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  estado == MesEstado.bueno
                      ? Icons.thumb_up_alt_rounded
                      : Icons.info_rounded,
                  size: 20,
                  color: ink,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    switch (estado) {
                      MesEstado.helada => context.tr('cal.adv.frost', {
                        'n': frostN,
                      }),
                      MesEstado.seco => context.tr('cal.adv.dry', {
                        'mm': balance.abs().round(),
                      }),
                      MesEstado.bueno => context.tr('cal.adv.good'),
                    },
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: ink),
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

/// Datos del mes que no cambian la decisión: evapotranspiración, temperatura,
/// estrés por calor y balance de agua.
class _MonthExtra extends StatelessWidget {
  const _MonthExtra({required this.climate});

  final CalendarioMes climate;

  @override
  Widget build(BuildContext context) {
    final temp = (climate.tMin == null || climate.tMax == null)
        ? context.tr('common.noData')
        : '${climate.tMin!.round()}° – ${climate.tMax!.round()}°C';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthName(context, climate.mes),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = AppSpacing.sm;
            final width = (constraints.maxWidth - spacing * 2) / 3;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StatTile(
                  width: width,
                  label: context.tr('cal.stat.et'),
                  value: '${climate.etMm.round()} mm',
                  color: const Color(0xFF92400E),
                ),
                _StatTile(
                  width: width,
                  label: context.tr('cal.stat.temp'),
                  value: temp,
                  color: const Color(0xFF075985),
                ),
                _StatTile(
                  width: width,
                  label: context.tr('cal.stat.heat'),
                  value: '${(climate.estresCalor * 100).round()}%',
                  color: climate.estresCalor > 0.25
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF92400E),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _WaterBalanceBar(climate: climate),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTypography.dataValue.copyWith(fontSize: 20),
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
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
            height: 12,
            child: Row(
              children: [
                Expanded(
                  flex: (rainRatio * 1000).round().clamp(1, 999).toInt(),
                  child: Container(color: AppColors.tecnologia),
                ),
                Expanded(
                  flex: ((1 - rainRatio) * 1000).round().clamp(1, 999).toInt(),
                  child: Container(color: AppColors.tierra),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.base,
          runSpacing: AppSpacing.xs,
          children: [
            _Dot(
              color: AppColors.tecnologia,
              label: context.tr('cal.stat.rain'),
            ),
            _Dot(color: AppColors.tierra, label: context.tr('cal.evap')),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _SeasonWindows extends StatelessWidget {
  const _SeasonWindows({required this.calendario});

  final List<CalendarioMes> calendario;

  @override
  Widget build(BuildContext context) {
    List<CalendarioMes> sorted(bool Function(CalendarioMes) test) =>
        calendario.where(test).toList()..sort((a, b) => a.mes.compareTo(b.mes));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('cal.windows.title'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        _WindowRow(
          label: context.tr('cal.windows.frost'),
          months: sorted((m) => m.probHelada >= 0.5),
          color: AppColors.helada,
          ink: _estadoInk(MesEstado.helada),
        ),
        const SizedBox(height: AppSpacing.md),
        _WindowRow(
          label: context.tr('cal.windows.dry'),
          months: sorted((m) => m.balanceHidricoMm < -40),
          color: AppColors.seco,
          ink: _estadoInk(MesEstado.seco),
        ),
        const SizedBox(height: AppSpacing.md),
        _WindowRow(
          label: context.tr('cal.windows.good'),
          months: sorted((m) => m.estado == MesEstado.bueno),
          color: AppColors.bueno,
          ink: _estadoInk(MesEstado.bueno),
        ),
      ],
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({
    required this.label,
    required this.months,
    required this.color,
    required this.ink,
  });

  final String label;
  final List<CalendarioMes> months;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (months.isEmpty)
          Text(
            context.tr('cal.windows.none'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final mes in months)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    monthShortName(context, mes.mes),
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: ink,
                    ),
                  ),
                ),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.tr('cal.source.title')} · '
          '${packageVersionLabel(context, paquete)}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.tr('cal.source.climate', {'src': paquete.fuenteClima}),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            VerifiedPills(paquete: paquete),
            Pill(
              label: paquete.meta.origen == 'zona_oficial'
                  ? context.tr('cal.source.official')
                  : paquete.meta.origen,
              icon: Icons.public_rounded,
              color: const Color(0xFF075985),
              background: AppColors.heladaSoft,
              compact: true,
            ),
          ],
        ),
        if (validity != null && validity.validoHasta.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr('cal.source.updated', {
              'u': validity.actualizado,
              'v': validity.validoHasta,
            }),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
        if (!paquete.validadaLocalmente) ...[
          const SizedBox(height: AppSpacing.md),
          InfoBanner(
            message: context.tr('cal.source.warn'),
            icon: Icons.info_outline_rounded,
            color: const Color(0xFF854D0E),
            background: const Color(0xFFFEF9C3),
          ),
        ],
      ],
    );
  }
}
