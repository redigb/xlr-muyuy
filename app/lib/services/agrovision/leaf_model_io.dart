import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

List<double> classifyLeaf(Uint8List model, Uint8List photo) {
  const size = 160;
  final decoded = img.decodeImage(photo);
  if (decoded == null) throw const FormatException('Imagen ilegible.');

  final rgb = img
      .copyResize(
        img.bakeOrientation(decoded),
        width: size,
        height: size,
        interpolation: img.Interpolation.linear,
      )
      .convert(format: img.Format.uint8, numChannels: 3);

  // AgroVision recibe RGB 0–255 y aplica el reescalado dentro del modelo.
  final input = Float32List(size * size * 3);
  var offset = 0;
  for (final pixel in rgb) {
    input[offset++] = pixel.r.toDouble();
    input[offset++] = pixel.g.toDouble();
    input[offset++] = pixel.b.toDouble();
  }

  final interpreter = Interpreter.fromBuffer(model);
  try {
    final output = List<double>.filled(10, 0).reshape([1, 10]);
    interpreter.run(input.buffer.asUint8List(), output);

    final scores = List<double>.from(output.single as List);
    final sum = scores.fold(0.0, (total, score) => total + score);
    if (!sum.isFinite || (sum - 1).abs() > 0.01) {
      throw StateError('El modelo devolvió puntuaciones inválidas.');
    }
    return scores;
  } finally {
    interpreter.close();
  }
}
