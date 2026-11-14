import 'package:flutter_test/flutter_test.dart';
import 'package:muyuy/data/soil_profiles.dart';
import 'package:muyuy/models/models.dart';
import 'package:muyuy/models/soil_analysis.dart';

Paquete _paquete() {
  return Paquete(
    meta: PaqueteMeta(
      formato: 2,
      origen: 'test',
      zonaId: 'huanuco-sierra',
      celda: '',
      validadaLocalmente: true,
      idioma: 'es',
      version: 1,
      generado: '',
      hash: '',
      secciones: const <String, SeccionValidez>{},
      extras: const <String>[],
    ),
    zona: const Zona(
      id: 'huanuco-sierra',
      nombre: 'Sierra',
      lat: -9.9,
      lon: -75.9,
    ),
    fuenteClima: '',
    inicioSiembraMes: 9,
    calendario: const [],
    cultivos: const [
      Cultivo(
        id: 'papa',
        nombre: 'Papa',
        familia: 'Solanaceae',
        fijaNitrogeno: false,
        toleraHelada: 'baja',
        agua: 'media',
        cicloMeses: 5,
      ),
      Cultivo(
        id: 'avena',
        nombre: 'Avena',
        familia: 'Poaceae',
        fijaNitrogeno: false,
        toleraHelada: 'alta',
        agua: 'baja',
        cicloMeses: 4,
        cobertura: true,
        raizProfunda: true,
      ),
      Cultivo(
        id: 'haba',
        nombre: 'Haba',
        familia: 'Fabaceae',
        fijaNitrogeno: true,
        toleraHelada: 'media',
        agua: 'media',
        cicloMeses: 6,
      ),
    ],
    rotaciones: const [],
  );
}

void main() {
  group('soilProfileFor', () {
    test('devuelve el perfil correcto por índice', () {
      expect(soilProfileFor(0).key, 'aluvial');
      expect(soilProfileFor(1).key, 'negro');
      expect(soilProfileFor(2).key, 'arcilloso');
      expect(soilProfileFor(3).key, 'rojo');
    });

    test('un índice fuera de rango cae al primer perfil', () {
      expect(soilProfileFor(-1).index, 0);
      expect(soilProfileFor(99).index, 0);
    });
  });

  group('soilAffinity', () {
    const withCover = Rotacion(
      id: 'cover',
      esActual: false,
      secuencia: ['avena'],
      puntajes: {'suelo': 0.6},
      confianza: {},
      explicacion: '',
      validarConExperto: '',
    );
    const withoutCover = Rotacion(
      id: 'papa',
      esActual: false,
      secuencia: ['papa'],
      puntajes: {'suelo': 0.6},
      confianza: {},
      explicacion: '',
      validarConExperto: '',
    );
    const legume = Rotacion(
      id: 'legume',
      esActual: false,
      secuencia: ['haba'],
      puntajes: {'suelo': 0.6},
      confianza: {},
      explicacion: '',
      validarConExperto: '',
    );

    test('en arcilloso prefiere cobertura y raíz profunda', () {
      final paquete = _paquete();
      final clay = soilProfileFor(2);
      expect(
        soilAffinity(clay, withCover, paquete),
        greaterThan(soilAffinity(clay, withoutCover, paquete)),
      );
    });

    test('en suelo negro valora las leguminosas', () {
      final paquete = _paquete();
      final black = soilProfileFor(1);
      expect(
        soilAffinity(black, legume, paquete),
        greaterThan(soilAffinity(black, withoutCover, paquete)),
      );
    });

    test('la afinidad se queda dentro de 0 y 1', () {
      final paquete = _paquete();
      final value = soilAffinity(soilProfileFor(2), withCover, paquete);
      expect(value, inInclusiveRange(0.0, 1.0));
    });

    test('la nota menciona el tipo de suelo', () {
      final note = soilRotationNote(soilProfileFor(2), withCover, _paquete());
      expect(note, contains('Afinidad'));
      expect(note, contains('arcilloso'));
    });
  });

  group('SoilRecord', () {
    const record = SoilRecord(
      zonaId: 'huanuco-sierra',
      predictedIndex: 2,
      confidence: 0.81,
      createdAt: '2026-11-14T12:00:00Z',
    );

    test('roundtrip de serialización', () {
      final back = SoilRecord.fromJson(record.toJson());
      expect(back.zonaId, 'huanuco-sierra');
      expect(back.predictedIndex, 2);
      expect(back.confidence, closeTo(0.81, 0.0001));
      expect(back.createdAt, '2026-11-14T12:00:00Z');
      expect(back.corrected, isFalse);
      expect(back.effectiveIndex, 2);
    });

    test('la corrección cambia el índice efectivo', () {
      final corrected = record.withCorrection(1);
      expect(corrected.corrected, isTrue);
      expect(corrected.correctedIndex, 1);
      expect(corrected.effectiveIndex, 1);
      expect(corrected.predictedIndex, 2);

      final back = SoilRecord.fromJson(corrected.toJson());
      expect(back.correctedIndex, 1);
      expect(back.effectiveIndex, 1);
    });
  });
}
