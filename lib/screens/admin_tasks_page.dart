import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/models/app_user.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:hr_management/widgets/skeleton_loading.dart';
import 'package:hr_management/widgets/work_due_date_picker.dart';
import 'package:hr_management/widgets/priority_badge.dart';
import 'package:hr_management/screens/project_detail/project_detail_page.dart';
import 'package:hr_management/screens/project_detail/project_detail_style.dart';
import 'task_assignment/task_assignment_domain.dart';
import 'task_assignment/task_assignment_view_model.dart';
import 'package:hr_management/widgets/user_avatar.dart';

export 'task_assignment/task_assignment_domain.dart';

part 'task_assignment/create_task_modal.dart';
part 'task_assignment/edit_task_modal.dart';
part 'task_assignment/task_detail_sheet.dart';
part 'task_assignment/filter_bottom_sheet.dart';
part 'task_assignment/task_notifications_sheet.dart';
part 'task_assignment/task_trash_sheet.dart';

class AdminTasksPage extends StatefulWidget {
  const AdminTasksPage({super.key, required this.service});

  final AuthFlowService service;

  @override
  State<AdminTasksPage> createState() => _AdminTasksPageState();
}

class _AdminTasksPageState extends State<AdminTasksPage> {
  late final TaskAssignmentViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();
  List<_TaskNotification> _taskNotifications = const [];

  List<TaskRecord> get _tasks => _viewModel.tasks;
  List<AppUser> get _users => _viewModel.users;
  List<BrandRecord> get _brands => _viewModel.brands;
  List<TaskCategoryRecord> get _categories => _viewModel.categories;
  Map<String, BrandRecord> get _brandMap => _viewModel.brandMap;
  Map<String, TaskCategoryRecord> get _catMap => _viewModel.categoryMap;
  bool get _loading => _viewModel.isLoading;
  String? get _error => _viewModel.error;
  String get _searchQuery => _viewModel.searchQuery;
  String? get _selectedBrandId => _viewModel.selectedBrandId;
  String? get _selectedCategoryId => _viewModel.selectedCategoryId;
  String? get _selectedOwnership => _viewModel.selectedOwnership;
  String get _selectedQuickView => _viewModel.selectedQuickView;

  @override
  void initState() {
    super.initState();
    _viewModel = TaskAssignmentViewModel(service: widget.service)
      ..addListener(_onViewModelChanged);
    _loadData();
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

  Future<void> _loadData() async {
    await Future.wait([_viewModel.loadData(), _loadTaskNotifications()]);
  }

  Future<void> _loadTaskNotifications() async {
    try {
      final raw = await widget.service.getMyNotifications();
      final notifications =
          raw
              .map(_TaskNotification.fromJson)
              .where((item) => item.taskId != null)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _taskNotifications = notifications);
    } catch (_) {
      // The task page remains usable when notification loading fails.
    }
  }

  List<_TaskNotification> get _mainTaskNotifications => _taskNotifications
      .where((item) => item.taskId != null && item.listId == null)
      .toList(growable: false);

  List<_TaskNotification> _listNotificationsForTask(String taskId) {
    return _taskNotifications
        .where((item) => item.taskId == taskId && item.listId != null)
        .toList(growable: false);
  }

  void _showMainTaskNotifications() {
    _showTaskNotifications(
      title: 'การแจ้งเตือนงานหลัก',
      emptyMessage: 'ยังไม่มีประวัติการแจ้งเตือนของงานหลัก',
      notifications: _mainTaskNotifications,
    );
  }

  void _showTaskTrash() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _TaskTrashSheet(service: widget.service, onRestored: _loadData),
    );
  }

  void _showListNotifications(TaskRecord task) {
    _showTaskNotifications(
      title: 'การแจ้งเตือนงานย่อย',
      subtitle: 'โครงการ: ${task.title}',
      emptyMessage: 'ยังไม่มีประวัติการแจ้งเตือนงานย่อยของโครงการนี้',
      notifications: _listNotificationsForTask(task.id),
    );
  }

  void _showTaskNotifications({
    required String title,
    String? subtitle,
    required String emptyMessage,
    required List<_TaskNotification> notifications,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskNotificationsSheet(
        title: title,
        subtitle: subtitle,
        emptyMessage: emptyMessage,
        notifications: notifications,
      ),
    );

    final unreadIds = notifications
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .toSet();
    if (unreadIds.isEmpty) return;
    setState(() {
      _taskNotifications = _taskNotifications
          .map(
            (item) => unreadIds.contains(item.id)
                ? item.copyWith(isRead: true)
                : item,
          )
          .toList(growable: false);
    });
    _markTaskNotificationsRead(unreadIds);
  }

  Future<void> _markTaskNotificationsRead(Set<String> ids) async {
    for (final id in ids) {
      try {
        await widget.service.markNotificationRead(id);
      } catch (_) {
        // Match the web behavior: keep the modal open if one read call fails.
      }
    }
  }

  void _showTaskDetailSheet(TaskRecord task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TaskDetailSheet(
        task: task,
        userMap: {for (var u in _users) u.id: u},
        brandMap: _brandMap,
        catMap: _catMap,
        statusConfig: taskStatusConfig,
        onEdit: () => _showEditTaskModal(task),
        onChangeStatus: (status) async {
          try {
            await widget.service.updateTaskStatus(task.id, status);
            if (!mounted) return;
            Navigator.pop(context);
            await _loadData();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('เปลี่ยนสถานะล้มเหลว: $e')));
          }
        },
        onDelete: () async {
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
                          'ต้องการลบงาน “${task.title}” หรือไม่?',
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
            await widget.service.deleteTask(task.id);
            if (!mounted) return;
            Navigator.pop(context);
            await _loadData();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('ลบงานล้มเหลว: $e')));
          }
        },
      ),
    );
  }

  Future<void> _showEditTaskModal(TaskRecord task) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditTaskModal(
        task: task,
        users: _users,
        brands: _brands,
        categories: _categories,
        currentUser: widget.service.currentUser,
        onDelete: () async {
          await widget.service.deleteTask(task.id);
        },
        onSave:
            ({
              required title,
              required description,
              required assigneeIds,
              required dueDate,
              brandId,
              categoryId,
              required priority,
              required status,
            }) async {
              await widget.service.updateTask(
                id: task.id,
                title: title,
                description: description,
                assigneeIds: assigneeIds,
                dueDate: dueDate,
                brandId: brandId,
                categoryId: categoryId,
                priority: priority,
                status: status,
              );
            },
      ),
    );
    if (saved == true && mounted) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('แก้ไขงานสำเร็จ'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  // ─── Create task modal sheet (โมดูล) ──────────────────────────────
  Future<void> _showCreateTaskModal() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateTaskModal(
        users: _users,
        brands: _brands,
        categories: _categories,
        currentUser: widget.service.currentUser,
        onSubmit:
            (
              title,
              desc,
              assignees,
              due,
              brand,
              category,
              priority,
              status,
              boards,
            ) async {
              final task = await widget.service.createTask(
                 title: title,
                description: desc,
                assignedTo: assignees.isNotEmpty ? assignees.first : '',
                brandId: brand,
                categoryId: category,
                dueDate: due,
                assigneeIds: assignees,
                priority: priority,
                status: status,
              );
              for (final board in boards) {
                await widget.service.createTaskList(
                  task.id,
                  name: board.name,
                  description: board.description,
                  dueDate: board.dueDate,
                  priority: board.priority,
                  assigneeIds: assignees,
                );
              }
            },
      ),
    );
    if (saved == true && mounted) {
      await _loadData();
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheetContent(
        brands: _brands,
        categories: _categories,
        initialBrandId: _selectedBrandId,
        initialCategoryId: _selectedCategoryId,
        initialOwnership: _selectedOwnership,
        initialStatus: _viewModel.selectedStatus,
        initialStarredOnly: _viewModel.selectedStarredOnly,
        onApply: (brandId, categoryId, ownership, status, starredOnly) {
          _viewModel.applySheetFilters(
            brandId,
            categoryId,
            ownership: ownership,
            status: status,
            starredOnly: starredOnly,
          );
        },
      ),
    );
  }

  void _clearAllFilters() {
    _viewModel.clearFilters();
    _searchController.clear();
  }

  Widget _buildQuickViewOption({
    required String value,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final selected = _selectedQuickView == value;
    return Expanded(
      child: InkWell(
        key: Key('task-view-$value'),
        onTap: () => _viewModel.setQuickView(value),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF475569),
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: workBackground,
        appBar: AppBar(
          title: const Text(
            'รายการมอบหมายงาน',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: const AssignmentListSkeleton(),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'โหลดข้อมูลล้มเหลว: $_error',
              style: const TextStyle(color: workText),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }

    final filteredTasks = _viewModel.filteredTasks;
    final hasSheetFilters = _viewModel.hasSheetFilters;

    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        titleSpacing: 4,
        title: const Text(
          'รายการมอบหมายงาน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      key: const Key('main-task-notifications'),
                      onPressed: _showMainTaskNotifications,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 38,
                        minHeight: 38,
                      ),
                      icon: Icon(
                        Icons.notifications_none_rounded,
                        size: 21,
                        color:
                            _mainTaskNotifications.any((item) => !item.isRead)
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF64748B),
                      ),
                      tooltip: 'การแจ้งเตือนงานหลัก',
                    ),
                    if (_mainTaskNotifications.any((item) => !item.isRead))
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE11D48),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 2),
                IconButton(
                  key: const Key('task-trash-button'),
                  tooltip: 'ถังขยะงานหลัก',
                  onPressed: _showTaskTrash,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 38,
                    height: 38,
                  ),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 3),
                Tooltip(
                  message: 'มอบหมายงานใหม่',
                  child: TextButton(
                    key: const Key('create-task-button'),
                    onPressed: _showCreateTaskModal,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: workBlue,
                      minimumSize: const Size(36, 36),
                      maximumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Icon(Icons.add_rounded, size: 21),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tasks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildQuickViewOption(
                      value: 'all',
                      label: 'รายการรวม',
                      icon: Icons.format_list_bulleted_rounded,
                      activeColor: workBlue,
                    ),
                    _buildQuickViewOption(
                      value: 'completed',
                      label: 'งานที่เสร็จแล้ว',
                      icon: Icons.event_available_rounded,
                      activeColor: const Color(0xFF16A34A),
                    ),
                    _buildQuickViewOption(
                      value: 'starred',
                      label: 'งานที่ติดดาว',
                      icon: Icons.star_rounded,
                      activeColor: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        key: const Key('task-search-field'),
                        controller: _searchController,
                        onChanged: _viewModel.setSearchQuery,
                        style: const TextStyle(fontSize: 12.5, color: workText),
                        decoration: InputDecoration(
                          hintText: 'ค้นหางาน...',
                          hintStyle: const TextStyle(
                            color: workMuted,
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: workMuted,
                            size: 17,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 34,
                                    minHeight: 34,
                                  ),
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: workMuted,
                                    size: 15,
                                  ),
                                  onPressed: () {
                                    _viewModel.setSearchQuery('');
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: _searchQuery.isNotEmpty
                                  ? workBlue.withValues(alpha: 0.5)
                                  : const Color(0xFFE2E8F0),
                              width: _searchQuery.isNotEmpty ? 1.3 : 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: workBlue,
                              width: 1.3,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 9,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: const Key('task-filter-button'),
                    onTap: _showFilterBottomSheet,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: hasSheetFilters
                                ? workBlue.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: hasSheetFilters
                                  ? workBlue
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.tune_rounded,
                              color: hasSheetFilters ? workBlue : workText,
                              size: 18,
                            ),
                          ),
                        ),
                        if (hasSheetFilters)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: workBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _tasks.isEmpty
                  ? const Center(
                      child: Text(
                        'ยังไม่มีงานมอบหมายในตอนนี้',
                        style: TextStyle(color: workMuted, fontSize: 13),
                      ),
                    )
                  : filteredTasks.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2,
                        ),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.filter_list_off_rounded,
                                size: 48,
                                color: workMuted.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'ไม่พบบอร์ดงานที่ตรงตามตัวกรอง',
                                style: TextStyle(
                                  color: workMuted,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: _clearAllFilters,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: workBlue,
                                  side: const BorderSide(color: workBlue),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text(
                                  'ล้างตัวกรองทั้งหมด',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: filteredTasks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final t = filteredTasks[index];
                        return _buildDraggableTaskCard(t);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Project list ───────────────────────────────────────────────

  Widget _buildDraggableTaskCard(TaskRecord task) {
    return _buildTaskCardContent(task);
  }

  Widget _buildTaskCardContent(TaskRecord task) {
    final brand = task.brandId != null ? _brandMap[task.brandId] : null;
    final category = task.categoryId != null ? _catMap[task.categoryId] : null;
    final isOverdue = isAssignmentOverdue(task.dueDate, task.status);
    final hasUnreadListNotification = _listNotificationsForTask(
      task.id,
    ).any((item) => !item.isRead);

    final isEmployee = widget.service.currentUser?.role == 'employee';
    final currentUser = widget.service.currentUser;
    final isAdmin = currentUser?.role == 'admin';
    // Multiple assignees mapping
    final assignees = isEmployee && currentUser != null
        ? [currentUser]
        : _users.where((u) {
            if (task.assigneeIds.isNotEmpty) {
              return task.assigneeIds.contains(u.id);
            }
            return u.id == task.assignedTo;
          }).toList();
    final assigneeCount = task.assigneeIds.isNotEmpty
        ? task.assigneeIds.length
        : assignees.length;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProjectDetailPage(
              project: task,
              service: widget.service,
              brandName: brand?.name,
              categoryName: category?.name,
              onChanged: _loadData,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: ProjectDetailStyle.surface,
          borderRadius: BorderRadius.circular(ProjectDetailStyle.cardRadius),
          border: Border.all(color: ProjectDetailStyle.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title, Star, and Meatballs Menu
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    try {
                      await widget.service.toggleStarTask(
                        task.id,
                        !task.isStarred,
                      );
                      _loadData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('สลับสถานะการติดดาวล้มเหลว: $e'),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Icon(
                      task.isStarred
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: task.isStarred
                          ? Colors.amber
                          : workMuted.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: workText,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Transform.translate(
                  offset: const Offset(0, -3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              key: Key('task-list-notifications-${task.id}'),
                              tooltip: 'ดูการแจ้งเตือนของงานนี้',
                              onPressed: () => _showListNotifications(task),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.notifications_none_rounded,
                                size: 18,
                                color: hasUnreadListNotification
                                    ? const Color(0xFFE11D48)
                                    : workMuted,
                              ),
                            ),
                            if (hasUnreadListNotification)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE11D48),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isAdmin ||
                          (currentUser != null &&
                              task.assignedBy == currentUser.id))
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            key: Key('task-more-${task.id}'),
                            tooltip: 'ตัวเลือกเพิ่มเติม',
                            icon: const Icon(
                              Icons.more_horiz,
                              color: workMuted,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showEditTaskModal(task),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Keep the card scannable: only immediate decision data belongs here.
            Wrap(
              spacing: 5,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildCardStatusBadge(task.status),
                PriorityBadge(priority: task.priority, isCompact: true),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.assignment_turned_in_rounded,
                  size: 11.5,
                  color: ProjectDetailStyle.secondary.withOpacity(0.7),
                ),
                const SizedBox(width: 3.5),
                Text(
                  '${task.cardDone}/${task.cardTotal}',
                  style: TextStyle(
                    fontSize: 10,
                    color: ProjectDetailStyle.secondary.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: task.cardTotal == 0
                          ? 0
                          : task.cardDone / task.cardTotal,
                      minHeight: 3.5,
                      backgroundColor: ProjectDetailStyle.line,
                      color:
                          task.cardTotal > 0 && task.cardDone == task.cardTotal
                          ? ProjectDetailStyle.success
                          : ProjectDetailStyle.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 13,
                  color: ProjectDetailStyle.secondary.withOpacity(0.7),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Footer Row: Assignees Avatar Stack & Due Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Assignees Stack
                Row(
                  children: [
                    if (assignees.isEmpty)
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: workMuted,
                      )
                    else
                      SizedBox(
                        height: 20,
                        width:
                            20.0 +
                            (assignees.length > 1
                                ? (assignees.length > 3
                                          ? 2
                                          : assignees.length - 1) *
                                      10.0
                                : 0),
                        child: Stack(
                          children: List.generate(
                            assignees.length > 3 ? 3 : assignees.length,
                            (index) {
                              final u = assignees[index];
                              return Positioned(
                                left: index * 10.0,
                                child: UserAvatar(
                                  avatarUrl: u.avatarUrl,
                                  name: u.firstName,
                                  radius: 10,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(width: 5),
                    Text(
                      assigneeCount == 1 && assignees.isNotEmpty
                          ? assignees.first.firstName
                          : (assigneeCount > 1
                                ? '$assigneeCount คน'
                                : 'ไม่ระบุ'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: workText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.calendar_month_rounded,
                      size: 11,
                      color: isOverdue ? Colors.red : workMuted,
                    ),
                    const SizedBox(width: 2.5),
                    Text(
                      DateFormat('dd MMM yy').format(task.dueDate),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red : workMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardStatusBadge(String status) {
    final meta = taskStatusConfig[status] ?? taskStatusConfig['pending']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: meta.border, width: 0.8),
      ),
      child: Text(
        meta.label,
        style: TextStyle(
          color: meta.color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
