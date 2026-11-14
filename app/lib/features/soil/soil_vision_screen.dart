import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/soil_profiles.dart';
import '../../models/soil_analysis.dart';
import '../../services/soil/soil_vision_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/soft_card.dart';

class SoilVisionScreen extends StatefulWidget {
  const SoilVisionScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SoilVisionScreen> createState() => _SoilVisionScreenState();
}

class _SoilVisionScreenState extends State<SoilVisionScreen> {
  final SoilVisionService _service = SoilVisionService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _bytes;
  SoilAnalysisResult? _result;
  String? _error;
  bool _busy = false;
  int? _correctedIndex;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 92,
      );
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _result = null;
        _correctedIndex = null;
      });

      await Future<void>.delayed(const Duration(milliseconds: 120));
      final result = await _service.analyze(bytes);
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
      await _remember(result);
    } on SoilVisionException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo usar la cámara o leer la foto. Intenta de nuevo.';
        _busy = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _bytes = null;
      _result = null;
      _error = null;
      _busy = false;
      _correctedIndex = null;
    });
  }

  Future<void> _remember(SoilAnalysisResult result) async {
    final prediction = result.prediction;
    final zona = widget.state.zona;
    if (prediction == null || zona == null) return;
    await widget.state.saveSoilAnalysis(
      SoilRecord(
        zonaId: zona.id,
        predictedIndex: prediction.index,
        confidence: prediction.confidence,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<void> _correct(int index) async {
    if (_result?.prediction == null) return;
    setState(() => _correctedIndex = index);
    await widget.state.correctSoil(index);
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.state.zona;

    return Scaffold(
      backgroundColor: AppColors.fondoSuave,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.gradientSoft),
        child: PageBody(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SoilVision AI',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        zone == null
                            ? 'Lectura visual del suelo'
                            : prettyZoneName(zone.nombre),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Pill(
                  label: kIsWeb ? 'Vista web' : 'TFLite local',
                  icon: Icons.memory_rounded,
                  color: AppColors.tecnologia,
                  background: AppColors.heladaSoft,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _SoilHero(),
            const SizedBox(height: 16),
            _PhotoCard(
              bytes: _bytes,
              busy: _busy,
              hasResult: _result != null,
              onCamera: () => _pick(ImageSource.camera),
              onGallery: () => _pick(ImageSource.gallery),
              onReset: _reset,
            ),
            if (_busy) ...[const SizedBox(height: 12), const _AnalyzingCard()],
            if (_error != null) ...[
              const SizedBox(height: 12),
              InfoBanner(
                message: _error!,
                icon: Icons.error_outline_rounded,
                color: AppColors.alerta,
                background: AppColors.alertaSoft,
                onClose: () => setState(() => _error = null),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _QualityCard(result: _result!),
              if (_result!.prediction != null) ...[
                const SizedBox(height: 12),
                _PredictionCard(prediction: _result!.prediction!),
                const SizedBox(height: 12),
                _AgronomyAdviceCard(
                  profile: soilProfileFor(_result!.prediction!.index),
                ),
                const SizedBox(height: 12),
                _CorrectionCard(
                  prediction: _result!.prediction!,
                  correctedIndex: _correctedIndex,
                  onSelect: _correct,
                ),
              ] else if (_result!.message != null) ...[
                const SizedBox(height: 12),
                InfoBanner(
                  message: _result!.message!,
                  icon: Icons.info_outline_rounded,
                  color: AppColors.tecnologia,
                  background: AppColors.heladaSoft,
                ),
              ],
              const SizedBox(height: 12),
              const _DisclaimerCard(),
              const SizedBox(height: 12),
              const _MeaningCard(),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Analizar otra foto',
                icon: Icons.camera_alt_rounded,
                onPressed: _reset,
              ),
            ],
            const SizedBox(height: 14),
            const InfoBanner(
              message:
                  'Modelo fp16 no validado en suelos de Huánuco. '
                  'Úsalo como apoyo visual, no como diagnóstico agronómico.',
              icon: Icons.science_rounded,
              color: AppColors.tierra,
              background: AppColors.secoSoft,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                SoilVisionService.modelVersion,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoilHero extends StatelessWidget {
  const _SoilHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F3D23), Color(0xFF14532D), Color(0xFF1B6B3A)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Opacity(
              opacity: 0.12,
              child: Icon(
                Icons.center_focus_strong_rounded,
                size: 120,
                color: AppColors.acentoNatural.withValues(alpha: 0.8),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 19,
                      color: AppColors.acentoNatural,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SOILVISION AI',
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Mira tu suelo.\nEntiende su apariencia.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.white,
                  fontSize: 26,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Clasifica color y textura con una foto. '
                'No mide pH, NPK ni fertilidad.',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppColors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: const [
                  _HeroChip(label: '4 clases'),
                  _HeroChip(label: '224 × 224'),
                  _HeroChip(label: '100% en el teléfono'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontWeight: FontWeight.w600,
          fontSize: 9.5,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.bytes,
    required this.busy,
    required this.hasResult,
    required this.onCamera,
    required this.onGallery,
    required this.onReset,
  });

  final Uint8List? bytes;
  final bool busy;
  final bool hasResult;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Foto del suelo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              const Pill(
                label: 'Enfoca la tierra',
                icon: Icons.center_focus_weak_rounded,
                color: AppColors.inkSoft,
                background: AppColors.fondoSuave,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 250,
              width: double.infinity,
              color: AppColors.fondoSuave,
              child: bytes == null
                  ? _EmptyPhoto(onCamera: onCamera, onGallery: onGallery)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          bytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          cacheWidth: 900,
                        ),
                        if (busy)
                          Container(
                            color: AppColors.verdePrincipal.withValues(
                              alpha: 0.72,
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Analizando en el teléfono…',
                                    style: TextStyle(
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
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: busy ? null : onReset,
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: AppColors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Quitar',
                                      style: TextStyle(
                                        fontFamily: AppFonts.body,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
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
          const SizedBox(height: 12),
          if (bytes == null)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onCamera,
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onCamera,
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: const Text('Repetir'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Elegir otra'),
                  ),
                ),
              ],
            ),
          if (!hasResult && bytes == null) ...[
            const SizedBox(height: 10),
            Text(
              'Toma la foto a 30–50 cm de la tierra, con luz natural y sin '
              'sombras fuertes. Evita incluir paredes, zapatos o plantas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          child: const Icon(
            Icons.landscape_rounded,
            size: 27,
            color: AppColors.verdeSecundario,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Una foto clara de tu suelo',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 3),
        Text(
          'El modelo mira color y textura.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AnalyzingCard extends StatelessWidget {
  const _AnalyzingCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Revisando calidad y ejecutando el modelo local…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.result});

  final SoilAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final quality = result.quality;
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rule_rounded,
                size: 18,
                color: AppColors.tecnologia,
              ),
              const SizedBox(width: 8),
              Text(
                'Calidad de la foto',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Pill(
                label: quality.ok ? 'Apta' : 'Repetir',
                icon: quality.ok
                    ? Icons.check_circle_rounded
                    : Icons.refresh_rounded,
                color: quality.ok ? AppColors.verdePrincipal : AppColors.tierra,
                background: quality.ok
                    ? AppColors.buenoSoft
                    : AppColors.secoSoft,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final check in quality.checks) ...[
            _CheckRow(check: check),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final SoilCheck check;

  IconData get _icon {
    switch (check.id) {
      case 'resolution':
        return Icons.photo_size_select_large_rounded;
      case 'light':
        return Icons.wb_sunny_rounded;
      case 'focus':
        return Icons.center_focus_strong_rounded;
      default:
        return Icons.palette_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = check.passed ? AppColors.verdeSecundario : AppColors.tierra;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          check.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
          size: 17,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, size: 13, color: AppColors.inkFaint),
                  const SizedBox(width: 5),
                  Text(
                    check.label,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    check.value,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontWeight: FontWeight.w500,
                      fontSize: 10.5,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (!check.passed) ...[
                const SizedBox(height: 2),
                Text(check.hint, style: Theme.of(context).textTheme.labelSmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction});

  final SoilPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final conclusive = prediction.conclusive;
    final color = conclusive ? AppColors.verdeSecundario : AppColors.tierra;

    return SoftCard(
      padding: const EdgeInsets.all(18),
      borderColor: color.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  conclusive
                      ? Icons.landscape_rounded
                      : Icons.help_outline_rounded,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conclusive ? prediction.labelEs : 'No concluyente',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      conclusive ? prediction.label : 'Confianza menor al 70%',
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
          const SizedBox(height: 12),
          Text(
            conclusive
                ? 'La foto se parece a esta categoría visual del dataset. '
                      'No es una medición de fertilidad.'
                : 'La foto no es suficientemente clara para una lectura '
                      'segura. Repite con más luz y enfoque.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < prediction.probabilities.length; i++) ...[
            _ProbabilityBar(
              label: SoilVisionService.labelsEs[i],
              value: prediction.probabilities[i],
              highlight: i == prediction.index,
            ),
            if (i < prediction.probabilities.length - 1)
              const SizedBox(height: 9),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.memory_rounded,
                size: 14,
                color: AppColors.inkFaint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ejecutado en el teléfono · fp16 · 224×224',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgronomyAdviceCard extends StatelessWidget {
  const _AgronomyAdviceCard({required this.profile});

  final SoilProfile profile;

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
                Icons.eco_rounded,
                size: 18,
                color: AppColors.verdeSecundario,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Qué significa para tu chacra',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Pill(
                label: profile.label,
                icon: Icons.landscape_rounded,
                color: AppColors.tierra,
                background: AppColors.secoSoft,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(profile.summary, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          _AdviceBlock(
            title: 'A favor',
            items: profile.strengths,
            color: AppColors.verdeSecundario,
          ),
          const SizedBox(height: 10),
          _AdviceBlock(
            title: 'Cuidados',
            items: profile.cautions,
            color: AppColors.tierra,
          ),
          const SizedBox(height: 10),
          _AdviceBlock(
            title: 'Consejos',
            items: profile.tips,
            color: AppColors.tecnologia,
          ),
          const SizedBox(height: 10),
          Text(
            'Consejos según la apariencia del suelo, no una medición de '
            'fertilidad. Confirma con un experto local.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _AdviceBlock extends StatelessWidget {
  const _AdviceBlock({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTypography.kicker.copyWith(fontSize: 9.5, color: color),
        ),
        const SizedBox(height: 6),
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
                const SizedBox(width: 8),
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

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({
    required this.prediction,
    required this.correctedIndex,
    required this.onSelect,
  });

  final SoilPrediction prediction;
  final int? correctedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final chosen = correctedIndex;
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: AppColors.tecnologia,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¿Coincide con tu suelo?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            chosen == null
                ? 'Elige la clase real. Ayuda a mejorar el modelo para Huánuco.'
                : '¡Gracias! Guardamos tu respuesta y la enviamos a la '
                      'comunidad.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < SoilVisionService.labelsEs.length; i++)
                _CorrectionChip(
                  label: SoilVisionService.labelsEs[i],
                  selected: chosen == i,
                  suggested: chosen == null && prediction.index == i,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CorrectionChip extends StatelessWidget {
  const _CorrectionChip({
    required this.label,
    required this.selected,
    required this.suggested,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.verdePrincipal : AppColors.inkSoft;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.buenoSoft : AppColors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? AppColors.verdeSecundario : AppColors.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.verdeSecundario,
                  ),
                )
              else if (suggested)
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: AppColors.verdeSecundario,
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
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
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11.5,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
                      tween: Tween<double>(end: value),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, animated, child) {
                        return Container(
                          width: constraints.maxWidth * animated,
                          decoration: BoxDecoration(
                            color: color,
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

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secoSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.tierra.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 19,
            color: AppColors.tierra,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Esto describe apariencia visual. No mide pH, fósforo, potasio, '
              'materia orgánica ni fertilidad. No cambia automáticamente tus '
              'rotaciones. Confirma siempre con un experto local.',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.tierra,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeaningCard extends StatelessWidget {
  const _MeaningCard();

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
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: AppColors.verdeSecundario,
              ),
              const SizedBox(width: 8),
              Text(
                '¿Para qué sirve?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _Bullet(
            text: 'Tamiza fotos oscuras, borrosas o con poco suelo visible.',
          ),
          const _Bullet(
            text: 'Apoyo educativo para reconocer apariencias del suelo.',
          ),
          const _Bullet(
            text: 'Para decidir siembra, usa el calendario y las rotaciones.',
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 5,
              color: AppColors.verdeSecundario,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
