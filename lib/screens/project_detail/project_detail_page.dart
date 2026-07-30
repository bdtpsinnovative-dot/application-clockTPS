import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/work_models.dart';
import '../../services/auth_flow_service.dart';
import 'deliverable_editor_sheet.dart';
import 'project_deliverable_detail_page.dart';
import 'project_detail_style.dart';
import 'project_detail_view_model.dart';
import 'project_deliverable_card.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.project,
    required this.service,
    required this.onChanged,
    this.brandName,
    this.categoryName,
  });

  final TaskRecord project;
  final AuthFlowService service;
  final VoidCallback onChanged;
  final String? brandName;
  final String? categoryName;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late final ProjectDetailViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  bool get _canEdit {
    final user = widget.service.currentUser;
    if (user == null) return false;
    return user.role == 'admin' ||
        widget.project.assignedBy == user.id ||
        widget.project.assignedTo == user.id ||
        widget.project.assigneeIds.contains(user.id);
  }

  List<String> get _defaultAssigneeIds {
    if (widget.project.assigneeIds.isNotEmpty) {
      return widget.project.assigneeIds;
    }
    if (widget.project.assignedTo.trim().isNotEmpty) {
      return [widget.project.assignedTo];
    }
    return const [];
  }

  List<String> _assigneeIdsFor(TaskListRecord deliverable) {
    final ids = deliverable.assigneeIds.isNotEmpty
        ? deliverable.assigneeIds
        : _defaultAssigneeIds;
    return ids.toSet().toList(growable: false);
  }

  List<UserSummary> _assigneesFor(TaskListRecord deliverable) {
    final ids = _assigneeIdsFor(deliverable).toSet();
    return _viewModel.members
        .where((member) => ids.contains(member.id))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _viewModel = ProjectDetailViewModel(
      service: widget.service,
      project: widget.project,
    )..addListener(_onViewModelChanged);
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onViewModelChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await _viewModel.load();
    widget.onChanged();
  }

  Future<void> _showCreateDeliverable() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ProjectDetailStyle.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DeliverableEditorSheet(
        projectId: widget.project.id,
        service: widget.service,
        defaultAssigneeIds: _defaultAssigneeIds,
        onCreate: _viewModel.createDeliverable,
      ),
    );
    if (created == true) widget.onChanged();
  }

  Future<void> _openDeliverable(TaskListRecord deliverable) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProjectDeliverableDetailPage(
          projectId: widget.project.id,
          deliverable: deliverable,
          service: widget.service,
          canEdit: _canEdit,
          defaultAssigneeIds: _defaultAssigneeIds,
          onChanged: () {
            _viewModel.refreshAfterDetailChange();
            widget.onChanged();
          },
        ),
      ),
    );
    await _viewModel.refreshAfterDetailChange();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProjectDetailStyle.canvas,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: ProjectDetailStyle.header,
        surfaceTintColor: ProjectDetailStyle.header,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        leadingWidth: 48,
        leading: IconButton(
          tooltip: 'ย้อนกลับ',
          onPressed: () => Navigator.maybePop(context),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.project.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            if (widget.brandName != null || widget.categoryName != null)
              Text(
                [if (widget.brandName != null) widget.brandName, if (widget.categoryName != null) widget.categoryName].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFDBEAFE),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'รีโหลดข้อมูล',
            onPressed: _viewModel.isLoading ? null : _refresh,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.small(
              onPressed: _viewModel.isBusy('create-deliverable')
                  ? null
                  : _showCreateDeliverable,
              tooltip: 'เพิ่มงาน',
              backgroundColor: ProjectDetailStyle.accent,
              foregroundColor: Colors.white,
              elevation: 2,
              child: const Icon(
                Icons.add_rounded,
                size: 20,
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: ProjectDetailStyle.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 104),
          children: [
            // Project Progress Banner Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: ProjectDetailStyle.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'กำหนดส่ง: ${DateFormat('dd MMMM yyyy', 'th').format(widget.project.dueDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_viewModel.completedCount}/${_viewModel.totalCount} งาน',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _viewModel.progress,
                      minHeight: 5,
                      color: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'รายการงานในโปรเจกต์',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      letterSpacing: -0.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_viewModel.visibleDeliverables.length} รายการ',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildSearch(),
            const SizedBox(height: 10),
            _buildStatusFilters(),
            const SizedBox(height: 14),
            _buildDeliverableList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: _viewModel.setSearchQuery,
      decoration: InputDecoration(
        hintText: 'ค้นหางานในโปรเจกต์',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        hintStyle: const TextStyle(fontSize: 12.5),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 40,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: ProjectDetailStyle.iconSmall,
          color: ProjectDetailStyle.muted,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: ProjectDetailStyle.tapTarget,
          minHeight: ProjectDetailStyle.tapTarget,
        ),
        suffixIcon: _viewModel.searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'ล้างคำค้นหา',
                iconSize: ProjectDetailStyle.iconSmall,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _searchController.clear();
                  _viewModel.setSearchQuery('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
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
      ),
    );
  }

  Widget _buildStatusFilters() {
    const filters = <(String, String?)>[
      ('ทั้งหมด', null),
      ('ยังไม่เริ่ม', 'pending'),
      ('กำลังทำ', 'in_progress'),
      ('ส่งแล้ว', 'in_review'),
      ('เสร็จแล้ว', 'completed'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            _QuietFilter(
              label: filter.$1,
              selected: _viewModel.selectedStatus == filter.$2,
              onTap: () => _viewModel.setStatusFilter(filter.$2),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliverableList() {
    if (_viewModel.isLoading && _viewModel.deliverables.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 72),
        child: Center(
          child: CircularProgressIndicator(color: ProjectDetailStyle.accent),
        ),
      );
    }
    if (_viewModel.error != null && _viewModel.deliverables.isEmpty) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'โหลดรายการงานไม่สำเร็จ',
        description: _viewModel.error!,
        actionLabel: 'ลองอีกครั้ง',
        onAction: _viewModel.load,
      );
    }
    if (_viewModel.deliverables.isEmpty) {
      return _EmptyState(
        icon: Icons.assignment_outlined,
        title: 'ยังไม่มีรายการงาน',
        description:
            'เพิ่มงานแรกของโปรเจกต์ พร้อมกำหนดวันส่งและผู้รับผิดชอบได้ทันที',
        actionLabel: _canEdit ? 'เพิ่มงาน' : null,
        onAction: _canEdit ? _showCreateDeliverable : null,
      );
    }
    if (_viewModel.visibleDeliverables.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'ไม่พบงานที่ค้นหา',
        description: 'ลองเปลี่ยนคำค้นหาหรือตัวกรองสถานะ',
      );
    }

    return Column(
      children: [
        for (final deliverable in _viewModel.visibleDeliverables) ...[
          ProjectDeliverableCard(
            key: ValueKey(deliverable.id),
            deliverable: deliverable,
            assignees: _assigneesFor(deliverable),
            assigneeCount: _assigneeIdsFor(deliverable).length,
            baseUrl: widget.service.baseUrl,
            onTap: () => _openDeliverable(deliverable),
            onStatusChanged: _canEdit
                ? (newStatus) async {
                    try {
                      await _viewModel.updateDeliverableStatus(
                        deliverable.id,
                        newStatus,
                      );
                      widget.onChanged();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('อัปเดตสถานะงานเรียบร้อย'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('อัปเดตสถานะล้มเหลว: $e')),
                      );
                    }
                  }
                : null,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ProjectHeaderTitle extends StatelessWidget {
  const _ProjectHeaderTitle({
    required this.project,
    required this.completed,
    required this.total,
    required this.progress,
    this.brandName,
    this.categoryName,
  });

  final TaskRecord project;
  final int completed;
  final int total;
  final double progress;
  final String? brandName;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final labels = [
      if (brandName?.trim().isNotEmpty == true) brandName!,
      if (categoryName?.trim().isNotEmpty == true) categoryName!,
    ];
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labels.isEmpty ? 'โปรเจกต์' : labels.join('  •  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ProjectDetailStyle.headerMuted,
              fontSize: 10,
              letterSpacing: 0.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            project.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              height: 1.25,
              letterSpacing: -0.3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: ProjectDetailStyle.iconTiny,
                color: ProjectDetailStyle.headerMuted,
              ),
              const SizedBox(width: 5),
              Text(
                DateFormat('dd MMM yyyy', 'th').format(project.dueDate),
                style: const TextStyle(
                  color: ProjectDetailStyle.headerMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$completed/$total งาน',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: ProjectDetailStyle.headerProgress,
              backgroundColor: ProjectDetailStyle.headerTrack,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietFilter extends StatelessWidget {
  const _QuietFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563EB) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF475569),
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      decoration: BoxDecoration(
        color: ProjectDetailStyle.surface,
        borderRadius: BorderRadius.circular(ProjectDetailStyle.cardRadius),
        border: Border.all(color: ProjectDetailStyle.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: ProjectDetailStyle.muted, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ProjectDetailStyle.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ProjectDetailStyle.secondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, ProjectDetailStyle.actionHeight),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
