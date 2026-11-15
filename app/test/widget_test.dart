import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:muyuy/data/demo_data.dart';
import 'package:muyuy/models/models.dart';
import 'package:muyuy/utils/package_hash.dart';

void main() {
  late Map<String, dynamic> rawDocument;
  late String rawJsonString;
  late Paquete paquete;

  setUpAll(() {
    final file = File('assets/data/paquete_huanuco-sierra.json');
    rawJsonString = file.readAsStringSync();
    rawDocument = jsonDecode(rawJsonString) as Map<String, dynamic>;
    paquete = Paquete.fromJson(rawDocument, rawJson: rawJsonString);
  });

  group('contrato real de la API', () {
    test('lee el paquete envuelto en meta + nucleo', () {
      expect(paquete.zona.id, 'huanuco-sierra');
      expect(paquete.calendario, hasLength(12));
      // Tamaños según el motor: 6–10 candidatas por cultivo inicial (spec 3.2).
      expect(paquete.cultivos, isNotEmpty);
      expect(paquete.rotaciones.length, greaterThanOrEqualTo(6));
      // v2 = la que publica el servidor (los incluidos son copia exacta).
      expect(paquete.meta.version, greaterThanOrEqualTo(2));
      expect(paquete.packageVersion, paquete.meta.version);
      expect(paquete.meta.validadaLocalmente, isTrue);
      expect(paquete.fuenteClima, isNotEmpty);
    });

    test('verifica el hash canónico del paquete', () {
      expect(paquete.verified, isTrue);
      expect(computePackageHashFromRaw(rawJsonString), paquete.hash);
    });

    test('rechaza un paquete alterado', () {
      final alteredRaw = rawJsonString.replaceFirst(
        '"fuente_clima":"',
        '"fuente_clima":"ALTERADA ',
      );
      expect(alteredRaw, isNot(rawJsonString));
      final altered = Paquete.fromJson(
        jsonDecode(alteredRaw) as Map<String, dynamic>,
        rawJson: alteredRaw,
      );
      expect(altered.verified, isFalse);
    });

    test('detecta la práctica común de la zona', () {
      final common = paquete.rotaciones.firstWhere(
        (rotation) => rotation.esPracticaComun,
      );
      expect(common.secuencia, ['papa', 'papa', 'descanso']);
      expect(common.cultivoInicial, 'papa');
    });

    test('las rotaciones traen cultivo inicial y puntaje total', () {
      for (final rotation in paquete.rotaciones) {
        expect(rotation.cultivoInicial, isNotEmpty);
        expect(rotation.puntajes['total'], isNotNull);
      }
    });

    test('el calendario trae temperaturas mínima y máxima', () {
      final june = paquete.mes(6)!;
      expect(june.tMin, isNotNull);
      expect(june.tMax, isNotNull);
      expect(june.temperaturaLabel, contains('°'));
    });

    test('serializa un paquete sin perder el hash', () {
      final copy = Paquete.fromJson(
        paquete.toJson(),
        rawJson: paquete.toJsonString(),
      );
      expect(copy.verified, isTrue);
      expect(copy.hash, paquete.hash);
      expect(copy.rotaciones, hasLength(paquete.rotaciones.length));
    });

    test('shortPackageHash recorta el hash para la UI', () {
      expect(shortPackageHash(paquete.hash), startsWith('sha256:'));
      expect(
        shortPackageHash(paquete.hash).length,
        lessThan(paquete.hash.length),
      );
    });
  });

  group('puntajeFinal', () {
    const rotacion = Rotacion(
      id: 'test',
      esActual: false,
      cultivoInicial: 'papa',
      secuencia: ['papa', 'haba', 'avena_forrajera'],
      puntajes: {'agua': 0.7, 'suelo': 0.9, 'ingresos': 0.6, 'riesgo': 0.8},
      confianza: {'clima': 'alta'},
      explicacion: 'Texto',
      validarConExperto: 'Confirma',
    );

    test('promedia los cuatro factores sin prioridades', () {
      expect(rotacion.puntajeFinal(const {}), closeTo(0.75, 0.0001));
    });

    test('duplica el peso de las prioridades elegidas', () {
      final score = rotacion.puntajeFinal(const {'agua', 'suelo'});
      expect(score, closeTo(0.7666, 0.0001));
    });

    test('cambiar prioridades cambia el orden', () {
      const otra = Rotacion(
        id: 'otra',
        esActual: false,
        cultivoInicial: 'papa',
        secuencia: ['tarwi', 'papa', 'haba'],
        puntajes: {'agua': 0.9, 'suelo': 0.6, 'ingresos': 0.9, 'riesgo': 0.5},
        confianza: {},
        explicacion: '',
        validarConExperto: '',
      );

      final byWater = Scoring.ordenar(
        const [rotacion, otra],
        const {'agua', 'ingresos'},
      );
      final bySoil = Scoring.ordenar(
        const [rotacion, otra],
        const {'suelo', 'riesgo'},
      );

      expect(byWater.first.id, 'otra');
      expect(bySoil.first.id, 'test');
    });
  });

  group('CalendarioMes', () {
    test('clasifica helada, seco y bueno', () {
      expect(
        const CalendarioMes(
          mes: 6,
          probHelada: 0.7,
          lluviaMm: 0,
          etMm: 90,
          balanceHidricoMm: -90,
          estresCalor: 0,
        ).estado,
        MesEstado.helada,
      );
      expect(
        const CalendarioMes(
          mes: 8,
          probHelada: 0.2,
          lluviaMm: 5,
          etMm: 90,
          balanceHidricoMm: -85,
          estresCalor: 0,
        ).estado,
        MesEstado.seco,
      );
      expect(
        const CalendarioMes(
          mes: 1,
          probHelada: 0.1,
          lluviaMm: 95,
          etMm: 80,
          balanceHidricoMm: 15,
          estresCalor: 0,
        ).estado,
        MesEstado.bueno,
      );
    });
  });
}
