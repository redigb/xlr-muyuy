import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/status_widgets.dart';
import '../agrovision/agrovision_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final showValidity =
        state.hasPackage && ValidityPanel.sections.any(state.seccionVencida);

    return PageBody(
      children: [
        Row(
          children: [
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: BrandLogo(height: 28),
              ),
            ),
            const LangSelector(),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        const ZoneWarning(),
        if (state.lastError != null)
          _Message(
            text: state.lastError!,
            icon: Icons.cloud_off_rounded,
            color: AppColors.tierra,
            background: AppColors.secoSoft,
            onClose: state.clearError,
          )
        else if (state.notice != null)
          _Message(
            text: state.notice!,
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.verdePrincipal,
            background: AppColors.buenoSoft,
            onClose: state.clearError,
          ),
        _HeroPanel(
          state: state,
          onNavigate: onNavigate,
          onChooseZone: () => _openZoneSheet(context),
        ),
        const SizedBox(height: AppSpacing.md),
        GradientButton(
          label: context.tr('home.agrovision'),
          icon: Icons.eco_outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AgroVisionScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _LocationButton(state: state),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.tr('location.privacy'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (showValidity) ...[
          const SizedBox(height: AppSpacing.base),
          const SoftCard(
            padding: EdgeInsets.all(AppSpacing.base),
            child: ValidityPanel(),
          ),
        ],
        if (state.alertas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.base),
          SectionFreshness(
            section: 'alertas',
            child: _AlertsCard(alertas: state.alertas),
          ),
        ],
        const SizedBox(height: AppSpacing.base),
        _CommunityCard(state: state),
        const SizedBox(height: AppSpacing.base),
        _PackagePanel(state: state, onDownload: () => _download(context)),
        const SizedBox(height: AppSpacing.md),
        _AdvancedSection(state: state),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.tr('home.footer1'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  Future<void> _openZoneSheet(BuildContext context) async {
    final state = AppScope.of(context);
    final selected = await showModalBottomSheet<Zona>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (_) => AppScope(
        state: state,
        child: _ZoneSheet(zonas: state.zonas, selectedId: state.zona?.id),
      ),
    );

    if (selected == null || !context.mounted) return;
    await state.selectZona(selected);
    if (!context.mounted) return;
    onNavigate(1);
  }

  Future<void> _download(BuildContext context) async {
    final state = AppScope.of(context);
    final ok = await state.downloadCurrent();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (state.notice ?? context.tr('home.pkg.updated'))
              : (state.lastError ?? context.tr('home.pkg.failed')),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.icon,
    required this.color,
    required this.background,
    required this.onClose,
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: InfoBanner(
        message: text,
        icon: icon,
        color: color,
        background: background,
        onClose: onClose,
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.state,
    required this.onNavigate,
    required this.onChooseZone,
  });

  final AppState state;
  final ValueChanged<int> onNavigate;
  final VoidCallback onChooseZone;

  @override
  Widget build(BuildContext context) {
    final zona = state.zona;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.lifted,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: AppColors.gradientHero),
                    child: CustomPaint(painter: _HeroContours()),
                  ),
                ),
                const Positioned(
                  right: -30,
                  bottom: -26,
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: 0.12,
                      child: BrandLogo(
                        height: 200,
                        white: true,
                        markOnly: true,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const BrandLogo(height: 24, white: true),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x24FFFFFF),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: const Color(0x22FFFFFF),
                              ),
                            ),
                            child: const Text(
                              'NASA POWER',
                              style: TextStyle(
                                fontFamily: AppFonts.body,
                                color: AppColors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.65,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        context.tr('home.heroTitle'),
                        style: const TextStyle(
                          fontFamily: AppFonts.display,
                          color: AppColors.white,
                          fontSize: 34,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.9,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('home.heroBody'),
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          color: Color(0xFFD5E6DA),
                          fontSize: 14,
                          height: 1.43,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _ZoneSelector(zona: zona, onTap: onChooseZone),
                      const SizedBox(height: 14),
                      GradientButton(
                        label: context.tr(
                          zona == null ? 'home.chooseZone' : 'home.seeFarm',
                        ),
                        icon: zona == null
                            ? Icons.travel_explore_rounded
                            : Icons.arrow_forward_rounded,
                        onPressed: zona == null
                            ? onChooseZone
                            : () => onNavigate(1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.hasPackage) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.tr('home.pkg.saved'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _HeroContours extends CustomPainter {
  const _HeroContours();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x16D9F4D9)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final width = size.width;
    final height = size.height;
    for (final fraction in [0.19, 0.30, 0.43, 0.61, 0.74]) {
      final y = height * fraction;
      final line = Path()
        ..moveTo(0, y + 13)
        ..cubicTo(
          width * 0.33,
          y + 25,
          width * 0.44,
          y - 42,
          width * 0.81,
          y - 8,
        )
        ..quadraticBezierTo(width * 0.94, y + 8, width, y + 7);
      canvas.drawPath(line, paint);
    }
    final center = Offset(width * 0.9, height * 0.17);
    canvas.drawCircle(center, width * 0.26, paint);
    canvas.drawCircle(center, width * 0.34, paint);
  }

  @override
  bool shouldRepaint(_HeroContours oldDelegate) => false;
}

class _ZoneSelector extends StatelessWidget {
  const _ZoneSelector({required this.zona, required this.onTap});

  final Zona? zona;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        zona == null ? 'home.zoneNone' : 'home.zoneActive',
                      ),
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: 0.55,
                        color: AppColors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      zona == null
                          ? context.tr('home.chooseZone')
                          : prettyZoneName(zona!.nombre),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.swap_horiz_rounded,
                size: 22,
                color: AppColors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Usar mi ubicación": lee el GPS (5 a 30 s) y calcula el paquete de la celda.
class _LocationButton extends StatelessWidget {
  const _LocationButton({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final busy = state.locating;
    return OutlinedButton.icon(
      onPressed: busy
          ? null
          : () {
              HapticFeedback.selectionClick();
              state.useMyLocation();
            },
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : const Icon(Icons.my_location_rounded, size: 20),
      label: Text(context.tr(busy ? 'location.reading' : 'location.use')),
    );
  }
}

/// Todo lo técnico del paquete, plegado.
class _PackagePanel extends StatelessWidget {
  const _PackagePanel({required this.state, required this.onDownload});

  final AppState state;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final paquete = state.paquete;
    final origin = state.origin;
    final theme = Theme.of(context).textTheme;

    return SoftCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xs,
      ),
      child: DetailsSection(
        title: context.tr('home.pkg.title'),
        subtitle: paquete == null
            ? context.tr('home.pkg.none')
            : context.tr('home.pkg.summary', {
                'm': paquete.calendario.length,
                'r': paquete.rotaciones.length,
              }),
        children: [
          if (paquete == null)
            _EmptyPackage(loading: state.loadingPackage)
          else ...[
            Text(
              '${prettyZoneName(paquete.zona.nombre)} · '
              '${packageVersionLabel(context, paquete)} · '
              '${formatVersion(paquete.version)}',
              style: theme.titleSmall,
            ),
            if (paquete.fuenteClima.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.tr('home.pkg.source', {'src': paquete.fuenteClima}),
                style: theme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                VerifiedPills(paquete: paquete),
                if (origin != null) OriginPill(origin: origin),
                if (!state.apiHealthy)
                  Pill(
                    label: context.tr('home.pkg.noApi'),
                    icon: Icons.cloud_off_rounded,
                    color: AppColors.inkSoft,
                    background: AppColors.pendienteSoft,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            const ValidityPanel(),
            const SizedBox(height: AppSpacing.base),
            if (state.downloading) ...[
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(100)),
                child: LinearProgressIndicator(minHeight: 5),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            OutlinedButton.icon(
              onPressed: state.downloading ? null : onDownload,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(
                context.tr(
                  state.downloading
                      ? 'home.pkg.downloading'
                      : 'common.updatePkg',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyPackage extends StatelessWidget {
  const _EmptyPackage({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (loading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(
            Icons.download_for_offline_outlined,
            color: AppColors.inkSoft,
          ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            context.tr(loading ? 'home.pkg.loading' : 'home.pkg.pick'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Reporte rápido: tocar lo que se ve en la chacra.
class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.state});

  final AppState state;

  static const _types = [
    'helada',
    'sequia',
    'lluvia_fuerte',
    'granizo',
    'plaga',
  ];

  @override
  Widget build(BuildContext context) {
    if (!state.hasZona) return const SizedBox.shrink();
    final pending = state.pendingObservations;
    final connections = state.pendingConexiones;
    final theme = Theme.of(context).textTheme;

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('home.comm.title'), style: theme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(context.tr('home.comm.sub'), style: theme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final type in _types)
                _EventChip(type: type, onTap: () => _report(context, type)),
            ],
          ),
          if (state.communityMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBanner(
              message: state.communityMessage!,
              icon: Icons.cloud_sync_rounded,
              color: AppColors.verdePrincipal,
              background: AppColors.buenoSoft,
              onClose: state.clearCommunityMessage,
            ),
          ],
          if (state.reportes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.base),
            Text(context.tr('home.comm.recent'), style: theme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            ReportList(reportes: state.reportes),
          ],
          if (pending > 0 || connections > 0 || state.syncingCommunity) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.hourglass_empty_rounded,
                  size: 18,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    pending > 0
                        ? context.tr('home.comm.pending', {'n': pending})
                        : context.tr('home.comm.connections', {
                            'n': connections,
                          }),
                    style: theme.bodySmall,
                  ),
                ),
                if (state.syncingCommunity)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: pending > 0 ? state.syncCommunity : null,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(context.tr('common.sync')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _report(BuildContext context, String type) async {
    HapticFeedback.selectionClick();
    await state.reportObservation(type);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          state.communityMessage ??
              context.tr(
                state.online
                    ? 'community.savedOnline'
                    : 'community.savedOffline',
              ),
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({required this.type, required this.onTap});

  final String type;
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(eventEmoji(type), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                eventLabel(context, type),
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.alertas});

  final List<Alerta> alertas;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('home.alerts.title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final alerta in alertas.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    eventEmoji(alerta.tipo),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${eventLabel(context, alerta.tipo)} · ${alerta.fecha}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    context.tr('home.alerts.confirm', {
                      'n': alerta.confirmaciones,
                    }),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Reiniciar demo": siempre visible en web; en el celular, dentro de Avanzado.
class _AdvancedSection extends StatefulWidget {
  const _AdvancedSection({required this.state});

  final AppState state;

  @override
  State<_AdvancedSection> createState() => _AdvancedSectionState();
}

class _AdvancedSectionState extends State<_AdvancedSection> {
  bool _open = false;

  Future<void> _reset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppScope(
        state: widget.state,
        child: Builder(
          builder: (dialogContext) => AlertDialog(
            title: Text(dialogContext.tr('home.reset.title')),
            content: Text(dialogContext.tr('home.reset.body')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.tr('common.cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dialogContext.tr('home.reset.btn')),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    await widget.state.resetDemo();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(widget.state.notice ?? context.tr('demo.reset.done')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: () => _reset(context),
      icon: const Icon(Icons.restart_alt_rounded, size: 20),
      label: Text(context.tr('home.reset.btn')),
    );

    if (widget.state.isDemo) return button;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(
            _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          ),
          label: Text(context.tr('home.advanced')),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        if (_open) button,
      ],
    );
  }
}

class _ZoneSheet extends StatelessWidget {
  const _ZoneSheet({required this.zonas, required this.selectedId});

  final List<Zona> zonas;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const BrandLogo(markOnly: true, height: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('home.zones.title'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('home.zones.sub'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final zona in zonas) ...[
                  _ZoneTile(
                    zona: zona,
                    selected: zona.id == selectedId,
                    onTap: () => Navigator.of(context).pop(zona),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.fondoSuave,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.offline_bolt_rounded,
                        size: 20,
                        color: AppColors.verdePrincipal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('home.zones.note'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
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

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({
    required this.zona,
    required this.selected,
    required this.onTap,
  });

  final Zona zona;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBackup = zona.id == 'huanuco-sierra';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.buenoSoft : AppColors.superficie,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.verdeSecundario : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              IconBadge(
                icon: isBackup
                    ? Icons.landscape_rounded
                    : zona.id.contains('selva')
                    ? Icons.forest_rounded
                    : zona.id.contains('valle')
                    ? Icons.water_rounded
                    : Icons.public_rounded,
                background: AppColors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prettyZoneName(zona.nombre),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${zona.coordenadas} · ${zona.elevacionM.round()} m',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Pill(
                      label: context.tr(
                        isBackup ? 'home.zones.ready' : 'home.zones.demo',
                      ),
                      icon: isBackup
                          ? Icons.offline_pin_rounded
                          : Icons.cloud_sync_rounded,
                      color: isBackup
                          ? AppColors.verdePrincipal
                          : const Color(0xFF075985),
                      background: isBackup
                          ? AppColors.white
                          : AppColors.heladaSoft,
                      compact: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 24,
                color: selected
                    ? AppColors.verdeSecundario
                    : AppColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
