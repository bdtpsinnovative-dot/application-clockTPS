import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceMLService {
  static const int inputSize = 112;
  static const int embeddingSize = 192;

  Interpreter? _interpreter;

  Future<void> init() async {
    if (_interpreter != null) return;

    final interpreter = await Interpreter.fromAsset(
      'assets/models/mobilefacenet.tflite',
    );

    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    if (!_sameShape(inputShape, const [1, inputSize, inputSize, 3]) ||
        !_sameShape(outputShape, const [1, embeddingSize])) {
      interpreter.close();
      throw StateError(
        'โมเดลใบหน้ามีขนาดไม่ถูกต้อง: input=$inputShape output=$outputShape',
      );
    }

    _interpreter = interpreter;
  }

  Future<List<double>> extractFaceVector(img.Image faceImage) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('โมเดลใบหน้ายังไม่พร้อมใช้งาน');
    }

    final resized = img.copyResize(
      faceImage,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );
    final input = Float32List(inputSize * inputSize * 3);

    var index = 0;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[index++] = (pixel.r.toDouble() - 128.0) / 128.0;
        input[index++] = (pixel.g.toDouble() - 128.0) / 128.0;
        input[index++] = (pixel.b.toDouble() - 128.0) / 128.0;
      }
    }

    final output = [List<double>.filled(embeddingSize, 0)];
    interpreter.run(input.reshape([1, inputSize, inputSize, 3]), output);

    final magnitude = math.sqrt(
      output.first.fold<double>(0, (sum, value) => sum + value * value),
    );
    if (!magnitude.isFinite || magnitude <= 1e-12) {
      throw StateError('โมเดลไม่สามารถสร้างข้อมูลใบหน้าที่ถูกต้องได้');
    }

    return output.first
        .map((value) => value / magnitude)
        .toList(growable: false);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  double compareVectors(List<double> vector1, List<double> vector2) {
    if (vector1.length != vector2.length) return 0.0;
    double dotProduct = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      dotProduct += vector1[i] * vector2[i];
    }
    return dotProduct;
  }

  bool _sameShape(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }
}
