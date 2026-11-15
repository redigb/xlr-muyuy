import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.labelKey,
  });

  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
}

const appDestinations = <NavDestination>[
  NavDestination(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    labelKey: 'nav.home',
  ),
  NavDestination(
    icon: Icons.agriculture_outlined,
    activeIcon: Icons.agriculture_rounded,
    labelKey: 'nav.farm',
  ),
  NavDestination(
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month_rounded,
    labelKey: 'nav.calendar',
  ),
  NavDestination(
    icon: Icons.layers_outlined,
    activeIcon: Icons.layers_rounded,
    labelKey: 'nav.options',
  ),
  NavDestination(
    icon: Icons.qr_code_2_outlined,
    activeIcon: Icons.qr_code_2_rounded,
    labelKey: 'nav.share',
  ),
];

class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        bottomInset > 0 ? bottomInset : 12,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.line),
              boxShadow: AppShadows.lifted,
            ),
            child: Row(
              children: [
                for (var i = 0; i < appDestinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      destination: appDestinations[i],
                      selected: i == index,
                      onTap: () => onChanged(i),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: context.tr(destination.labelKey),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          splashColor: AppColors.verdeSecundario.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? AppColors.buenoSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.06 : 1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    selected ? destination.activeIcon : destination.icon,
                    size: 22,
                    color: selected
                        ? AppColors.verdePrincipal
                        : AppColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11.5,
                    letterSpacing: 0,
                    color: selected
                        ? AppColors.verdePrincipal
                        : AppColors.inkFaint,
                    height: 1.1,
                  ),
                  child: Text(
                    context.tr(destination.labelKey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
