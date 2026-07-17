import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/work_ui.dart';

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String type; // 'leave', 'attendance', 'system', 'announcement'
  final bool isRead;
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.onMenu,
    required this.isActive,
  });

  final VoidCallback onMenu;
  final bool isActive;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = false;
  List<NotificationRecord> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() => _loading = true);
    // สร้าง Mock Notifications สวยงามสำหรับการดีบักใช้งานจริง
    final now = DateTime.now();
    _notifications = [
      NotificationRecord(
        id: '1',
        title: 'อนุมัติใบลาพักร้อนสำเร็จ',
        body: 'คำขอลาพักร้อนของคุณในวันที่ 28 กรกฎาคม 2026 ได้รับการอนุมัติแล้วจากผู้ดูแลระบบ',
        createdAt: now.subtract(const Duration(hours: 2)),
        type: 'leave',
        isRead: false,
      ),
      NotificationRecord(
        id: '2',
        title: 'แจ้งเตือน: ลืมบันทึกเวลาออกงาน (Check-out)',
        body: 'ระบบพบว่าคุณยังไม่มีการลงเวลาออกงานในวันที่ 16 กรกฎาคม 2026 กรุณาแจ้งฝ่ายบุคคลหากลงเวลาตกหล่น',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        type: 'attendance',
        isRead: false,
      ),
      NotificationRecord(
        id: '3',
        title: 'ประกาศบริษัท: งานสังสรรค์กลางปี',
        body: 'ขอเชิญพี่น้องชาว NexHR เข้าร่วมงานเลี้ยงสังสรรค์กลางปีในวันเสาร์หน้า เวลา 18:00 น. ณ โรงแรมสยามเกรด',
        createdAt: now.subtract(const Duration(days: 2)),
        type: 'announcement',
        isRead: true,
      ),
      NotificationRecord(
        id: '4',
        title: 'การผูกอุปกรณ์เรียบร้อย',
        body: 'บัญชีของคุณได้ทำการผูกกับโทรศัพท์เครื่องนี้เสร็จสิ้นแล้ว รหัสอุปกรณ์: (Device Bound)',
        createdAt: now.subtract(const Duration(days: 4)),
        type: 'system',
        isRead: true,
      ),
    ];
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: workBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          WorkHeader(
            title: 'แจ้งเตือน',
            subtitle: 'ศูนย์การแจ้งเตือนและข่าวสาร',
            onMenu: widget.onMenu,
            bottomPadding: 58,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'กล่องข้อความแจ้งเตือน',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: WorkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WorkCardTitle(
                      icon: Icons.notifications_active_rounded,
                      title: 'รายการแจ้งเตือนล่าสุด',
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: workBlue,
                          ),
                        ),
                      )
                    else if (_notifications.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'ยังไม่มีการแจ้งเตือนสำหรับคุณ',
                            style: TextStyle(color: workMuted, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 24,
                          color: Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          return Opacity(
                            opacity: n.isRead ? 0.65 : 1.0,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getIconBgColor(n.type),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getIconData(n.type),
                                    color: _getIconColor(n.type),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n.title,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: n.isRead
                                                    ? FontWeight.w500
                                                    : FontWeight.w700,
                                                color: workText,
                                              ),
                                            ),
                                          ),
                                          if (!n.isRead)
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFEF4444),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.body,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: workMuted,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatTime(n.createdAt),
                                        style: const TextStyle(fontSize: 10, color: workMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String type) {
    switch (type) {
      case 'leave':
        return Icons.event_busy_rounded;
      case 'attendance':
        return Icons.fingerprint_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      default:
        return Icons.settings_suggest_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'leave':
        return const Color(0xFFEF4444);
      case 'attendance':
        return const Color(0xFF10B981);
      case 'announcement':
        return const Color(0xFFF59E0B);
      default:
        return workBlue;
    }
  }

  Color _getIconBgColor(String type) {
    final color = _getIconColor(type);
    return color.withValues(alpha: 0.12);
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else {
      return DateFormat('dd MMM yyyy HH:mm น.').format(dt);
    }
  }
}
