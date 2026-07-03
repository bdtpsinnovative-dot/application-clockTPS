import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/app_loading_view.dart';

class PendingApprovalPage extends StatefulWidget {
  const PendingApprovalPage({
    super.key,
    required this.onCheckStatus,
    required this.onSignOut,
  });

  final Future<void> Function() onCheckStatus;
  final Future<void> Function() onSignOut;

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage> {
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    await widget.onCheckStatus();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'กำลังรออนุมัติบัญชี',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ผู้ดูแลระบบต้องเปลี่ยนสถานะบัญชีเป็น active ก่อน จึงจะเข้าสู่หน้าหลักได้\n\nระบบจะตรวจสอบให้อัตโนมัติทุก 10 วินาที',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF637083), height: 1.55),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _checking ? null : _checkStatus,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('ตรวจสอบสถานะตอนนี้'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _checking ? null : widget.onSignOut,
                    child: const Text('ออกจากระบบ'),
                  ),
                ],
              ),
            ),
          ),
          if (_checking)
            const AppLoadingOverlay(message: 'กำลังตรวจสอบสถานะ...'),
        ],
      ),
    );
  }
}
