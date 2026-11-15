import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muyuy/features/farm/farm_parcel_view.dart';
import 'package:muyuy/features/farm/farm_screen.dart';
import 'package:muyuy/features/farm/parcel_scene.dart';
import 'package:muyuy/l10n/strings.dart';
import 'package:muyuy/models/models.dart';
import 'package:muyuy/state/app_state.dart';
import 'package:muyuy/widgets/crop_icon.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _crops = [
  'papa',
  'olluco',
  'oca',
  'haba',
  'arveja',
  'tarwi',
  'quinua',
  'cebada',
  'avena_forrajera',
  'trigo',
  'maiz_amilaceo',
  'frijol',
  'maiz_duro',
  'yuca',
  'mucuna',
  'maiz',
  'sorgo',
  'mijo',
  'arroz',
  'soya',
  'mani',
  'caupi',
  'garbanzo',
  'lenteja',
  'camote',
  'girasol',
  'tomate',
  'cebolla',
  'colza',
  'descanso',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('los 30 cultivos tienen ícono propio y se dibujan', () {
    final canvas = Canvas(ui.PictureRecorder());
    for (final id in _crops) {
      CropIconPainter(id).paint(canvas, const Size(48, 48));
    }
    final colors = {for (final id in _crops) cropColor(id).toARGB32()};
    expect(colors.length, greaterThan(25), reason: 'colores distintos');
  });

  test('la escena arma surcos y plantas para todos los tipos de cultivo', () {
    for (var i = 0; i < _crops.length; i += 3) {
      final scene = ParcelScene(
        ParcelSetup(
          sectors: [
            for (var s = 0; s < 3; s++)
              ParcelSector(crop: _crops[(i + s) % _crops.length], growth: 0.9),
          ],
          soil: const Color(0xFF8B6544),
          slope: 0.08,
          climate: MesEstado.values[i % 3],
        ),
      );
      expect(scene.faces.length, greaterThan(800));
      expect(scene.faces.any((f) => f.sector == 2), isTrue);
    }
  });

  testWidgets('la vista 3D funciona sin paquete y cambia de año', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final state = AppState(initialLang: AppLang.en);
    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          state: state,
          child: const Scaffold(
            body: SingleChildScrollView(child: FarmParcelView()),
          ),
        ),
      ),
    );
    expect(find.text('Year 2'), findsOneWidget);
    expect(find.text('Potato'), findsOneWidget);
    await tester.ensureVisible(find.text('Year 2'));
    await tester.tap(find.text('Year 2'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Año 2: el cultivo del sector 1 pasa a ser el del antiguo sector 2.
    expect(find.text('Fava bean'), findsOneWidget);
  });

  testWidgets('Mi chacra muestra las herramientas de hojas y tierra', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final state = AppState(initialLang: AppLang.en);
    await tester.pumpWidget(
      MaterialApp(
        home: AppScope(
          state: state,
          child: Scaffold(body: FarmScreen(onNavigate: (_) {})),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tool-soil')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Check leaves'), findsOneWidget);
    expect(find.text('Analyze soil'), findsOneWidget);
  });
}
