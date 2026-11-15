import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/agrovision/agrovision_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';

class AgroVisionScreen extends StatefulWidget {
  const AgroVisionScreen({super.key});

  @override
  State<AgroVisionScreen> createState() => _AgroVisionScreenState();
}

class _AgroVisionScreenState extends State<AgroVisionScreen> {
  final _picker = ImagePicker();
  Uint8List? _photo;
  ({int index, double score})? _result;
  String? _error;
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null || !mounted) return;
      setState(() {
        _photo = null;
        _result = null;
      });
      final photo = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photo = photo);
      final result = await analyzeLeaf(photo);
      if (mounted) setState(() => _result = result);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _error = context.tr('agro.err.camera'));
    } on FormatException {
      if (!mounted) return;
      setState(() => _error = context.tr('agro.err.unreadable'));
    } catch (error, stackTrace) {
      debugPrint('AgroVision: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = context.tr('agro.err.failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final result = _result;
    final supported =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      backgroundColor: AppColors.fondoSuave,
      appBar: AppBar(title: const Text('AgroVision')),
      body: PageBody(
        children: [
          Text(
            context.tr('agro.title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            supported
                ? context.tr('agro.intro')
                : context.tr('agro.androidOnly'),
          ),
          if (supported) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr('agro.tomatoOnly'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (supported) ...[
            const SizedBox(height: AppSpacing.base),
            GradientButton(
              label: context.tr('agro.takePhoto'),
              icon: Icons.photo_camera_outlined,
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(context.tr('agro.gallery')),
            ),
          ],
          if (photo != null) ...[
            const SizedBox(height: AppSpacing.base),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.memory(
                photo,
                height: 240,
                fit: BoxFit.contain,
                semanticLabel: context.tr('agro.photoLabel'),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: AppSpacing.base),
            LinearProgressIndicator(
              semanticsLabel: context.tr('agro.processing'),
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: AppSpacing.base),
            InfoBanner(message: error, icon: Icons.error_outline),
          ],
          if (result != null) ...[
            const SizedBox(height: AppSpacing.base),
            SoftCard(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('agro.result')),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr(leafLabels[result.index]),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr('agro.score', {
                      'pct': (result.score * 100).toStringAsFixed(1),
                    }),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
