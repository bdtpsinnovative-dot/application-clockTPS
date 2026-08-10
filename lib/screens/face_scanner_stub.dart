import 'package:flutter/material.dart';

import 'face_scanner_result.dart';

class FaceScannerPage extends StatefulWidget {
  const FaceScannerPage({super.key});

  static FaceScannerResult? mockResult;

  @override
  State<FaceScannerPage> createState() => _FaceScannerPageState();
}

class _FaceScannerPageState extends State<FaceScannerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (FaceScannerPage.mockResult != null) {
          Navigator.of(context).pop(FaceScannerPage.mockResult);
        } else {
          // You could potentially show a dialog here or just return null
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ระบบแสกนใบหน้าไม่รองรับบนเว็บเบราว์เซอร์'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop(null);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'ระบบแสกนใบหน้าไม่รองรับบนเว็บเบราว์เซอร์\nกำลังนำคุณกลับ...',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
