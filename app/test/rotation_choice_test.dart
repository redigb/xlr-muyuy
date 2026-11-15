import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muyuy/l10n/strings.dart';
import 'package:muyuy/services/api_service.dart';
import 'package:muyuy/services/location_service.dart';
import 'package:muyuy/services/package_repository.dart';
import 'package:muyuy/state/app_state.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeLocation extends LocationService {
  @override
  Future<LocationResult> current() async =>
      const LocationResult.ok(LatLon(-9.295, -75.997));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> open() async {
    final selva = File('assets/data/paquete_huanuco-selva.json')
        .readAsBytesSync();
    final api = ApiService(
      client: MockClient((_) async => http.Response.bytes(selva, 200)),
    );
    final state = AppState(
      repository: PackageRepository(api: api),
      locationService: _FakeLocation(),
      initialLang: AppLang.en,
    );
    await state.useMyLocation();
    return state;
  }

  test(
    'sin elegir: muestra la mejor y no está marcada por el usuario',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final state = await open();
      expect(state.rotacionesTodas, isNotEmpty);
      expect(state.rotacionElegidaPorUsuario, isFalse);
      expect(state.rotacionElegida?.id, state.rotacionesTodas.first.id);
    },
  );

  test('elegir una rotación se guarda por zona y vuelve al reabrir', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final state = await open();
    final target = state.rotacionesTodas.last;
    state.elegirRotacion(target.id);
    expect(state.rotacionElegidaPorUsuario, isTrue);
    expect(state.rotacionElegida?.id, target.id);
    await Future<void>.delayed(Duration.zero);

    final again = await open(); // mismo almacenamiento en memoria
    expect(again.rotacionElegidaPorUsuario, isTrue);
    expect(again.rotacionElegida?.id, target.id);
  });

  test(
    'si cambia el cultivo y ya no aplica, vuelve a la mejor y avisa',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final state = await open();
      final target = state.rotacionesTodas.last;
      state.elegirRotacion(target.id);
      final other = state.paquete!.cultivos
          .map((c) => c.id)
          .firstWhere((id) => id != state.cultivoInicial, orElse: () => '');
      if (other.isEmpty) return;
      state.setCultivoInicial(other);
      if (state.rotacionesTodas.any((r) => r.id == target.id)) return;
      expect(state.rotacionElegidaPorUsuario, isFalse);
      expect(state.notice, contains('no longer fits'));
    },
  );
}
