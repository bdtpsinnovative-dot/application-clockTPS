import 'package:flutter/material.dart';
import '../widgets/work_ui.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: const Text(
          'ตั้งค่าบัญชี',
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
          _SeparatedSettingsTile(
            icon: Icons.notifications_active_rounded,
            title: 'การแจ้งเตือน',
            subtitle: 'ตั้งค่าการรับการแจ้งเตือนต่างๆ',
            iconColor: const Color(0xFFF59E0B), // Amber for notifications
            iconBgColor: const Color(0xFFFEF3C7),
            onTap: () {
              // Navigate to Notifications settings
            },
          ),
          const SizedBox(height: 16),
          _SeparatedSettingsTile(
            icon: Icons.privacy_tip_rounded,
            title: 'ความเป็นส่วนตัว',
            subtitle: 'จัดการข้อมูลและความปลอดภัย',
            iconColor: const Color(0xFF10B981), // Emerald for privacy
            iconBgColor: const Color(0xFFD1FAE5),
            onTap: () {
              // Navigate to Privacy settings
            },
          ),
        ],
      ),
    );
  }
}

class _SeparatedSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onTap;

  const _SeparatedSettingsTile({
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
