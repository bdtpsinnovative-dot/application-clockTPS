import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/models/app_user.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:hr_management/widgets/skeleton_loading.dart';
import 'package:hr_management/widgets/work_due_date_picker.dart';
import 'package:hr_management/screens/project_detail/project_detail_page.dart';
import 'package:hr_management/screens/project_detail/project_detail_style.dart';
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
        onSubmit: (title, desc, assignees, due, brand, category) async {
          await widget.service.createTask(
            title: title,
            description: desc,
            assignedTo: assignees.isNotEmpty ? assignees.first : '',
            brandId: brand,
            categoryId: category,
            dueDate: due,
            assigneeIds: assignees,
            // Every new project starts with one deliverable using the
            // entered work title. Legacy task cards are no longer created.
            listNames: [title.trim()],
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

  // ─── Project list ───────────────────────────────────────────────

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

    final primaryAssignee = assignees.isNotEmpty ? assignees.first : null;
    final avatarUrl = primaryAssignee?.avatarUrl;
    final resolvedAvatar = (avatarUrl != null && avatarUrl.trim().isNotEmpty)
        ? (avatarUrl.startsWith('r2://')
            ? avatarUrl.replaceFirst(
                'r2://',
                'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
              )
            : avatarUrl)
        : null;

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
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C0F172A),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Title & Action Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Color(0xFF0F172A),
                      height: 1.25,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (widget.service.currentUser?.role == 'admin')
                  IconButton(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showTaskDetailSheet(task),
                  ),
              ],
            ),

            // 2. Subtitle / Description
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 3. Tags Row (Solid Pill + Outlined Pill)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (category != null || brand != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF08A), // Soft neon yellow
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category?.name ?? brand?.name ?? '',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF422006),
                      ),
                    ),
                  ),
                // Priority / Status Tag (Outlined Pill)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    isOverdue ? 'เกินกำหนดส่ง' : 'ความสำคัญปกติ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF475569),
                    ),
                  ),
                ),
                // Soft Owner Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isBoardCreator ? 'คุณเป็นเจ้าของ' : 'บอร์ดของ $boardCreatorName',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 4. Meta Information Grid (Clean text + icons, NO nested boxes!)
            Row(
              children: [
                // Due date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Due date',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                            color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            DateFormat('MMM dd, yyyy').format(task.dueDate),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Tracked time / Progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tracked time',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.hourglass_empty_rounded,
                            size: 15,
                            color: Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${task.cardDone}/${task.cardTotal} งาน',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 5. Footer Row: Overlapping Avatar Stack + Name / Count on left, Dark Chevron Circle on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildAssigneeAvatarStack(assignees, assigneeCount),
                    const SizedBox(width: 10),
                    Text(
                      assigneeCount == 0
                          ? 'ไม่ระบุผู้รับผิดชอบ'
                          : (assigneeCount == 1 && primaryAssignee != null
                              ? primaryAssignee.fullName
                              : '$assigneeCount คน'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                // Circular Action Chevron
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatarStack(List<AppUser> assignees, int totalCount) {
    if (assignees.isEmpty || totalCount == 0) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF1F5F9),
        ),
        child: const Icon(
          Icons.person_outline_rounded,
          size: 18,
          color: Color(0xFF94A3B8),
        ),
      );
    }

    final visible = assignees.take(3).toList();
    final extraCount = totalCount > 3 ? totalCount - 3 : 0;
    final totalItems = visible.length + (extraCount > 0 ? 1 : 0);

    return SizedBox(
      height: 36,
      width: totalItems == 0 ? 36 : 36.0 + ((totalItems - 1) * 20.0),
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            Positioned(
              left: i * 20.0,
              child: _buildAvatarCircle(visible[i]),
            ),
          ],
          if (extraCount > 0)
            Positioned(
              left: visible.length * 20.0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E293B),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$extraCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(AppUser u) {
    final avatarUrl = u.avatarUrl;
    final resolvedAvatar = (avatarUrl != null && avatarUrl.trim().isNotEmpty)
        ? (avatarUrl.startsWith('r2://')
            ? avatarUrl.replaceFirst(
                'r2://',
                'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
              )
            : avatarUrl)
        : null;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: Colors.white, width: 2),
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
                u.firstName.isNotEmpty ? u.firstName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTag(String label, Color bg, Color fg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
