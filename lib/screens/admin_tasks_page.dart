import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/models/app_user.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:hr_management/widgets/skeleton_loading.dart';
import 'package:hr_management/widgets/work_due_date_picker.dart';
import 'package:hr_management/screens/task_board_page.dart';
import 'task_assignment/task_assignment_domain.dart';
import 'task_assignment/task_assignment_view_model.dart';

export 'task_assignment/task_assignment_domain.dart';

part 'task_assignment/create_task_modal.dart';
part 'task_assignment/edit_task_modal.dart';
part 'task_assignment/task_detail_sheet.dart';
part 'task_assignment/filter_bottom_sheet.dart';

class AdminTasksPage extends StatefulWidget {
  const AdminTasksPage({super.key, required this.service});

  final AuthFlowService service;

  @override
  State<AdminTasksPage> createState() => _AdminTasksPageState();
}

class _AdminTasksPageState extends State<AdminTasksPage> {
  late final TaskAssignmentViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

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

  Future<void> _loadData() {
    return _viewModel.loadData();
  }

  void _showTaskDetailSheet(TaskRecord task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
            _loadData();
            Navigator.pop(context);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('เปลี่ยนสถานะล้มเหลว: $e')));
          }
        },
        onDelete: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('ยืนยันการลบงาน'),
              content: Text('ต้องการลบงาน “${task.title}” หรือไม่?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('ยกเลิก'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('ลบงาน'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          try {
            await widget.service.deleteTask(task.id);
            if (!mounted) return;
            _loadData();
            Navigator.pop(context);
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
        onSave:
            ({
              required title,
              required description,
              required assigneeIds,
              required dueDate,
            }) async {
              await widget.service.updateTask(
                id: task.id,
                title: title,
                description: description,
                assigneeIds: assigneeIds,
                dueDate: dueDate,
                brandId: task.brandId,
                categoryId: task.categoryId,
              );
            },
      ),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop();
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
  void _showCreateTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateTaskModal(
        users: _users,
        brands: _brands,
        categories: _categories,
        onSubmit:
            (title, desc, assignees, due, brand, category, cardNames) async {
              final validLists = cardNames
                  .map((name) => name.trim())
                  .where((name) => name.isNotEmpty)
                  .toList(growable: false);
              await widget.service.createTask(
                title: title,
                description: desc,
                assignedTo: assignees.isNotEmpty ? assignees.first : '',
                brandId: brand,
                categoryId: category,
                dueDate: due,
                assigneeIds: assignees,
                listNames: validLists,
              );
              _loadData();
            },
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheetContent(
        brands: _brands,
        categories: _categories,
        initialBrandId: _selectedBrandId,
        initialCategoryId: _selectedCategoryId,
        onApply: _viewModel.applySheetFilters,
      ),
    );
  }

  void _clearAllFilters() {
    _viewModel.clearFilters();
    _searchController.clear();
  }

  Widget _buildCategoryChip(String? id, String name) {
    final isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () => _viewModel.setCategory(id),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? workBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? workBlue : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: workBlue.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : workText,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildOwnershipOption({
    required String label,
    required String? value,
  }) {
    final isSelected = _selectedOwnership == value;
    return Expanded(
      child: InkWell(
        onTap: () => _viewModel.setOwnership(value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0C0F172A),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? workBlue : workMuted,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
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
        title: const Text(
          'รายการมอบหมายงาน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (widget.service.currentUser?.role != 'employee')
            IconButton(
              onPressed: _showCreateTaskModal,
              icon: const Icon(Icons.add_task_rounded, color: workBlue),
              tooltip: 'มอบหมายงานใหม่',
            ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: workMuted),
            tooltip: 'รีโหลด',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tasks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    _buildOwnershipOption(label: 'ทั้งหมด', value: null),
                    _buildOwnershipOption(
                      label: 'งานที่ฉันสร้าง',
                      value: 'created_by_me',
                    ),
                    _buildOwnershipOption(
                      label: 'งานที่ถูกเพิ่มเข้า',
                      value: 'joined',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _searchQuery.isNotEmpty
                              ? workBlue.withValues(alpha: 0.5)
                              : const Color(0xFFE2E8F0),
                          width: _searchQuery.isNotEmpty ? 1.5 : 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x05000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _viewModel.setSearchQuery,
                        style: const TextStyle(fontSize: 13.5, color: workText),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาบอร์ดงาน...',
                          hintStyle: const TextStyle(
                            color: workMuted,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: workMuted,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: workMuted,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _viewModel.setSearchQuery('');
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _showFilterBottomSheet,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasSheetFilters
                                ? workBlue.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasSheetFilters
                                  ? workBlue
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x05000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: hasSheetFilters ? workBlue : workText,
                            size: 20,
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  _buildCategoryChip(null, 'ทั้งหมด'),
                  ..._categories.map((c) => _buildCategoryChip(c.id, c.name)),
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

  // ─── Kanban board ───────────────────────────────────────────────

  Widget _buildDraggableTaskCard(TaskRecord task) {
    return _buildTaskCardContent(task);
  }

  Widget _buildTaskCardContent(TaskRecord task) {
    final brand = task.brandId != null ? _brandMap[task.brandId] : null;
    final category = task.categoryId != null ? _catMap[task.categoryId] : null;
    final isOverdue = isAssignmentOverdue(task.dueDate, task.status);

    final isEmployee = widget.service.currentUser?.role == 'employee';
    final currentUser = widget.service.currentUser;
    final isBoardCreator =
        currentUser != null && task.assignedBy == currentUser.id;
    final boardCreatorName = task.assignedByName.isNotEmpty
        ? task.assignedByName
        : 'เพื่อนร่วมงาน';
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskBoardPage(
              task: task,
              service: widget.service,
              onRefreshNeeded: _loadData,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Tags & Ownership Tag & Actions
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (brand != null)
                        _buildTag(
                          brand.name,
                          const Color(0xFFEFF6FF),
                          workBlue,
                          const Color(0xFFBFDBFE),
                        ),
                      if (category != null)
                        _buildTag(
                          category.name,
                          const Color(0xFFFEF3C7),
                          const Color(0xFFB45309),
                          const Color(0xFFFDE68A),
                        ),
                      // Soft Owner Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isBoardCreator
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isBoardCreator
                                ? const Color(0xFFFECACA)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isBoardCreator
                                  ? Icons.star_rounded
                                  : Icons.people_outline_rounded,
                              size: 11,
                              color: isBoardCreator
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isBoardCreator
                                  ? 'คุณเป็นเจ้าของ'
                                  : 'บอร์ดของ $boardCreatorName',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isBoardCreator
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.service.currentUser?.role == 'admin')
                  IconButton(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: workMuted,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showTaskDetailSheet(task),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Title & Description
            Text(
              task.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: workText,
                height: 1.3,
              ),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: workMuted,
                  height: 1.45,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Progress Section
            Builder(
              builder: (context) {
                final hasCards = task.cardTotal > 0;
                final hasSubItems = task.subItems.isNotEmpty;
                if (!hasCards && !hasSubItems) return const SizedBox.shrink();

                final int total = hasCards
                    ? task.cardTotal
                    : task.subItems.length;
                final int done = hasCards
                    ? task.cardDone
                    : task.subItems.where((s) => s.isDone).length;
                final double ratio = total > 0 ? (done / total) : 0;
                final int pct = (ratio * 100).toInt();
                final bool isAllDone = total > 0 && done == total;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hasCards
                                  ? Icons.view_kanban_rounded
                                  : Icons.checklist_rounded,
                              size: 13,
                              color: workMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasCards
                                  ? '$done/$total การ์ด'
                                  : '$done/$total รายการ',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: workMuted,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isAllDone
                                ? const Color(0xFF16A34A)
                                : workBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: isAllDone ? const Color(0xFF16A34A) : workBlue,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),

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
                        size: 16,
                        color: workMuted,
                      )
                    else
                      SizedBox(
                        height: 24,
                        width:
                            24.0 +
                            (assignees.length > 1
                                ? (assignees.length > 3
                                          ? 2
                                          : assignees.length - 1) *
                                      12.0
                                : 0),
                        child: Stack(
                          children: List.generate(
                            assignees.length > 3 ? 3 : assignees.length,
                            (index) {
                              final u = assignees[index];
                              final avatarUrl = u.avatarUrl;
                              final hasAvatar =
                                  avatarUrl != null &&
                                  avatarUrl.trim().isNotEmpty;
                              final resolvedAvatar = hasAvatar
                                  ? (avatarUrl.startsWith('r2://')
                                        ? avatarUrl.replaceFirst(
                                            'r2://',
                                            'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
                                          )
                                        : avatarUrl)
                                  : null;

                              return Positioned(
                                left: index * 12.0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFEFF6FF),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                    image: resolvedAvatar != null
                                        ? DecorationImage(
                                            image: NetworkImage(resolvedAvatar),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: resolvedAvatar == null
                                      ? Center(
                                          child: Text(
                                            u.firstName.isNotEmpty
                                                ? u.firstName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: workBlue,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      assigneeCount == 1 && assignees.isNotEmpty
                          ? assignees.first.firstName
                          : (assigneeCount > 1
                                ? '$assigneeCount คน'
                                : 'ไม่ระบุ'),
                      style: const TextStyle(
                        fontSize: 11,
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
                      size: 12,
                      color: isOverdue ? Colors.red : workMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat('dd MMM yy').format(task.dueDate),
                      style: TextStyle(
                        fontSize: 10.5,
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

  Widget _buildTag(String label, Color bg, Color fg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
