import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/organic_background.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';
import '../soil/soil_vision_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Stack(
      children: [
        const Positioned.fill(child: OrganicBackground()),
        PageBody(
          children: [
            _HomeTopBar(state: state),
            const SizedBox(height: 18),
            _HeroPanel(
              state: state,
              onNavigate: onNavigate,
              onChooseZone: () => _openZoneSheet(context),
            ),
            const SizedBox(height: 16),
            _PackagePanel(state: state, onDownload: () => _download(context)),
            if (state.lastError != null) ...[
              const SizedBox(height: 12),
              InfoBanner(
                message: state.lastError!,
                icon: Icons.cloud_off_rounded,
                color: AppColors.alerta,
                background: AppColors.alertaSoft,
                onClose: state.clearError,
              ).animate().fadeIn().slideY(begin: 0.1),
            ] else if (state.notice != null) ...[
              const SizedBox(height: 12),
              InfoBanner(
                message: state.notice!,
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.verdePrincipal,
                background: AppColors.buenoSoft,
                onClose: state.clearError,
              ).animate().fadeIn().slideY(begin: 0.1),
            ],
            const SizedBox(height: 14),
            _CommunityCard(state: state),
            if (state.alertas.isNotEmpty) ...[
              const SizedBox(height: 14),
              _AlertsCard(alertas: state.alertas),
            ],
            const SizedBox(height: 28),
            const SectionHeader(
              kicker: 'Tu temporada',
              title: 'Decide con claridad',
              subtitle: 'Todo lo importante, listo para usar en el campo.',
            ),
            const SizedBox(height: 14),
            _FeatureTile(
              icon: Icons.calendar_month_rounded,
              title: 'Calendario climático',
              subtitle: 'Heladas, meses secos y ventanas buenas.',
              color: AppColors.tecnologia,
              background: AppColors.heladaSoft,
              onTap: () => onNavigate(2),
            ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08),
            const SizedBox(height: 10),
            _FeatureTile(
              icon: Icons.layers_rounded,
              title: 'Rotaciones explicadas',
              subtitle: 'Ordenadas según lo que más te importa.',
              color: AppColors.verdeSecundario,
              background: AppColors.buenoSoft,
              onTap: () => onNavigate(3),
            ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.08),
            const SizedBox(height: 10),
            _FeatureTile(
              icon: Icons.camera_alt_rounded,
              title: 'SoilVision AI',
              subtitle: 'Analiza la apariencia de tu suelo.',
              color: AppColors.tecnologia,
              background: AppColors.heladaSoft,
              onTap: () => _openSoilVision(context, state),
            ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.08),
            const SizedBox(height: 10),
            _FeatureTile(
              icon: Icons.qr_code_2_rounded,
              title: 'Comparte sin internet',
              subtitle: 'QR y archivo para otro celular.',
              color: AppColors.tierra,
              background: AppColors.secoSoft,
              onTap: () => onNavigate(4),
            ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.08),
            const SizedBox(height: 26),
            const _Footer(),
          ],
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
      builder: (_) =>
          _ZoneSheet(zonas: state.zonas, selectedId: state.zona?.id),
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
              ? (state.notice ?? 'Paquete actualizado.')
              : (state.lastError ?? 'No se pudo descargar el paquete.'),
        ),
      ),
    );
  }

  void _openSoilVision(BuildContext context, AppState state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SoilVisionScreen(state: state)),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandLogo(height: 28),
        const Spacer(),
        Pill(
          label: state.online ? 'En línea' : 'Sin señal',
          icon: state.online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          color: state.online ? AppColors.verdePrincipal : AppColors.tierra,
          background: state.online ? AppColors.buenoSoft : AppColors.secoSoft,
          compact: true,
        ),
      ],
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

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.gradientHero,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.lifted,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _HeroTexturePainter()),
          ),
          Positioned(
            right: -34,
            bottom: -24,
            child: Opacity(
              opacity: 0.12,
              child: BrandLogo(markOnly: true, white: true, height: 210),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandLogo(white: true, height: 26),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: AppColors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: const Text(
                        'NASA POWER',
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontWeight: FontWeight.w600,
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Del dato satelital\na tu chacra.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.white,
                    fontSize: 34,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Calendario, rotaciones y explicaciones simples para decidir '
                  'mejor. Diseñado para funcionar aunque no haya señal.',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13.5,
                    height: 1.5,
                    color: AppColors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 20),
                _ZoneSelector(zona: zona, onTap: onChooseZone),
                const SizedBox(height: 14),
                GradientButton(
                  label: zona == null ? 'Elegir mi zona' : 'Ver mi chacra',
                  icon: zona == null
                      ? Icons.travel_explore_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: zona == null ? onChooseZone : () => onNavigate(1),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.06);
  }
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
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
                      zona == null ? 'Mi zona' : 'Zona activa',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                        fontSize: 9.5,
                        letterSpacing: 0.7,
                        color: AppColors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      zona?.nombre ?? 'Elegir mi zona',
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
              Icon(
                Icons.swap_horiz_rounded,
                size: 20,
                color: AppColors.white.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackagePanel extends StatelessWidget {
  const _PackagePanel({required this.state, required this.onDownload});

  final AppState state;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final paquete = state.paquete;
    final origin = state.origin;

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.fondoSuave,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(
                  Icons.storage_rounded,
                  color: AppColors.verdePrincipal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paquete de datos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      paquete == null
                          ? 'Sin paquete cargado'
                          : '${paquete.calendario.length} meses · '
                                '${paquete.rotaciones.length} rotaciones',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (origin != null)
                Pill(
                  label: origin.shortLabel,
                  icon: _originIcon(origin),
                  color: _originColor(origin),
                  background: _originBackground(origin),
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (paquete == null)
            _EmptyPackage(loading: state.loadingPackage)
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.superficie,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    paquete.verified
                        ? Icons.verified_rounded
                        : Icons.gpp_maybe_rounded,
                    size: 16,
                    color: paquete.verified
                        ? AppColors.verdeSecundario
                        : AppColors.tierra,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${prettyZoneName(paquete.zona.nombre)} · '
                          '${paquete.versionLabel} · '
                          '${formatVersion(paquete.version)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        if (paquete.fuenteClima.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Fuente del clima: ${paquete.fuenteClima}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 9.5,
                              height: 1.35,
                              color: AppColors.inkFaint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
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
                if (!state.apiHealthy)
                  const Pill(
                    label: 'API sin respuesta',
                    icon: Icons.cloud_off_rounded,
                    color: AppColors.tierra,
                    background: AppColors.secoSoft,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    value: '${paquete.calendario.length}',
                    label: 'meses',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    value: '${paquete.cultivos.length}',
                    label: 'cultivos',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    value: '${(paquete.rotaciones.length)}',
                    label: 'opciones',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (state.downloading) ...[
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(100)),
                child: LinearProgressIndicator(minHeight: 5),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: state.downloading
                        ? 'Descargando…'
                        : 'Actualizar paquete',
                    icon: Icons.download_rounded,
                    loading: state.downloading,
                    height: 50,
                    gradient: AppColors.gradientHero,
                    foreground: AppColors.white,
                    onPressed: state.downloading ? null : onDownload,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.offline_bolt_rounded,
                  size: 14,
                  color: AppColors.verdeSecundario,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Guardado en el celular. Funciona completo en modo avión.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _originIcon(PackageOrigin origin) {
    switch (origin) {
      case PackageOrigin.api:
        return Icons.cloud_done_rounded;
      case PackageOrigin.cache:
        return Icons.phone_android_rounded;
      case PackageOrigin.asset:
        return Icons.inventory_2_rounded;
      case PackageOrigin.demo:
        return Icons.preview_rounded;
      case PackageOrigin.imported:
        return Icons.file_download_done_rounded;
    }
  }

  Color _originColor(PackageOrigin origin) {
    switch (origin) {
      case PackageOrigin.api:
        return AppColors.verdePrincipal;
      case PackageOrigin.cache:
        return AppColors.tecnologia;
      case PackageOrigin.asset:
        return AppColors.tierra;
      case PackageOrigin.demo:
        return AppColors.tecnologia;
      case PackageOrigin.imported:
        return AppColors.verdePrincipal;
    }
  }

  Color _originBackground(PackageOrigin origin) {
    switch (origin) {
      case PackageOrigin.api:
      case PackageOrigin.imported:
        return AppColors.buenoSoft;
      case PackageOrigin.cache:
      case PackageOrigin.demo:
        return AppColors.heladaSoft;
      case PackageOrigin.asset:
        return AppColors.secoSoft;
    }
  }
}

class _EmptyPackage extends StatelessWidget {
  const _EmptyPackage({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(
              Icons.download_for_offline_outlined,
              color: AppColors.inkFaint,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loading
                  ? 'Cargando el paquete local…'
                  : 'Elige una zona para cargar su paquete.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(value, style: AppTypography.dataValue),
          Text(label, style: AppTypography.dataLabel),
        ],
      ),
    );
  }
}

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

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.heladaSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  size: 20,
                  color: AppColors.tecnologia,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comunidad de tu zona',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Reporta lo que ves. Se envía al recuperar señal.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Pill(
                label: pending == 0 ? 'Al día' : '$pending pendiente(s)',
                icon: pending == 0
                    ? Icons.check_circle_rounded
                    : Icons.cloud_upload_rounded,
                color: pending == 0
                    ? AppColors.verdePrincipal
                    : AppColors.tierra,
                background: pending == 0
                    ? AppColors.buenoSoft
                    : AppColors.secoSoft,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in _types)
                _EventChip(type: type, onTap: () => _report(context, type)),
            ],
          ),
          if (state.communityMessage != null) ...[
            const SizedBox(height: 10),
            InfoBanner(
              message: state.communityMessage!,
              icon: Icons.cloud_sync_rounded,
              color: AppColors.tecnologia,
              background: AppColors.heladaSoft,
              onClose: state.clearCommunityMessage,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                state.apiHealthy
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                size: 14,
                color: state.apiHealthy
                    ? AppColors.verdeSecundario
                    : AppColors.tierra,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.apiHealthy
                      ? 'Servidor disponible'
                      : 'Servidor sin respuesta · se reintentará',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (state.syncingCommunity)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: pending > 0 ? state.syncCommunity : null,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Sincronizar'),
                ),
            ],
          ),
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
          state.online
              ? 'Reporte guardado. Enviando a la comunidad…'
              : 'Reporte guardado. Se enviará cuando vuelva la señal.',
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(eventEmoji(type), style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                eventLabel(type),
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: AppColors.inkSoft,
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
              const Icon(
                Icons.campaign_rounded,
                size: 18,
                color: AppColors.tierra,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alertas de la comunidad',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Pill(
                label: '${alertas.length}',
                color: AppColors.tierra,
                background: AppColors.secoSoft,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final alerta in alertas.take(4)) ...[
            Row(
              children: [
                Text(
                  eventEmoji(alerta.tipo),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${eventLabel(alerta.tipo)} · ${alerta.fecha}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  '${alerta.confirmaciones} confirmaciones',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w600,
                    fontSize: 9.5,
                    color: AppColors.inkFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
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

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 18, height: 2, color: AppColors.line),
            const SizedBox(width: 8),
            const BrandLogo(height: 17),
            const SizedBox(width: 8),
            Container(width: 18, height: 2, color: AppColors.line),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'NASA Space Apps Challenge 2026 · Huánuco, Perú',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          'Datos abiertos NASA POWER · decisiones con criterio local',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    const BrandLogo(markOnly: true, height: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Dónde está tu chacra?',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Elige una zona para cargar su paquete climático.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
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
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
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
                        size: 18,
                        color: AppColors.verdeSecundario,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'La sierra de Huánuco viene incluida para que '
                          'puedas empezar sin señal. Las demás zonas se '
                          'actualizan al conectar.',
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
    ).animate().slideY(
      begin: 0.06,
      duration: 320.ms,
      curve: Curves.easeOutCubic,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.verdeSecundario.withValues(alpha: 0.16)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Icon(
                  isBackup
                      ? Icons.landscape_rounded
                      : zona.id.contains('selva')
                      ? Icons.forest_rounded
                      : zona.id.contains('valle')
                      ? Icons.water_rounded
                      : Icons.public_rounded,
                  color: AppColors.verdePrincipal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zona.nombre,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${zona.coordenadas} · ${zona.elevacionM.round()} m',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Pill(
                      label: isBackup
                          ? 'Listo sin señal'
                          : 'Demo offline · API al conectar',
                      icon: isBackup
                          ? Icons.offline_pin_rounded
                          : Icons.cloud_sync_rounded,
                      color: isBackup
                          ? AppColors.verdePrincipal
                          : AppColors.tecnologia,
                      background: isBackup
                          ? AppColors.white
                          : AppColors.heladaSoft,
                      compact: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.verdeSecundario
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.verdeSecundario
                        : AppColors.inkFaint,
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroTexturePainter extends CustomPainter {
  const _HeroTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.white.withValues(alpha: 0.07);

    for (var i = 0; i < 6; i++) {
      final path = Path();
      final base = size.height * (0.18 + i * 0.115);
      path.moveTo(-20, base);
      for (var x = -20.0; x <= size.width + 20; x += 14) {
        final y =
            base + math.sin((x / size.width) * math.pi * 2.4 + i * 0.5) * 14;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.18),
      size.width * 0.22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.acentoNatural.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.18),
      size.width * 0.3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.acentoNatural.withValues(alpha: 0.1),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
