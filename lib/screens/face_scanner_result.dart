import 'dart:io';

class FaceScannerResult {
  final List<double> faceVector;
  final File imageFile;

  FaceScannerResult({required this.faceVector, required this.imageFile});
}
