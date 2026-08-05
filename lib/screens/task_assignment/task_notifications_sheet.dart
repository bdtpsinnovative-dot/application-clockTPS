part of '../admin_tasks_page.dart';

class _TaskNotification {
  const _TaskNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.taskId,
    this.listId,
  });

  factory _TaskNotification.fromJson(Map<String, dynamic> json) {
    dynamic metadata = json['metadata'];
    if (metadata is String && metadata.trim().isNotEmpty) {
      try {
        metadata = jsonDecode(metadata);
      } catch (_) {
        metadata = null;
      }
    }
    final metadataMap = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : const <String, dynamic>{};
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    return _TaskNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      createdAt: createdAt?.toLocal() ?? DateTime.now(),
      isRead: json['is_read'] as bool? ?? json['read'] as bool? ?? false,
      taskId: _metadataId(metadataMap['task_id']),
      listId: _metadataId(metadataMap['list_id']),
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? taskId;
  final String? listId;

  _TaskNotification copyWith({bool? isRead}) {
    return _TaskNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      taskId: taskId,
      listId: listId,
    );
  }

  static String? _metadataId(dynamic value) {
    final id = value?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }
}

class _TaskNotificationsSheet extends StatelessWidget {
  const _TaskNotificationsSheet({
    required this.title,
    required this.emptyMessage,
    required this.notifications,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String emptyMessage;
  final List<_TaskNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Color(0xFF4F46E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: workText,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: workMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('close-task-notifications'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: workMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              size: 40,
                              color: Color(0xFFCBD5E1),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              emptyMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: workMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notification.title,
                                      style: const TextStyle(
                                        color: workText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat(
                                      'HH:mm',
                                    ).format(notification.createdAt),
                                    style: const TextStyle(
                                      color: workMuted,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (notification.body.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  notification.body,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 5),
                              Text(
                                _thaiShortDate(notification.createdAt),
                                style: const TextStyle(
                                  color: workMuted,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE2E8F0),
                    foregroundColor: workText,
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text(
                    'ปิดหน้าต่าง',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _thaiShortDate(DateTime date) {
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
