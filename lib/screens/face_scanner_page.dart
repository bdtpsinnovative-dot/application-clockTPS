import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../services/face_ml_service.dart';

class FaceScannerResult {
  final List<double> faceVector;
  final File imageFile;

  FaceScannerResult({required this.faceVector, required this.imageFile});
}

enum LivenessStep {
  lookStraight,
  turnLeft,
  turnRight,
  captureStraight,
  processing,
  done,
}

class FaceScannerPage extends StatefulWidget {
  const FaceScannerPage({super.key});

  @visibleForTesting
  static FaceScannerResult? mockResult;

  @override
  State<FaceScannerPage> createState() => _FaceScannerPageState();
}

class _FaceScannerPageState extends State<FaceScannerPage> {
  CameraController? _cameraController;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  final FaceMLService _mlService = FaceMLService();

  bool _isProcessingImage = false;
  String? _fatalError;
  LivenessStep _currentStep = LivenessStep.lookStraight;
  String _instruction = 'กรุณามองตรง ให้ใบหน้าอยู่ภายในกรอบ';

  @override
  void initState() {
    super.initState();
    if (FaceScannerPage.mockResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(FaceScannerPage.mockResult);
        }
      });
      return;
    }
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _mlService.init();
      await _initCamera();
    } catch (error) {
      if (!mounted) return;
      setState(() => _fatalError = _friendlyError(error));
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('ไม่พบกล้องในอุปกรณ์');
    }

    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    _cameraController = controller;
    await controller.startImageStream((image) {
      if (!_isProcessingImage &&
          _currentStep != LivenessStep.processing &&
          _currentStep != LivenessStep.done) {
        _isProcessingImage = true;
        unawaited(_processCameraImage(image));
      }
    });
    if (mounted) setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final inputImage = _toInputImage(image);
      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) return;

      if (faces.length != 1) {
        setState(() {
          _instruction = faces.isEmpty
              ? 'ไม่พบใบหน้า กรุณามองกล้อง'
              : 'กรุณาให้มีใบหน้าเพียงคนเดียวในกรอบ';
          _currentStep = LivenessStep.lookStraight;
        });
        return;
      }

      await _checkLiveness(faces.single, image);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _instruction = error.toString().toLowerCase().contains('waiting')
            ? 'กำลังเตรียมระบบตรวจจับใบหน้า กรุณารอสักครู่...'
            : 'อ่านภาพจากกล้องไม่สำเร็จ กรุณาลองใหม่';
      });
    } finally {
      _isProcessingImage = false;
    }
  }

  InputImage _toInputImage(CameraImage image) {
    late Uint8List bytes;
    late InputImageFormat format;

    if (Platform.isAndroid) {
      bytes = _convertYuv420ToNv21(image);
      format = InputImageFormat.nv21;
    } else {
      final buffer = WriteBuffer();
      for (final plane in image.planes) {
        buffer.putUint8List(plane.bytes);
      }
      bytes = buffer.done().buffer.asUint8List();
      format = InputImageFormat.bgra8888;
    }

    final rotation = switch (_cameraController?.description.sensorOrientation ??
        0) {
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => InputImageRotation.rotation0deg,
    };

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final nv21 = Uint8List(width * height + (width * height ~/ 2));

    var outputIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(outputIndex, outputIndex + width, yPlane.bytes, rowStart);
      outputIndex += width;
    }

    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    for (var row = 0; row < height ~/ 2; row++) {
      for (var column = 0; column < width ~/ 2; column++) {
        nv21[outputIndex++] =
            vPlane.bytes[row * vPlane.bytesPerRow + column * vPixelStride];
        nv21[outputIndex++] =
            uPlane.bytes[row * uPlane.bytesPerRow + column * uPixelStride];
      }
    }
    return nv21;
  }

  Future<void> _checkLiveness(Face face, CameraImage cameraImage) async {
    final rotationY = face.headEulerAngleY;
    if (rotationY == null || !mounted) return;

    var capture = false;
    setState(() {
      switch (_currentStep) {
        case LivenessStep.lookStraight:
          if (rotationY.abs() < 10) {
            _currentStep = LivenessStep.turnLeft;
            _instruction = 'ผ่านขั้นที่ 1 กรุณาหันหน้าไปทางซ้ายเล็กน้อย';
          } else {
            _instruction = 'พบใบหน้าแล้ว กรุณามองตรงเข้าหากล้อง';
          }
        case LivenessStep.turnLeft:
          if (rotationY < -20) {
            _currentStep = LivenessStep.turnRight;
            _instruction = 'ผ่านขั้นที่ 2 กรุณาหันหน้าไปทางขวาเล็กน้อย';
          } else {
            _instruction = 'กรุณาหันหน้าไปทางซ้ายช้า ๆ';
          }
        case LivenessStep.turnRight:
          if (rotationY > 20) {
            _currentStep = LivenessStep.captureStraight;
            _instruction = 'ผ่านขั้นที่ 3 กรุณากลับมามองตรงเพื่อบันทึก';
          } else {
            _instruction = 'กรุณาหันหน้าไปทางขวาช้า ๆ';
          }
        case LivenessStep.captureStraight:
          if (rotationY.abs() < 8) {
            _currentStep = LivenessStep.processing;
            _instruction = 'กำลังสร้างข้อมูลใบหน้า...';
            capture = true;
          } else {
            _instruction = 'กรุณากลับมามองตรงเข้าหากล้อง';
          }
        case LivenessStep.processing:
        case LivenessStep.done:
          break;
      }
    });

    if (capture) {
      await _extractAndReturn(cameraImage, face);
    }
  }

  Future<void> _extractAndReturn(CameraImage cameraImage, Face face) async {
    try {
      final controller = _cameraController;
      if (controller?.value.isStreamingImages ?? false) {
        await controller!.stopImageStream();
      }

      final faceImage = _cropFace(cameraImage, face);
      final vector = await _mlService.extractFaceVector(faceImage);
      if (!mounted) return;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/face_scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.parent.create(recursive: true);
      await tempFile.writeAsBytes(img.encodeJpg(faceImage));

      setState(() => _currentStep = LivenessStep.done);
      if (!mounted) return;
      Navigator.of(context).pop(FaceScannerResult(faceVector: vector, imageFile: tempFile));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _currentStep = LivenessStep.lookStraight;
        _instruction = _friendlyError(error);
      });
      await _restartImageStream();
    }
  }

  img.Image _cropFace(CameraImage cameraImage, Face face) {
    var converted = _cameraImageToRgb(cameraImage);
    final sensorOrientation =
        _cameraController?.description.sensorOrientation ?? 0;
    if (sensorOrientation != 0) {
      converted = img.copyRotate(converted, angle: sensorOrientation);
    }

    final box = face.boundingBox;
    final paddingX = box.width * 0.18;
    final paddingY = box.height * 0.18;
    final left = (box.left - paddingX).round().clamp(0, converted.width - 1);
    final top = (box.top - paddingY).round().clamp(0, converted.height - 1);
    final right = (box.right + paddingX).round().clamp(1, converted.width);
    final bottom = (box.bottom + paddingY).round().clamp(1, converted.height);
    final width = right - left;
    final height = bottom - top;

    if (width < 80 || height < 80) {
      throw StateError('ใบหน้าอยู่ไกลเกินไป กรุณาขยับเข้าใกล้กล้อง');
    }
    return img.copyCrop(
      converted,
      x: left,
      y: top,
      width: width,
      height: height,
    );
  }

  img.Image _cameraImageToRgb(CameraImage cameraImage) {
    final output = img.Image(
      width: cameraImage.width,
      height: cameraImage.height,
    );

    if (cameraImage.planes.length == 1) {
      final plane = cameraImage.planes.first;
      for (var y = 0; y < cameraImage.height; y++) {
        for (var x = 0; x < cameraImage.width; x++) {
          final index = y * plane.bytesPerRow + x * 4;
          output.setPixelRgb(
            x,
            y,
            plane.bytes[index + 2],
            plane.bytes[index + 1],
            plane.bytes[index],
          );
        }
      }
      return output;
    }

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var y = 0; y < cameraImage.height; y++) {
      for (var x = 0; x < cameraImage.width; x++) {
        final yValue = yPlane.bytes[y * yPlane.bytesPerRow + x].toDouble();
        final uvX = x ~/ 2;
        final uvY = y ~/ 2;
        final uValue =
            uPlane.bytes[uvY * uPlane.bytesPerRow + uvX * uPixelStride]
                .toDouble() -
            128;
        final vValue =
            vPlane.bytes[uvY * vPlane.bytesPerRow + uvX * vPixelStride]
                .toDouble() -
            128;

        final red = (yValue + 1.402 * vValue).round().clamp(0, 255);
        final green = (yValue - 0.344136 * uValue - 0.714136 * vValue)
            .round()
            .clamp(0, 255);
        final blue = (yValue + 1.772 * uValue).round().clamp(0, 255);
        output.setPixelRgb(x, y, red, green, blue);
      }
    }
    return output;
  }

  Future<void> _restartImageStream() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }
    await controller.startImageStream((image) {
      if (!_isProcessingImage &&
          _currentStep != LivenessStep.processing &&
          _currentStep != LivenessStep.done) {
        _isProcessingImage = true;
        unawaited(_processCameraImage(image));
      }
    });
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '');
    if (message.contains('Unable to load asset')) {
      return 'โหลดโมเดลใบหน้าไม่สำเร็จ กรุณาติดตั้งแอปใหม่';
    }
    return message;
  }

  @override
  void dispose() {
    final controller = _cameraController;
    if (controller?.value.isStreamingImages ?? false) {
      unawaited(controller!.stopImageStream());
    }
    unawaited(controller?.dispose());
    unawaited(_faceDetector.close());
    _mlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _fatalError;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.black54,
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(color: Colors.transparent),
                Align(
                  alignment: const Alignment(0, -0.3),
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 100,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _currentStep == LivenessStep.processing
                        ? 'กำลังบันทึกข้อมูล...'
                        : 'การตรวจสอบใบหน้า',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (_currentStep == LivenessStep.processing)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
