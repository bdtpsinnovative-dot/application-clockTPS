import 'package:image/image.dart' as img;

class FaceMLService {
  Future<void> init() async {
    // Stub implementation for Web
  }

  Future<List<double>> extractFaceVector(img.Image faceImage) async {
    throw UnsupportedError('Face ML is not supported on this platform');
  }

  double compareVectors(List<double> vector1, List<double> vector2) {
    return 0.0;
  }

  void dispose() {
    // Stub implementation for Web
  }
}
