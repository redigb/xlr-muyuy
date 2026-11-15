import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/models.dart';
import '../../services/share_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../utils/package_hash.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/status_widgets.dart';

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
          title: context.tr('share.title'),
          subtitle: context.tr('share.subtitle'),
        ),
        const SizedBox(height: AppSpacing.base),
        if (paquete == null)
          EmptyCard(
            icon: Icons.share_rounded,
            color: const Color(0xFF075985),
            titleKey: 'share.empty.t',
            bodyKey: 'share.empty.s',
            onAction: () => widget.onNavigate(0),
          )
        else ...[
          _FileActions(
            zona: prettyZoneName(paquete.zona.nombre),
            detail:
                '${packageVersionLabel(context, paquete)} · '
                '${formatVersion(paquete.version)} · '
                '${formatKb(utf8.encode(jsonEncode(paquete.toJson())).length / 1024)}',
            sharing: _sharing,
            importing: _importing,
            onShare: () => _share(context, state),
            onImport: () => _import(context, state),
          ),
          const SizedBox(height: AppSpacing.base),
          SoftCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.xs,
            ),
            child: DetailsSection(
              title: context.tr('share.qr.t'),
              subtitle: context.tr('share.qr.s'),
              children: [
                _QrBlock(
                  data: state.qrPayload(),
                  zona: prettyZoneName(paquete.zona.nombre),
                  version:
                      '${packageVersionLabel(context, paquete)} · '
                      '${formatVersion(paquete.version)}',
                ),
              ],
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
                _StorageDetails(
                  state: state,
                  onRefresh: () => _refresh(context, state),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _share(BuildContext context, AppState state) async {
    if (state.paquete == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final outcome = await state.sharePackage();
      if (!context.mounted) return;
      _showSnack(
        context,
        context.tr(
          outcome == ShareOutcome.shared ? 'share.shared' : 'share.copied',
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, context.tr('share.shareFail'));
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
            label: context.tr('share.import.type'),
            extensions: const ['json'],
            mimeTypes: const ['application/json'],
          ),
        ],
      );
      if (file == null) return;

      if ((await file.length()) > 512 * 1024) {
        if (!context.mounted) return;
        _showSnack(context, context.tr('common.fileTooBig'));
        return;
      }

      final raw = utf8.decode(await file.readAsBytes());
      final ok = await state.importPackage(raw);
      if (!context.mounted) return;
      // El estado ya deja el mensaje traducido (ok, versión más nueva, error).
      _showSnack(
        context,
        ok
            ? (state.notice ?? context.tr('share.importOk'))
            : (state.lastError ??
                  state.notice ??
                  context.tr('share.importFail')),
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, context.tr('share.readFail'));
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
          ? (state.notice ?? context.tr('share.refreshOk'))
          : (state.lastError ?? context.tr('share.refreshFail')),
    );
  }

  void _showSnack(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _QrBlock extends StatelessWidget {
  const _QrBlock({
    required this.data,
    required this.zona,
    required this.version,
  });

  final String data;
  final String zona;
  final String version;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final side = (constraints.maxWidth - 36)
                .clamp(160.0, 240.0)
                .toDouble();
            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.line),
              ),
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
                embeddedImage: const AssetImage('assets/images/logo_mark.png'),
                embeddedImageStyle: QrEmbeddedImageStyle(
                  size: Size(side * 0.18, side * 0.18),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          zona,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          version,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        InfoBanner(
          message: context.tr('share.qr.note'),
          icon: Icons.info_outline_rounded,
          color: const Color(0xFF075985),
          background: AppColors.heladaSoft,
        ),
      ],
    );
  }
}

/// Acción dominante: pasar el paquete a otro celular.
class _FileActions extends StatelessWidget {
  const _FileActions({
    required this.zona,
    required this.detail,
    required this.sharing,
    required this.importing,
    required this.onShare,
    required this.onImport,
  });

  final String zona;
  final String detail;
  final bool sharing;
  final bool importing;
  final VoidCallback onShare;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zona,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge,
          ),
          Text(detail, style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.base),
          GradientButton(
            label: context.tr(kIsWeb ? 'share.send.btnWeb' : 'share.send.btn'),
            icon: kIsWeb ? Icons.copy_rounded : Icons.share_rounded,
            loading: sharing,
            onPressed: sharing ? null : onShare,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: importing ? null : onImport,
            icon: importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open_rounded),
            label: Text(
              context.tr(
                importing ? 'share.import.reading' : 'share.import.btn',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageDetails extends StatelessWidget {
  const _StorageDetails({required this.state, required this.onRefresh});

  final AppState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final origin = state.origin;
    final paquete = state.paquete;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: context.tr('share.store.origin'),
          value: origin == null
              ? context.tr('common.localCopy')
              : context.tr(origin.labelKey),
        ),
        _InfoRow(
          label: context.tr('share.store.integrity'),
          value: context.tr(
            (paquete?.verified ?? false) ? 'common.hashOk' : 'common.hashNo',
          ),
        ),
        _InfoRow(
          label: context.tr('share.store.hash'),
          value: (paquete?.hash.isNotEmpty ?? false)
              ? shortPackageHash(paquete!.hash)
              : context.tr('share.store.noHash'),
        ),
        _InfoRow(
          label: context.tr('share.store.state'),
          value: context.tr(
            state.online ? 'share.store.online' : 'common.offline',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: state.downloading ? null : onRefresh,
          icon: state.downloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(
            context.tr(
              state.downloading ? 'common.updating' : 'common.updatePkg',
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: textTheme.labelMedium)),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
