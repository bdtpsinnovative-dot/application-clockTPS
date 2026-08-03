import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/work_models.dart';
import '../../widgets/priority_badge.dart';
import 'project_detail_style.dart';
import 'project_media_url.dart';

class ProjectDeliverableCard extends StatelessWidget {
  const ProjectDeliverableCard({
    super.key,
    required this.deliverable,
    required this.onTap,
    this.assignees = const [],
    this.assigneeCount,
    this.baseUrl = '',
    this.onStatusChanged,
  });

  final TaskListRecord deliverable;
  final VoidCallback onTap;
  final List<UserSummary> assignees;
  final int? assigneeCount;
  final String baseUrl;
  final ValueChanged<String>? onStatusChanged;

  void _showStatusPicker(BuildContext context) {
    if (onStatusChanged == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'เปลี่ยนสถานะงาน',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              for (final option in const [
                ('ยังไม่เริ่ม', 'pending', Color(0xFFF1F5F9), Color(0xFF475569)),
                ('กำลังทำ', 'in_progress', Color(0xFFFEF08A), Color(0xFF854D0E)),
                ('ส่งงานแล้ว', 'in_review', Color(0xFFDBEAFE), Color(0xFF1E40AF)),
                ('เสร็จแล้ว', 'completed', Color(0xFFDCFCE7), Color(0xFF166534)),
              ]) ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: deliverable.status == option.$2
                      ? const Color(0xFFF8FAFC)
                      : Colors.transparent,
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: option.$3,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      option.$1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: option.$4,
                      ),
                    ),
                  ),
                  trailing: deliverable.status == option.$2
                      ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB))
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onStatusChanged!(option.$2);
                  },
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = deliverableStatusStyle(deliverable.status);
    final statusColorTuple = deliverableStatusColors(deliverable.status);
    final isOverdue =
        deliverable.status != 'completed' &&
        deliverable.dueDate != null &&
        _dateOnly(deliverable.dueDate!).isBefore(_dateOnly(DateTime.now()));

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFF1F5F9)),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C0F172A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Title
              Text(
                deliverable.name,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 17,
                  height: 1.25,
                  letterSpacing: -0.3,
                  fontWeight: FontWeight.w800,
                ),
              ),

              // 2. Subtitle / Description
              if (deliverable.description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  deliverable.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 3. Tags Row (Dynamic Status Pill + Priority Outlined Pill)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Interactive Status Pill
                  GestureDetector(
                    onTap: onStatusChanged != null ? () => _showStatusPicker(context) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColorTuple.$1,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            status.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: statusColorTuple.$2,
                            ),
                          ),
                          if (onStatusChanged != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: statusColorTuple.$2,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Priority Outlined Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFCA5A5),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      deliverablePriorityLabel(deliverable.priority),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 4. Meta Information Grid (Clean un-nested text with icons!)
              Row(
                children: [
                  // Due Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Due date',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 15,
                              color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              deliverable.dueDate != null
                                  ? DateFormat('MMM dd, yyyy').format(deliverable.dueDate!)
                                  : 'ไม่ระบุ',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Files / Links count (Formerly Tracked time)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ไฟล์/ลิงก์',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.attach_file_rounded,
                              size: 15,
                              color: Color(0xFF0F172A),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              deliverable.attachments.isNotEmpty
                                  ? '${deliverable.attachments.length} รายการ'
                                  : '0 รายการ',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 5. Footer Row: Assignee & Action Chevron
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _AssigneeSummary(
                    assignees: assignees,
                    count: assigneeCount ?? deliverable.assigneeIds.length,
                    baseUrl: baseUrl,
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssigneeSummary extends StatelessWidget {
  const _AssigneeSummary({
    required this.assignees,
    required this.count,
    required this.baseUrl,
  });

  final List<UserSummary> assignees;
  final int count;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final visible = assignees.take(3).toList(growable: false);
    final extraCount = count > 3 ? count - 3 : 0;
    final totalItems = visible.length + (extraCount > 0 ? 1 : 0);
    final firstName = assignees.isNotEmpty ? assignees.first.fullName : 'ไม่ระบุ';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count > 0) ...[
          SizedBox(
            width: totalItems == 0 ? 36 : 36.0 + ((totalItems - 1) * 22.0),
            height: 36,
            child: Stack(
              children: [
                if (visible.isEmpty)
                  const _AssigneeAvatar(user: null, left: 0, baseUrl: '')
                else ...[
                  for (final entry in visible.indexed)
                    _AssigneeAvatar(
                      user: entry.$2,
                      left: entry.$1 * 22.0,
                      baseUrl: baseUrl,
                    ),
                  if (extraCount > 0)
                    Positioned(
                      left: visible.length * 22.0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E293B),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '+$extraCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        Text(
          count == 0
              ? 'ยังไม่ระบุ'
              : (count == 1 ? firstName : '$count คน'),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AssigneeAvatar extends StatelessWidget {
  const _AssigneeAvatar({
    required this.user,
    required this.left,
    required this.baseUrl,
  });

  final UserSummary? user;
  final double left;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final rawUrl = user?.resolvedAvatarUrl ?? user?.avatarUrl;
    final avatarUrl = resolveProjectMediaUrl(rawUrl, baseUrl);
    final hasAvatar = avatarUrl.isNotEmpty;
    final name = user?.fullName.trim() ?? '';
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Positioned(
      left: left,
      child: Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          backgroundColor: const Color(0xFFEFF6FF),
          backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
          onBackgroundImageError: hasAvatar ? (error, stack) {} : null,
          child: !hasAvatar
              ? Text(
                  initial,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.style});

  final DeliverableStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          style.label,
          style: TextStyle(
            color: style.color,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.label,
    this.color = ProjectDetailStyle.secondary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: ProjectDetailStyle.iconTiny, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class DeliverableStatusStyle {
  const DeliverableStatusStyle(this.label, this.color);

  final String label;
  final Color color;
}

DeliverableStatusStyle deliverableStatusStyle(String status) {
  switch (status) {
    case 'completed':
      return const DeliverableStatusStyle(
        'เสร็จสิ้น',
        ProjectDetailStyle.success,
      );
    case 'in_review':
      return const DeliverableStatusStyle(
        'ส่งงานแล้ว',
        ProjectDetailStyle.accent,
      );
    case 'pending':
      return const DeliverableStatusStyle(
        'ยังไม่เริ่ม',
        ProjectDetailStyle.muted,
      );
    default:
      return const DeliverableStatusStyle(
        'กำลังทำ',
        ProjectDetailStyle.secondary,
      );
  }
}

(Color, Color) deliverableStatusColors(String status) {
  switch (status) {
    case 'completed':
      return (const Color(0xFFDCFCE7), const Color(0xFF166534));
    case 'in_review':
      return (const Color(0xFFDBEAFE), const Color(0xFF1E40AF));
    case 'pending':
      return (const Color(0xFFF1F5F9), const Color(0xFF475569));
    default:
      return (const Color(0xFFFEF08A), const Color(0xFF854D0E));
  }
}

String deliverablePriorityLabel(String priority) {
  switch (priority) {
    case 'urgent':
      return 'เร่งด่วน';
    case 'high':
      return 'สำคัญสูง';
    case 'low':
      return 'สำคัญต่ำ';
    default:
      return 'สำคัญปานกลาง';
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
