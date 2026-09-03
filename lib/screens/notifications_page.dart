import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../services/auth_flow_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/work_ui.dart';
import '../widgets/skeleton_loading.dart';
import 'task_board_page.dart';

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    this.isRead = false,
    this.avatarUrl,
    this.actorName,
    this.actorId,
    this.taskId,
    this.listId,
    this.cardId,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] is Map<String, dynamic>
        ? json['metadata'] as Map<String, dynamic>
        : null;
    final type = json['type'] as String? ?? 'system';

    String? taskId = meta?['task_id'] as String? ??
        meta?['taskId'] as String? ??
        json['task_id'] as String?;
    if (taskId == null && (type.startsWith('task:') || type.startsWith('task_list:') || type.startsWith('task_comment:'))) {
      final parts = type.split(':');
      if (parts.length > 1) taskId = parts[1];
    }

    final listId = meta?['list_id'] as String? ??
        meta?['listId'] as String? ??
        json['list_id'] as String?;

    final cardId = meta?['card_id'] as String? ??
        meta?['cardId'] as String? ??
        json['card_id'] as String?;

    return NotificationRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? json['message'] as String? ?? '',
      createdAt: _tryDate(json['created_at']) ?? DateTime.now(),
      type: type,
      isRead: json['is_read'] as bool? ?? json['read'] as bool? ?? false,
      avatarUrl: meta?['avatar_url'] as String? ?? meta?['actor_avatar'] as String?,
      actorName: meta?['actor_name'] as String? ?? meta?['employee_name'] as String?,
      actorId: meta?['actor_id'] as String? ?? meta?['user_id'] as String?,
      taskId: taskId,
      listId: listId,
      cardId: cardId,
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String type; // 'leave', 'attendance', 'system', 'announcement'
  final bool isRead;
  final String? avatarUrl;
  final String? actorName;
  final String? actorId;
  final String? taskId;
  final String? listId;
  final String? cardId;

  NotificationRecord copyWith({bool? isRead}) {
    return NotificationRecord(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      type: type,
      isRead: isRead ?? this.isRead,
      avatarUrl: avatarUrl,
      actorName: actorName,
      actorId: actorId,
      taskId: taskId,
      listId: listId,
      cardId: cardId,
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
    this.onMenu,
    required this.isActive,
    required this.service,
    this.onNavigateToRequests,
    this.onNavigateToCalendar,
    this.onUnreadCountChanged,
  });

  final VoidCallback? onMenu;
  final bool isActive;
  final AuthFlowService service;
  final ValueChanged<String?>? onNavigateToRequests;
  final VoidCallback? onNavigateToCalendar;
  final ValueChanged<int>? onUnreadCountChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<NotificationRecord> _notifications = [];
  List<AppUser> _users = [];
  Map<String, AppUser> _userMap = {};
  int _displayLimit = 10;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void didUpdateWidget(covariant NotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _displayLimit = 10;
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _displayLimit = 10;
    });

    try {
      final results = await Future.wait([
        widget.service.getMyNotifications(),
        widget.service.getAdminUsers(),
      ]);
      if (!mounted) return;
      final raw = results[0] as List<Map<String, dynamic>>;
      final users = results[1] as List<AppUser>;
      final records = raw.map(NotificationRecord.fromJson).toList();
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _notifications = records;
        _users = users;
        _userMap = {for (final u in users) u.id: u};
        _loading = false;
      });
      widget.onUnreadCountChanged?.call(_unreadCount);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  AppUser? _findUserForNotification(NotificationRecord n) {
    if (n.actorId != null && _userMap.containsKey(n.actorId)) {
      return _userMap[n.actorId];
    }
    for (final u in _users) {
      final fullName = '${u.firstName} ${u.lastName}'.trim();
      if (fullName.isNotEmpty && (n.body.contains(fullName) || n.title.contains(fullName))) {
        return u;
      }
      if (u.firstName.isNotEmpty && (n.body.startsWith(u.firstName) || n.body.contains(' ${u.firstName} '))) {
        return u;
      }
      if (u.nickname.isNotEmpty && (n.body.contains(u.nickname) || n.title.contains(u.nickname))) {
        return u;
      }
    }
    return null;
  }

  String _getNotificationActorName(NotificationRecord n, AppUser? user) {
    if (user != null) {
      if (user.nickname.trim().isNotEmpty) {
        return '${user.firstName} (${user.nickname.trim()})';
      }
      final full = user.fullName.trim();
      return full.isNotEmpty ? full : user.firstName;
    }
    if (n.actorName != null && n.actorName!.trim().isNotEmpty) {
      return n.actorName!.trim();
    }
    final body = n.body.trim();
    const actionKeywords = [
      ' ทำงานย่อย',
      ' อัปเดต',
      ' ส่งงานย่อย',
      ' แก้ไข',
      ' ยื่นคำขอ',
      ' ได้เปลี่ยนสถานะ',
      ' ได้แก้ไข',
      ' ได้มอบหมาย',
      ' ทำการ'
    ];
    for (final kw in actionKeywords) {
      final idx = body.indexOf(kw);
      if (idx > 0 && idx < 45) {
        return body.substring(0, idx).trim();
      }
    }
    return n.title.isNotEmpty ? n.title : 'การแจ้งเตือน';
  }

  String _getNotificationCleanBody(NotificationRecord n, AppUser? user) {
    var body = n.body.trim();
    if (user != null) {
      final fullName = user.fullName.trim();
      if (fullName.isNotEmpty && body.startsWith(fullName)) {
        body = body.substring(fullName.length).trim();
      } else if (user.firstName.isNotEmpty && body.startsWith(user.firstName)) {
        body = body.substring(user.firstName.length).trim();
      }
    }
    if (n.actorName != null && n.actorName!.isNotEmpty && body.startsWith(n.actorName!)) {
      body = body.substring(n.actorName!.length).trim();
    }
    const actionKeywords = [
      'ทำงานย่อย',
      'อัปเดต',
      'ส่งงานย่อย',
      'แก้ไข',
      'ยื่นคำขอ',
      'ได้เปลี่ยนสถานะ',
      'ได้แก้ไข',
      'ได้มอบหมาย',
      'ทำการ'
    ];
    for (final kw in actionKeywords) {
      final idx = body.indexOf(' $kw');
      if (idx > 0 && idx < 45) {
        body = body.substring(idx).trim();
        break;
      }
    }
    return body.isNotEmpty ? body : n.title;
  }

  Widget _buildNotificationAvatar(NotificationRecord n) {
    final user = _findUserForNotification(n);
    final avatarUrl = user?.avatarUrl ?? n.avatarUrl;
    final name = user != null
        ? (user.nickname.isNotEmpty ? user.nickname : user.firstName)
        : (n.actorName ?? (n.title.isNotEmpty ? n.title : 'U'));

    final hasPerson = user != null || (avatarUrl != null && avatarUrl.isNotEmpty);

    if (hasPerson) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(
            avatarUrl: avatarUrl,
            name: name,
            radius: 19,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getIconBgColor(n),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Icon(
                  _getIconData(n),
                  color: _getIconColor(n),
                  size: 9,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _getIconBgColor(n),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          _getIconData(n),
          color: _getIconColor(n),
          size: 19,
        ),
      ),
    );
  }

  Future<void> _navigateToTask(NotificationRecord n) async {
    final taskId = n.taskId;
    if (taskId == null || taskId.isEmpty) return;

    try {
      final task = await widget.service.getTask(taskId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TaskBoardPage(
            task: task,
            service: widget.service,
            onRefreshNeeded: _loadNotifications,
            initialListId: n.listId,
            initialCardId: n.cardId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถเปิดงานได้ หรืออาจถูกลบไปแล้ว: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _markRead(NotificationRecord n) async {
    if (n.type.startsWith('leave:')) {
      final parts = n.type.split(':');
      final targetId = parts.length > 1 ? parts[1] : null;
      widget.onNavigateToRequests?.call(targetId);
    } else if (n.type == 'leave') {
      widget.onNavigateToRequests?.call(null);
    } else if (n.type == 'attendance') {
      widget.onNavigateToCalendar?.call();
    } else if (n.taskId != null && n.taskId!.isNotEmpty) {
      _navigateToTask(n);
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
      widget.onUnreadCountChanged?.call(_unreadCount);
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
    widget.onUnreadCountChanged?.call(0);
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
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (!_loading &&
                scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200) {
              if (_displayLimit < _notifications.length) {
                // We don't want to call setState too frequently, but here it's fast.
                // We'll delay it to avoid build during scroll issues.
                Future.microtask(() {
                  if (mounted && _displayLimit < _notifications.length) {
                    setState(() {
                      _displayLimit += 10;
                    });
                  }
                });
              }
            }
            return false;
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              WorkHeader(
                title: 'แจ้งเตือน',
                subtitle: 'ศูนย์การแจ้งเตือนและข่าวสาร',
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
                                  'อ่านแล้วทั้งหมด ($_unreadCount)',
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
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  size: 40,
                                  color: workMuted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: workMuted,
                                    fontSize: 12,
                                  ),
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
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 40,
                                    color: workMuted,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'ยังไม่มีการแจ้งเตือนสำหรับคุณ',
                                    style: TextStyle(
                                      color: workMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              final displayed = _notifications
                                  .take(_displayLimit)
                                  .toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: displayed.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(
                                      height: 10,
                                      thickness: 0.6,
                                      color: Color(0xFFF1F5F9),
                                    ),
                                    itemBuilder: (context, index) {
                                      final n = displayed[index];
                                      final user = _findUserForNotification(n);
                                      final actorName = _getNotificationActorName(n, user);
                                      final cleanBody = _getNotificationCleanBody(n, user);

                                      return InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () => _markRead(n),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: !n.isRead
                                                ? const Color(0xFFF8FAFC)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              _buildNotificationAvatar(n),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    // บรรทัดแรก: ชื่อคน (ตัวหนา) + เวลา (ขวา) + จุดแดงถ้ายังไม่อ่าน
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            actorName,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: !n.isRead
                                                                  ? FontWeight.w700
                                                                  : FontWeight.w600,
                                                              color: !n.isRead
                                                                  ? workText
                                                                  : const Color(0xFF475569),
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          _formatTime(n.createdAt),
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            color: !n.isRead
                                                                ? workBlue
                                                                : workMuted,
                                                            fontWeight: !n.isRead
                                                                ? FontWeight.w600
                                                                : FontWeight.normal,
                                                          ),
                                                        ),
                                                        if (!n.isRead) ...[
                                                          const SizedBox(width: 5),
                                                          Container(
                                                            width: 6,
                                                            height: 6,
                                                            decoration:
                                                                const BoxDecoration(
                                                              color: Color(0xFFEF4444),
                                                              shape: BoxShape.circle,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    // บรรทัดสอง: ข้อความรายละเอียดกระชับ ไม่เยิ่นเย้อ
                                                    Text(
                                                      cleanBody,
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        color: !n.isRead
                                                            ? const Color(0xFF334155)
                                                            : workMuted,
                                                        height: 1.25,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                  if (displayed.length < _notifications.length) ...[
                                    const SizedBox(height: 16),
                                    Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: workBlue,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'เลื่อนลงเพื่อดูต่อ (${displayed.length}/${_notifications.length})',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: workMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
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
      return 'เมื่อกี้';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ชม.ที่แล้ว';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} วันที่แล้ว';
    } else {
      return DateFormat('d MMM, HH:mm น.').format(dt);
    }
  }
}
