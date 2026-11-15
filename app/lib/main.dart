import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'features/splash/splash_view.dart';
import 'state/app_state.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // El splash nativo (verde + logo) sigue en pantalla hasta que el splash de
  // Flutter tenga su logo listo: sin cuadro verde vacío ni logo que "salta".
  binding.deferFirstFrame();
  SplashView.firstFrameDeferred = true;
  final state = AppState();
  runApp(MuyuyApp(state: state));
  unawaited(state.initialize());
}
