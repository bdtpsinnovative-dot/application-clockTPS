import 'package:flutter/material.dart';

/// The canonical status contract for project deliverables/task lists.
///
/// Keep these transport values aligned with the web and backend. The parent
/// task status has a smaller, separate contract and should not use this map.
class TaskListStatusStyle {
  const TaskListStatusStyle({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
}

const taskListStatusValues = <String>[
  'waiting',
  'pending',
  'in_progress',
  'in_review',
  'revision',
  'completed',
];

const taskListStatusStyles = <String, TaskListStatusStyle>{
  'waiting': TaskListStatusStyle(
    label: 'รอรับ',
    textColor: Color(0xFF0369A1),
    backgroundColor: Color(0xFFF0F9FF),
    borderColor: Color(0xFFBAE6FD),
  ),
  'pending': TaskListStatusStyle(
    label: 'รอทำ',
    textColor: Color(0xFF475569),
    backgroundColor: Color(0xFFF1F5F9),
    borderColor: Color(0xFFCBD5E1),
  ),
  'in_progress': TaskListStatusStyle(
    label: 'กำลังทำ',
    textColor: Color(0xFFB45309),
    backgroundColor: Color(0xFFFFFBEB),
    borderColor: Color(0xFFFDE68A),
  ),
  'in_review': TaskListStatusStyle(
    label: 'รอตรวจ',
    textColor: Color(0xFF1D4ED8),
    backgroundColor: Color(0xFFEFF6FF),
    borderColor: Color(0xFFBFDBFE),
  ),
  'revision': TaskListStatusStyle(
    label: 'แก้ไข',
    textColor: Color(0xFFBE123C),
    backgroundColor: Color(0xFFFFF1F2),
    borderColor: Color(0xFFFECDD3),
  ),
  'completed': TaskListStatusStyle(
    label: 'เสร็จสิ้น',
    textColor: Color(0xFF047857),
    backgroundColor: Color(0xFFECFDF5),
    borderColor: Color(0xFFA7F3D0),
  ),
};

TaskListStatusStyle taskListStatusStyle(String status) {
  return taskListStatusStyles[status] ?? taskListStatusStyles['pending']!;
}
