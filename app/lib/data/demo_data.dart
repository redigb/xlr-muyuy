import 'dart:math' as math;

import '../models/models.dart';

class DemoData {
  DemoData._();

  static const List<Zona> zonas = [
    Zona(
      id: 'huanuco-sierra',
      nombre: 'Sierra de Huanuco, Peru',
      lat: -9.90,
      lon: -75.99,
      elevacionM: 3200,
      region: 'sierra',
      cultivosIniciales: ['papa'],
      practicaComun: ['papa', 'papa', 'descanso'],
    ),
    Zona(
      id: 'huanuco-valle',
      nombre: 'Valle del Huallaga, Huanuco, Peru',
      lat: -9.93,
      lon: -76.24,
      elevacionM: 1900,
      region: 'valle',
      cultivosIniciales: ['papa', 'maiz_amilaceo'],
      practicaComun: ['maiz_amilaceo', 'maiz_amilaceo', 'descanso'],
    ),
    Zona(
      id: 'huanuco-selva',
      nombre: 'Selva de Huanuco (Tingo Maria), Peru',
      lat: -9.30,
      lon: -76.00,
      elevacionM: 650,
      region: 'selva',
      cultivosIniciales: ['maiz_duro'],
      practicaComun: ['maiz_duro', 'maiz_duro', 'descanso'],
    ),
    Zona(
      id: 'global-demo',
      nombre: 'Zona demo global',
      lat: -9.90,
      lon: -75.99,
      elevacionM: 3200,
      region: 'global',
      cultivosIniciales: ['papa'],
    ),
  ];

  static Zona? zona(String id) {
    for (final item in zonas) {
      if (item.id == id) return item;
    }
    return null;
  }
}

class Scoring {
  Scoring._();

  static List<Rotacion> ordenar(
    List<Rotacion> rotaciones,
    Set<String> prioridades,
  ) {
    final sorted = List<Rotacion>.of(rotaciones);
    sorted.sort((a, b) {
      final diff = b
          .puntajeFinal(prioridades)
          .compareTo(a.puntajeFinal(prioridades));
      if (diff != 0) return diff;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  static String etiqueta(double score) {
    if (score >= 0.8) return 'Excelente';
    if (score >= 0.68) return 'Muy buena';
    if (score >= 0.56) return 'Buena';
    return 'A considerar';
  }

  static String percent(double value) => '${math.max(0, value * 100).round()}%';
}
