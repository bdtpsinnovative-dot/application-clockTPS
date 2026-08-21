import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    required this.onImagePicked,
    required this.onError,
    this.initialImageUrl,
  });

  final void Function(File image) onImagePicked;
  final void Function(String message) onError;
  final String? initialImageUrl;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  File? _image;
  bool _processing = false;

  bool get _hasNetworkImage {
    final value = widget.initialImageUrl;
    return value?.startsWith('https://') == true ||
        value?.startsWith('http://') == true;
  }

  Future<void> _showPickerBottomSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'เลือกรูปภาพโปรไฟล์',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  context,
                  icon: Icons.camera_alt_rounded,
                  label: 'ถ่ายรูป',
                  source: ImageSource.camera,
                ),
                _buildSourceOption(
                  context,
                  icon: Icons.photo_library_rounded,
                  label: 'แกลลอรี่',
                  source: ImageSource.gallery,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );

  if (source != null) {
    await _pickImage(source);
  }
  }

  Widget _buildSourceOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(source),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E9F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: const Color(0xFF2563EB)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    setState(() => _processing = true);

    try {
      // Crop 1:1
      final cropper = ImageCropper();
      final cropped = await cropper.cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ปรับรูปโปรไฟล์',
            toolbarColor: const Color(0xFF0EB7A8),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'ปรับรูปโปรไฟล์',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (cropped == null) {
        setState(() => _processing = false);
        return;
      }

      // Compress and convert to WebP
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.webp';

      final result = await FlutterImageCompress.compressAndGetFile(
        cropped.path,
        targetPath,
        format: CompressFormat.webp,
        quality: 80,
      );

      if (result != null) {
        final file = File(result.path);
        setState(() {
          _image = file;
          _processing = false;
        });
        widget.onImagePicked(file);
      } else {
        setState(() => _processing = false);
      }
    } catch (error) {
      if (mounted) setState(() => _processing = false);
      widget.onError('เปิดหน้าปรับรูปไม่สำเร็จ กรุณาลองเลือกรูปใหม่');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE4E9F0), width: 2),
              image: _image != null
                  ? DecorationImage(
                      image: FileImage(_image!),
                      fit: BoxFit.cover,
                    )
                  : _hasNetworkImage
                  ? DecorationImage(
                      image: NetworkImage(widget.initialImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _image == null && !_hasNetworkImage
                ? const Icon(
                    Icons.person_outline_rounded,
                    size: 60,
                    color: Color(0xFF94A3B8),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                onTap: _processing ? null : _showPickerBottomSheet,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
