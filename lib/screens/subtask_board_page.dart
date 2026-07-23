import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class SubtaskBoardPage extends StatefulWidget {
  const SubtaskBoardPage({
    super.key,
    required this.task,
    required this.service,
    required this.onRefreshNeeded,
  });

  final TaskRecord task;
  final AuthFlowService service;
  final VoidCallback onRefreshNeeded;

  @override
  State<SubtaskBoardPage> createState() => _SubtaskBoardPageState();
}

class _SubtaskBoardPageState extends State<SubtaskBoardPage> {
  static const _columns = <_BoardColumn>[
    _BoardColumn(
      status: 'pending',
      label: 'รอทำ',
      color: Color(0xFF64748B),
      background: Color(0xFFF1F5F9),
    ),
    _BoardColumn(
      status: 'in_progress',
      label: 'กำลังทำ',
      color: Color(0xFFEA580C),
      background: Color(0xFFFFF7ED),
    ),
    _BoardColumn(
      status: 'completed',
      label: 'เสร็จแล้ว',
      color: Color(0xFF16A34A),
      background: Color(0xFFF0FDF4),
    ),
  ];

  List<TaskSubItem> _items = [];
  bool _loading = true;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.service.getTaskSubItems(widget.task.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createSubtask() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('เพิ่มงานย่อย'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ชื่องานย่อย',
            hintText: 'เช่น ตรวจข้อความก่อนเผยแพร่',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('เพิ่มงานย่อย'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || !mounted) return;

    setState(() => _adding = true);
    try {
      final item = await widget.service.createTaskSubItem(
        widget.task.id,
        title,
      );
      if (!mounted) return;
      setState(() => _items.add(item));
      widget.onRefreshNeeded();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เพิ่มงานย่อยไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _moveItem(TaskSubItem item, String status) async {
    if (item.status == status) return;
    final index = _items.indexWhere((value) => value.id == item.id);
    if (index == -1) return;

    final previous = _items[index];
    setState(() {
      _items[index] = item.copyWith(
        status: status,
        isDone: status == 'completed',
      );
    });

    try {
      await widget.service.toggleTaskSubItem(item.id, status);
      widget.onRefreshNeeded();
    } catch (error) {
      if (!mounted) return;
      setState(() => _items[index] = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ย้ายงานย่อยไม่สำเร็จ: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: workText,
              ),
            ),
            const Text(
              'กระดานงานย่อย',
              style: TextStyle(fontSize: 11, color: workMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadItems,
            tooltip: 'โหลดใหม่',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adding ? null : _createSubtask,
        backgroundColor: workBlue,
        foregroundColor: Colors.white,
        icon: _adding
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_rounded),
        label: const Text('เพิ่มงานย่อย'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: workMuted),
              const SizedBox(height: 12),
              Text(
                'โหลดกระดานไม่สำเร็จ\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: workMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadItems,
                child: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final columnWidth = width < 600 ? width * 0.84 : 340.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 88, 96),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final column in _columns) ...[
            SizedBox(width: columnWidth, child: _buildColumn(column)),
            const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildColumn(_BoardColumn column) {
    final items =
        _items
            .where((item) => _normalizedStatus(item) == column.status)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return DragTarget<TaskSubItem>(
      onWillAcceptWithDetails: (details) =>
          _normalizedStatus(details.data) != column.status,
      onAcceptWithDetails: (details) => _moveItem(details.data, column.status),
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 480),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: highlighted ? column.background : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted ? column.color : const Color(0xFFE2E8F0),
              width: highlighted ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: column.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      column.label,
                      style: const TextStyle(
                        color: workText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: column.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        color: column.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                _EmptyColumn(color: column.color)
              else
                for (final item in items) _buildDraggableCard(item, column),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableCard(TaskSubItem item, _BoardColumn column) {
    final card = _SubtaskCard(
      item: item,
      column: column,
      onTap: () => _editItem(item),
    );
    return LongPressDraggable<TaskSubItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 280, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.28, child: card),
      child: card,
    );
  }

  Future<void> _editItem(TaskSubItem item) async {
    final updated = await showModalBottomSheet<TaskSubItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SubtaskDetailSheet(item: item, service: widget.service),
    );
    if (updated == null || !mounted) return;

    setState(() {
      final index = _items.indexWhere((value) => value.id == updated.id);
      if (index != -1) _items[index] = updated;
    });
    widget.onRefreshNeeded();
  }

  String _normalizedStatus(TaskSubItem item) {
    if (item.isDone || item.status == 'completed') return 'completed';
    if (item.status == 'in_progress') return 'in_progress';
    return 'pending';
  }
}

class _SubtaskCard extends StatelessWidget {
  const _SubtaskCard({
    required this.item,
    required this.column,
    required this.onTap,
  });

  final TaskSubItem item;
  final _BoardColumn column;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EDF4)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.isDone
                    ? Icons.check_circle_rounded
                    : Icons.drag_indicator_rounded,
                size: 20,
                color: item.isDone ? column.color : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: item.isDone ? workMuted : workText,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        decoration: item.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (_hasEvidence) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (item.linkUrl?.isNotEmpty == true)
                            const Icon(
                              Icons.link_rounded,
                              size: 15,
                              color: workBlue,
                            ),
                          if (item.linkUrl?.isNotEmpty == true &&
                              item.attachmentUrl?.isNotEmpty == true)
                            const SizedBox(width: 8),
                          if (item.attachmentUrl?.isNotEmpty == true)
                            const Icon(
                              Icons.image_outlined,
                              size: 15,
                              color: Color(0xFF7C3AED),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasEvidence =>
      item.linkUrl?.isNotEmpty == true ||
      item.attachmentUrl?.isNotEmpty == true;
}

class _SubtaskDetailSheet extends StatefulWidget {
  const _SubtaskDetailSheet({required this.item, required this.service});

  final TaskSubItem item;
  final AuthFlowService service;

  @override
  State<_SubtaskDetailSheet> createState() => _SubtaskDetailSheetState();
}

class _SubtaskDetailSheetState extends State<_SubtaskDetailSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _linkController;
  late String _status;
  String? _attachmentUrl;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _linkController = TextEditingController(text: widget.item.linkUrl ?? '');
    _status = widget.item.isDone ? 'completed' : widget.item.status;
    if (!const {'pending', 'in_progress', 'completed'}.contains(_status)) {
      _status = 'pending';
    }
    _attachmentUrl = widget.item.attachmentUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await fp.FilePicker.pickFiles(type: fp.FileType.image);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await widget.service.uploadImage(File(path));
      if (mounted) setState(() => _attachmentUrl = url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $error')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่องานย่อย')));
      return;
    }

    setState(() => _saving = true);
    try {
      final link = _linkController.text.trim();
      await widget.service.updateTaskSubItemDetail(
        widget.item.id,
        title: title,
        linkUrl: link.isEmpty ? null : link,
        attachmentUrl: _attachmentUrl,
      );
      if (_status != widget.item.status ||
          (_status == 'completed') != widget.item.isDone) {
        await widget.service.toggleTaskSubItem(widget.item.id, _status);
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        TaskSubItem(
          id: widget.item.id,
          taskId: widget.item.taskId,
          cardId: widget.item.cardId,
          title: title,
          isDone: _status == 'completed',
          status: _status,
          sortOrder: widget.item.sortOrder,
          startDate: widget.item.startDate,
          dueDate: widget.item.dueDate,
          linkUrl: link.isEmpty ? null : link,
          attachmentUrl: _attachmentUrl,
          verificationNotes: widget.item.verificationNotes,
          adminComment: widget.item.adminComment,
          verifications: widget.item.verifications,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openLink(String value) async {
    final normalized =
        value.startsWith('http://') || value.startsWith('https://')
        ? value
        : 'https://$value';
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('เปิดลิงก์นี้ไม่ได้')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullAttachmentUrl = _attachmentUrl == null
        ? null
        : _resolveAttachmentUrl(_attachmentUrl!);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'รายละเอียดงานย่อย',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: workText,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'ชื่องานย่อย',
                prefixIcon: Icon(Icons.checklist_rounded),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'สถานะ',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('รอทำ')),
                DropdownMenuItem(value: 'in_progress', child: Text('กำลังทำ')),
                DropdownMenuItem(value: 'completed', child: Text('เสร็จแล้ว')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _linkController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'ลิงก์ส่งงาน',
                hintText: 'https://...',
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: _linkController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => _openLink(_linkController.text.trim()),
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (fullAttachmentUrl != null && fullAttachmentUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  fullAttachmentUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    alignment: Alignment.center,
                    color: const Color(0xFFF1F5F9),
                    child: const Text('แสดงตัวอย่างรูปไม่ได้'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : _pickImage,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _attachmentUrl == null ? 'แนบรูปภาพ' : 'เปลี่ยนรูปภาพ',
                    ),
                  ),
                ),
                if (_attachmentUrl != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _attachmentUrl = null),
                    tooltip: 'นำรูปออก',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving || _uploading ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('บันทึกการเปลี่ยนแปลง'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveAttachmentUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('r2://')) {
      return trimmed.replaceFirst(
        'r2://',
        'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
      );
    }
    if (trimmed.startsWith('okpr2://')) {
      return trimmed.replaceFirst(
        'okpr2://',
        'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
      );
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${widget.service.baseUrl}$trimmed';
    }
    return '${widget.service.baseUrl}/$trimmed';
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.move_to_inbox_outlined,
            color: color.withValues(alpha: .6),
          ),
          const SizedBox(height: 8),
          const Text(
            'ลากงานย่อยมาวางที่นี่',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: workMuted),
          ),
        ],
      ),
    );
  }
}

class _BoardColumn {
  const _BoardColumn({
    required this.status,
    required this.label,
    required this.color,
    required this.background,
  });

  final String status;
  final String label;
  final Color color;
  final Color background;
}
