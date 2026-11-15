import 'dart:typed_data';

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

Future<({int index, double score})> analyzeLeaf(Uint8List photo) async {
  final model = await rootBundle.load('model/agrovision_rgb.tflite');
  final scores = await compute(_classify, (
    model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
    photo,
  ));
  var best = 0;
  for (var index = 1; index < scores.length; index++) {
    if (scores[index] > scores[best]) best = index;
  }
  return (index: best, score: scores[best]);
}

List<double> _classify((Uint8List, Uint8List) request) =>
    classifyLeaf(request.$1, request.$2);
