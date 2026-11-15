import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/crop_diseases.dart';
import '../../services/agrovision/agrovision_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/status_widgets.dart';

class AgroVisionScreen extends StatefulWidget {
  const AgroVisionScreen({super.key});

  @override
  State<AgroVisionScreen> createState() => _AgroVisionScreenState();
}

class _AgroVisionScreenState extends State<AgroVisionScreen> {
  final _picker = ImagePicker();
  final List<_ScanLog> _history = [];
  Uint8List? _photo;
  LeafPrediction? _prediction;
  String? _error;
  bool _busy = false;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
        _prediction = null;
      });
      final photo = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photo = photo);
      final prediction = await analyzeLeaf(photo);
      if (!mounted) return;
      setState(() {
        _prediction = prediction;
        _history.insert(
          0,
          _ScanLog(
            index: prediction.index,
            confidence: prediction.confidence,
            at: DateTime.now(),
          ),
        );
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() => _error = context.tr('agro.err.camera'));
    } on UnsupportedError {
      if (!mounted) return;
      setState(() => _error = context.tr('agro.androidOnly'));
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

  void _reset() {
    setState(() {
      _photo = null;
      _prediction = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final prediction = _prediction;
    final disease = prediction == null
        ? null
        : cropDiseaseFor(prediction.index, lang);

    return Scaffold(
      backgroundColor: AppColors.fondoSuave,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.gradientSoft),
        child: PageBody(
          children: [
            _Header(supported: _supported),
            const SizedBox(height: AppSpacing.md),
            if (!_supported) ...[
              InfoBanner(
                message: context.tr('agro.androidOnly'),
                icon: Icons.phone_android_rounded,
                color: AppColors.tierra,
                background: AppColors.secoSoft,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (prediction == null) ..._intro(context),
            _PhotoCard(
              photo: _photo,
              busy: _busy,
              onCamera: () => _pick(ImageSource.camera),
              onGallery: () => _pick(ImageSource.gallery),
              onRemove: _reset,
              enabled: _supported,
            ),
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              InfoBanner(
                message: error,
                icon: Icons.error_outline_rounded,
                color: AppColors.alerta,
                background: AppColors.alertaSoft,
                onClose: () => setState(() => _error = null),
              ),
            ],
            if (prediction != null && disease != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ResultCard(prediction: prediction, disease: disease),
              const SizedBox(height: AppSpacing.md),
              _ListCard(
                icon: Icons.biotech_rounded,
                color: AppColors.tecnologia,
                title: context.tr('agro.symptoms'),
                items: disease.symptoms,
              ),
              const SizedBox(height: AppSpacing.md),
              _ListCard(
                icon: Icons.help_outline_rounded,
                color: AppColors.tierra,
                title: context.tr('agro.causes'),
                items: disease.causes,
              ),
              const SizedBox(height: AppSpacing.md),
              _TreatmentCard(steps: disease.treatment),
              const SizedBox(height: AppSpacing.md),
              SoftCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: AppSpacing.xs,
                ),
                child: DetailsSection(
                  title: context.tr('agro.prevention'),
                  subtitle: context.tr('agro.preventionS'),
                  children: [
                    _Bullets(
                      items: disease.prevention,
                      color: AppColors.verdeSecundario,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.tr('agro.pathogenNote', {
                        'pathogen': disease.pathogen,
                      }),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.tr('agro.ran'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _Disclaimer(),
              const SizedBox(height: AppSpacing.base),
              GradientButton(
                label: context.tr('agro.again'),
                icon: Icons.camera_alt_rounded,
                onPressed: _reset,
              ),
            ],
            if (_history.length > 1) ...[
              const SizedBox(height: AppSpacing.base),
              _HistoryCard(history: _history),
            ],
            const SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
  }

  List<Widget> _intro(BuildContext context) {
    return [
      SoftCard(
        padding: const EdgeInsets.all(AppSpacing.base),
        gradient: AppColors.gradientHero,
        borderColor: AppColors.verdePrincipal,
        shadows: AppShadows.lifted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('agro.kicker'),
              style: AppTypography.kicker.copyWith(
                color: AppColors.acentoNatural,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('agro.title'),
              style: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 24,
                height: 1.15,
                letterSpacing: -0.4,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr('agro.intro'),
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.45,
                color: Color(0xFFD5E6DA),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                Pill(
                  label: context.tr('agro.chip.classes'),
                  icon: Icons.category_rounded,
                  color: AppColors.white,
                  background: const Color(0x1FFFFFFF),
                  borderColor: const Color(0x33FFFFFF),
                  compact: true,
                ),
                Pill(
                  label: context.tr('agro.chip.phone'),
                  icon: Icons.offline_bolt_rounded,
                  color: AppColors.white,
                  background: const Color(0x1FFFFFFF),
                  borderColor: const Color(0x33FFFFFF),
                  compact: true,
                ),
                Pill(
                  label: context.tr('agro.tomatoOnly'),
                  icon: Icons.eco_rounded,
                  color: AppColors.white,
                  background: const Color(0x1FFFFFFF),
                  borderColor: const Color(0x33FFFFFF),
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.supported});

  final bool supported;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('agro.appTitle'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                context.tr(supported ? 'agro.subtitle' : 'agro.subtitleWeb'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Pill(
          label: context.tr(supported ? 'agro.local' : 'agro.web'),
          icon: supported ? Icons.offline_pin_rounded : Icons.cloud_outlined,
          color: supported ? AppColors.verdePrincipal : AppColors.tierra,
          background: supported ? AppColors.buenoSoft : AppColors.secoSoft,
          compact: true,
        ),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
    required this.enabled,
  });

  final Uint8List? photo;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('agro.photo'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (photo != null)
                Text(
                  context.tr('agro.oneLeaf'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: photo == null
                  ? _EmptyPhoto(enabled: enabled)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: AppColors.ink,
                          child: Image.memory(
                            photo!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            cacheWidth: 900,
                            semanticLabel: context.tr('agro.photoLabel'),
                          ),
                        ),
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(painter: _ScanCorners()),
                          ),
                        ),
                        if (busy) const Positioned.fill(child: _Scanning()),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: busy ? null : onRemove,
                              borderRadius: BorderRadius.circular(100),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.ink.withValues(alpha: 0.62),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: AppColors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.tr('agro.remove'),
                                      style: const TextStyle(
                                        fontFamily: AppFonts.body,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (photo == null)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: enabled && !busy ? onCamera : null,
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: Text(context.tr('agro.camera')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled && !busy ? onGallery : null,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: Text(context.tr('agro.gallery')),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled && !busy ? onCamera : null,
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: Text(context.tr('agro.retake')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled && !busy ? onGallery : null,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: Text(context.tr('agro.other')),
                  ),
                ),
              ],
            ),
          if (photo == null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: AppColors.tierra,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('agro.tip'),
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
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.fondoSuave,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(
              Icons.eco_rounded,
              size: 27,
              color: enabled ? AppColors.verdeSecundario : AppColors.pendiente,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr('agro.empty.t'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 3),
          Text(
            context.tr('agro.empty.s'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ScanCorners extends CustomPainter {
  const _ScanCorners();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 12.0;
    const length = 24.0;
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final path = Path()
      ..moveTo(rect.left, rect.top + length)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + length, rect.top)
      ..moveTo(rect.right - length, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + length)
      ..moveTo(rect.right, rect.bottom - length)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - length, rect.bottom)
      ..moveTo(rect.left + length, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScanCorners oldDelegate) => false;
}

class _Scanning extends StatefulWidget {
  const _Scanning();

  @override
  State<_Scanning> createState() => _ScanningState();
}

class _ScanningState extends State<_Scanning>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: AppColors.verdePrincipal.withValues(alpha: 0.6)),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Align(
              alignment: Alignment(0, _controller.value * 2 - 1),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.verdeSecundario.withValues(alpha: 0),
                      AppColors.verdeSecundario,
                      AppColors.verdeSecundario.withValues(alpha: 0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.verdeSecundario.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('agro.analyzing'),
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.prediction, required this.disease});

  final LeafPrediction prediction;
  final CropDisease disease;

  @override
  Widget build(BuildContext context) {
    final conclusive = prediction.conclusive;
    final risk = _riskStyle(disease.risk);
    final color = conclusive ? risk.color : AppColors.tierra;
    final ranked = prediction.ranked;
    final top = ranked.take(3).toList();

    return SoftCard(
      padding: const EdgeInsets.all(18),
      borderColor: color.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  conclusive ? risk.icon : Icons.help_outline_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        conclusive
                            ? leafLabels[prediction.index]
                            : 'agro.inconclusive',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      disease.pathogen,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Pill(
                label: '${(prediction.confidence * 100).round()}%',
                icon: Icons.insights_rounded,
                color: color,
                background: color.withValues(alpha: 0.12),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                label: context.tr(disease.riskKey),
                icon: risk.icon,
                color: risk.color,
                background: risk.soft,
                compact: true,
              ),
              if (!conclusive)
                Pill(
                  label: context.tr('agro.lowConf'),
                  icon: Icons.info_outline_rounded,
                  color: AppColors.tierra,
                  background: AppColors.secoSoft,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            conclusive
                ? context.tr('agro.confidence', {
                    'pct': (prediction.confidence * 100).toStringAsFixed(1),
                  })
                : context.tr('agro.unclear'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.tr('agro.top'),
            style: AppTypography.kicker.copyWith(
              fontSize: 11,
              color: AppColors.inkFaint,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < top.length; i++) ...[
            _ProbabilityBar(
              label: context.tr(leafLabels[top[i]]),
              value: prediction.probabilities[top[i]],
              highlight: top[i] == prediction.index,
            ),
            if (i < top.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
          DetailsSection(
            title: context.tr('agro.distribution'),
            children: [
              for (var i = 0; i < ranked.length; i++) ...[
                _ProbabilityBar(
                  label: context.tr(leafLabels[ranked[i]]),
                  value: prediction.probabilities[ranked[i]],
                  highlight: ranked[i] == prediction.index,
                ),
                if (i < ranked.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.tr('agro.ran'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(disease.summary, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Bullets(items: items, color: color),
        ],
      ),
    );
  }
}

class _TreatmentCard extends StatelessWidget {
  const _TreatmentCard({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medical_services_rounded,
                size: 18,
                color: AppColors.verdeSecundario,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('agro.treatment'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Pill(
                label: context.tr('agro.actionable'),
                icon: Icons.checklist_rounded,
                color: AppColors.verdePrincipal,
                background: AppColors.buenoSoft,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.verdeSecundario.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: AppColors.verdePrincipal,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            context.tr('agro.treatmentNote'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items, required this.color});

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Icon(Icons.circle, size: 5, color: color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProbabilityBar extends StatelessWidget {
  const _ProbabilityBar({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final double value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.verdeSecundario : AppColors.tecnologia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: SizedBox(
            height: 7,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(color: color.withValues(alpha: 0.1)),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: value.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, animated, child) {
                        return Container(
                          width: constraints.maxWidth * animated,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.5), color],
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      message: context.tr('agro.disclaimer'),
      icon: Icons.science_rounded,
      color: AppColors.tierra,
      background: AppColors.secoSoft,
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  final List<_ScanLog> history;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 18,
                color: AppColors.tecnologia,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('agro.history'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final scan in history.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _riskStyle(cropDiseaseFor(scan.index).risk).icon,
                    size: 16,
                    color: _riskStyle(cropDiseaseFor(scan.index).risk).color,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      context.tr(leafLabels[scan.index]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${(scan.confidence * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    _time(scan.at),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _time(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

class _ScanLog {
  const _ScanLog({
    required this.index,
    required this.confidence,
    required this.at,
  });

  final int index;
  final double confidence;
  final DateTime at;
}

({Color color, Color soft, IconData icon}) _riskStyle(DiseaseRisk risk) {
  switch (risk) {
    case DiseaseRisk.low:
      return (
        color: AppColors.verdeSecundario,
        soft: AppColors.buenoSoft,
        icon: Icons.eco_rounded,
      );
    case DiseaseRisk.medium:
      return (
        color: AppColors.seco,
        soft: AppColors.secoSoft,
        icon: Icons.warning_amber_rounded,
      );
    case DiseaseRisk.high:
      return (
        color: AppColors.alerta,
        soft: AppColors.alertaSoft,
        icon: Icons.coronavirus_rounded,
      );
  }
}
