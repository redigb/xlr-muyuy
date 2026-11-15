import 'package:material_ui/material_ui.dart';

import '../l10n/strings.dart';
import '../models/community.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'gradient_button.dart';
import 'page_layout.dart';
import 'soft_card.dart';

/// Cuadro de color con un ícono (se repetía en todas las pantallas).
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.verdePrincipal,
    this.background = AppColors.fondoSuave,
    this.size = 44,
    this.gradient,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: gradient == null ? background : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Aviso 🟡 de zona no validada localmente (spec 3). No se muestra sin paquete.
class ZoneWarning extends StatelessWidget {
  const ZoneWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.hasPackage || state.validadaLocalmente) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoBanner(
        message: context.tr('location.notValidated'),
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFF854D0E),
        background: const Color(0xFFFEF9C3),
      ),
    );
  }
}

/// Color, ícono y clave de texto de cada estado de vigencia.
({Color color, Color soft, IconData icon, String key}) validityStyle(
  ValidityState value,
) {
  switch (value) {
    case ValidityState.fresh:
      return (
        color: AppColors.verdePrincipal,
        soft: AppColors.buenoSoft,
        icon: Icons.check_circle_rounded,
        key: 'validity.fresh',
      );
    case ValidityState.expiring:
      return (
        color: const Color(0xFF854D0E),
        soft: const Color(0xFFFEF9C3),
        icon: Icons.schedule_rounded,
        key: 'validity.expiring',
      );
    case ValidityState.expired:
      return (
        color: const Color(0xFF991B1B),
        soft: AppColors.alertaSoft,
        icon: Icons.error_rounded,
        key: 'validity.expired',
      );
    case ValidityState.unknown:
      return (
        color: AppColors.inkSoft,
        soft: AppColors.pendienteSoft,
        icon: Icons.help_rounded,
        key: 'validity.unknown',
      );
  }
}

/// Una fila por sección con su vigencia (🟢🟡🔴). Si alguna está vencida,
/// muestra la pista para pedir la versión nueva.
class ValidityPanel extends StatelessWidget {
  const ValidityPanel({super.key});

  static const sections = ['calendario', 'condiciones', 'alertas'];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.hasPackage) return const SizedBox.shrink();
    final anyExpired = sections.any(state.seccionVencida);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('home.valid.title'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final section in sections)
              _ValidityChip(
                section: section,
                value: state.vigencias[section] ?? ValidityState.unknown,
              ),
          ],
        ),
        if (anyExpired) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr('validity.expired.hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ValidityChip extends StatelessWidget {
  const _ValidityChip({required this.section, required this.value});

  final String section;
  final ValidityState value;

  @override
  Widget build(BuildContext context) {
    final style = validityStyle(value);
    return Pill(
      label: '${context.tr('section.$section')} · ${context.tr(style.key)}',
      icon: style.icon,
      color: style.color,
      background: style.soft,
    );
  }
}

/// Atenúa una sección vencida (opacidad 0.5) y muestra la pista.
class SectionFreshness extends StatelessWidget {
  const SectionFreshness({
    super.key,
    required this.section,
    required this.child,
  });

  final String section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.seccionVencida(section)) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InfoBanner(
            message:
                '${context.tr('section.$section')} · '
                '${context.tr('validity.expired.hint')}',
            icon: Icons.error_outline_rounded,
            color: const Color(0xFF991B1B),
            background: AppColors.alertaSoft,
          ),
        ),
        Opacity(opacity: 0.5, child: child),
      ],
    );
  }
}

/// Ícono por estado de un reporte.
({IconData icon, Color color}) reportStyle(String estado) {
  switch (estado) {
    case 'validada':
      return (
        icon: Icons.check_circle_rounded,
        color: AppColors.verdePrincipal,
      );
    case 'pendiente':
      return (icon: Icons.hourglass_top_rounded, color: AppColors.seco);
    case 'sospechosa':
      return (
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFF854D0E),
      );
    case 'rechazada':
      return (icon: Icons.cancel_rounded, color: const Color(0xFF991B1B));
    default:
      return (icon: Icons.hourglass_empty_rounded, color: AppColors.inkSoft);
  }
}

/// Últimos reportes con su estado (⏳ por enviar/pendiente, ✅, ⚠️, ✖).
class ReportList extends StatelessWidget {
  const ReportList({super.key, required this.reportes, this.max = 4});

  final List<Reporte> reportes;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (reportes.isEmpty) {
      return Text(
        context.tr('home.comm.none'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final recent = reportes.take(max).toList();
    return Column(
      children: [
        for (final r in recent)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(eventEmoji(r.tipo), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${eventLabel(context, r.tipo)} · ${r.fechaEvento}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  reportStyle(r.estado).icon,
                  size: 18,
                  color: reportStyle(r.estado).color,
                ),
                const SizedBox(width: 4),
                Text(
                  context.tr(r.estadoKey),
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: reportStyle(r.estado).color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Selector ES · EN · QU (cada idioma en su propia lengua).
class LangSelector extends StatelessWidget {
  const LangSelector({super.key});

  static const _codes = {AppLang.es: 'ES', AppLang.en: 'EN', AppLang.qu: 'QU'};

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Semantics(
      label: context.tr('lang.label'),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in AppLang.values)
              Tooltip(
                message: lang.nativeName,
                child: InkWell(
                  onTap: () => state.setLang(lang),
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 40,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: state.lang == lang
                          ? AppColors.verdePrincipal
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      _codes[lang]!,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: state.lang == lang
                            ? AppColors.white
                            : AppColors.inkSoft,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío con un solo botón (reemplaza 4 copias en las pantallas).
class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.bodyKey,
    required this.onAction,
    this.actionKey = 'common.goHome',
    this.actionIcon = Icons.home_rounded,
  });

  final IconData icon;
  final Color color;
  final String titleKey;
  final String bodyKey;
  final String actionKey;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            context.tr(titleKey),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(bodyKey),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: context.tr(actionKey),
            icon: actionIcon,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

/// Fila de píldoras de verificación (hash + validación local).
class VerifiedPills extends StatelessWidget {
  const VerifiedPills({super.key, required this.paquete});

  final Paquete paquete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        Pill(
          label: context.tr(
            paquete.verified ? 'common.hashOk' : 'common.hashNo',
          ),
          icon: paquete.verified
              ? Icons.verified_user_rounded
              : Icons.gpp_maybe_rounded,
          color: paquete.verified ? AppColors.verdePrincipal : AppColors.tierra,
          background: paquete.verified
              ? AppColors.buenoSoft
              : AppColors.secoSoft,
          compact: true,
        ),
        Pill(
          label: context.tr(
            paquete.validadaLocalmente
                ? 'common.validated'
                : 'common.notValidated',
          ),
          icon: Icons.place_rounded,
          color: paquete.validadaLocalmente
              ? AppColors.verdePrincipal
              : AppColors.tierra,
          background: paquete.validadaLocalmente
              ? AppColors.buenoSoft
              : AppColors.secoSoft,
          compact: true,
        ),
      ],
    );
  }
}

/// Etiqueta del puntaje (umbrales de `Scoring.etiqueta`).
String scoreLabel(BuildContext context, double score) {
  final key = score >= 0.8
      ? 'score.excellent'
      : score >= 0.68
      ? 'score.verygood'
      : score >= 0.56
      ? 'score.good'
      : 'score.consider';
  return context.tr(key);
}

/// Texto de versión del paquete traducido ("v3" o "Sin versión").
String packageVersionLabel(BuildContext context, Paquete paquete) =>
    paquete.meta.version > 0
    ? 'v${paquete.meta.version}'
    : context.tr('common.noVersion');

/// Píldora con el origen del paquete (API, offline, importado, ubicación…).
class OriginPill extends StatelessWidget {
  const OriginPill({super.key, required this.origin});

  final PackageOrigin origin;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (origin) {
      PackageOrigin.api => (
        Icons.cloud_done_rounded,
        AppColors.verdePrincipal,
        AppColors.buenoSoft,
      ),
      PackageOrigin.cache => (
        Icons.phone_android_rounded,
        const Color(0xFF075985),
        AppColors.heladaSoft,
      ),
      PackageOrigin.asset => (
        Icons.inventory_2_rounded,
        AppColors.tierra,
        AppColors.secoSoft,
      ),
      PackageOrigin.demo => (
        Icons.preview_rounded,
        const Color(0xFF075985),
        AppColors.heladaSoft,
      ),
      PackageOrigin.imported => (
        Icons.file_download_done_rounded,
        AppColors.verdePrincipal,
        AppColors.buenoSoft,
      ),
      PackageOrigin.location => (
        Icons.my_location_rounded,
        AppColors.tierra,
        AppColors.secoSoft,
      ),
    };
    return Pill(
      label: context.tr(origin.shortLabelKey),
      icon: icon,
      color: color,
      background: bg,
      compact: true,
    );
  }
}

/// Sección plegable ("Detalles técnicos"): la información que no cambia
/// una decisión queda cerrada por defecto.
class DetailsSection extends StatefulWidget {
  const DetailsSection({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
  });

  final List<Widget> children;

  /// Si es nulo se usa "Detalles técnicos".
  final String? title;
  final String? subtitle;

  @override
  State<DetailsSection> createState() => _DetailsSectionState();
}

class _DetailsSectionState extends State<DetailsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title ?? context.tr('ux.details'),
                        style: theme.titleSmall,
                      ),
                      if (widget.subtitle != null)
                        Text(widget.subtitle!, style: theme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.inkSoft,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: AppSpacing.sm),
          ...widget.children,
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
