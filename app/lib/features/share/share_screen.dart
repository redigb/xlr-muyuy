import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/models.dart';
import '../../services/share_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../utils/package_hash.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  bool _sharing = false;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final paquete = state.paquete;

    return PageBody(
      children: [
        PageTopBar(
          title: 'Compartir',
          subtitle: 'Lleva el paquete a otro celular',
          trailing: Pill(
            label: state.origin?.shortLabel ?? 'Local',
            icon: Icons.offline_pin_rounded,
            color: AppColors.verdePrincipal,
            background: AppColors.buenoSoft,
            compact: true,
          ),
        ),
        const SizedBox(height: 18),
        if (paquete == null)
          _ShareEmpty(onNavigate: widget.onNavigate)
        else ...[
          _PackageSummary(
            state: state,
            size: _packageSize(paquete.toJson()),
          ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.04),
          const SizedBox(height: 16),
          _QrCard(
            data: state.sharing.qrPayload(paquete),
            zona: prettyZoneName(paquete.zona.nombre),
            version:
                '${paquete.versionLabel} · ${formatVersion(paquete.version)}',
          ).animate().fadeIn(duration: 420.ms, delay: 60.ms).slideY(begin: 0.04),
          const SizedBox(height: 16),
          _FileActions(
            sharing: _sharing,
            importing: _importing,
            onShare: () => _share(context, state),
            onImport: () => _import(context, state),
          ),
          const SizedBox(height: 16),
          const _OfflineNote(),
          const SizedBox(height: 16),
          _StorageCard(state: state, onRefresh: () => _refresh(context, state)),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  int _packageSize(Map<String, dynamic> json) {
    return utf8.encode(jsonEncode(json)).length;
  }

  Future<void> _share(BuildContext context, AppState state) async {
    final paquete = state.paquete;
    if (paquete == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final outcome = await state.sharing.sharePackage(paquete);
      if (!context.mounted) return;
      _showSnack(
        context,
        outcome == ShareOutcome.shared
            ? 'Paquete listo para enviar por Quick Share o Bluetooth.'
            : 'Paquete copiado. Pégalo en un mensaje o archivo.',
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, 'No se pudo compartir el paquete. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _import(BuildContext context, AppState state) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: 'Paquetes MUYUY',
            extensions: const ['json'],
            mimeTypes: const ['application/json'],
          ),
        ],
      );
      if (file == null) return;

      if ((await file.length()) > 512 * 1024) {
        if (!context.mounted) return;
        _showSnack(context, 'El archivo es demasiado grande para un paquete.');
        return;
      }

      final bytes = await file.readAsBytes();
      final raw = utf8.decode(bytes);
      final ok = await state.importPackage(raw);
      if (!context.mounted) return;
      _showSnack(
        context,
        ok
            ? 'Paquete importado. Ya está disponible sin señal.'
            : (state.lastError ?? 'No se pudo leer el archivo.'),
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, 'No se pudo leer el archivo seleccionado.');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _refresh(BuildContext context, AppState state) async {
    final ok = await state.downloadCurrent();
    if (!context.mounted) return;
    _showSnack(
      context,
      ok
          ? 'Paquete actualizado. Ya funciona sin señal.'
          : (state.lastError ?? 'No se pudo actualizar el paquete.'),
    );
  }

  void _showSnack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PackageSummary extends StatelessWidget {
  const _PackageSummary({required this.state, required this.size});

  final AppState state;
  final int size;

  @override
  Widget build(BuildContext context) {
    final paquete = state.paquete!;

    return SoftCard(
      padding: const EdgeInsets.all(16),
      gradient: AppColors.gradientSoft,
      child: Row(
        children: [
          const BrandLogo(markOnly: true, height: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prettyZoneName(paquete.zona.nombre),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${paquete.versionLabel} · '
                  '${formatVersion(paquete.version)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatKb(size / 1024),
                style: AppTypography.dataValue.copyWith(fontSize: 16),
              ),
              Text('peso', style: AppTypography.dataLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.data,
    required this.zona,
    required this.version,
  });

  final String data;
  final String zona;
  final String version;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.fondoSuave,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
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
                      'Identifica tu paquete',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'El QR guarda la zona y la versión.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Pill(
                label: 'Pequeño y rápido',
                icon: Icons.bolt_rounded,
                color: AppColors.verdePrincipal,
                background: AppColors.buenoSoft,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.maxWidth
                    .clamp(160.0, 248.0)
                    .toDouble();
                return _QrFrame(
                  child: QrImageView(
                    data: data,
                    version: QrVersions.auto,
                    size: side,
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.verdePrincipal,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.verdePrincipal,
                    ),
                    embeddedImage: const AssetImage(
                      'assets/images/logo_mark.png',
                    ),
                    embeddedImageStyle: QrEmbeddedImageStyle(
                      size: Size(side * 0.18, side * 0.18),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            zona,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            version,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const InfoBanner(
            message:
                'El QR no lleva el paquete completo. Para enviar todo, '
                'comparte el archivo JSON de abajo.',
            icon: Icons.info_outline_rounded,
            color: AppColors.tecnologia,
            background: AppColors.heladaSoft,
          ),
        ],
      ),
    );
  }
}

class _QrFrame extends StatelessWidget {
  const _QrFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.soft,
      ),
      child: Stack(
        children: [
          child,
          Positioned(
            left: 0,
            top: 0,
            child: _Corner(color: AppColors.verdeSecundario, top: true),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _Corner(
              color: AppColors.verdeSecundario,
              top: true,
              right: true,
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: _Corner(color: AppColors.verdeSecundario),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _Corner(color: AppColors.verdeSecundario, right: true),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.color, this.top = false, this.right = false});

  final Color color;
  final bool top;
  final bool right;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: color, width: 2.5) : BorderSide.none,
          bottom: !top ? BorderSide(color: color, width: 2.5) : BorderSide.none,
          left: !right ? BorderSide(color: color, width: 2.5) : BorderSide.none,
          right: right ? BorderSide(color: color, width: 2.5) : BorderSide.none,
        ),
      ),
    );
  }
}

class _FileActions extends StatelessWidget {
  const _FileActions({
    required this.sharing,
    required this.importing,
    required this.onShare,
    required this.onImport,
  });

  final bool sharing;
  final bool importing;
  final VoidCallback onShare;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
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
                  Icons.ios_share_rounded,
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
                      'Enviar el paquete completo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      kIsWeb
                          ? 'En web se copia el JSON al portapapeles.'
                          : 'Archivo JSON · Quick Share, Bluetooth o correo.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: kIsWeb ? 'Copiar paquete' : 'Compartir archivo del paquete',
            icon: kIsWeb ? Icons.copy_rounded : Icons.share_rounded,
            loading: sharing,
            onPressed: sharing ? null : onShare,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: importing ? null : onImport,
            icon: importing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open_rounded, size: 18),
            label: Text(
              importing ? 'Leyendo archivo…' : 'Recibir un paquete (.json)',
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.gradientHero,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.bluetooth_rounded,
              color: AppColors.acentoNatural,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sin internet, sin problema',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppColors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pasa el archivo de un celular a otro con Quick Share, '
                  'Bluetooth o un cable. La app lo importa y queda listo '
                  'para usarse en modo avión.',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.white.withValues(alpha: 0.78),
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

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.state, required this.onRefresh});

  final AppState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final origin = state.origin;
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_android_rounded,
                size: 18,
                color: AppColors.verdePrincipal,
              ),
              const SizedBox(width: 8),
              Text(
                'En este celular',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Origen', value: origin?.label ?? 'Copia local'),
          const SizedBox(height: 6),
          _InfoRow(
            label: 'Versión',
            value: state.paquete?.versionLabel ?? 'Sin versión',
          ),
          const SizedBox(height: 6),
          _InfoRow(
            label: 'Integridad',
            value: (state.paquete?.verified ?? false)
                ? 'Hash verificado'
                : 'Sin verificar',
          ),
          const SizedBox(height: 6),
          _InfoRow(
            label: 'Hash',
            value: (state.paquete?.hash.isNotEmpty ?? false)
                ? shortPackageHash(state.paquete!.hash)
                : 'Sin hash',
          ),
          const SizedBox(height: 6),
          _InfoRow(
            label: 'Estado',
            value: state.online
                ? 'En línea · listo para actualizar'
                : 'Offline',
          ),
          const SizedBox(height: 6),
          const _InfoRow(
            label: 'Modo avión',
            value: 'Calendario y rotaciones disponibles',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: state.downloading ? null : onRefresh,
              icon: state.downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 17),
              label: Text(
                state.downloading ? 'Actualizando…' : 'Actualizar paquete',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: AppColors.inkFaint,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareEmpty extends StatelessWidget {
  const _ShareEmpty({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.share_rounded,
            size: 44,
            color: AppColors.tecnologia,
          ),
          const SizedBox(height: 12),
          Text(
            'Nada para compartir todavía',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Elige una zona y carga su paquete primero.',
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
