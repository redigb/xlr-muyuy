import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Solo vertical: la UI está diseñada para teléfono en vertical.
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );
  final state = AppState();
  runApp(MuyuyApp(state: state));
  unawaited(state.initialize());
}
