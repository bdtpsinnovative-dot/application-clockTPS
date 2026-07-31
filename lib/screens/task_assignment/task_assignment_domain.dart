import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/work_models.dart';

class TaskStatusMeta {
  const TaskStatusMeta(this.label, this.color, this.bg, this.border);

  final String label;
  final Color color;
  final Color bg;
  final Color border;
}

const taskStatusConfig = {
  'pending': TaskStatusMeta(
    'รอทำ',
    Color(0xFF64748B),
    Color(0xFFF1F5F9),
    Color(0xFFCBD5E1),
  ),
  'in_progress': TaskStatusMeta(
    'กำลังทำ',
    Color(0xFFEA580C),
    Color(0xFFFFF7ED),
    Color(0xFFFED7AA),
  ),
  'in_review': TaskStatusMeta(
    'รอตรวจ',
    Color(0xFF7C3AED),
    Color(0xFFF5F3FF),
    Color(0xFFDDD6FE),
  ),
  'completed': TaskStatusMeta(
    'เสร็จสิ้น',
    Color(0xFF16A34A),
    Color(0xFFF0FDF4),
    Color(0xFFBBF7D0),
  ),
};

bool isAssignmentOverdue(DateTime dueDate, String status, {DateTime? now}) {
  if (status == 'completed') return false;
  final current = now ?? DateTime.now();
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final today = DateTime(current.year, current.month, current.day);
  return dueDay.isBefore(today);
}

String assignmentFilterUserId(AppUser? currentUser, String fallbackAuthId) {
  final databaseUserId = currentUser?.id.trim() ?? '';
  return databaseUserId.isNotEmpty ? databaseUserId : fallbackAuthId;
}

/// Keeps the admin assignment list scoped to the same work as the web app.
///
/// The admin endpoint intentionally returns all tasks so that privileged
/// clients can perform their own views. The assignment screen, however,
/// should show only boards created by the signed-in admin or boards where the
/// admin is an assignee.
bool taskMatchesAdminVisibilityFilter(TaskRecord task, String? currentUserId) {
  final userId = currentUserId?.trim() ?? '';
  if (userId.isEmpty) return false;

  if (task.assignedBy == userId) return true;

  final assignees = task.assigneeIds.isNotEmpty
      ? task.assigneeIds
      : <String>[task.assignedTo];
  return assignees.contains(userId);
}

bool taskMatchesOwnershipFilter(
  TaskRecord task,
  String? currentUserId,
  String? ownershipFilter,
) {
  if (ownershipFilter == null || currentUserId == null) return true;
  final isCreator = task.assignedBy == currentUserId;
  if (ownershipFilter == 'created_by_me') return isCreator;
  if (ownershipFilter == 'joined') {
    final isAssignee = task.assigneeIds.isNotEmpty
        ? task.assigneeIds.contains(currentUserId)
        : task.assignedTo == currentUserId;
    return !isCreator && isAssignee;
  }
  return true;
}
