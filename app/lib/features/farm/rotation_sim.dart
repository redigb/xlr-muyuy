import '../../models/models.dart';

/// Simulación simple de 3 años de una rotación en los 3 sectores de la chacra.
///
/// La salud del suelo es una ESTIMACIÓN por tipo de cultivo (no un dato
/// medido): leguminosas y descanso la suben; cultivos exigentes la bajan;
/// repetir familia en el mismo sector la castiga. El clima sí es del paquete NASA.
class RotationSim {
  RotationSim._(this.soil, this.harvests, this.riskMonths);

  static const years = 3;
  static const soilStart = 50.0;

  /// soil[sector][k] = salud al inicio del año k (k = 0..years).
  final List<List<double>> soil;
  final int harvests;
  final int riskMonths;

  /// Cambio medio del suelo al final, en % respecto al inicio.
  double get soilChangePct {
    var total = 0.0;
    for (final s in soil) {
      total += s.last;
    }
    final avg = total / soil.length;
    return (avg - soilStart) / soilStart * 100;
  }

  /// Salud del suelo del sector en el año/mes dados (interpolada en la campaña).
  double soilAt(int sector, int year, num month) {
    final y = year.clamp(0, years - 1);
    final a = soil[sector][y], b = soil[sector][y + 1];
    return a + (b - a) * ((month + 1) / 12).clamp(0, 1);
  }

  static const _legumes = {
    'haba', 'arveja', 'tarwi', 'frijol', 'soya', 'mani', 'caupi', //
    'garbanzo', 'lenteja', 'mucuna',
  };
  static const _heavy = {'papa', 'maiz', 'maiz_duro', 'maiz_amilaceo', 'arroz'};

  /// Efecto de una campaña sobre la salud del suelo (puntos sobre 100).
  static double effect(String crop, Cultivo? c, {String? prevFamily}) {
    if (crop == 'descanso') return 8;
    var e = 0.0;
    if (c?.fijaNitrogeno ?? _legumes.contains(crop)) {
      e += 10;
    } else {
      e -= _heavy.contains(crop) ? 8 : 5;
    }
    if (c?.cobertura ?? false) e += 4;
    if (c?.raizProfunda ?? false) e += 3;
    final fam = c?.familia;
    if (fam != null && fam.isNotEmpty && fam == prevFamily) e -= 6;
    return e;
  }

  static RotationSim run(
    List<String> sequence, {
    Cultivo? Function(String id)? cultivo,
    MesEstado Function(int calendarMonth)? climate,
    int sowMonth = 10,
  }) {
    final crops = [...sequence.take(3)];
    while (crops.length < 3) {
      crops.add('descanso');
    }
    final soil = <List<double>>[];
    var harvests = 0;
    for (var s = 0; s < 3; s++) {
      final values = [soilStart];
      String? prevFamily;
      for (var y = 0; y < years; y++) {
        final crop = crops[(s + y) % 3];
        final c = cultivo?.call(crop);
        final next = values.last + effect(crop, c, prevFamily: prevFamily);
        values.add(next.clamp(0, 100).toDouble());
        prevFamily = c?.familia;
        if (crop != 'descanso') harvests++;
      }
      soil.add(values);
    }

    var risk = 0;
    for (var y = 0; y < years; y++) {
      for (var m = 0; m < 12; m++) {
        final cal = (sowMonth - 1 + m) % 12 + 1;
        final state = climate?.call(cal) ?? MesEstado.bueno;
        if (state == MesEstado.bueno) continue;
        final growing = [for (var s = 0; s < 3; s++) crops[(s + y) % 3]]
            .any((crop) {
              if (crop == 'descanso') return false;
              final cycle = (cultivo?.call(crop)?.cicloMeses ?? 5).clamp(1, 12);
              return m < cycle;
            });
        if (growing) risk++;
      }
    }
    return RotationSim._(soil, harvests, risk);
  }
}
