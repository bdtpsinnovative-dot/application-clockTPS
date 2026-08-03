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
        onEdit: () => _showEditTaskTitleDialog(task),
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

  Future<void> _showEditTaskTitleDialog(TaskRecord task) async {
    final controller = TextEditingController(text: task.title);
    final formKey = GlobalKey<FormState>();

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('แก้ไขชื่องาน'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'ชื่องาน',
                hintText: 'กรอกชื่องาน',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกชื่องาน';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() == true) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      );

      if (saved != true || !mounted) return;
      final existingAssigneeIds = task.assigneeIds.isNotEmpty
          ? task.assigneeIds
          : task.assignedTo.isNotEmpty
          ? [task.assignedTo]
          : const <String>[];
      await widget.service.updateTask(
        id: task.id,
        title: controller.text.trim(),
        description: task.description,
        assigneeIds: existingAssigneeIds,
        dueDate: task.dueDate,
        brandId: task.brandId,
        categoryId: task.categoryId,
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('แก้ไขชื่องานสำเร็จ'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('แก้ไขชื่องานไม่สำเร็จ: $e')));
    } finally {
      controller.dispose();
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
            (
              title,
              desc,
              assignees,
              due,
              brand,
              category,
              priority,
              status,
              initialListName,
            ) async {
              await widget.service.createTask(
                title: title,
                description: desc,
                assignedTo: assignees.isNotEmpty ? assignees.first : '',
                brandId: brand,
                categoryId: category,
                dueDate: due,
                assigneeIds: assignees,
                listNames: [
                  initialListName.isNotEmpty
                      ? initialListName.trim()
                      : title.trim(),
                ],
                priority: priority,
                status: status,
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
        initialStatus: _viewModel.selectedStatus,
        initialStarredOnly: _viewModel.selectedStarredOnly,
        onApply: (brandId, categoryId, status, starredOnly) {
          _viewModel.applySheetFilters(
            brandId,
            categoryId,
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5.5),
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
              fontSize: 11,
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
                        style: const TextStyle(fontSize: 13, color: workText),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาบอร์ดงาน...',
                          hintStyle: const TextStyle(
                            color: workMuted,
                            fontSize: 12.5,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: workMuted,
                            size: 18,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: workMuted,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _viewModel.setSearchQuery('');
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8.5,
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
                          padding: const EdgeInsets.all(8.5),
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
                            size: 18,
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
                  : _buildTaskBoard(filteredTasks),
            ),
          ),
        ],
      ),
    );
  }

  static const _boardStatuses = [
    'pending',
    'in_progress',
    'in_review',
    'completed',
  ];

  Widget _buildTaskBoard(List<TaskRecord> tasks) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 104
                  ? constraints.maxHeight - 104
                  : 0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final status in _boardStatuses) ...[
                    SizedBox(
                      width: 296,
                      child: _buildBoardColumn(
                        status,
                        tasks.where((task) => task.status == status).toList(),
                      ),
                    ),
                    if (status != _boardStatuses.last)
                      const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardColumn(String status, List<TaskRecord> tasks) {
    final meta = taskStatusConfig[status] ?? taskStatusConfig['pending']!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: meta.bg.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: meta.border.withValues(alpha: 0.82)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: meta.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meta.label,
                  style: const TextStyle(
                    color: workText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                    color: meta.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    color: meta.color.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ยังไม่มีงาน',
                    style: TextStyle(
                      color: meta.color.withValues(alpha: 0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final task in tasks) ...[
              _buildBoardTaskCard(task),
              if (task != tasks.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildBoardTaskCard(TaskRecord task) {
    final brand = task.brandId != null ? _brandMap[task.brandId] : null;
    final category = task.categoryId != null ? _catMap[task.categoryId] : null;
    final isOverdue = isAssignmentOverdue(task.dueDate, task.status);
    final assignees = _users.where((user) {
      if (task.assigneeIds.isNotEmpty) {
        return task.assigneeIds.contains(user.id);
      }
      return user.id == task.assignedTo;
    }).toList();
    final assigneeLabel = assignees.length == 1
        ? assignees.first.firstName
        : assignees.length > 1
        ? '${assignees.length} คน'
        : task.assignedToName.isNotEmpty
        ? task.assignedToName
        : 'ยังไม่ระบุ';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: workText,
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showEditTaskTitleDialog(task),
                    tooltip: 'แก้ไขชื่องาน',
                    icon: const Icon(Icons.edit_rounded, size: 17),
                    color: workBlue,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: workMuted,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 11),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  PriorityBadge(priority: task.priority, isCompact: true),
                  if (brand != null)
                    _buildTag(
                      brand.name,
                      const Color(0xFFF8FAFC),
                      const Color(0xFF475569),
                      const Color(0xFFE2E8F0),
                    ),
                  if (category != null)
                    _buildTag(
                      category.name,
                      const Color(0xFFF8FAFC),
                      const Color(0xFF475569),
                      const Color(0xFFE2E8F0),
                    ),
                ],
              ),
              if (task.cardTotal > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 14,
                      color: workMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${task.cardDone}/${task.cardTotal}',
                      style: const TextStyle(
                        color: workMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          value: task.cardDone / task.cardTotal,
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: task.cardDone == task.cardTotal
                              ? const Color(0xFF16A34A)
                              : workBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 14,
                    color: workMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      assigneeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: workText,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.calendar_month_rounded,
                    size: 14,
                    color: isOverdue ? const Color(0xFFDC2626) : workMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yy').format(task.dueDate),
                    style: TextStyle(
                      color: isOverdue ? const Color(0xFFDC2626) : workMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

    AppUser? creator;
    for (final u in _users) {
      if (u.id == task.assignedBy) {
        creator = u;
        break;
      }
    }

    String? creatorAvatar;
    String creatorName = boardCreatorName;
    if (creator != null) {
      creatorName = creator.nickname.isNotEmpty
          ? creator.nickname
          : creator.firstName;
      final av = creator.avatarUrl;
      if (av != null && av.trim().isNotEmpty) {
        creatorAvatar = av.startsWith('r2://')
            ? av.replaceFirst(
                'r2://',
                'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
              )
            : av;
      }
    }

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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: workText,
                      height: 1.3,
                    ),
                  ),
                ),
                if (widget.service.currentUser?.role == 'admin') ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(
                      Icons.more_horiz,
                      color: workMuted,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showTaskDetailSheet(task),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 6),

            // Second Row: Status, Priority, Tags & Ownership Tag
            Wrap(
              spacing: 5,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildCardStatusBadge(task.status),
                PriorityBadge(priority: task.priority, isCompact: true),
                if (brand != null)
                  _buildTag(
                    brand.name,
                    ProjectDetailStyle.soft,
                    ProjectDetailStyle.secondary,
                    ProjectDetailStyle.line,
                  ),
                if (category != null)
                  _buildTag(
                    category.name,
                    ProjectDetailStyle.soft,
                    ProjectDetailStyle.secondary,
                    ProjectDetailStyle.line,
                  ),
                // Soft Owner Tag
                if (isBoardCreator)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFEF08A)),
                    ),
                    child: const Text(
                      '👑 คุณเป็นเจ้าของ',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF854D0E),
                      ),
                    ),
                  )
                else if (creator != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ProjectDetailStyle.soft,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 0.8,
                                ),
                                image: creatorAvatar != null
                                    ? DecorationImage(
                                        image: NetworkImage(creatorAvatar),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: creatorAvatar == null
                                  ? Center(
                                      child: Text(
                                        creator.firstName.isNotEmpty
                                            ? creator.firstName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.bold,
                                          color: ProjectDetailStyle.accent,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const Positioned(
                              top: -5,
                              right: -4,
                              child: Text(
                                '👑',
                                style: TextStyle(fontSize: 7.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          creatorName,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: ProjectDetailStyle.soft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ProjectDetailStyle.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 10,
                          color: ProjectDetailStyle.muted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'บอร์ดของ $boardCreatorName',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: ProjectDetailStyle.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: workMuted,
                  height: 1.4,
                ),
              ),
            ],

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
                                left: index * 10.0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ProjectDetailStyle.soft,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.0,
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
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: ProjectDetailStyle.accent,
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
