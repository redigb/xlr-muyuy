import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'leaf_model_stub.dart' if (dart.library.io) 'leaf_model_io.dart';

const leafLabels = [
  'Mancha bacteriana',
  'Tizón temprano',
  'Tizón tardío',
  'Moho de la hoja',
  'Mancha foliar por septoria',
  'Araña roja de dos manchas',
  'Mancha diana',
  'Virus del rizado amarillo del tomate',
  'Virus del mosaico del tomate',
  'Hoja sana',
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
