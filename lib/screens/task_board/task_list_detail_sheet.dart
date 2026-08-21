part of '../task_board_page.dart';

extension _TaskListDetailSheetLauncher on _TaskBoardPageState {
  void _showTaskListDetailSheet(TaskListRecord list) {
    final user = widget.service.currentUser;
    final canEdit =
        user?.role == 'admin' ||
        user?.id == widget.task.assignedTo ||
        widget.task.assigneeIds.contains(user?.id);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _TaskListDetailSheet(
        task: widget.task,
        list: list,
        service: widget.service,
        canEdit: canEdit,
        onChanged: () {
          widget.onRefreshNeeded();
          _loadBoard();
        },
      ),
    );
  }
}

class _TaskListDetailSheet extends StatefulWidget {
  const _TaskListDetailSheet({
    required this.task,
    required this.list,
    required this.service,
    required this.canEdit,
    required this.onChanged,
  });

  final TaskRecord task;
  final TaskListRecord list;
  final AuthFlowService service;
  final bool canEdit;
  final VoidCallback onChanged;

  @override
  State<_TaskListDetailSheet> createState() => _TaskListDetailSheetState();
}

class _TaskListDetailSheetState extends State<_TaskListDetailSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _commentController;
  late String _status;
  late String _priority;
  DateTime? _dueDate;
  late List<TaskListAttachment> _attachments;
  late List<String> _assigneeIds;
  List<UserSummary> _members = [];
  bool _saving = false;
  bool _submittingRevision = false;
  bool _loadingMembers = true;

  bool get _canEditComment {
    final role = widget.service.currentUser?.role;
    return role == 'admin' || role == 'hr';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list.name);
    _descriptionController = TextEditingController(
      text: widget.list.description,
    );
    _commentController = TextEditingController(text: widget.list.adminComment);
    _status = widget.list.status;
    _priority = widget.list.priority;
    _dueDate = widget.list.dueDate;
    _attachments = List<TaskListAttachment>.from(widget.list.attachments);
    _assigneeIds = List<String>.from(widget.list.assigneeIds);
    _members = List<UserSummary>.from(widget.list.assignees);
    _loadMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final loadedMembers = await widget.service.getTaskMembers(widget.task.id);
      final merged = <String, UserSummary>{
        for (final member in widget.list.assignees) member.id: member,
        for (final member in loadedMembers) member.id: member,
      };
      if (mounted) setState(() => _members = merged.values.toList());
    } catch (error) {
      debugPrint('Failed to load task members: $error');
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _save() async {
    if (!widget.canEdit || _nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.service.updateTaskList(
        widget.list.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        status: _status,
        adminComment: _commentController.text.trim(),
        attachments: _attachments,
        assigneeIds: _assigneeIds,
      );
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _message('บันทึกข้อมูลงานไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitRevision() async {
    if (!widget.canEdit || _saving || _submittingRevision) {
      return;
    }

    final reasonController = TextEditingController(
      text: _commentController.text.trim(),
    );
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: Color(0xFFE11D48)),
            SizedBox(width: 8),
            Text('ส่งแก้ไขงานย่อย'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'งาน "${widget.list.name}" จะถูกเปลี่ยนสถานะเป็น "แก้ไข" และแจ้งเตือนผู้รับผิดชอบ',
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'เหตุผล / รายละเอียดที่ต้องแก้ไข *',
                hintText: 'ระบุจุดที่ต้องปรับปรุง...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
            ),
            icon: const Icon(Icons.replay_rounded, size: 17),
            label: const Text('ยืนยันส่งแก้ไข'),
          ),
        ],
      ),
    );
    reasonController.dispose();

    final reasonText = reason?.trim() ?? '';
    if (reasonText.isEmpty || !mounted) return;

    setState(() => _submittingRevision = true);
    try {
      await widget.service.updateTaskList(
        widget.list.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        status: 'revision',
        adminComment: reasonText,
        attachments: _attachments,
        assigneeIds: _assigneeIds,
      );
      widget.onChanged();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่งแก้ไขงานย่อยสำเร็จ')));
    } catch (error) {
      if (mounted) _message('ส่งแก้ไขงานย่อยไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _submittingRevision = false);
    }
  }

  Future<void> _delete() async {
    if (!widget.canEdit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบงาน'),
        content: Text('ต้องการลบงาน "${_nameController.text}" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.service.deleteTaskList(widget.list.id);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _message('ลบงานไม่สำเร็จ: $error');
    }
  }

  void _showActivity() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskListActivitySheet(
        taskId: widget.task.id,
        list: widget.list,
        service: widget.service,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showWorkDueDatePicker(
      context,
      initialDate: _dueDate ?? DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _pickAssignees() async {
    if (!widget.canEdit || _loadingMembers) return;
    final selected = Set<String>.from(_assigneeIds);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'เลือกผู้รับผิดชอบงาน',
                  style: TextStyle(
                    color: workText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final isSelected = selected.contains(member.id);
                      void toggle() {
                        setModalState(() {
                          if (isSelected) {
                            selected.remove(member.id);
                          } else {
                            selected.add(member.id);
                          }
                        });
                      }

                      return ListTile(
                        leading: UserAvatar(
                          avatarUrl: member.avatarUrl,
                          name: member.displayName,
                          radius: 19,
                        ),
                        title: Text(member.displayName),
                        subtitle: Text(member.position),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (_) => toggle(),
                        ),
                        onTap: toggle,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('ยืนยัน'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _assigneeIds = selected.toList());
  }

  Future<void> _uploadFile() async {
    if (!widget.canEdit) return;
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'txt',
      ],
      allowMultiple: true,
    );
    if (result == null) return;
    try {
      setState(() => _saving = true);
      for (final item in result.files) {
        if (item.path == null) continue;
        final url = await widget.service.uploadImage(File(item.path!));
        final isImage = RegExp(
          r'\.(jpg|jpeg|png|webp)$',
          caseSensitive: false,
        ).hasMatch(item.name);
        _attachments.add(
          TaskListAttachment(
            name: item.name,
            url: url,
            type: isImage ? 'image' : 'file',
          ),
        );
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _message('แนบไฟล์ไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _attachLink() async {
    if (!widget.canEdit) return;
    final name = TextEditingController();
    final url = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แนบลิงก์'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'ชื่อเอกสาร'),
            ),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
    if (ok == true && url.text.trim().isNotEmpty && mounted) {
      setState(() {
        _attachments.add(
          TaskListAttachment(
            name: name.text.trim().isEmpty ? url.text.trim() : name.text.trim(),
            url: url.text.trim(),
            type: 'link',
          ),
        );
      });
    }
    name.dispose();
    url.dispose();
  }

  void _showAttachment(TaskListAttachment attachment) {
    final url = resolveFullR2Url(attachment.url, widget.service.baseUrl);
    if (attachment.type == 'image') {
      showDialog<void>(
        context: context,
        builder: (_) =>
            Dialog(child: InteractiveViewer(child: Image.network(url))),
      );
    } else {
      _message(url);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: workBlue, width: 1.5),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: workText,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _select<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) => DropdownButtonFormField<T>(
    value: value,
    isExpanded: true,
    items: items,
    onChanged: widget.canEdit ? onChanged : null,
    decoration: _decoration(''),
  );

  List<DropdownMenuItem<String>> get _statusItems {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'waiting', child: Text('รอรับ')),
      const DropdownMenuItem(value: 'pending', child: Text('รอดำเนินการ')),
      const DropdownMenuItem(value: 'in_progress', child: Text('กำลังทำ')),
      const DropdownMenuItem(value: 'in_review', child: Text('รอตรวจ')),
      const DropdownMenuItem(value: 'revision', child: Text('แก้ไข')),
      const DropdownMenuItem(value: 'completed', child: Text('เสร็จสิ้น')),
    ];

    // Keep legacy or newly introduced backend statuses selectable so a
    // notification cannot crash the detail sheet before the user can update it.
    if (!items.any((item) => item.value == _status)) {
      items.add(DropdownMenuItem(value: _status, child: Text(_status)));
    }
    return items;
  }

  Widget _generalTab() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('ชื่องาน'),
        TextField(
          controller: _nameController,
          readOnly: !widget.canEdit,
          decoration: _decoration('ชื่องาน...'),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('วันกำหนดส่ง'),
                  InkWell(
                    onTap: widget.canEdit ? _pickDate : null,
                    child: InputDecorator(
                      decoration: _decoration('เลือกวันส่ง'),
                      child: Text(
                        _dueDate == null
                            ? 'เลือกวันส่ง'
                            : _formatDate(_dueDate),
                        style: const TextStyle(color: workText, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('ความสำคัญ (Priority)'),
                  _select<String>(
                    value: _priority,
                    items: const [
                      DropdownMenuItem(
                        value: 'low',
                        child: Text('งานไม่รีบ (Low)'),
                      ),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('งานปานกลาง (Medium)'),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: Text('งานสำคัญ (High)'),
                      ),
                      DropdownMenuItem(
                        value: 'urgent',
                        child: Text('งานด่วนมาก (Urgent)'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _priority = value ?? 'medium'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _label('สถานะงาน (Status)'),
        _select<String>(
          value: _status,
          items: _statusItems,
          onChanged: (value) => setState(() => _status = value ?? 'pending'),
        ),
        const SizedBox(height: 20),
        _label('มอบหมายให้ (Assignees)'),
        InkWell(
          onTap: _pickAssignees,
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final member
                  in _members.where((m) => _assigneeIds.contains(m.id)).take(4))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(
                      avatarUrl: member.avatarUrl,
                      name: member.displayName,
                      radius: 17,
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: workText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(Icons.add, color: workMuted, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _label('รายละเอียดเพิ่มเติม (Details)'),
        TextField(
          controller: _descriptionController,
          readOnly: !widget.canEdit,
          minLines: 4,
          maxLines: 6,
          decoration: _decoration('กรอกรายละเอียดของงานนี้...'),
        ),
      ],
    ),
  );

  Widget _docsTab() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('NOTE / Remark (ความคิดเห็นจากผู้ดูแล)'),
        TextField(
          controller: _commentController,
          readOnly: !widget.canEdit || !_canEditComment,
          minLines: 4,
          maxLines: 6,
          decoration: _decoration('เพิ่มคำอธิบายหรือความคิดเห็นจากผู้ดูแล...'),
        ),
        const SizedBox(height: 22),
        _label('เอกสารแนบ & ลิงก์ทำงาน (Attachments)'),
        if (_attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'ยังไม่มีเอกสารแนบในงานนี้',
                style: TextStyle(color: workMuted),
              ),
            ),
          )
        else
          ..._attachments.map(
            (attachment) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                attachment.type == 'image' ? Icons.image_outlined : Icons.link,
                color: workBlue,
              ),
              title: Text(
                attachment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showAttachment(attachment),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: workMuted),
                onPressed: widget.canEdit
                    ? () => setState(() => _attachments.remove(attachment))
                    : null,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.canEdit ? _uploadFile : null,
                icon: const Icon(Icons.attach_file),
                label: const Text('แนบไฟล์'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.canEdit ? _attachLink : null,
                icon: const Icon(Icons.link),
                label: const Text('แนบลิงก์'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: workBlue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'แก้ไขข้อมูลงาน',
                      style: TextStyle(
                        color: workText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_saving)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 4),
                  _headerAction(
                    key: const Key('task-list-activity-button'),
                    tooltip: 'ดูประวัติกิจกรรมของบอร์ดนี้',
                    icon: Icons.access_time_rounded,
                    onPressed: _showActivity,
                  ),
                  _headerAction(
                    tooltip: 'ลบงานนี้',
                    icon: Icons.delete_outline_rounded,
                    onPressed: widget.canEdit ? _delete : null,
                  ),
                  _headerAction(
                    tooltip: 'ปิด',
                    icon: Icons.close_rounded,
                    size: 23,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const TabBar(
              labelColor: workBlue,
              unselectedLabelColor: workMuted,
              indicatorColor: workBlue,
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('ข้อมูลทั่วไป (General Info)'),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('เอกสาร & หมายเหตุ (Docs & Notes)'),
                  ),
                ),
              ],
            ),
            Expanded(child: TabBarView(children: [_generalTab(), _docsTab()])),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('task-list-submit-revision-button'),
                      onPressed:
                          widget.canEdit && !_saving && !_submittingRevision
                          ? _submitRevision
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE11D48),
                        side: const BorderSide(color: Color(0xFFFDA4AF)),
                        minimumSize: const Size(0, 44),
                      ),
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('ส่งแก้ไข'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text('ยกเลิก'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: widget.canEdit && !_saving ? _save : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.save_outlined),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('บันทึกข้อมูล'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerAction({
    Key? key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 20,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: workMuted, size: size),
    );
  }
}
