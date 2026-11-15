import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muyuy/services/api_service.dart';
import 'package:muyuy/services/package_repository.dart';
import 'package:muyuy/l10n/strings.dart';
import 'package:muyuy/services/location_service.dart';
import 'package:muyuy/state/app_state.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeLocation extends LocationService {
  _FakeLocation(this.result);
  final LocationResult result;

  @override
  Future<LocationResult> current() async => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> run(LocationIssue issue) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final state = AppState(
      locationService: _FakeLocation(LocationResult.fail(issue)),
      initialLang: AppLang.en,
    );
    await state.useMyLocation();
    return state;
  }

  test('GPS apagado: mensaje claro y vuelve a Huánuco', () async {
    final state = await run(LocationIssue.serviceOff);
    expect(state.locationStatus, LocationStatus.fallback);
    expect(state.notice, contains('location is off'));
  });

  test('sin fix a tiempo: no dice "sin permiso"', () async {
    final state = await run(LocationIssue.timeout);
    expect(state.notice, contains('could not get your location'));
  });

  test('permiso denegado', () async {
    final state = await run(LocationIssue.denied);
    expect(state.notice, contains('No location permission'));
  });

  test('cerca de una zona oficial usa esa zona y su paquete validado', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final selva = File('assets/data/paquete_huanuco-selva.json').readAsBytesSync();
    final api = ApiService(
      client: MockClient((_) async => http.Response.bytes(selva, 200)),
    );
    final state = AppState(
      repository: PackageRepository(api: api),
      locationService: _FakeLocation(
        const LocationResult.ok(LatLon(-9.295, -75.997)),
      ),
      initialLang: AppLang.en,
    );
    await state.useMyLocation();
    expect(state.locationStatus, LocationStatus.done);
    expect(state.zona?.id, 'huanuco-selva');
    expect(state.validadaLocalmente, isTrue);
    expect(state.notice, contains('validated package'));
  });
}
