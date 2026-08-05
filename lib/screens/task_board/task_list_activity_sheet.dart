part of '../task_board_page.dart';

const _taskListActivityLabels = <String, String>{
  'board_created': 'สร้างบอร์ด',
  'board_deleted': 'ลบบอร์ด',
  'board_updated': 'แก้ไขบอร์ด',
  'board_name_changed': 'เปลี่ยนชื่อบอร์ด',
  'board_description_changed': 'แก้ไขรายละเอียด',
  'board_start_date_changed': 'เปลี่ยนวันเริ่มต้น',
  'board_due_date_changed': 'เปลี่ยนกำหนดส่ง',
  'board_priority_changed': 'เปลี่ยนความสำคัญ',
  'board_status_changed': 'เปลี่ยนสถานะ',
  'board_note_changed': 'แก้ไขหมายเหตุ',
  'board_attachment_added': 'เพิ่มเอกสาร',
  'board_attachment_removed': 'ลบเอกสาร',
  'board_assignees_added': 'เพิ่มผู้รับผิดชอบ',
  'board_assignees_removed': 'นำผู้รับผิดชอบออก',
  'board_order_changed': 'เปลี่ยนลำดับบอร์ด',
  'card_created': 'สร้างการ์ดงาน',
  'card_updated': 'แก้ไขการ์ดงาน',
  'card_status_changed': 'เปลี่ยนสถานะการ์ด',
  'card_moved': 'ย้ายการ์ดงาน',
  'card_deleted': 'ลบการ์ดงาน',
  'sub_item_created': 'เพิ่มงานย่อย',
  'sub_item_updated': 'แก้ไขงานย่อย',
  'sub_item_status_changed': 'เปลี่ยนสถานะงานย่อย',
  'sub_item_verified': 'ตรวจงานย่อย',
  'sub_item_deleted': 'ลบงานย่อย',
  'attachment_created': 'เพิ่มไฟล์แนบ',
  'attachment_deleted': 'ลบไฟล์แนบ',
  'comment_added': 'แสดงความคิดเห็น',
};

class _TaskListActivitySheet extends StatefulWidget {
  const _TaskListActivitySheet({
    required this.taskId,
    required this.list,
    required this.service,
  });

  final String taskId;
  final TaskListRecord list;
  final AuthFlowService service;

  @override
  State<_TaskListActivitySheet> createState() => _TaskListActivitySheetState();
}

class _TaskListActivitySheetState extends State<_TaskListActivitySheet> {
  List<TaskEventRecord> _events = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.service.getTaskEvents(
        widget.taskId,
        listId: widget.list.id,
      );
      if (!mounted) return;
      setState(() => _events = events);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดประวัติกิจกรรมไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Material(
        key: const Key('task-list-activity-sheet'),
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time_rounded,
              color: Color(0xFF4F46E5),
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ประวัติกิจกรรมของบอร์ด',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: workText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.list.name} · ใครทำอะไรและเมื่อไร',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: workMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('refresh-task-list-activity'),
            tooltip: 'รีเฟรชประวัติ',
            onPressed: _loading ? null : _loadEvents,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: workMuted, size: 19),
          ),
          IconButton(
            key: const Key('close-task-list-activity'),
            tooltip: 'ปิดประวัติกิจกรรม',
            onPressed: () => Navigator.pop(context),
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close_rounded, color: workMuted, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 10),
            Text(
              'กำลังโหลดประวัติกิจกรรม...',
              style: TextStyle(color: workMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: workMuted, size: 32),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: workMuted)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }
    if (_events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, color: workMuted, size: 34),
            SizedBox(height: 8),
            Text(
              'ยังไม่มีประวัติกิจกรรมของบอร์ดนี้',
              style: TextStyle(color: workMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _ActivityTimelineItem(
        event: _events[index],
        isLast: index == _events.length - 1,
      ),
    );
  }
}

class _ActivityTimelineItem extends StatelessWidget {
  const _ActivityTimelineItem({required this.event, required this.isLast});

  final TaskEventRecord event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final content = event.content.trim().isNotEmpty
        ? event.content.trim()
        : event.action.trim().isNotEmpty
        ? event.action.trim()
        : 'ทำรายการในบอร์ด';
    final actionLabel = _taskListActivityLabels[event.action] ?? 'กิจกรรมบอร์ด';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF4F46E5),
                    size: 16,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1, color: const Color(0xFFE0E7FF)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.userFullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: workText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatActivityDate(event.createdAt),
                        style: const TextStyle(color: workMuted, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                    ),
                  ),
                  if (event.action.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatActivityDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year + 543} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}
