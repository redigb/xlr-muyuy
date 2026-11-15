import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../calendar/calendar_screen.dart';
import '../farm/farm_screen.dart';
import '../home/home_screen.dart';
import '../options/options_screen.dart';
import '../share/share_screen.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_nav_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late PageController _controller;
  int _index = 0;

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Con una rotación elegida, la app abre directo en Finca (su chacra 3D).
    if (AppScope.of(context).rotacionElegidaPorUsuario) {
      _index = 1;
      _controller.dispose();
      _controller = PageController(initialPage: 1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.fondoSuave,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.fondoSuave,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.gradientSoft),
          child: PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              HomeScreen(onNavigate: _goTo),
              FarmScreen(onNavigate: _goTo),
              CalendarScreen(onNavigate: _goTo),
              OptionsScreen(onNavigate: _goTo),
              ShareScreen(onNavigate: _goTo),
            ],
          ),
        ),
        bottomNavigationBar: AppNavBar(index: _index, onChanged: _goTo),
      ),
    );
  }
}
