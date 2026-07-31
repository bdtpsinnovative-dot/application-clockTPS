import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/skeleton_loading.dart';

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    this.isRead = false,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? json['message'] as String? ?? '',
      createdAt: _tryDate(json['created_at']) ?? DateTime.now(),
      type: json['type'] as String? ?? 'system',
      isRead: json['is_read'] as bool? ?? json['read'] as bool? ?? false,
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String type; // 'leave', 'attendance', 'system', 'announcement'
  final bool isRead;

  NotificationRecord copyWith({bool? isRead}) {
    return NotificationRecord(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      type: type,
      isRead: isRead ?? this.isRead,
    );
  }
}

DateTime? _tryDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.onMenu,
    required this.isActive,
    required this.service,
    this.onNavigateToRequests,
  });

  final VoidCallback onMenu;
  final bool isActive;
  final AuthFlowService service;
  final ValueChanged<String?>? onNavigateToRequests;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<NotificationRecord> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void didUpdateWidget(covariant NotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final raw = await widget.service.getMyNotifications();
      if (!mounted) return;
      final records = raw.map(NotificationRecord.fromJson).toList();
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _notifications = records;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markRead(NotificationRecord n) async {
    if (n.type.startsWith('leave:')) {
      final parts = n.type.split(':');
      final targetId = parts.length > 1 ? parts[1] : null;
      widget.onNavigateToRequests?.call(targetId);
    } else if (n.type == 'leave') {
      widget.onNavigateToRequests?.call(null);
    }

    if (n.isRead) return;
    // Optimistic update
    setState(() {
      final idx = _notifications.indexWhere((x) => x.id == n.id);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      }
    });
    try {
      await widget.service.markNotificationRead(n.id);
    } catch (_) {
      // Revert on error
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((x) => x.id == n.id);
        if (idx != -1) {
          _notifications[idx] = _notifications[idx].copyWith(isRead: false);
        }
      });
    }
  }

  Future<void> _markAllRead() async {
    final hasUnread = _notifications.any((n) => !n.isRead);
    if (!hasUnread) return;

    setState(() {
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
    });
    try {
      await widget.service.markAllNotificationsRead();
    } catch (_) {
      // Reload on error
      _loadNotifications();
    }
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: workBackground,
      child: RefreshIndicator(
        color: workBlue,
        onRefresh: _loadNotifications,
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
                      Row(
                        children: [
                          Expanded(
                            child: WorkCardTitle(
                              icon: Icons.notifications_active_rounded,
                              title: 'รายการแจ้งเตือนล่าสุด',
                            ),
                          ),
                          if (!_loading && _unreadCount > 0)
                            GestureDetector(
                              onTap: _markAllRead,
                              child: Text(
                                'อ่านทั้งหมด ($_unreadCount)',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: workBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loading && _notifications.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: SimpleManagementListSkeleton(),
                        )
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              const Icon(Icons.wifi_off_rounded,
                                  size: 40, color: workMuted),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: workMuted, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: _loadNotifications,
                                child: const Text('ลองใหม่'),
                              ),
                            ],
                          ),
                        )
                      else if (_notifications.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.notifications_off_outlined,
                                    size: 40, color: workMuted),
                                SizedBox(height: 8),
                                Text(
                                  'ยังไม่มีการแจ้งเตือนสำหรับคุณ',
                                  style:
                                      TextStyle(color: workMuted, fontSize: 13),
                                ),
                              ],
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
                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _markRead(n),
                              child: Opacity(
                                opacity: n.isRead ? 0.65 : 1.0,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getIconBgColor(n),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getIconData(n),
                                        color: _getIconColor(n),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
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
                                                  margin: const EdgeInsets.only(
                                                      left: 6, top: 4),
                                                  decoration:
                                                      const BoxDecoration(
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
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: workMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
      ),
    );
  }

  IconData _getIconData(NotificationRecord n) {
    final title = n.title;
    final body = n.body;

    if (title.contains('อนุมัติ') || body.contains('อนุมัติ')) {
      return Icons.check_circle_rounded;
    }
    if (title.contains('ปฏิเสธ') || body.contains('ปฏิเสธ')) {
      return Icons.cancel_rounded;
    }
    if (title.contains('คำขอใหม่') ||
        body.contains('คำขอใหม่') ||
        title.contains('ยื่นคำขอ') ||
        body.contains('ยื่นคำขอ')) {
      return Icons.pending_actions_rounded;
    }

    final baseType = n.type.split(':')[0];
    switch (baseType) {
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

  Color _getIconColor(NotificationRecord n) {
    final title = n.title;
    final body = n.body;

    if (title.contains('อนุมัติ') || body.contains('อนุมัติ')) {
      return const Color(0xFF10B981); // เขียว
    }
    if (title.contains('ปฏิเสธ') || body.contains('ปฏิเสธ')) {
      return const Color(0xFFEF4444); // แดง
    }
    if (title.contains('คำขอใหม่') ||
        body.contains('คำขอใหม่') ||
        title.contains('ยื่นคำขอ') ||
        body.contains('ยื่นคำขอ')) {
      return const Color(0xFFF59E0B); // ส้ม/เหลือง
    }

    final baseType = n.type.split(':')[0];
    switch (baseType) {
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

  Color _getIconBgColor(NotificationRecord n) {
    final color = _getIconColor(n);
    return color.withValues(alpha: 0.12);
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.inMinutes < 1) {
      return 'เมื่อกี้นี้';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else {
      return DateFormat('dd MMM yyyy HH:mm น.').format(dt);
    }
  }
}
