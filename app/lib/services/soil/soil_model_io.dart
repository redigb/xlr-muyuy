import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

class SoilModelRunner {
  static const bool available = true;

  Interpreter? _interpreter;

  Future<void> load() async {
    if (_interpreter != null) return;
    _interpreter = await Interpreter.fromAsset(
      'assets/models/soil_classifier_fp16.tflite',
    );
  }

  Future<List<double>?> run(Float32List input) async {
    final interpreter = _interpreter;
    if (interpreter == null) return null;

    final outputTensor = interpreter.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final output = List<double>.filled(
      outputShape.fold<int>(1, (value, item) => value * item),
      0,
    ).reshape(outputShape);

    interpreter.run(input.buffer.asUint8List(), output);

    final values = <double>[];
    void collect(Object? value) {
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
      } else if (value is num) {
        values.add(value.toDouble());
      }
    }

    collect(output);
    return values;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
