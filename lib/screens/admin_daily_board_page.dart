import 'package:flutter/material.dart';
import 'dart:async';

import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/models/task_list_status.dart';
import 'package:hr_management/screens/task_board_page.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/widgets/work_ui.dart';
import '../widgets/user_avatar.dart';

class AdminDailyBoardPage extends StatefulWidget {
  const AdminDailyBoardPage({super.key, required this.service});

  final AuthFlowService service;

  @override
  State<AdminDailyBoardPage> createState() => _AdminDailyBoardPageState();
}

class _AdminDailyBoardPageState extends State<AdminDailyBoardPage> {
  // Match the main TaskBoard's regular near-full-width board page.
  static const double _viewportFraction = 0.96;

  late final PageController _pageController;
  int _currentPage = 0;
  bool _isLoading = true;
  String? _error;
  List<TaskListRecord> _allLists = const [];
  final Set<String> _updatingListIds = <String>{};
  final Map<String, String> _statusOverrides = <String, String>{};
  final Map<String, List<UserSummary>> _fallbackMembersByTaskId = {};
  int _memberLoadToken = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _viewportFraction)
      ..addListener(_handlePageChanged);
    _loadData();
  }

  @override
  void dispose() {
    _pageController
      ..removeListener(_handlePageChanged)
      ..dispose();
    super.dispose();
  }

  void _handlePageChanged() {
    if (!mounted) return;
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  String _effectiveStatus(TaskListRecord list) {
    return _statusOverrides[list.id] ?? list.status;
  }

  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  String _formatDateRange(DateTime? startDate, DateTime? dueDate) {
    if (startDate != null && dueDate != null) {
      return '${_formatDate(startDate)} → ${_formatDate(dueDate)}';
    }
    if (startDate != null) return 'เริ่ม ${_formatDate(startDate)}';
    if (dueDate != null) return 'ครบกำหนด ${_formatDate(dueDate)}';
    return '';
  }

  String _overdueLabel(DateTime? dueDate, {required bool isCompleted}) {
    if (isCompleted || dueDate == null) return '';
    final overdueDays = _todayDate.difference(_dateOnly(dueDate)).inDays;
    return overdueDays > 0 ? 'เลยกำหนด $overdueDays วัน' : '';
  }

  Color _deadlineColor(DateTime? dueDate, {required bool isCompleted}) {
    if (isCompleted) return const Color(0xFF15803D);
    if (dueDate == null) return workMuted;

    final today = _todayDate;
    final daysLeft = _dateOnly(dueDate).difference(today).inDays;
    if (daysLeft < 0) return const Color(0xFFB91C1C);
    if (daysLeft <= 2) return const Color(0xFFB45309);
    return workMuted;
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final lists = await widget.service.getDailyTaskLists();
      if (!mounted) return;

      final serverIds = lists.map((list) => list.id).toSet();
      _statusOverrides.removeWhere((id, _) => !serverIds.contains(id));
      setState(() {
        _allLists = lists;
        _isLoading = false;
      });

      if (lists.any(
        (list) => list.assigneeIds.isNotEmpty && list.assignees.isEmpty,
      )) {
        unawaited(_loadFallbackTaskMembers(lists));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'ไม่สามารถโหลดรายการงานรายวันได้';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFallbackTaskMembers(List<TaskListRecord> lists) async {
    final token = ++_memberLoadToken;
    final taskIds = lists
        .where((list) => list.assigneeIds.isNotEmpty && list.assignees.isEmpty)
        .map((list) => list.taskId)
        .toSet();
    final results = await Future.wait<MapEntry<String, List<UserSummary>>>(
      taskIds.map((taskId) async {
        try {
          return MapEntry(taskId, await widget.service.getTaskMembers(taskId));
        } catch (_) {
          return MapEntry(taskId, const <UserSummary>[]);
        }
      }),
    );

    if (!mounted || token != _memberLoadToken) return;
    setState(() {
      _fallbackMembersByTaskId
        ..clear()
        ..addEntries(results);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: workBackground,
      body: BoardKeyboardDismissRegion(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [workBlue, workSky],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                ),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'งานรายวัน (ทั้งหมด)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'ภาพรวมรายการงานแยกตามวันกำหนดส่ง',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'รีเฟรช',
                onPressed: _isLoading ? null : _loadData,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: workBlue));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: workMuted)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: workBlue),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    return _buildBoard();
  }

  List<TaskListRecord> _sortedLists() {
    final items = [..._allLists];
    items.sort((a, b) {
      final aDue = a.dueDate;
      final bDue = b.dueDate;
      if (aDue == null && bDue == null) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      final byDueDate = aDue.compareTo(bDue);
      return byDueDate == 0 ? a.sortOrder.compareTo(b.sortOrder) : byDueDate;
    });
    return items;
  }

  List<_DailyBoardColumn> _buildColumns() {
    return [_DailyBoardColumn(title: 'งานทั้งหมด', items: _sortedLists())];
  }

  Widget _buildBoard() {
    final columns = _buildColumns();
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: columns.length,
          itemBuilder: (context, index) {
            final column = columns[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 36),
              child: _buildColumn(column),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 10,
          child: Center(
            child: BoardPageIndicator(
              currentPage: _currentPage,
              pageCount: columns.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColumn(_DailyBoardColumn column) {
    final completedCount = column.items
        .where((list) => _effectiveStatus(list) == 'completed')
        .length;
    final completionRatio = column.items.isEmpty
        ? 0.0
        : completedCount / column.items.length;
    final completionPercent = (completionRatio * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.drag_indicator_rounded,
                  color: workMuted,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        column.title,
                        style: const TextStyle(
                          color: workText,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (column.items.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: completionRatio,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  color: completionPercent == 100
                                      ? const Color(0xFF10B981)
                                      : workBlue,
                                  minHeight: 3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$completionPercent%',
                              style: TextStyle(
                                color: completionPercent == 100
                                    ? const Color(0xFF10B981)
                                    : workBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${column.items.length}',
                  style: const TextStyle(
                    color: workMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Expanded(
            child: column.items.isEmpty
                ? const Center(
                    child: Text(
                      'ไม่มีรายการงาน',
                      style: TextStyle(color: workMuted, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      5,
                      6,
                      5,
                      92 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: column.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) =>
                        _buildTaskCard(column.items[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleListCompleted(TaskListRecord list) async {
    if (_updatingListIds.contains(list.id)) return;

    final oldStatus = _effectiveStatus(list);
    final newStatus = oldStatus == 'completed' ? 'pending' : 'completed';
    setState(() {
      _updatingListIds.add(list.id);
      _statusOverrides[list.id] = newStatus;
    });

    try {
      await widget.service.updateTaskList(list.id, status: newStatus);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (oldStatus == list.status) {
          _statusOverrides.remove(list.id);
        } else {
          _statusOverrides[list.id] = oldStatus;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('อัปเดตสถานะงานไม่สำเร็จ')));
    } finally {
      if (mounted) {
        setState(() => _updatingListIds.remove(list.id));
      }
    }
  }

  Widget _buildTaskCard(TaskListRecord list) {
    final status = _effectiveStatus(list);
    final isCompleted = status == 'completed';
    final statusStyle = taskListStatusStyle(status);
    final cardBackground = statusStyle.backgroundColor;
    final cardBorder = statusStyle.borderColor;
    final badgeColor = statusStyle.textColor;
    final badgeLabel = statusStyle.label;
    final dateLabel = _formatDateRange(list.startDate, list.dueDate);
    final overdueLabel = _overdueLabel(list.dueDate, isCompleted: isCompleted);
    final scheduleLabel = overdueLabel.isNotEmpty ? overdueLabel : dateLabel;
    final dateColor = _deadlineColor(list.dueDate, isCompleted: isCompleted);
    final isUpdating = _updatingListIds.contains(list.id);

    return InkWell(
      onTap: isUpdating ? null : () => _showListDetail(list),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 4,
              offset: Offset(0, 1.5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: isCompleted
                  ? 'ทำเครื่องหมายว่ายังไม่เสร็จ'
                  : 'ทำเครื่องหมายว่าเสร็จแล้ว',
              child: GestureDetector(
                onTap: isUpdating ? null : () => _toggleListCompleted(list),
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1, right: 10),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isUpdating
                      ? const Padding(
                          padding: EdgeInsets.all(3),
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: workBlue,
                          ),
                        )
                      : isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (list.projectName != null &&
                                list.projectName!.trim().isNotEmpty) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.folder_open_rounded,
                                    size: 12,
                                    color: workMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      list.projectName!.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: workMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              list.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCompleted
                                    ? const Color(0xFF6B7280)
                                    : workText,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                height: 1.25,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (list.assigneeIds.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildAssigneeAvatars(list),
                  ],
                  if (scheduleLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: dateColor == workMuted
                              ? const Color(0xFF94A3B8)
                              : dateColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            scheduleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: dateColor == workMuted
                                  ? const Color(0xFF64748B)
                                  : dateColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatars(TaskListRecord list) {
    final assignedIds = list.assigneeIds.toSet();
    final sourceMembers = list.assignees.isNotEmpty
        ? list.assignees
        : (_fallbackMembersByTaskId[list.taskId] ?? const <UserSummary>[]);
    final members = sourceMembers
        .where((member) => assignedIds.contains(member.id))
        .take(4)
        .toList(growable: false);
    if (members.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'ผู้รับผิดชอบ ${members.length} คน',
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          for (final member in members)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(
                  avatarUrl: member.avatarUrl,
                  name: member.displayName,
                  radius: 12,
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 82),
                  child: Text(
                    member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: workMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<TaskRecord?> _findProjectTask(TaskListRecord list) async {
    try {
      final role = widget.service.currentUser?.role;
      final tasks = role == 'admin'
          ? await widget.service.getAdminTasks()
          : await widget.service.getMyTasks();
      return tasks.where((task) => task.id == list.taskId).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  TaskRecord _buildFallbackTask(TaskListRecord list) {
    final now = DateTime.now();
    return TaskRecord(
      id: list.taskId,
      assignedTo: '',
      title: list.projectName?.trim().isNotEmpty == true
          ? list.projectName!.trim()
          : list.name,
      description: '',
      dueDate: list.dueDate ?? now,
      status: 'pending',
      createdAt: now,
      priority: list.priority,
      assigneeIds: list.assigneeIds,
    );
  }

  Future<void> _showListDetail(TaskListRecord list) async {
    var loadingDialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: workBlue)),
    );

    try {
      final project = await _findProjectTask(list);
      final detailTask = project ?? _buildFallbackTask(list);

      if (!mounted) return;
      Navigator.of(context).pop();
      loadingDialogOpen = false;
      final user = widget.service.currentUser;
      final canEdit =
          user?.role == 'admin' ||
          (project != null &&
              (user?.id == project.assignedTo ||
                  project.assigneeIds.contains(user?.id)));
      await showProjectTaskListDetailSheet(
        context: context,
        task: detailTask,
        list: list,
        service: widget.service,
        canEdit: canEdit,
        onChanged: _loadData,
      );
    } catch (_) {
      if (!mounted) return;
      if (loadingDialogOpen) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถโหลดข้อมูลโปรเจกต์ได้')),
      );
    }
  }
}

class _DailyBoardColumn {
  const _DailyBoardColumn({required this.title, required this.items});

  final String title;
  final List<TaskListRecord> items;
}
