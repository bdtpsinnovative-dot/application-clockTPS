import 'package:flutter/material.dart';
import '../widgets/work_ui.dart';
import 'edit_user_info_page.dart';
import 'change_password_page.dart';
import '../services/auth_flow_service.dart';
import '../models/app_user.dart';

class PrivacySettingsPage extends StatelessWidget {
  final AuthFlowService service;
  final AppUser user;
  final VoidCallback onProfileUpdated;

  const PrivacySettingsPage({
    super.key,
    required this.service,
    required this.user,
    required this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: const Text(
          'ความเป็นส่วนตัว',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: workBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _PrivacyActionTile(
            icon: Icons.person_outline_rounded,
            title: 'ข้อมูลผู้ใช้',
            subtitle: 'แก้ไขชื่อจริง นามสกุล และชื่อเล่น',
            iconColor: const Color(0xFF3B82F6), // Blue
            iconBgColor: const Color(0xFFDBEAFE),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditUserInfoPage(
                    service: service,
                    user: user,
                    onProfileUpdated: onProfileUpdated,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _PrivacyActionTile(
            icon: Icons.lock_outline_rounded,
            title: 'เปลี่ยนรหัสผ่าน',
            subtitle: 'ตั้งรหัสผ่านใหม่เพื่อความปลอดภัย',
            iconColor: const Color(0xFFEF4444), // Red
            iconBgColor: const Color(0xFFFEE2E2),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangePasswordPage(service: service),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrivacyActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onTap;

  const _PrivacyActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: workText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: workMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_right_rounded, color: workMuted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
