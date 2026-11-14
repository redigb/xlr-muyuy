import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(MuyuyApp(state: state));
  unawaited(state.initialize());
}
