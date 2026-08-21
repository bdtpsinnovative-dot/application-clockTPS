part of '../task_board_page.dart';

class _CardDetailSheet extends StatefulWidget {
  const _CardDetailSheet({
    required this.taskId,
    required this.listName,
    required this.card,
    required this.service,
    required this.canEdit,
    required this.onChanged,
  });

  final String taskId;
  final String listName;
  final TaskCardRecord card;
  final AuthFlowService service;
  final bool canEdit;
  final VoidCallback onChanged;

  @override
  State<_CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends State<_CardDetailSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _adminCommentController;

  late String _status;
  late String _priority;
  DateTime? _dueDate;
  late List<CardAttachment> _attachments;
  late List<String> _assigneeIds;
  late List<UserSummary> _assignees;
  bool _saving = false;
  bool _loadingLatest = false;

  bool get _canEditAdminComment {
    final role = widget.service.currentUser?.role;
    return role == 'admin' || role == 'hr';
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _descriptionController = TextEditingController(
      text: widget.card.description,
    );
    _adminCommentController = TextEditingController(
      text: widget.card.adminComment ?? '',
    );
    _status = widget.card.status;
    _priority = widget.card.priority;
    _dueDate = widget.card.dueDate;
    _attachments = List<CardAttachment>.from(widget.card.attachments);
    _assigneeIds = List<String>.from(widget.card.assigneeIds);
    _assignees = List<UserSummary>.from(widget.card.assignees);

    Future.microtask(_refreshLatestCard);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _adminCommentController.dispose();
    super.dispose();
  }

  void _applyCard(TaskCardRecord card) {
    _titleController.text = card.title;
    _descriptionController.text = card.description;
    _adminCommentController.text = card.adminComment ?? '';
    _status = card.status;
    _priority = card.priority;
    _dueDate = card.dueDate;
    _attachments = List<CardAttachment>.from(card.attachments);
    _assigneeIds = List<String>.from(card.assigneeIds);
    _assignees = List<UserSummary>.from(card.assignees);
  }

  Future<void> _refreshLatestCard() async {
    if (!mounted) return;
    setState(() => _loadingLatest = true);
    try {
      final board = await widget.service.getTrelloBoard(widget.taskId);
      for (final list in board) {
        for (final card in list.cards) {
          if (card.id == widget.card.id && mounted) {
            setState(() => _applyCard(card));
            return;
          }
        }
      }
    } catch (error) {
      debugPrint('Failed to refresh card details: $error');
    } finally {
      if (mounted) setState(() => _loadingLatest = false);
    }
  }

  Future<void> _saveCard() async {
    if (!widget.canEdit || _titleController.text.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.service.updateTaskCard(
        widget.card.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        status: _status,
        priority: _priority,
        dueDate: _dueDate,
        adminComment: _adminCommentController.text.trim(),
      );
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        _showMessage('บันทึกข้อมูลงานไม่สำเร็จ: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCard() async {
    if (!widget.canEdit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบงาน'),
        content: Text('ต้องการลบงาน "${_titleController.text}" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.service.deleteTaskCard(widget.card.id);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showMessage('ลบงานไม่สำเร็จ: $error');
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showWorkDueDatePicker(
      context,
      initialDate: _dueDate ?? DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _uploadAttachments() async {
    if (!widget.canEdit) return;
    try {
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

      for (final pickedFile in result.files) {
        final path = pickedFile.path;
        if (path == null || path.isEmpty) continue;
        final file = File(path);
        final lowerName = pickedFile.name.toLowerCase();
        final isImage =
            lowerName.endsWith('.jpg') ||
            lowerName.endsWith('.jpeg') ||
            lowerName.endsWith('.png') ||
            lowerName.endsWith('.webp');

        setState(() => _saving = true);
        final url = await widget.service.uploadImage(file);
        final attachment = await widget.service.createCardAttachment(
          widget.card.id,
          url: url,
          name: pickedFile.name,
          type: isImage ? 'image' : 'file',
        );
        if (mounted) setState(() => _attachments.add(attachment));
      }
      widget.onChanged();
    } catch (error) {
      if (mounted) _showMessage('แนบไฟล์ไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _attachLink() async {
    if (!widget.canEdit) return;
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แนบลิงก์'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'ชื่อเอกสาร'),
            ),
            TextField(
              controller: urlController,
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
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    final url = urlController.text.trim();
    if (confirmed != true || url.isEmpty) return;
    try {
      final attachment = await widget.service.createCardAttachment(
        widget.card.id,
        url: url,
        name: nameController.text.trim().isEmpty
            ? url
            : nameController.text.trim(),
        type: 'link',
      );
      if (mounted) setState(() => _attachments.add(attachment));
      widget.onChanged();
    } catch (error) {
      if (mounted) _showMessage('แนบลิงก์ไม่สำเร็จ: $error');
    }
  }

  Future<void> _removeAttachment(CardAttachment attachment) async {
    if (!widget.canEdit) return;
    try {
      await widget.service.deleteCardAttachment(attachment.id);
      if (mounted) setState(() => _attachments.remove(attachment));
      widget.onChanged();
    } catch (error) {
      if (mounted) _showMessage('ลบไฟล์แนบไม่สำเร็จ: $error');
    }
  }

  void _showAttachment(CardAttachment attachment) {
    final url = resolveFullR2Url(attachment.url, widget.service.baseUrl);
    if (attachment.type == 'image') {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      );
    } else {
      _showMessage(url);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final canEditAdminComment = widget.canEdit && _canEditAdminComment;

    return DefaultTabController(
      length: 2,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.92,
          child: Column(
            children: [
              _buildHeader(),
              _buildTabs(),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGeneralTab(context),
                    _buildDocsTab(canEditAdminComment),
                  ],
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: Color(0xFF6366F1),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.listName} › งาน',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: workMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'แก้ไขข้อมูลงาน',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: workText,
                  ),
                ),
              ],
            ),
          ),
          if (_loadingLatest)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (widget.canEdit)
            IconButton(
              onPressed: _saving ? null : _deleteCard,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              tooltip: 'ลบงาน',
            ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            tooltip: 'ปิด',
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: const TabBar(
        indicatorColor: workBlue,
        indicatorWeight: 2.5,
        labelColor: workBlue,
        unselectedLabelColor: Color(0xFF64748B),
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        tabs: [
          Tab(text: 'ข้อมูลทั่วไป (General Info)'),
          Tab(text: 'เอกสาร & หมายเหตุ (Docs & Notes)'),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('ชื่องาน'),
          const SizedBox(height: 6),
          _textField(
            controller: _titleController,
            enabled: widget.canEdit,
            hintText: 'ชื่องาน...',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _dateField(
                  label: 'วันกำหนดส่ง',
                  value: _dueDate,
                  onTap: widget.canEdit ? _pickDueDate : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _priorityField()),
            ],
          ),
          const SizedBox(height: 14),
          _label('สถานะงาน (Status)'),
          const SizedBox(height: 6),
          _statusField(),
          const SizedBox(height: 14),
          _label('มอบหมายให้ (Assignees)'),
          const SizedBox(height: 8),
          CardAssigneePicker(
            key: ValueKey(_assigneeIds.join(',')),
            service: widget.service,
            taskId: widget.taskId,
            cardId: widget.card.id,
            initialAssigneeIds: _assigneeIds,
            initialAssignees: _assignees,
            isReadOnly: !widget.canEdit,
            onAssigneesChanged: (ids, users) {
              if (!mounted) return;
              setState(() {
                _assigneeIds = List<String>.from(ids);
                _assignees = List<UserSummary>.from(users);
              });
              widget.onChanged();
            },
          ),
          const SizedBox(height: 14),
          _label('รายละเอียดเพิ่มเติม (Details)'),
          const SizedBox(height: 6),
          _textField(
            controller: _descriptionController,
            enabled: widget.canEdit,
            hintText: 'กรอกรายละเอียดของงานนี้...',
            maxLines: 4,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDocsTab(bool canEditAdminComment) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('NOTE / Remark (ความคิดเห็นจากผู้ดูแล)'),
          const SizedBox(height: 6),
          _textField(
            controller: _adminCommentController,
            enabled: canEditAdminComment,
            hintText: 'เพิ่มคำอธิบายหรือความคิดเห็นจากผู้ดูแล...',
            maxLines: 5,
            fillColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.attach_file_rounded, size: 18, color: workBlue),
              const SizedBox(width: 6),
              _label('เอกสารแนบ & ลิงก์ไฟล์งาน (Attachments)'),
            ],
          ),
          const SizedBox(height: 8),
          if (_attachments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text(
                  'ยังไม่มีเอกสารแนบในงานนี้',
                  style: TextStyle(fontSize: 12.5, color: workMuted),
                ),
              ),
            )
          else
            Column(
              children: _attachments
                  .map((attachment) => _attachmentRow(attachment))
                  .toList(),
            ),
          if (widget.canEdit) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _uploadAttachments,
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                    label: const Text(
                      'แนบไฟล์',
                      style: TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFA5B4FC)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _attachLink,
                    icon: const Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    label: const Text(
                      'แนบลิงก์',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF6EE7B7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _attachmentRow(CardAttachment attachment) {
    final icon = attachment.type == 'link'
        ? Icons.link_rounded
        : Icons.attach_file_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: workBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.name.isEmpty ? attachment.url : attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: workText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _showAttachment(attachment),
            child: const Text('เปิด'),
          ),
          if (widget.canEdit)
            IconButton(
              onPressed: () => _removeAttachment(attachment),
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
              tooltip: 'ลบไฟล์แนบ',
            ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13,
      color: workText,
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required bool enabled,
    required String hintText,
    int maxLines = 1,
    Color fillColor = const Color(0xFFF8FAFC),
    Color borderColor = const Color(0xFFE2E8F0),
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13, color: workText),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.all(12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: workBlue, width: 1.5),
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value == null ? 'เลือกวันส่ง' : _formatCardDate(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: value == null ? workMuted : workText,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: workMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _priorityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('ความสำคัญ (Priority)'),
        const SizedBox(height: 6),
        _dropdownBox(
          value: _priority,
          enabled: widget.canEdit,
          items: const [
            DropdownMenuItem(value: 'low', child: Text('ต่ำ (Low)')),
            DropdownMenuItem(value: 'medium', child: Text('ปานกลาง (Medium)')),
            DropdownMenuItem(value: 'high', child: Text('สูง (High)')),
            DropdownMenuItem(value: 'urgent', child: Text('เร่งด่วน (Urgent)')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _priority = value);
          },
        ),
      ],
    );
  }

  Widget _statusField() {
    return _dropdownBox(
      value: _status,
      enabled: widget.canEdit,
      items: const [
        DropdownMenuItem(
          value: 'pending',
          child: Text('รอดำเนินการ (Pending)'),
        ),
        DropdownMenuItem(
          value: 'in_progress',
          child: Text('กำลังทำ (In Progress)'),
        ),
        DropdownMenuItem(
          value: 'completed',
          child: Text('เสร็จสิ้น (Completed)'),
        ),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _status = value);
      },
    );
  }

  Widget _dropdownBox({
    required String value,
    required bool enabled,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: const TextStyle(fontSize: 12, color: workText),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(color: workMuted, fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: widget.canEdit && !_saving ? _saveCard : null,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกข้อมูล'),
            style: FilledButton.styleFrom(
              backgroundColor: workBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCardDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
