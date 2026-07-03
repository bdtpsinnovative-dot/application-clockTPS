import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../widgets/work_ui.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    super.key,
    required this.user,
    required this.onMenu,
    required this.onSignOut,
  });

  final AppUser user;
  final VoidCallback onMenu;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: workBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          WorkHeader(
            title: 'โปรไฟล์ของฉัน',
            subtitle: user.email,
            onMenu: onMenu,
            bottomPadding: 66,
          ),
          Transform.translate(
            offset: const Offset(0, -42),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  WorkCard(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            color: workText,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        StatusBadge(status: user.status),
                        const SizedBox(height: 20),
                        _ProfileRow(
                          icon: Icons.email_outlined,
                          label: 'อีเมล',
                          value: user.email,
                        ),
                        _ProfileRow(
                          icon: Icons.business_outlined,
                          label: 'แผนก',
                          value: user.department.isEmpty
                              ? 'ยังไม่ระบุ'
                              : user.department,
                        ),
                        _ProfileRow(
                          icon: Icons.badge_outlined,
                          label: 'ตำแหน่ง',
                          value: user.position.isEmpty
                              ? 'ยังไม่ระบุ'
                              : user.position,
                        ),
                        _ProfileRow(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'สิทธิ์',
                          value: user.role == 'admin' ? 'Admin' : 'Employee',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: TextButton.icon(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'ออกจากระบบ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        backgroundColor: const Color(0xFFFEF2F2),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
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

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, color: workMuted, size: 21),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: workMuted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: workText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
