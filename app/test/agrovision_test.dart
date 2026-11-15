import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muyuy/features/agrovision/agrovision_screen.dart';
import 'package:muyuy/l10n/strings.dart';
import 'package:muyuy/state/app_state.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AgroVision muestra el encabezado y la guía de la foto', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState(initialLang: AppLang.es);
    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(state: state, child: const AgroVisionScreen()),
      ),
    );

    expect(find.text('AgroVision AI'), findsOneWidget);
    expect(find.text('Foto de la hoja'), findsOneWidget);
    expect(find.text('Una hoja clara y enfocada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
