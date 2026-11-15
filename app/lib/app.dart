import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import 'features/shell/app_shell.dart';
import 'features/splash/splash_view.dart';
import 'l10n/strings.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class MuyuyApp extends StatelessWidget {
  const MuyuyApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    // Reconstruye al cambiar de idioma.
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => _buildApp(),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      title: 'MUYUY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      themeMode: ThemeMode.light,
      // Quechua no tiene localización de Material: usa la de español.
      locale: state.lang == AppLang.en
          ? const Locale('en')
          : const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      scrollBehavior: const _AppScrollBehavior(),
      // Sobre el Navigator: rutas, sheets y diálogos también ven AppScope.
      builder: (context, child) => AppScope(state: state, child: child!),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: state.initializing
          ? const SplashView(key: ValueKey('splash'))
          : const AppShell(key: ValueKey('shell')),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}
