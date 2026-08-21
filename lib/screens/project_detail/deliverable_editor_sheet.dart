import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/work_models.dart';
import '../../services/auth_flow_service.dart';
import '../../widgets/user_avatar.dart';
import 'project_detail_style.dart';

typedef DeliverableCreateCallback =
    Future<void> Function({
      required String name,
      required String description,
      required String priority,
      required List<String> assigneeIds,
      required List<TaskListAttachment> attachments,
      DateTime? dueDate,
    });

class DeliverableEditorSheet extends StatefulWidget {
  const DeliverableEditorSheet({
    super.key,
    required this.projectId,
    required this.service,
    this.initial,
    this.defaultAssigneeIds = const [],
    this.onCreate,
  });

  final String projectId;
  final AuthFlowService service;
  final TaskListRecord? initial;
  final List<String> defaultAssigneeIds;
  final DeliverableCreateCallback? onCreate;

  @override
  State<DeliverableEditorSheet> createState() => _DeliverableEditorSheetState();
}

class _DeliverableEditorSheetState extends State<DeliverableEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _adminCommentController;
  late String _priority;
  late List<String> _assigneeIds;
  late List<TaskListAttachment> _attachments;
  DateTime? _dueDate;
  List<UserSummary> _members = const [];
  bool _saving = false;
  bool _uploading = false;

  bool get _isEditing => widget.initial != null;
  bool get _isAdmin => widget.service.currentUser?.role == 'admin';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _adminCommentController = TextEditingController(
      text: initial?.adminComment ?? '',
    );
    _priority = initial?.priority ?? 'medium';
    _dueDate = initial?.dueDate;
    _assigneeIds = List.of(
      initial?.assigneeIds.isNotEmpty == true
          ? initial!.assigneeIds
          : widget.defaultAssigneeIds,
    );
    _attachments = List.of(initial?.attachments ?? const []);
    _loadMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _adminCommentController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.service.getTaskMembers(widget.projectId);
      if (mounted) setState(() => _members = members);
    } catch (_) {
      // The editor remains usable with the inherited project assignees.
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _addLink() async {
    final attachment = await showModalBottomSheet<TaskListAttachment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddLinkSheet(),
    );
    if (attachment != null && mounted) {
      setState(() => _attachments.add(attachment));
    }
  }

  Future<void> _pickAndUploadFile() async {
    if (_uploading) return;
    final result = await fp.FilePicker.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await widget.service.uploadImage(File(path));
      if (!mounted) return;
      setState(
        () => _attachments.add(
          TaskListAttachment(
            name: result!.files.single.name,
            url: url,
            type: 'file',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving || _uploading) return;
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await widget.service.updateTaskList(
          widget.initial!.id,
          name: name,
          description: _descriptionController.text.trim(),
          dueDate: _dueDate,
          priority: _priority,
          adminComment: _adminCommentController.text.trim(),
          attachments: _attachments,
          assigneeIds: _assigneeIds,
        );
      } else {
        await widget.onCreate!(
          name: name,
          description: _descriptionController.text.trim(),
          priority: _priority,
          dueDate: _dueDate,
          assigneeIds: _assigneeIds,
          attachments: _attachments,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: ProjectDetailStyle.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isEditing ? 'แก้ไขรายการส่งงาน' : 'เพิ่มรายการส่งงาน',
                  style: const TextStyle(
                    color: ProjectDetailStyle.ink,
                    fontSize: 19,
                    letterSpacing: -0.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'ปิด',
                onPressed: () => Navigator.pop(context),
                iconSize: ProjectDetailStyle.iconMedium,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            autofocus: !_isEditing,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              label: 'ชื่องาน',
              hint: 'ระบุผลงานหรือสิ่งที่ต้องส่ง',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            decoration: _decoration(
              label: 'รายละเอียด',
              hint: 'อธิบายผลลัพธ์ที่ต้องการให้ชัดเจน',
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDueDate,
            borderRadius: BorderRadius.circular(
              ProjectDetailStyle.controlRadius,
            ),
            child: InputDecorator(
              decoration: _decoration(label: 'กำหนดส่ง'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dueDate == null
                          ? 'ยังไม่กำหนด'
                          : DateFormat('dd MMM yyyy', 'th').format(_dueDate!),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: ProjectDetailStyle.iconSmall,
                    color: ProjectDetailStyle.secondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'ความสำคัญ',
            style: TextStyle(
              color: ProjectDetailStyle.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in const [
                {
                  'value': 'low',
                  'label': 'ต่ำ',
                  'icon': Icons.keyboard_double_arrow_down_rounded,
                  'color': Color(0xFF0284C7),
                  'bg': Color(0xFFE0F2FE),
                },
                {
                  'value': 'medium',
                  'label': 'ปานกลาง',
                  'icon': Icons.drag_handle_rounded,
                  'color': Color(0xFFD97706),
                  'bg': Color(0xFFFEF3C7),
                },
                {
                  'value': 'high',
                  'label': 'สูง',
                  'icon': Icons.keyboard_double_arrow_up_rounded,
                  'color': Color(0xFFEA580C),
                  'bg': Color(0xFFFFEDD5),
                },
                {
                  'value': 'urgent',
                  'label': 'ด่วนมาก',
                  'icon': Icons.local_fire_department_rounded,
                  'color': Color(0xFFDC2626),
                  'bg': Color(0xFFFEE2E2),
                },
              ])
                Builder(
                  builder: (context) {
                    final isSelected = _priority == opt['value'];
                    final color = opt['color'] as Color;
                    final bg = opt['bg'] as Color;
                    final icon = opt['icon'] as IconData;
                    final label = opt['label'] as String;

                    return InkWell(
                      onTap: () =>
                          setState(() => _priority = opt['value'] as String),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? bg : ProjectDetailStyle.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isSelected ? color : ProjectDetailStyle.line,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 14,
                              color: isSelected
                                  ? color
                                  : ProjectDetailStyle.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? color
                                    : ProjectDetailStyle.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          if (_members.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'ผู้รับผิดชอบ',
              style: TextStyle(
                color: ProjectDetailStyle.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                 for (final member in _members)
                  FilterChip(
                    avatar: UserAvatar(
                      avatarUrl: member.avatarUrl,
                      name: member.displayName,
                      radius: 10,
                    ),
                    label: Text(member.displayName),
                    selected: _assigneeIds.contains(member.id),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _assigneeIds.add(member.id);
                        } else {
                          _assigneeIds.remove(member.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'หลักฐานและไฟล์งาน',
                  style: TextStyle(
                    color: ProjectDetailStyle.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _uploading ? null : _pickAndUploadFile,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, ProjectDetailStyle.tapTarget),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.upload_file_outlined,
                        size: ProjectDetailStyle.iconSmall,
                      ),
                label: const Text('ไฟล์'),
              ),
              TextButton.icon(
                onPressed: _addLink,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, ProjectDetailStyle.tapTarget),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(
                  Icons.link_rounded,
                  size: ProjectDetailStyle.iconSmall,
                ),
                label: const Text('ลิงก์'),
              ),
            ],
          ),
          if (_attachments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ProjectDetailStyle.canvas,
                borderRadius: BorderRadius.circular(
                  ProjectDetailStyle.controlRadius,
                ),
                border: Border.all(color: ProjectDetailStyle.line),
              ),
              child: const Text(
                'ยังไม่มีไฟล์หรือลิงก์แนบ',
                style: TextStyle(
                  color: ProjectDetailStyle.muted,
                  fontSize: 11.5,
                ),
              ),
            )
          else
            ..._attachments.indexed.map(
              (entry) => _AttachmentEditorRow(
                attachment: entry.$2,
                onRemove: () => setState(() => _attachments.removeAt(entry.$1)),
              ),
            ),
          if (_isAdmin) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _adminCommentController,
              minLines: 2,
              maxLines: 4,
              decoration: _decoration(
                label: 'หมายเหตุจากผู้ตรวจ',
                hint: 'ข้อความสำหรับผู้รับผิดชอบ',
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: ProjectDetailStyle.actionHeight,
            child: FilledButton(
              onPressed: _saving || _uploading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: ProjectDetailStyle.accent,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ProjectDetailStyle.controlRadius,
                  ),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(_isEditing ? 'บันทึกการแก้ไข' : 'เพิ่มรายการ'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: ProjectDetailStyle.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ProjectDetailStyle.controlRadius),
        borderSide: const BorderSide(color: ProjectDetailStyle.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ProjectDetailStyle.controlRadius),
        borderSide: const BorderSide(color: ProjectDetailStyle.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ProjectDetailStyle.controlRadius),
        borderSide: const BorderSide(
          color: ProjectDetailStyle.accent,
          width: 1.5,
        ),
      ),
    );
  }
}

class _AttachmentEditorRow extends StatelessWidget {
  const _AttachmentEditorRow({
    required this.attachment,
    required this.onRemove,
  });

  final TaskListAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: ProjectDetailStyle.canvas,
        borderRadius: BorderRadius.circular(ProjectDetailStyle.controlRadius),
        border: Border.all(color: ProjectDetailStyle.line),
      ),
      child: Row(
        children: [
          Icon(
            attachment.type == 'link'
                ? Icons.link_rounded
                : Icons.description_outlined,
            color: ProjectDetailStyle.secondary,
            size: ProjectDetailStyle.iconSmall,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ProjectDetailStyle.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'นำออก',
            onPressed: onRemove,
            iconSize: ProjectDetailStyle.iconSmall,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              color: ProjectDetailStyle.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddLinkSheet extends StatefulWidget {
  const _AddLinkSheet();

  @override
  State<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends State<_AddLinkSheet> {
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
