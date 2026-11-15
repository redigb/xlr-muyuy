import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../l10n/strings.dart';
import 'soil_model_stub.dart' if (dart.library.io) 'soil_model_io.dart';

class SoilVisionException implements Exception {
  const SoilVisionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SoilCheck {
  const SoilCheck({
    required this.id,
    required this.label,
    required this.passed,
    required this.value,
    required this.hint,
  });

  final String id;
  final String label;
  final bool passed;
  final String value;
  final String hint;
}

class SoilQualityResult {
  const SoilQualityResult(this.checks);

  final List<SoilCheck> checks;

  bool get ok => checks.every((item) => item.passed);
}

class SoilPrediction {
  const SoilPrediction({
    required this.index,
    required this.probabilities,
    required this.confidence,
  });

  final int index;
  final List<double> probabilities;
  final double confidence;

  bool get conclusive => confidence >= SoilVisionService.threshold;
  String get label => SoilVisionService.labels[index];
  String get labelEs => SoilVisionService.labelsEs[index];
  String labelIn(AppLang lang) => SoilVisionService.labelFor(index, lang);
}

class SoilAnalysisResult {
  const SoilAnalysisResult({
    required this.quality,
    this.prediction,
    this.message,
  });

  final SoilQualityResult quality;
  final SoilPrediction? prediction;
  final String? message;

  bool get modelAvailable => SoilModelRunner.available;
}

class SoilVisionService {
  static const double threshold = 0.70;
  static const int inputSize = 224;
  static const String modelVersion =
      'soil_classifier_fp16 · MobileNetV3Small · 224×224';

  static const List<String> labels = [
    'Alluvial soil',
    'Black Soil',
    'Clay soil',
    'Red soil',
  ];

  static const List<String> labelsEs = [
    'Suelo aluvial',
    'Suelo negro',
    'Suelo arcilloso',
    'Suelo rojo',
  ];

  static String labelFor(int index, AppLang lang) =>
      lang == AppLang.en ? labels[index] : labelsEs[index];

  final SoilModelRunner _runner = SoilModelRunner();
  bool _loaded = false;

  Future<SoilAnalysisResult> analyze(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const SoilVisionException('soil.msg.unreadable');
    }

    final oriented = img.bakeOrientation(decoded);
    final quality = _evaluateQuality(oriented);
    if (!quality.ok) {
      return SoilAnalysisResult(
        quality: quality,
        message: 'soil.msg.qualityFail',
      );
    }

    if (!SoilModelRunner.available) {
      return SoilAnalysisResult(quality: quality, message: 'soil.msg.webOnly');
    }

    try {
      if (!_loaded) {
        await _runner.load();
        _loaded = true;
      }

      final square = _centerSquare(oriented);
      final resized = img.copyResize(
        square,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.cubic,
      );

      final rawForward = await _runner.run(_toInput(resized));
      if (rawForward == null || rawForward.length != labels.length) {
        return SoilAnalysisResult(
          quality: quality,
          message: 'soil.msg.invalid',
        );
      }

      var probabilities = _normalize(rawForward);

      // Test-time augmentation: average the prediction with a horizontal flip
      // so a single photo is less sensitive to orientation and framing.
      final rawFlipped = await _runner.run(
        _toInput(img.flipHorizontal(resized)),
      );
      if (rawFlipped != null && rawFlipped.length == labels.length) {
        probabilities = _average(probabilities, _normalize(rawFlipped));
      }

      var top = 0;
      for (var i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > probabilities[top]) top = i;
      }

      return SoilAnalysisResult(
        quality: quality,
        prediction: SoilPrediction(
          index: top,
          probabilities: probabilities,
          confidence: probabilities[top],
        ),
      );
    } catch (_) {
      return SoilAnalysisResult(quality: quality, message: 'soil.msg.runFail');
    }
  }

  SoilQualityResult _evaluateQuality(img.Image source) {
    final checks = <SoilCheck>[];
    final minSide = math.min(source.width, source.height);
    checks.add(
      SoilCheck(
        id: 'resolution',
        label: 'soil.check.resolution',
        passed: minSide >= inputSize,
        value: '${source.width}×${source.height} px',
        hint: 'soil.check.resolution.hint',
      ),
    );

    final sample = _downscale(source, 360);
    final width = sample.width;
    final height = sample.height;
    final gray = Float64List(width * height);
    var sumSaturation = 0.0;
    var blown = 0;
    var count = 0;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = sample.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        gray[y * width + x] = 0.299 * r + 0.587 * g + 0.114 * b;

        final maxChannel = math.max(r, math.max(g, b));
        final minChannel = math.min(r, math.min(g, b));
        final saturation = maxChannel == 0
            ? 0.0
            : (maxChannel - minChannel) / maxChannel;
        sumSaturation += saturation;
        if (saturation > 0.98) blown++;
        count++;
      }
    }

    final meanLuminance =
        gray.fold<double>(0, (value, item) => value + item) / gray.length;
    checks.add(
      SoilCheck(
        id: 'light',
        label: 'soil.check.light',
        passed: meanLuminance >= 35 && meanLuminance <= 225,
        value: '${meanLuminance.round()} / 255',
        hint: 'soil.check.light.hint',
      ),
    );

    var lapSum = 0.0;
    var lapSquareSum = 0.0;
    var lapCount = 0;
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final center = gray[y * width + x];
        final left = gray[y * width + x - 1];
        final right = gray[y * width + x + 1];
        final up = gray[(y - 1) * width + x];
        final down = gray[(y + 1) * width + x];
        final laplacian = 4 * center - left - right - up - down;
        lapSum += laplacian;
        lapSquareSum += laplacian * laplacian;
        lapCount++;
      }
    }
    final lapMean = lapCount == 0 ? 0.0 : lapSum / lapCount;
    final variance = lapCount == 0
        ? 0.0
        : (lapSquareSum / lapCount) - (lapMean * lapMean);
    checks.add(
      SoilCheck(
        id: 'focus',
        label: 'soil.check.focus',
        passed: variance >= 30,
        value: variance.round().toString(),
        hint: 'soil.check.focus.hint',
      ),
    );

    final meanSaturation = count == 0 ? 0.0 : sumSaturation / count;
    final blownFraction = count == 0 ? 1.0 : blown / count;
    checks.add(
      SoilCheck(
        id: 'color',
        label: 'soil.check.color',
        passed: meanSaturation >= 0.02 && blownFraction <= 0.20,
        value: '${(meanSaturation * 100).round()}%',
        hint: 'soil.check.color.hint',
      ),
    );

    return SoilQualityResult(checks);
  }

  img.Image _downscale(img.Image source, int maxSide) {
    if (source.width <= maxSide && source.height <= maxSide) return source;
    if (source.width >= source.height) {
      return img.copyResize(
        source,
        width: maxSide,
        interpolation: img.Interpolation.linear,
      );
    }
    return img.copyResize(
      source,
      height: maxSide,
      interpolation: img.Interpolation.linear,
    );
  }

  img.Image _centerSquare(img.Image source) {
    final side = math.min(source.width, source.height);
    final x = ((source.width - side) / 2).round();
    final y = ((source.height - side) / 2).round();
    return img.copyCrop(source, x: x, y: y, width: side, height: side);
  }

  Float32List _toInput(img.Image image) {
    final input = Float32List(inputSize * inputSize * 3);
    var offset = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        input[offset++] = pixel.r.toDouble();
        input[offset++] = pixel.g.toDouble();
        input[offset++] = pixel.b.toDouble();
      }
    }
    return input;
  }

  List<double> _average(List<double> first, List<double> second) {
    final size = math.min(first.length, second.length);
    final result = List<double>.filled(size, 0);
    var sum = 0.0;
    for (var i = 0; i < size; i++) {
      result[i] = (first[i] + second[i]) / 2;
      sum += result[i];
    }
    if (sum <= 0) return result;
    for (var i = 0; i < size; i++) {
      result[i] /= sum;
    }
    return result;
  }

  List<double> _normalize(List<double> values) {
    final sum = values.fold<double>(0, (total, item) => total + item);
    final unitRange = values.every((item) => item >= 0 && item <= 1);
    if (unitRange && (sum - 1).abs() <= 0.2) {
      return values;
    }

    final maxValue = values.reduce(math.max);
    final exps = values
        .map((item) => math.exp(item - maxValue))
        .toList(growable: false);
    final expSum = exps.fold<double>(0, (total, item) => total + item);
    if (expSum == 0) return List<double>.filled(values.length, 0);
    return exps.map((item) => item / expSum).toList(growable: false);
  }

  void dispose() {
    _runner.dispose();
    _loaded = false;
  }
}
