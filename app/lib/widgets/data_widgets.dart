import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'crop_icon.dart';

class ScoreBar extends StatelessWidget {
  const ScoreBar({
    super.key,
    required this.factor,
    required this.value,
    this.showIcon = true,
    this.compact = false,
  });

  final String factor;
  final double value;
  final bool showIcon;
  final bool compact;

  IconData get _icon {
    switch (factor) {
      case 'agua':
        return Icons.water_drop_rounded;
      case 'suelo':
        return Icons.landscape_rounded;
      case 'ingresos':
        return Icons.payments_rounded;
      case 'riesgo':
        return Icons.shield_rounded;
      default:
        return Icons.insights_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.factor(factor);
    final label = factorLabel(context, factor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showIcon) ...[
              Icon(_icon, size: compact ? 13 : 15, color: color),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 12.5 : 13.5,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: value.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animated, child) {
                return Text(
                  '${(animated * 100).round()}%',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12.5 : 13.5,
                    color: color,
                  ),
                );
              },
            ),
          ],
        ),
        SizedBox(height: compact ? 5 : 7),
        LayoutBuilder(
          builder: (context, constraints) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: SizedBox(
                height: compact ? 6 : 8,
                child: Stack(
                  children: [
                    Container(color: color.withValues(alpha: 0.12)),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: value.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, animated, child) {
                        return Container(
                          width: constraints.maxWidth * animated,
                          height: compact ? 6 : 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.55), color],
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class ConfidenceChip extends StatelessWidget {
  const ConfidenceChip({super.key, required this.factor, required this.level});

  final String factor;
  final String level;

  String _label(BuildContext context) {
    final text = context.tr('confk.$factor');
    return text == 'confk.$factor' ? factor : text;
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.confianza(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '${_label(context)} · ${confidenceLabel(context, level)}',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class CropChip extends StatelessWidget {
  const CropChip({super.key, required this.id, this.compact = false});

  final String id;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.fondoSuave,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CropIcon(id, size: compact ? 16 : 20),
          const SizedBox(width: 4),
          Text(
            cropName(context, id),
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 13,
              color: AppColors.verdePrincipal,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class CropSequence extends StatelessWidget {
  const CropSequence({super.key, required this.sequence, this.compact = false});

  final List<String> sequence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < sequence.length; i++) {
      children.add(CropChip(id: sequence[i], compact: compact));
      if (i < sequence.length - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: compact ? 12 : 14,
              color: AppColors.inkFaint,
            ),
          ),
        );
      }
    }
    return Wrap(
      spacing: 2,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
