part of '../task_board_page.dart';

extension _TaskListDetailSheetLauncher on _TaskBoardPageState {
  void _showTaskListDetailSheet(TaskListRecord list) {
    final user = widget.service.currentUser;
    final canEdit =
        user?.role == 'admin' ||
        _members.any((member) => member.id == user?.id) ||
        user?.id == widget.task.assignedBy ||
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

  bool get _canSubmitRevision =>
      widget.canEdit &&
      const {'in_review', 'completed', 'revision'}.contains(_status);

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

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SubmitRevisionSheet(
        taskListName: widget.list.name,
        initialReason: _commentController.text.trim(),
      ),
    );

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
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: Color(0xFFE11D48),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'ยืนยันการลบงาน',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'การดำเนินการนี้ไม่สามารถย้อนกลับได้',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'ต้องการลบงาน "${_nameController.text}" หรือไม่?',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text(
                          'ลบงานนี้',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      useSafeArea: true,
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
    final attachment = await showModalBottomSheet<TaskListAttachment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AttachLinkSheet(),
    );
    if (attachment != null && mounted) {
      setState(() => _attachments.add(attachment));
    }
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
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  if (_canSubmitRevision) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('task-list-submit-revision-button'),
                        onPressed: !_saving && !_submittingRevision
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
                  ],
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

class _SubmitRevisionSheet extends StatefulWidget {
  const _SubmitRevisionSheet({
    required this.taskListName,
    this.initialReason = '',
  });

  final String taskListName;
  final String initialReason;

  @override
  State<_SubmitRevisionSheet> createState() => _SubmitRevisionSheetState();
}

class _SubmitRevisionSheetState extends State<_SubmitRevisionSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialReason);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.assignment_return_rounded,
                      color: Color(0xFFE11D48),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'ส่งแก้ไขงานย่อย',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ส่งคืนงานย่อยเพื่อให้ผู้รับผิดชอบปรับปรุงแก้ไข',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFFE11D48),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9F1239),
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(text: 'งาน '),
                            TextSpan(
                              text: '“${widget.taskListName}”',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(
                              text:
                                  ' จะถูกเปลี่ยนสถานะเป็น "แก้ไข" และส่งแจ้งเตือนไปยังผู้รับผิดชอบงานย่อยนี้',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'รายละเอียดสิ่งที่ต้องแก้ไข *',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText:
                      'ระบุจุดที่ต้องปรับปรุงแก้ไข เช่น รูปแบบไม่ตรงตามข้อกำหนด...',
                  hintStyle:
                      const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFE11D48), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 17),
                      label: const Text(
                        'ยืนยันส่งแก้ไข',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

class _AttachLinkSheet extends StatefulWidget {
  const _AttachLinkSheet();

  @override
  State<_AttachLinkSheet> createState() => _AttachLinkSheetState();
}

class _AttachLinkSheetState extends State<_AttachLinkSheet> {
  late final TextEditingController nameController;
  late final TextEditingController urlController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    urlController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    super.dispose();
  }

  void _submit() {
    final url = urlController.text.trim();
    if (url.isEmpty) return;
    Navigator.pop(
      context,
      TaskListAttachment(
        name: nameController.text.trim().isEmpty
            ? url
            : nameController.text.trim(),
        url: url,
        type: 'link',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      color: Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'แนบลิงก์อ้างอิง',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'เพิ่มลิงก์หรือไฟล์แนบจากภายนอก',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'ชื่อลิงก์ / ชื่อเอกสาร',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'เช่น ไฟล์บน Google Drive / Canva',
                  hintStyle:
                      const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'URL ลิงก์ *',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'https://...',
                  hintStyle:
                      const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_link_rounded, size: 17),
                      label: const Text(
                        'แนบลิงก์',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

