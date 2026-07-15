import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_flow_service.dart';

class MainDashboardPage extends StatelessWidget {
  const MainDashboardPage({
    super.key,
    required this.user,
    required this.service,
  });

  final AppUser user;
  final AuthFlowService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('หน้าหลัก (ใหม่)'),
      ),
      body: const Center(
        child: Text(
          'หน้านี้จะเป็นหน้าหลักใหม่ตามที่คุณต้องการครับ\n(รอการออกแบบเพิ่มเติม)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
