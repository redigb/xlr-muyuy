import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'leaf_model_stub.dart' if (dart.library.io) 'leaf_model_io.dart';

/// Claves de traducción de las 10 clases (orden de salida del modelo).
const leafLabels = [
  'agro.leaf.0',
  'agro.leaf.1',
  'agro.leaf.2',
  'agro.leaf.3',
  'agro.leaf.4',
  'agro.leaf.5',
  'agro.leaf.6',
  'agro.leaf.7',
  'agro.leaf.8',
  'agro.leaf.9',
];

/// Debajo de este puntaje la lectura se muestra como no concluyente.
const double leafThreshold = 0.70;

class LeafPrediction {
  const LeafPrediction({required this.index, required this.probabilities});

  final int index;
  final List<double> probabilities;

  double get confidence => probabilities[index];
  bool get conclusive => confidence >= leafThreshold;

  /// Índices ordenados de mayor a menor probabilidad.
  List<int> get ranked {
    final order = List<int>.generate(probabilities.length, (index) => index);
    order.sort((a, b) => probabilities[b].compareTo(probabilities[a]));
    return order;
  }
}

Future<LeafPrediction> analyzeLeaf(Uint8List photo) async {
  final model = await rootBundle.load('model/agrovision_rgb.tflite');
  final scores = await compute(_classify, (
    model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
    photo,
  ));
  var best = 0;
  for (var index = 1; index < scores.length; index++) {
    if (scores[index] > scores[best]) best = index;
  }
  return LeafPrediction(index: best, probabilities: scores);
}

List<double> _classify((Uint8List, Uint8List) request) =>
    classifyLeaf(request.$1, request.$2);
