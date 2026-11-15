import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:muyuy/features/farm/farm_parcel_view.dart';
import 'package:muyuy/features/farm/rotation_sim.dart';
import 'package:muyuy/l10n/strings.dart';
import 'package:muyuy/models/models.dart';
import 'package:muyuy/state/app_state.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test(
    'leguminosa y descanso mejoran el suelo; monocultivo de papa lo baja',
    () {
      final good = RotationSim.run(['papa', 'haba', 'descanso']);
      final bad = RotationSim.run(['papa', 'papa', 'papa']);
      expect(good.soilChangePct, greaterThan(0));
      expect(bad.soilChangePct, lessThan(0));
      expect(good.harvests, 6); // 2 cultivos x 3 sectores
      expect(bad.harvests, 9);
    },
  );

  test('cuenta meses de riesgo solo con cultivo creciendo', () {
    final sim = RotationSim.run([
      'descanso',
      'descanso',
      'descanso',
    ], climate: (_) => MesEstado.helada);
    expect(sim.riskMonths, 0);
    final risky = RotationSim.run([
      'papa',
      'haba',
      'oca',
    ], climate: (_) => MesEstado.helada);
    expect(risky.riskMonths, 3 * 5); // ciclo por defecto 5 meses x 3 años
  });

  test('la salud se interpola dentro de la campaña', () {
    final sim = RotationSim.run(['haba', 'haba', 'haba']);
    expect(sim.soilAt(0, 0, 0), lessThan(sim.soilAt(0, 0, 11)));
    expect(sim.soilAt(0, 0, 11), closeTo(sim.soil[0][1], 0.001));
  });

  testWidgets('▶ recorre 3 años y muestra el resumen', (tester) async {
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
    expect(find.text('Start 3-year simulation'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('sim-play')));
    await tester.tap(find.byKey(const ValueKey('sim-play')));
    await tester.pump();
    expect(find.byKey(const ValueKey('sim-summary')), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Pause simulation'), findsOneWidget); // aún corre
    await tester.pump(const Duration(seconds: 35));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('sim-summary')), findsOneWidget);
    expect(find.textContaining('harvests'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
