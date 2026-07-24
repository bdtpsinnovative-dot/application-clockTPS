import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

void main() async {
  final result = await FlutterImageCompress.compressAndGetFile(
    'path',
    'target',
    format: CompressFormat.webp,
  );
  if (result != null) {
    File f = File(result.path);
  }
}
