import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/work_models.dart';
import '../../models/task_list_status.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/user_avatar.dart';
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
  });

  final TaskListRecord deliverable;
  final VoidCallback onTap;
  final List<UserSummary> assignees;
  final int? assigneeCount;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final status = deliverableStatusStyle(deliverable.status);
    final isOverdue =
        deliverable.status != 'completed' &&
        deliverable.dueDate != null &&
        _dateOnly(deliverable.dueDate!).isBefore(_dateOnly(DateTime.now()));

    return Material(
      color: ProjectDetailStyle.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ProjectDetailStyle.cardRadius),
        side: const BorderSide(color: ProjectDetailStyle.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ProjectDetailStyle.cardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusLabel(style: status),
                  const SizedBox(width: 10),
                  PriorityBadge(
                    priority: deliverable.priority,
                    isCompact: true,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ProjectDetailStyle.secondary,
                    size: ProjectDetailStyle.iconMedium,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                deliverable.name,
                style: const TextStyle(
                  color: ProjectDetailStyle.ink,
                  fontSize: 15.5,
                  height: 1.35,
                  letterSpacing: -0.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (deliverable.description.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  deliverable.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ProjectDetailStyle.secondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  if (deliverable.dueDate != null)
                    _Meta(
                      icon: isOverdue
                          ? Icons.error_outline_rounded
                          : Icons.calendar_today_outlined,
                      label: DateFormat(
                        'dd MMM yyyy',
                        'th',
                      ).format(deliverable.dueDate!),
                      color: isOverdue
                          ? ProjectDetailStyle.danger
                          : ProjectDetailStyle.secondary,
                    ),
                  _AssigneeSummary(
                    assignees: assignees,
                    count: assigneeCount ?? deliverable.assigneeIds.length,
                    baseUrl: baseUrl,
                  ),
                  if (deliverable.attachments.isNotEmpty)
                    _Meta(
                      icon: Icons.attach_file_rounded,
                      label: '${deliverable.attachments.length} รายการ',
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count > 0) ...[
          SizedBox(
            width: visible.isEmpty ? 20 : 20 + ((visible.length - 1) * 14),
            height: 20,
            child: Stack(
              children: [
                if (visible.isEmpty)
                  const _AssigneeAvatar(user: null, left: 0, baseUrl: '')
                else
                  for (final entry in visible.indexed)
                    _AssigneeAvatar(
                      user: entry.$2,
                      left: entry.$1 * 14,
                      baseUrl: baseUrl,
                    ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          count == 0 ? 'ยังไม่ระบุ' : '$count คน',
          style: const TextStyle(
            color: ProjectDetailStyle.secondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
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
        width: 20,
        height: 20,
        padding: const EdgeInsets.all(1.5),
        decoration: const BoxDecoration(
          color: ProjectDetailStyle.surface,
          shape: BoxShape.circle,
        ),
        child: UserAvatar(
          avatarUrl: user?.avatarUrl,
          name: user?.displayName ?? '',
          radius: 8.5,
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
  final style = taskListStatusStyle(status);
  return DeliverableStatusStyle(style.label, style.textColor);
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
