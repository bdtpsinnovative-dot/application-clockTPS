import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/work_models.dart';
import '../../widgets/priority_badge.dart';
import '../../services/auth_flow_service.dart';
import 'deliverable_comment_section.dart';
import 'deliverable_editor_sheet.dart';
import 'project_detail_style.dart';
import 'project_deliverable_card.dart';
import 'project_media_url.dart';

class ProjectDeliverableDetailPage extends StatefulWidget {
  const ProjectDeliverableDetailPage({
    super.key,
    required this.projectId,
    required this.deliverable,
    required this.service,
    required this.canEdit,
    required this.defaultAssigneeIds,
    required this.onChanged,
  });

  final String projectId;
  final TaskListRecord deliverable;
  final AuthFlowService service;
  final bool canEdit;
  final List<String> defaultAssigneeIds;
  final VoidCallback onChanged;

  @override
  State<ProjectDeliverableDetailPage> createState() =>
      _ProjectDeliverableDetailPageState();
}

class _ProjectDeliverableDetailPageState
    extends State<ProjectDeliverableDetailPage> {
  late TaskListRecord _deliverable;
  List<UserSummary> _members = const [];
  bool _updatingStatus = false;

  bool get _isAdmin => widget.service.currentUser?.role == 'admin';

  @override
  void initState() {
    super.initState();
    _deliverable = widget.deliverable;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.service.getTaskMembers(widget.projectId);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
  }

  Future<void> _reload() async {
    final items = await widget.service.getTrelloBoard(widget.projectId);
    final updated = items
        .where((item) => item.id == _deliverable.id)
        .firstOrNull;
    if (updated != null && mounted) setState(() => _deliverable = updated);
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ProjectDetailStyle.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DeliverableEditorSheet(
        projectId: widget.projectId,
        service: widget.service,
        initial: _deliverable,
        defaultAssigneeIds: widget.defaultAssigneeIds,
      ),
    );
    if (saved == true) {
      await _reload();
      widget.onChanged();
    }
  }

  Future<void> _setStatus(String status) async {
    if (_updatingStatus || status == _deliverable.status) return;
    setState(() => _updatingStatus = true);
    try {
      final updated = await widget.service.updateTaskList(
        _deliverable.id,
        status: status,
      );
      if (!mounted) return;
      if (updated != null) {
        setState(() => _deliverable = updated);
      } else {
        await _reload();
      }
      if (!mounted) return;
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'in_review'
                ? 'ส่งงานให้ผู้ตรวจแล้ว'
                : 'อัปเดตสถานะเรียบร้อย',
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
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _openAttachment(TaskListAttachment attachment) async {
    var raw = attachment.url.trim();
    if (raw.startsWith('r2://')) {
      raw = raw.replaceFirst(
        'r2://',
        'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
      );
    }
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เปิดไฟล์หรือลิงก์ไม่สำเร็จ')),
      );
    }
  }

  String get _primaryActionLabel {
    if (_deliverable.status == 'completed') return 'เปิดงานอีกครั้ง';
    if (_isAdmin && _deliverable.status == 'in_review') return 'อนุมัติงาน';
    return 'ส่งงาน';
  }

  String get _primaryActionStatus {
    if (_deliverable.status == 'completed') return 'in_progress';
    if (_isAdmin && _deliverable.status == 'in_review') return 'completed';
    return 'in_review';
  }

  @override
  Widget build(BuildContext context) {
    final status = deliverableStatusStyle(_deliverable.status);
    final assignees = _members
        .where((member) => _deliverable.assigneeIds.contains(member.id))
        .toList();

    return Scaffold(
      backgroundColor: ProjectDetailStyle.canvas,
      appBar: AppBar(
        backgroundColor: ProjectDetailStyle.surface,
        surfaceTintColor: ProjectDetailStyle.surface,
        leadingWidth: 48,
        leading: IconButton(
          tooltip: 'ย้อนกลับ',
          onPressed: () => Navigator.maybePop(context),
          iconSize: ProjectDetailStyle.iconMedium,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'รายละเอียดงาน',
          style: TextStyle(
            color: ProjectDetailStyle.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (widget.canEdit)
            IconButton(
              tooltip: 'แก้ไข',
              onPressed: _edit,
              iconSize: ProjectDetailStyle.iconMedium,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
        children: [
          Text(
            _deliverable.name,
            style: const TextStyle(
              color: ProjectDetailStyle.ink,
              fontSize: 25,
              height: 1.25,
              letterSpacing: -0.55,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _DetailMeta(
                label: 'สถานะ',
                value: status.label,
                icon: Icons.circle,
                iconColor: status.color,
              ),
              _DetailMeta(
                label: 'กำหนดส่ง',
                value: _deliverable.dueDate == null
                    ? 'ยังไม่กำหนด'
                    : DateFormat(
                        'dd MMM yyyy',
                        'th',
                      ).format(_deliverable.dueDate!),
                icon: Icons.calendar_today_outlined,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Text(
                      'ความสำคัญ: ',
                      style: TextStyle(
                        color: ProjectDetailStyle.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    PriorityBadge(
                      priority: _deliverable.priority,
                      isCompact: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: ProjectDetailStyle.line),
          const SizedBox(height: 14),
          const Text(
            'รายละเอียด',
            style: TextStyle(
              color: ProjectDetailStyle.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _deliverable.description.trim().isEmpty
                ? 'ยังไม่มีรายละเอียดเพิ่มเติม'
                : _deliverable.description,
            style: TextStyle(
              color: _deliverable.description.trim().isEmpty
                  ? ProjectDetailStyle.muted
                  : ProjectDetailStyle.secondary,
              fontSize: 13,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'ผู้รับผิดชอบ',
            style: TextStyle(
              color: ProjectDetailStyle.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (assignees.isEmpty)
            const Text(
              'ใช้ผู้รับผิดชอบตามโปรเจกต์',
              style: TextStyle(color: ProjectDetailStyle.muted, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final user in assignees)
                  _AssigneeChip(user: user, baseUrl: widget.service.baseUrl),
              ],
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ไฟล์และลิงก์',
                  style: TextStyle(
                    color: ProjectDetailStyle.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.canEdit)
                TextButton.icon(
                  onPressed: _edit,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, ProjectDetailStyle.tapTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(
                    Icons.add_rounded,
                    size: ProjectDetailStyle.iconSmall,
                  ),
                  label: const Text('เพิ่ม'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_deliverable.attachments.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ProjectDetailStyle.surface,
                borderRadius: BorderRadius.circular(
                  ProjectDetailStyle.controlRadius,
                ),
                border: Border.all(color: ProjectDetailStyle.line),
              ),
              child: const Text(
                'ยังไม่มีไฟล์หรือลิงก์แนบ',
                style: TextStyle(color: ProjectDetailStyle.muted, fontSize: 12),
              ),
            )
          else
            ..._deliverable.attachments.map(
              (attachment) => _AttachmentRow(
                attachment: attachment,
                onTap: () => _openAttachment(attachment),
              ),
            ),
          if (_deliverable.adminComment.trim().isNotEmpty) ...[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ProjectDetailStyle.dangerSoft,
                borderRadius: BorderRadius.circular(
                  ProjectDetailStyle.controlRadius,
                ),
                border: Border.all(
                  color: ProjectDetailStyle.danger.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'หมายเหตุจากผู้ตรวจ',
                    style: TextStyle(
                      color: ProjectDetailStyle.danger,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _deliverable.adminComment,
                    style: const TextStyle(
                      color: ProjectDetailStyle.ink,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          DeliverableCommentSection(
            service: widget.service,
            taskId: widget.projectId,
            deliverableId: _deliverable.id,
            isReadOnly: !widget.canEdit,
          ),
        ],
      ),
      bottomNavigationBar: widget.canEdit
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                decoration: const BoxDecoration(
                  color: ProjectDetailStyle.surface,
                  border: Border(
                    top: BorderSide(color: ProjectDetailStyle.line),
                  ),
                ),
                child: Row(
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'เปลี่ยนสถานะ',
                      onSelected: _setStatus,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'pending',
                          child: Text('ยังไม่เริ่ม'),
                        ),
                        PopupMenuItem(
                          value: 'in_progress',
                          child: Text('กำลังทำ'),
                        ),
                        PopupMenuItem(
                          value: 'in_review',
                          child: Text('ส่งงานแล้ว'),
                        ),
                        PopupMenuItem(
                          value: 'completed',
                          child: Text('เสร็จแล้ว'),
                        ),
                      ],
                      child: Container(
                        height: ProjectDetailStyle.actionHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            ProjectDetailStyle.controlRadius,
                          ),
                          border: Border.all(color: ProjectDetailStyle.line),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: ProjectDetailStyle.iconSmall,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'เปลี่ยนสถานะ',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: ProjectDetailStyle.actionHeight,
                        child: FilledButton(
                          onPressed: _updatingStatus
                              ? null
                              : () => _setStatus(_primaryActionStatus),
                          style: FilledButton.styleFrom(
                            backgroundColor: ProjectDetailStyle.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ProjectDetailStyle.controlRadius,
                              ),
                            ),
                          ),
                          child: _updatingStatus
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_primaryActionLabel),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _DetailMeta extends StatelessWidget {
  const _DetailMeta({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = ProjectDetailStyle.secondary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 144,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ProjectDetailStyle.muted,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                icon,
                size: icon == Icons.circle ? 7 : ProjectDetailStyle.iconTiny,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ProjectDetailStyle.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssigneeChip extends StatelessWidget {
  const _AssigneeChip({required this.user, required this.baseUrl});

  final UserSummary user;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final rawUrl = user.resolvedAvatarUrl ?? user.avatarUrl;
    final avatarUrl = resolveProjectMediaUrl(rawUrl, baseUrl);
    final hasAvatar = avatarUrl.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: ProjectDetailStyle.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: ProjectDetailStyle.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: ProjectDetailStyle.soft,
            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
            onBackgroundImageError: hasAvatar ? (error, stack) {} : null,
            child: !hasAvatar
                ? Text(
                    user.firstName.isEmpty ? '?' : user.firstName[0],
                    style: const TextStyle(
                      color: ProjectDetailStyle.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 7),
          Text(
            user.fullName,
            style: const TextStyle(
              color: ProjectDetailStyle.ink,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment, required this.onTap});

  final TaskListAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: ProjectDetailStyle.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ProjectDetailStyle.controlRadius),
          side: const BorderSide(color: ProjectDetailStyle.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ProjectDetailStyle.controlRadius),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ProjectDetailStyle.soft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    attachment.type == 'link'
                        ? Icons.link_rounded
                        : Icons.description_outlined,
                    color: ProjectDetailStyle.secondary,
                    size: ProjectDetailStyle.iconSmall,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ProjectDetailStyle.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        attachment.type == 'link' ? 'ลิงก์' : 'ไฟล์แนบ',
                        style: const TextStyle(
                          color: ProjectDetailStyle.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: ProjectDetailStyle.muted,
                  size: ProjectDetailStyle.iconSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
