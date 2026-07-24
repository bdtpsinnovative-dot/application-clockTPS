import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/models/app_user.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:hr_management/widgets/skeleton_loading.dart';
import 'package:hr_management/widgets/work_due_date_picker.dart';
import 'package:hr_management/screens/task_board_page.dart';

// ─── Status config ───────────────────────────────────────────────
const _statusConfig = {
  'pending': _StatusMeta(
    'รอทำ',
    Color(0xFF64748B),
    Color(0xFFF1F5F9),
    Color(0xFFCBD5E1),
  ),
  'in_progress': _StatusMeta(
    'กำลังทำ',
    Color(0xFFEA580C),
    Color(0xFFFFF7ED),
    Color(0xFFFED7AA),
  ),
  'in_review': _StatusMeta(
    'รอตรวจ',
    Color(0xFF7C3AED),
    Color(0xFFF5F3FF),
    Color(0xFFDDD6FE),
  ),
  'completed': _StatusMeta(
    'เสร็จสิ้น',
    Color(0xFF16A34A),
    Color(0xFFF0FDF4),
    Color(0xFFBBF7D0),
  ),
};

bool isAssignmentOverdue(DateTime dueDate, String status, {DateTime? now}) {
  if (status == 'completed') return false;
  final current = now ?? DateTime.now();
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final today = DateTime(current.year, current.month, current.day);
  return dueDay.isBefore(today);
}

String assignmentFilterUserId(AppUser? currentUser, String fallbackAuthId) {
  final databaseUserId = currentUser?.id.trim() ?? '';
  return databaseUserId.isNotEmpty ? databaseUserId : fallbackAuthId;
}

bool taskMatchesOwnershipFilter(
  TaskRecord task,
  String? currentUserId,
  String? ownershipFilter,
) {
  if (ownershipFilter == null || currentUserId == null) return true;
  final isCreator = task.assignedBy == currentUserId;
  if (ownershipFilter == 'created_by_me') return isCreator;
  if (ownershipFilter == 'joined') {
    final isAssignee = task.assigneeIds.isNotEmpty
        ? task.assigneeIds.contains(currentUserId)
        : task.assignedTo == currentUserId;
    return !isCreator && isAssignee;
  }
  return true;
}

class _StatusMeta {
  const _StatusMeta(this.label, this.color, this.bg, this.border);
  final String label;
  final Color color;
  final Color bg;
  final Color border;
}

class AdminTasksPage extends StatefulWidget {
  const AdminTasksPage({super.key, required this.service});

  final AuthFlowService service;

  @override
  State<AdminTasksPage> createState() => _AdminTasksPageState();
}

class _AdminTasksPageState extends State<AdminTasksPage> {
  List<TaskRecord> _tasks = [];
  List<AppUser> _users = [];
  List<BrandRecord> _brands = [];
  List<TaskCategoryRecord> _categories = [];
  Map<String, AppUser> _userMap = {};
  Map<String, BrandRecord> _brandMap = {};
  Map<String, TaskCategoryRecord> _catMap = {};
  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String? _selectedBrandId;
  String? _selectedCategoryId;
  String? _selectedOwnership;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isEmployee = widget.service.currentUser?.role == 'employee';
      final tasks = await (isEmployee
          ? widget.service.getMyTasks()
          : widget.service.getAdminTasks());
      final auxiliary = await Future.wait<Object>([
        (isEmployee
                ? Future.value(<AppUser>[])
                : widget.service.getAdminUsers())
            .catchError((_) => <AppUser>[]),
        widget.service.getBrands().catchError((_) => <BrandRecord>[]),
        widget.service.getTaskCategories().catchError(
          (_) => <TaskCategoryRecord>[],
        ),
      ]);

      final users = (auxiliary[0] as List<AppUser>)
          .where((u) => u.status == 'active')
          .toList();
      final brands = auxiliary[1] as List<BrandRecord>;
      final cats = auxiliary[2] as List<TaskCategoryRecord>;

      final Map<String, AppUser> userMap = {for (final u in users) u.id: u};
      final Map<String, BrandRecord> brandMap = {
        for (final b in brands) b.id: b,
      };
      final Map<String, TaskCategoryRecord> catMap = {
        for (final c in cats) c.id: c,
      };

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _users = users;
          _brands = brands;
          _categories = cats;
          _userMap = userMap;
          _brandMap = brandMap;
          _catMap = catMap;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  // ─── Delete task ────────────────────────────────────────────────
  Future<void> _deleteTask(TaskRecord task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการลบงาน'),
        content: Text('ต้องการลบงาน "${task.title}" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบงาน'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    try {
      await widget.service.deleteTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบงานสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ลบงานล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // ─── Change status ──────────────────────────────────────────────
  Future<void> _changeStatus(TaskRecord task, String newStatus) async {
    try {
      await widget.service.updateTaskStatus(task.id, newStatus);
      if (mounted) _loadData();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เปลี่ยนสถานะล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
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
        statusConfig: _statusConfig,
        onEdit: () => _showEditTaskModal(task),
        onChangeStatus: (status) async {
          try {
            await widget.service.updateTaskStatus(task.id, status);
            _loadData();
            Navigator.pop(context);
          } catch (e) {
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
            _loadData();
            Navigator.pop(context);
          } catch (e) {
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
        onApply: (brandId, categoryId) {
          setState(() {
            _selectedBrandId = brandId;
            _selectedCategoryId = categoryId;
          });
        },
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _selectedBrandId = null;
      _selectedCategoryId = null;
      _selectedOwnership = null;
      _searchController.clear();
    });
  }

  Widget _buildCategoryChip(String? id, String name) {
    final isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryId = id;
        });
      },
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
                color: workBlue.withOpacity(0.2),
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
        onTap: () => setState(() => _selectedOwnership = value),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected ? const Color(0xFFBFDBFE) : Colors.transparent,
            ),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0F0F172A),
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
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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

    final filteredTasks = _tasks.where((task) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = task.title.toLowerCase().contains(query);
        final matchDesc = task.description.toLowerCase().contains(query);
        if (!matchTitle && !matchDesc) return false;
      }
      if (_selectedBrandId != null && task.brandId != _selectedBrandId) {
        return false;
      }
      if (_selectedCategoryId != null &&
          task.categoryId != _selectedCategoryId) {
        return false;
      }
      if (!taskMatchesOwnershipFilter(
        task,
        assignmentFilterUserId(
          widget.service.currentUser,
          widget.service.currentUserId,
        ),
        _selectedOwnership,
      )) {
        return false;
      }
      return true;
    }).toList();

    final hasSheetFilters =
        _selectedBrandId != null || _selectedCategoryId != null;

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
                              ? workBlue.withOpacity(0.5)
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
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
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
                                    setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
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
                                ? workBlue.withOpacity(0.1)
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
                                color: workMuted.withOpacity(0.5),
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tags row
            if (brand != null || category != null) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
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
                ],
              ),
              const SizedBox(height: 6),
            ],
            // Title & Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: workText,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: workMuted,
                          ),
                        ),
                      ],
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

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isBoardCreator
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isBoardCreator ? Icons.star_rounded : Icons.group_rounded,
                    size: 11,
                    color: isBoardCreator
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isBoardCreator
                        ? 'คุณเป็นเจ้าของบอร์ด'
                        : 'บอร์ดของ $boardCreatorName (คุณเข้าร่วม)',
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

            // Progress: การ์ดงาน (Kanban) or รายการย่อย
            Builder(
              builder: (context) {
                // ลำดับความสำคัญ: card progress > sub_items progress
                if (task.cardTotal > 0) {
                  final pct = (task.cardDone / task.cardTotal * 100).toInt();
                  final isAllDone = task.cardDone == task.cardTotal;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.view_kanban_rounded,
                                size: 12,
                                color: workMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${task.cardDone}/${task.cardTotal} การ์ด',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: workMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isAllDone
                                  ? const Color(0xFF10B981)
                                  : workBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: task.cardDone / task.cardTotal,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: isAllDone ? const Color(0xFF10B981) : workBlue,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  );
                } else if (task.subItems.isNotEmpty) {
                  final doneCount = task.subItems.where((s) => s.isDone).length;
                  final totalCount = task.subItems.length;
                  final pct = (doneCount / totalCount * 100).toInt();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.checklist_rounded,
                                size: 12,
                                color: workMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$doneCount/$totalCount รายการ',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: workMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$pct%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: workBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: doneCount / totalCount,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: workBlue,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            // Footer: assignee list + due date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Render overlapping avatars for assignees
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
                        width: 24.0 + (assignees.length - 1) * 12.0,
                        child: Stack(
                          children: List.generate(assignees.length, (index) {
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
                                width: 22,
                                height: 22,
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
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 10,
                                        color: workBlue,
                                      )
                                    : null,
                              ),
                            );
                          }),
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

// ─── Create Task Modal Sheet widget ──────────────────────────────
class _CreateTaskModal extends StatefulWidget {
  const _CreateTaskModal({
    required this.users,
    required this.brands,
    required this.categories,
    required this.onSubmit,
  });

  final List<AppUser> users;
  final List<BrandRecord> brands;
  final List<TaskCategoryRecord> categories;
  final Function(
    String,
    String,
    List<String>,
    DateTime,
    String?,
    String?,
    List<String>,
  )
  onSubmit;

  @override
  State<_CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends State<_CreateTaskModal> {
  String? _formBrand;
  String? _formCategory;
  final List<String> _formAssignees = [];
  String _formTitle = '';
  String _formDesc = '';
  DateTime _formDue = DateTime.now().add(const Duration(days: 1));
  final List<TextEditingController> _subControllers = [];
  bool _formLoading = false;

  void _addSubItem() =>
      setState(() => _subControllers.add(TextEditingController()));
  void _removeSubItem(int i) {
    _subControllers[i].dispose();
    setState(() => _subControllers.removeAt(i));
  }

  @override
  void dispose() {
    for (final c in _subControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.add_task_rounded, color: workBlue, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'มอบหมายงานใหม่',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: workText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: workMuted,
                    size: 20,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),

            // ── Row 1: Brand + Category ──
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'แบรนด์',
                    icon: Icons.label_outline_rounded,
                    value: _formBrand,
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— ไม่ระบุ —'),
                      ),
                      ...widget.brands.map(
                        (b) => DropdownMenuItem<String?>(
                          value: b.id,
                          child: Text(
                            b.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _formBrand = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'หมวดหมู่',
                    icon: Icons.folder_outlined,
                    value: _formCategory,
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— ไม่ระบุ —'),
                      ),
                      ...widget.categories.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(
                            c.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _formCategory = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Row 2: Multi-assignee Selector Horizontal list with Avatars ──
            _fieldLabel(
              'ผู้รับผิดชอบ * (เลือกได้มากกว่า 1 คน)',
              Icons.people_outline_rounded,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.users.length,
                itemBuilder: (context, i) {
                  final u = widget.users[i];
                  final isSelected = _formAssignees.contains(u.id);
                  final resolvedAvatar =
                      u.avatarUrl != null && u.avatarUrl!.trim().isNotEmpty
                      ? (u.avatarUrl!.startsWith('r2://')
                            ? u.avatarUrl!.replaceFirst(
                                'r2://',
                                'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
                              )
                            : u.avatarUrl)
                      : null;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _formAssignees.remove(u.id);
                        } else {
                          _formAssignees.add(u.id);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(
                        right: 10,
                        top: 2,
                        bottom: 6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? workBlue
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? const [
                                BoxShadow(
                                  color: Color(0x0F2563EB),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                backgroundImage: resolvedAvatar != null
                                    ? NetworkImage(resolvedAvatar)
                                    : null,
                                radius: 16,
                                child: resolvedAvatar == null
                                    ? Text(
                                        u.firstName[0],
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              if (isSelected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: const BoxDecoration(
                                      color: workBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 7,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.fullName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: workText,
                                ),
                              ),
                              Text(
                                u.position.isEmpty ? '-' : u.position,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: workMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // ── Row 3: Due date ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('กำหนดส่ง *', Icons.calendar_month_rounded),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final p = await showWorkDueDatePicker(
                      context,
                      initialDate: _formDue,
                    );
                    if (p != null) setState(() => _formDue = p);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isWorkDatePast(_formDue)
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFF8FAFC),
                      border: Border.all(
                        color: isWorkDatePast(_formDue)
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFE2E8F0),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('dd MMMM yyyy', 'th').format(_formDue),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isWorkDatePast(_formDue)
                                  ? const Color(0xFFDC2626)
                                  : workText,
                              fontWeight: isWorkDatePast(_formDue)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.calendar_month_rounded,
                          color: isWorkDatePast(_formDue)
                              ? const Color(0xFFDC2626)
                              : workBlue,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isWorkDatePast(_formDue)) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'วันที่กำหนดส่งผ่านมาแล้ว แต่ยังสามารถสร้างงานได้',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Title ──
            _fieldLabel('ชื่องาน *', Icons.title_rounded),
            const SizedBox(height: 4),
            TextField(
              decoration: _inputDeco('กรอกชื่องาน / หัวข้อ'),
              onChanged: (v) => _formTitle = v,
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 16),

            // ── Description ──
            _fieldLabel('รายละเอียดงาน', Icons.notes_rounded),
            const SizedBox(height: 4),
            TextField(
              maxLines: 3,
              decoration: _inputDeco('อธิบายรายละเอียดงาน...'),
              onChanged: (v) => _formDesc = v,
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 16),

            // ── Cards (การ์ดงาน) ──
            Row(
              children: [
                const Icon(
                  Icons.view_kanban_rounded,
                  color: workBlue,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'การ์ดงาน',
                  style: TextStyle(
                    fontSize: 12,
                    color: workText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addSubItem,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    '+ เพิ่มการ์ดงาน',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: workBlue,
                    backgroundColor: const Color(0xFFEFF6FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(
              _subControllers.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: workBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _subControllers[i],
                        decoration: _inputDeco(
                          'ชื่อการ์ดงาน / สิ่งที่ต้องทำ...',
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _removeSubItem(i),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: workMuted,
                        size: 16,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.all(6),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit ──
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [workBlue, workSky],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3F2563EB),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _formLoading
                    ? null
                    : () async {
                        if (_formTitle.trim().isEmpty ||
                            _formAssignees.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'กรุณากรอกชื่องานและเลือกผู้รับผิดชอบอย่างน้อย 1 คน',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _formLoading = true);
                        try {
                          final subItems = _subControllers
                              .map((c) => c.text.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          await widget.onSubmit(
                            _formTitle,
                            _formDesc,
                            _formAssignees,
                            _formDue,
                            _formBrand,
                            _formCategory,
                            subItems,
                          );
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _formLoading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _formLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'มอบหมายงาน',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, icon),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          value: value,
          decoration: _inputDeco('').copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13.5, color: workText),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: workBlue),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: workMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: workMuted),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(color: workBlue, width: 1.5),
      ),
    );
  }
}

class _EditTaskModal extends StatefulWidget {
  const _EditTaskModal({
    required this.task,
    required this.users,
    required this.onSave,
  });

  final TaskRecord task;
  final List<AppUser> users;
  final Future<void> Function({
    required String title,
    required String description,
    required List<String> assigneeIds,
    required DateTime dueDate,
  })
  onSave;

  @override
  State<_EditTaskModal> createState() => _EditTaskModalState();
}

class _EditTaskModalState extends State<_EditTaskModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final Set<String> _assigneeIds;
  late DateTime _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _assigneeIds = {
      ...(widget.task.assigneeIds.isNotEmpty
          ? widget.task.assigneeIds
          : [widget.task.assignedTo]),
    }..removeWhere((id) => id.isEmpty);
    _dueDate = widget.task.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _assigneeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่องานและเลือกผู้รับผิดชอบอย่างน้อย 1 คน'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assigneeIds: _assigneeIds.toList(growable: false),
        dueDate: _dueDate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('แก้ไขงานไม่สำเร็จ: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueDateIsPast = isWorkDatePast(_dueDate);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: workBlue, size: 22),
                SizedBox(width: 8),
                Text(
                  'แก้ไขงานมอบหมาย',
                  style: TextStyle(
                    color: workText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'ชื่องาน',
              style: TextStyle(
                color: workText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: _editInputDecoration('กรอกชื่องาน'),
            ),
            const SizedBox(height: 14),
            const Text(
              'รายละเอียด',
              style: TextStyle(
                color: workText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: _editInputDecoration('รายละเอียดงาน'),
            ),
            const SizedBox(height: 14),
            const Text(
              'ผู้รับผิดชอบ',
              style: TextStyle(
                color: workText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              constraints: const BoxConstraints(maxHeight: 190),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: widget.users.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, index) {
                  final user = widget.users[index];
                  final selected = _assigneeIds.contains(user.id);
                  return CheckboxListTile(
                    value: selected,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.trailing,
                    activeColor: workBlue,
                    title: Text(
                      user.fullName,
                      style: const TextStyle(
                        color: workText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: user.position.isEmpty
                        ? null
                        : Text(
                            user.position,
                            style: const TextStyle(
                              color: workMuted,
                              fontSize: 10.5,
                            ),
                          ),
                    onChanged: (_) => setState(() {
                      if (selected) {
                        _assigneeIds.remove(user.id);
                      } else {
                        _assigneeIds.add(user.id);
                      }
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'วันที่สิ้นสุด',
              style: TextStyle(
                color: workText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showWorkDueDatePicker(
                  context,
                  initialDate: _dueDate,
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: dueDateIsPast
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dueDateIsPast
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: dueDateIsPast ? const Color(0xFFDC2626) : workBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      DateFormat('dd MMMM yyyy', 'th').format(_dueDate),
                      style: TextStyle(
                        color: dueDateIsPast
                            ? const Color(0xFFDC2626)
                            : workText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (dueDateIsPast) ...[
              const SizedBox(height: 6),
              const Text(
                'วันที่สิ้นสุดผ่านมาแล้ว แต่ยังบันทึกได้',
                style: TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('บันทึกการแก้ไข'),
                style: FilledButton.styleFrom(
                  backgroundColor: workBlue,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _editInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: workBlue, width: 1.4),
      ),
    );
  }
}

// ─── Task Detail Bottom Sheet ────────────────────────────────────
class _TaskDetailSheet extends StatelessWidget {
  const _TaskDetailSheet({
    required this.task,
    required this.userMap,
    required this.brandMap,
    required this.catMap,
    required this.statusConfig,
    required this.onEdit,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final TaskRecord task;
  final Map<String, AppUser> userMap;
  final Map<String, BrandRecord> brandMap;
  final Map<String, TaskCategoryRecord> catMap;
  final Map<String, _StatusMeta> statusConfig;
  final VoidCallback onEdit;
  final ValueChanged<String> onChangeStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final user = userMap[task.assignedTo];
    final List<AppUser> detailAssignees = task.assigneeIds.isNotEmpty
        ? task.assigneeIds
              .map((id) => userMap[id])
              .whereType<AppUser>()
              .toList()
        : (user != null ? [user] : []);
    final String assigneeNames = detailAssignees.isNotEmpty
        ? detailAssignees.map((u) => u.fullName).join(', ')
        : 'ไม่ระบุ';
    final brand = task.brandId != null ? brandMap[task.brandId] : null;
    final category = task.categoryId != null ? catMap[task.categoryId] : null;
    final meta = statusConfig[task.status] ?? statusConfig['pending']!;
    final isOverdue = isAssignmentOverdue(task.dueDate, task.status);
    const otherStatuses = ['pending', 'in_progress', 'completed'];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tags
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Status tag
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: meta.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: meta.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: meta.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      meta.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: meta.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (brand != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.label_outline_rounded,
                        size: 12,
                        color: workBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        brand.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: workBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              if (category != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 12,
                        color: Color(0xFFB45309),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: workText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('แก้ไข'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: workBlue,
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ],
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.description,
              style: const TextStyle(
                fontSize: 14,
                color: workMuted,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Assignee + Due date
          Row(
            children: [
              Expanded(
                child: _infoCard(
                  icon: Icons.person_rounded,
                  label: 'ผู้รับผิดชอบ',
                  value: assigneeNames,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  icon: isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.calendar_month_rounded,
                  label: 'กำหนดส่ง',
                  value: DateFormat('dd MMMM yyyy', 'th').format(task.dueDate),
                  valueColor: isOverdue ? Colors.red : workText,
                  iconColor: isOverdue ? Colors.red : workBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-items checklist
          if (task.subItems.isNotEmpty) ...[
            const Text(
              'CHECKLIST',
              style: TextStyle(
                fontSize: 11,
                color: workMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...task.subItems.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.isDone
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: item.isDone
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFCBD5E1),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: item.isDone ? workMuted : workText,
                          decoration: item.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Change status
          const Text(
            'เปลี่ยนสถานะ',
            style: TextStyle(
              fontSize: 11,
              color: workMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: otherStatuses.where((s) => s != task.status).map((s) {
              final m = statusConfig[s]!;
              return OutlinedButton(
                onPressed: () => onChangeStatus(s),
                style: OutlinedButton.styleFrom(
                  foregroundColor: m.color,
                  side: BorderSide(color: m.border, width: 1.5),
                  backgroundColor: m.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  '→ ${m.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Delete
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text(
                'ลบงานนี้',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Color(0xFFFECACA)),
                backgroundColor: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor ?? workBlue),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: workMuted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: valueColor ?? workText,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBottomSheetContent extends StatefulWidget {
  final List<BrandRecord> brands;
  final List<TaskCategoryRecord> categories;
  final String? initialBrandId;
  final String? initialCategoryId;
  final Function(String? brandId, String? categoryId) onApply;

  const _FilterBottomSheetContent({
    super.key,
    required this.brands,
    required this.categories,
    this.initialBrandId,
    this.initialCategoryId,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheetContent> createState() =>
      _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends State<_FilterBottomSheetContent> {
  String? _tempBrandId;
  String? _tempCategoryId;

  @override
  void initState() {
    super.initState();
    _tempBrandId = widget.initialBrandId;
    _tempCategoryId = widget.initialCategoryId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: workBlue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ตัวกรองบอร์ดงาน',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: workText,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: workMuted),
                ),
              ],
            ),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            const Text(
              'แบรนด์ (Brand)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: workText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: 'ทั้งหมด',
                  isSelected: _tempBrandId == null,
                  onTap: () => setState(() => _tempBrandId = null),
                ),
                ...widget.brands.map(
                  (b) => _buildFilterChip(
                    label: b.name,
                    isSelected: _tempBrandId == b.id,
                    onTap: () => setState(() => _tempBrandId = b.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'หมวดหมู่ (Category)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: workText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(
                  label: 'ทั้งหมด',
                  isSelected: _tempCategoryId == null,
                  onTap: () => setState(() => _tempCategoryId = null),
                ),
                ...widget.categories.map(
                  (c) => _buildFilterChip(
                    label: c.name,
                    isSelected: _tempCategoryId == c.id,
                    onTap: () => setState(() => _tempCategoryId = c.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _tempBrandId = null;
                        _tempCategoryId = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: workMuted,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'ล้างตัวกรอง',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_tempBrandId, _tempCategoryId);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: workBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ใช้ตัวกรอง',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final finalActiveColor = activeColor ?? workBlue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? finalActiveColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? finalActiveColor : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? finalActiveColor : workText,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
