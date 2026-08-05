part of '../admin_tasks_page.dart';

// ─── Task Detail Bottom Sheet ────────────────────────────────────
class _TaskDetailSheet extends StatelessWidget {
  const _TaskDetailSheet({
    required this.task,
    required this.userMap,
    required this.brandMap,
    required this.catMap,
    required this.statusConfig,
    required this.onEdit,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final TaskRecord task;
  final Map<String, AppUser> userMap;
  final Map<String, BrandRecord> brandMap;
  final Map<String, TaskCategoryRecord> catMap;
  final Map<String, TaskStatusMeta> statusConfig;
  final VoidCallback onEdit;
  final ValueChanged<String> onChangeStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final user = userMap[task.assignedTo];
    final List<AppUser> detailAssignees = task.assigneeIds.isNotEmpty
        ? task.assigneeIds
              .map((id) => userMap[id])
              .whereType<AppUser>()
              .toList()
        : (user != null ? [user] : []);
    final String assigneeNames = detailAssignees.isNotEmpty
        ? detailAssignees.map((u) => u.fullName).join(', ')
        : 'ไม่ระบุ';
    final brand = task.brandId != null ? brandMap[task.brandId] : null;
    final category = task.categoryId != null ? catMap[task.categoryId] : null;
    final meta = statusConfig[task.status] ?? statusConfig['pending']!;
    final isOverdue = isAssignmentOverdue(task.dueDate, task.status);
    const otherStatuses = ['pending', 'in_progress', 'in_review', 'completed'];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tags
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Status tag
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: meta.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: meta.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: meta.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      meta.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: meta.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (brand != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.label_outline_rounded,
                        size: 12,
                        color: workBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        brand.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: workBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              if (category != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 12,
                        color: Color(0xFFB45309),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: workText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('แก้ไข'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: workBlue,
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.description,
              style: const TextStyle(
                fontSize: 14,
                color: workMuted,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Assignee + Due date
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  icon: Icons.person_rounded,
                  label: 'ผู้รับผิดชอบ',
                  value: assigneeNames,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  icon: isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.calendar_month_rounded,
                  label: 'กำหนดส่ง',
                  value: DateFormat('dd MMMM yyyy', 'th').format(task.dueDate),
                  valueColor: isOverdue ? Colors.red : workText,
                  iconColor: isOverdue ? Colors.red : workBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-items checklist
          if (task.subItems.isNotEmpty) ...[
            const Text(
              'CHECKLIST',
              style: TextStyle(
                fontSize: 11,
                color: workMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...task.subItems.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.isDone
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: item.isDone
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFCBD5E1),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: item.isDone ? workMuted : workText,
                          decoration: item.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Change status
          const Text(
            'เปลี่ยนสถานะ',
            style: TextStyle(
              fontSize: 11,
              color: workMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: otherStatuses.where((s) => s != task.status).map((s) {
              final m = statusConfig[s]!;
              return OutlinedButton(
                onPressed: () => onChangeStatus(s),
                style: OutlinedButton.styleFrom(
                  foregroundColor: m.color,
                  side: BorderSide(color: m.border, width: 1.5),
                  backgroundColor: m.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  '→ ${m.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Delete
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text(
                'ลบงานนี้',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Color(0xFFFECACA)),
                backgroundColor: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Color? iconColor,
  }) {
    final effectiveIconColor = iconColor ?? workBlue;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveIconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: effectiveIconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: valueColor ?? const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
