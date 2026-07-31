part of '../admin_tasks_page.dart';

class _EditTaskModal extends StatefulWidget {
  const _EditTaskModal({
    required this.task,
    required this.users,
    required this.onSave,
  });

  final TaskRecord task;
  final List<AppUser> users;
  final Future<void> Function({
    required String title,
    required String description,
    required List<String> assigneeIds,
    required DateTime dueDate,
  })
  onSave;

  @override
  State<_EditTaskModal> createState() => _EditTaskModalState();
}

class _EditTaskModalState extends State<_EditTaskModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final Set<String> _assigneeIds;
  late DateTime _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _assigneeIds = {
      ...(widget.task.assigneeIds.isNotEmpty
          ? widget.task.assigneeIds
          : [widget.task.assignedTo]),
    }..removeWhere((id) => id.isEmpty);
    _dueDate = widget.task.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _assigneeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่องานและเลือกผู้รับผิดชอบอย่างน้อย 1 คน'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assigneeIds: _assigneeIds.toList(growable: false),
        dueDate: _dueDate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('แก้ไขงานไม่สำเร็จ: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueDateIsPast = isWorkDatePast(_dueDate);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: workBlue, size: 22),
                SizedBox(width: 8),
                Text(
                  'แก้ไขงานมอบหมาย',
                  style: TextStyle(
                    color: workText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'ชื่องาน',
              style: TextStyle(
                color: workText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: _editInputDecoration('กรอกชื่องาน'),
            ),
            const SizedBox(height: 14),
            const Text(
              'รายละเอียด',
              style: TextStyle(
                color: workText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: _editInputDecoration('รายละเอียดงาน'),
            ),
            const SizedBox(height: 14),
            const Text(
              'ผู้รับผิดชอบ',
              style: TextStyle(
                color: workText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              constraints: const BoxConstraints(maxHeight: 190),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: widget.users.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, index) {
                  final user = widget.users[index];
                  final selected = _assigneeIds.contains(user.id);
                  return CheckboxListTile(
                    value: selected,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.trailing,
                    activeColor: workBlue,
                    title: Text(
                      user.fullName,
                      style: const TextStyle(
                        color: workText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: user.position.isEmpty
                        ? null
                        : Text(
                            user.position,
                            style: const TextStyle(
                              color: workMuted,
                              fontSize: 10.5,
                            ),
                          ),
                    onChanged: (_) => setState(() {
                      if (selected) {
                        _assigneeIds.remove(user.id);
                      } else {
                        _assigneeIds.add(user.id);
                      }
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'วันที่สิ้นสุด',
              style: TextStyle(
                color: workText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showWorkDueDatePicker(
                  context,
                  initialDate: _dueDate,
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: dueDateIsPast
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dueDateIsPast
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: dueDateIsPast ? const Color(0xFFDC2626) : workBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      DateFormat('dd MMMM yyyy', 'th').format(_dueDate),
                      style: TextStyle(
                        color: dueDateIsPast
                            ? const Color(0xFFDC2626)
                            : workText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (dueDateIsPast) ...[
              const SizedBox(height: 6),
              const Text(
                'วันที่สิ้นสุดผ่านมาแล้ว แต่ยังบันทึกได้',
                style: TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('บันทึกการแก้ไข'),
                style: FilledButton.styleFrom(
                  backgroundColor: workBlue,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _editInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: workBlue, width: 1.4),
      ),
    );
  }
}
