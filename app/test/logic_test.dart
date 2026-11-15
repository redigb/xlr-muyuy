import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muyuy/l10n/strings.dart';
import 'package:muyuy/models/community.dart';
import 'package:muyuy/models/models.dart';
import 'package:muyuy/services/api_service.dart';
import 'package:muyuy/services/package_repository.dart';
import 'package:muyuy/utils/package_hash.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Cambia la versión dentro de meta (fuera del hash) sin tocar nucleo.
String withVersion(String raw, int version) =>
    raw.replaceFirst(RegExp(r'"version"\s*:\s*\d+'), '"version": $version');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String raw;

  setUpAll(() {
    raw = File('assets/data/paquete_huanuco-sierra.json').readAsStringSync();
  });

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('sobre (fuera del hash)', () {
    test('envolver con sobre conserva el hash', () {
      final wrapped = wrapWithSobre(raw, {
        'compartido_por': 'disp-a',
        'fecha_compartido': '2026-11-15T09:12:00Z',
      });
      final doc = jsonDecode(wrapped) as Map<String, dynamic>;
      expect(doc['sobre']['compartido_por'], 'disp-a');
      final paquete = Paquete.fromJson(doc, rawJson: wrapped);
      expect(paquete.verified, isTrue);
    });

    test('re-envolver reemplaza el sobre anterior', () {
      final first = wrapWithSobre(raw, {'compartido_por': 'disp-a'});
      final second = wrapWithSobre(first, {'compartido_por': 'disp-b'});
      final doc = jsonDecode(second) as Map<String, dynamic>;
      expect(doc['sobre']['compartido_por'], 'disp-b');
      expect(Paquete.fromJson(doc, rawJson: second).verified, isTrue);
    });
  });

  group('importar: gana la más nueva', () {
    test('instala, registra quién lo compartió', () async {
      final repo = PackageRepository();
      final file = wrapWithSobre(withVersion(raw, 50), {'compartido_por': 'disp-a'});
      final result = await repo.importJson(file);
      expect(result.outcome, ImportOutcome.installed);
      expect(result.compartidoPor, 'disp-a');
      expect(result.paquete.packageVersion, 50);
    });

    test('descarta una versión más vieja que la instalada', () async {
      final repo = PackageRepository();
      await repo.importJson(withVersion(raw, 50));
      final result = await repo.importJson(withVersion(raw, 30));
      expect(result.outcome, ImportOutcome.older);
      expect(result.installedVersion, 50);
      final local = await repo.loadLocal('huanuco-sierra');
      expect(local!.paquete.packageVersion, 50);
    });

    test('misma versión y hash = ya la tenía', () async {
      final repo = PackageRepository();
      await repo.importJson(withVersion(raw, 50));
      final result = await repo.importJson(withVersion(raw, 50));
      expect(result.outcome, ImportOutcome.same);
    });

    test('rechaza un paquete sin hash', () async {
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      (doc['paquete']['meta'] as Map).remove('hash');
      expect(
        () => PackageRepository().importJson(jsonEncode(doc)),
        throwsA(
          isA<ImportException>().having((e) => e.code, 'code', 'import.unsigned'),
        ),
      );
    });

    test('rechaza un paquete alterado', () async {
      final altered = raw.replaceFirst('"prob_helada"', '"prob_helada_x"');
      expect(
        () => PackageRepository().importJson(altered),
        throwsA(
          isA<ImportException>().having((e) => e.code, 'code', 'import.tampered'),
        ),
      );
    });

    test('guarda el paquete sin el sobre', () async {
      final repo = PackageRepository();
      await repo.importJson(
        wrapWithSobre(withVersion(raw, 7), {'compartido_por': 'disp-a'}),
      );
      final local = await repo.loadLocal('huanuco-sierra');
      expect(local!.paquete.rawJson, isNot(contains('compartido_por')));
      expect(local.paquete.verified, isTrue);
    });
  });

  group('vigencia por sección', () {
    test('vigente, por vencer y vencido', () {
      const s = SeccionValidez(actualizado: '2026-11-01', validoHasta: '2026-12-01');
      expect(s.estadoEn(DateTime(2026, 11, 5)), ValidityState.fresh);
      expect(s.estadoEn(DateTime(2026, 11, 26)), ValidityState.expiring);
      expect(s.estadoEn(DateTime(2026, 12, 2)), ValidityState.expired);
      expect(const SeccionValidez().estado, ValidityState.unknown);
    });
  });

  group('contrato de sync', () {
    test('observación con zona lleva lat/lon y no celda', () {
      const obs = Observacion(
        idLocal: 'x',
        zonaId: 'huanuco-sierra',
        tipo: 'helada',
        fechaEvento: '2026-06-18',
        demo: false,
        creado: '2026-06-18T07:10:00Z',
        latAprox: -9.9,
        lonAprox: -75.99,
      );
      final json = obs.toJson();
      expect(json['zona_id'], 'huanuco-sierra');
      expect(json['celda'], isNull);
      expect(json['lat_aprox'], -9.9);
    });

    test('observación por celda no manda zona_id', () {
      const obs = Observacion(
        idLocal: 'x',
        zonaId: 'celda_-0.5_36.0',
        celda: '-0.5_36.0',
        tipo: 'sequia',
        fechaEvento: '2026-06-18',
        demo: true,
        creado: '2026-06-18T07:10:00Z',
      );
      expect(obs.toJson()['zona_id'], isNull);
      expect(obs.toJson()['celda'], '-0.5_36.0');
    });

    test('conexión COMPARTIO', () {
      const c = Conexion(
        origen: 'disp-a',
        destino: 'disp-b',
        paquete: 'huanuco-sierra@12',
        fecha: '2026-11-15T09:12:00Z',
        demo: false,
      );
      expect(c.toJson()['tipo'], 'COMPARTIO');
    });

    test('ubicación con riego lo pide al servidor', () async {
      final urls = <Uri>[];
      final api = ApiService(
        baseUrl: 'https://x',
        client: MockClient((req) async {
          urls.add(req.url);
          return http.Response('{}', 200);
        }),
      );
      for (final riego in [false, true]) {
        try {
          await api.fetchCoordenada(lat: 42, lon: -93.5, lang: 'en', riego: riego);
        } on ApiException {
          // '{}' no es un paquete: aquí solo importa la URL.
        }
      }
      expect(urls[0].queryParameters.containsKey('riego'), isFalse);
      expect(urls[1].queryParameters['riego'], 'true');
    });

    test('sync trae estados actuales de mis reportes', () {
      final s = SyncSummary.fromJson({
        'aceptadas': 0,
        'rechazadas': 0,
        'conexiones': 0,
        'detalle': [],
        'estados': [
          {'id_local': 'r1', 'aceptada': true, 'estado': 'validada', 'puntaje': 70},
        ],
      });
      expect(s.estados.single.idLocal, 'r1');
      expect(s.estados.single.estado, 'validada');
      expect(SyncSummary.fromJson({}).estados, isEmpty);
    });
  });

  group('idiomas', () {
    test('cae a español si falta la clave', () {
      expect(tr(AppLang.qu, 'err.format'), tr(AppLang.es, 'err.format'));
      expect(tr(AppLang.en, 'pkg.latest', {'version': 3}), contains('v3'));
    });
  });
}
