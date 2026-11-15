import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = true,
    this.gradient = AppColors.gradientFresh,
    this.foreground = AppColors.verdePrincipal,
    this.height = 56,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final Gradient gradient;
  final Color foreground;
  final double height;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final button = AnimatedScale(
      scale: _pressed && _enabled ? 0.975 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _enabled ? 1 : 0.55,
        duration: const Duration(milliseconds: 180),
        child: Container(
          height: widget.height,
          width: widget.expand ? double.infinity : null,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: _enabled ? AppShadows.glow : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _enabled ? widget.onPressed : null,
              onHighlightChanged: (value) {
                if (_pressed != value) setState(() => _pressed = value);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisSize: widget.expand
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.loading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: widget.foreground,
                        ),
                      )
                    else if (widget.icon != null)
                      Icon(widget.icon, size: 20, color: widget.foreground),
                    if (widget.loading || widget.icon != null)
                      const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: 0.1,
                          color: widget.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: button,
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.verdePrincipal,
    this.background = AppColors.buenoSoft,
    this.borderColor,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color background;
  final Color? borderColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderColor ?? background),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 14 : 16, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 12 : 13,
                color: color,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
