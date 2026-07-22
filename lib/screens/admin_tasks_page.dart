import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/models/app_user.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:hr_management/widgets/app_loading_view.dart';
import 'package:hr_management/screens/task_board_page.dart';


// ─── Status config ───────────────────────────────────────────────
const _statusConfig = {
  'pending':     _StatusMeta('รอทำ',      Color(0xFF64748B), Color(0xFFF1F5F9), Color(0xFFCBD5E1)),
  'in_progress': _StatusMeta('กำลังทำ',   Color(0xFFEA580C), Color(0xFFFFF7ED), Color(0xFFFED7AA)),
  'completed':   _StatusMeta('เสร็จสิ้น', Color(0xFF16A34A), Color(0xFFF0FDF4), Color(0xFFBBF7D0)),
};

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
  List<TaskRecord> _tasks     = [];
  List<AppUser>   _users      = [];
  List<BrandRecord>         _brands     = [];
  List<TaskCategoryRecord>  _categories = [];
  Map<String, AppUser>      _userMap    = {};
  Map<String, BrandRecord>  _brandMap   = {};
  Map<String, TaskCategoryRecord> _catMap = {};
  bool   _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final isEmployee = widget.service.currentUser?.role == 'employee';
      final results = await Future.wait([
        isEmployee ? widget.service.getMyTasks() : widget.service.getAdminTasks(),
        isEmployee ? Future.value(<AppUser>[]) : widget.service.getAdminUsers(),
        widget.service.getBrands(),
        widget.service.getTaskCategories(),
      ]);

      final tasks  = results[0] as List<TaskRecord>;
      final users  = (results[1] as List<AppUser>).where((u) => u.status == 'active').toList();
      final brands = results[2] as List<BrandRecord>;
      final cats   = results[3] as List<TaskCategoryRecord>;

      final Map<String, AppUser>          userMap  = {for (final u in users)  u.id: u};
      final Map<String, BrandRecord>      brandMap = {for (final b in brands) b.id: b};
      final Map<String, TaskCategoryRecord> catMap = {for (final c in cats)   c.id: c};

      if (mounted) {
        setState(() {
          _tasks      = tasks;
          _users      = users;
          _brands     = brands;
          _categories = cats;
          _userMap    = userMap;
          _brandMap   = brandMap;
          _catMap     = catMap;
          _loading    = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบงานสำเร็จ'), backgroundColor: Colors.green));
        _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบงานล้มเหลว: $e'), backgroundColor: Colors.red));
    }
  }

  // ─── Change status ──────────────────────────────────────────────
  Future<void> _changeStatus(TaskRecord task, String newStatus) async {
    try {
      await widget.service.updateTaskStatus(task.id, newStatus);
      if (mounted) _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เปลี่ยนสถานะล้มเหลว: $e'), backgroundColor: Colors.red));
    }
  }



  // ─── Create task modal sheet (โมดูล) ──────────────────────────────
  void _showCreateTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CreateTaskModal(
        users: _users,
        brands: _brands,
        categories: _categories,
        onSubmit: (title, desc, assignees, due, brand, category, cardNames) async {
          // 1. สร้างงานก่อน
          final task = await widget.service.createTask(
            title: title,
            description: desc,
            assignedTo: assignees.isNotEmpty ? assignees.first : '',
            brandId: brand,
            categoryId: category,
            dueDate: due,
            assigneeIds: assignees,
          );
          // 2. ถ้ามีการ์ดงาน → สร้าง list ตั้งต้นแล้วใส่การ์ดเข้าไป
          final validCards = cardNames.where((n) => n.trim().isNotEmpty).toList();
          if (validCards.isNotEmpty) {
            final list = await widget.service.createTaskList(task.id, 'งานทั้งหมด');
            for (final cardName in validCards) {
              await widget.service.createTaskCard(list.id, cardName.trim());
            }
          }
          _loadData();
        },
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoadingView(message: 'กำลังโหลดข้อมูลงาน...');
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('โหลดข้อมูลล้มเหลว: $_error', style: const TextStyle(color: workText)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: const Text('รายการมอบหมายงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (widget.service.currentUser?.role != 'employee')
            IconButton(
              onPressed: _showCreateTaskModal,
              icon: const Icon(Icons.add_task_rounded, color: workBlue),
              tooltip: 'มอบหมายงานใหม่',
            ),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, color: workMuted), tooltip: 'รีโหลด'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _tasks.isEmpty
            ? const Center(
                child: Text(
                  'ยังไม่มีงานมอบหมายในตอนนี้',
                  style: TextStyle(color: workMuted, fontSize: 13),
                ),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _tasks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final t = _tasks[index];
                  return _buildDraggableTaskCard(t);
                },
              ),
      ),
    );

  }

  // ─── Kanban board ───────────────────────────────────────────────


  Widget _buildDraggableTaskCard(TaskRecord task) {
    return _buildTaskCardContent(task);
  }


  Widget _buildTaskCardContent(TaskRecord task) {
    final brand    = task.brandId != null ? _brandMap[task.brandId] : null;
    final category = task.categoryId != null ? _catMap[task.categoryId] : null;
    final isOverdue = task.status != 'completed' && task.dueDate.isBefore(DateTime.now());

    final isEmployee = widget.service.currentUser?.role == 'employee';
    final currentUser = widget.service.currentUser;
    // Multiple assignees mapping
    final assignees = task.subItems.isNotEmpty && task.status == 'completed'
        ? <AppUser>[]
        : (isEmployee && currentUser != null
            ? [currentUser]
            : _users.where((u) {
                if (task.subItems.isNotEmpty) {
                  // Standard field or assignees list mapping
                }
                return u.id == task.assignedTo;
              }).toList());

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
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2))],
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
                    _buildTag(brand.name, const Color(0xFFEFF6FF), workBlue, const Color(0xFFBFDBFE)),
                  if (category != null)
                    _buildTag(category.name, const Color(0xFFFEF3C7), const Color(0xFFB45309), const Color(0xFFFDE68A)),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // Title
            Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: workText)),

            // Description
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: workMuted)),
            ],

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: task.assignedBy == widget.service.currentUserId ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    task.assignedBy == widget.service.currentUserId ? Icons.star_rounded : Icons.group_rounded,
                    size: 11,
                    color: task.assignedBy == widget.service.currentUserId ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    task.assignedBy == widget.service.currentUserId
                        ? 'คุณเป็นเจ้าของบอร์ด'
                        : 'บอร์ดของ ${task.assignedByName?.isNotEmpty == true ? task.assignedByName : "เพื่อนร่วมงาน"} (คุณเข้าร่วม)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: task.assignedBy == widget.service.currentUserId ? const Color(0xFFDC2626) : const Color(0xFF64748B),
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
                              const Icon(Icons.view_kanban_rounded, size: 12, color: workMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${task.cardDone}/${task.cardTotal} การ์ด',
                                style: const TextStyle(fontSize: 10.5, color: workMuted),
                              ),
                            ],
                          ),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isAllDone ? const Color(0xFF10B981) : workBlue,
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
                              const Icon(Icons.checklist_rounded, size: 12, color: workMuted),
                              const SizedBox(width: 4),
                              Text(
                                '$doneCount/$totalCount รายการ',
                                style: const TextStyle(fontSize: 10.5, color: workMuted),
                              ),
                            ],
                          ),
                          Text(
                            '$pct%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: workBlue),
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
                      const Icon(Icons.person_outline_rounded, size: 16, color: workMuted)
                    else
                      SizedBox(
                        height: 24,
                        width: 24.0 + (assignees.length - 1) * 12.0,
                        child: Stack(
                          children: List.generate(assignees.length, (index) {
                            final u = assignees[index];
                            final avatarUrl = u.avatarUrl;
                            final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
                            final resolvedAvatar = hasAvatar
                                ? (avatarUrl.startsWith('r2://')
                                    ? avatarUrl.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                                    : avatarUrl)
                                : null;

                            return Positioned(
                              left: index * 12.0,
                              child: Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFEFF6FF),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  image: resolvedAvatar != null
                                      ? DecorationImage(image: NetworkImage(resolvedAvatar), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: resolvedAvatar == null
                                    ? const Icon(Icons.person_rounded, size: 10, color: workBlue)
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      assignees.length == 1
                          ? assignees.first.firstName
                          : (assignees.length > 1 ? '${assignees.length} คน' : 'ไม่ระบุ'),
                      style: const TextStyle(fontSize: 11, color: workText, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(isOverdue ? Icons.warning_amber_rounded : Icons.calendar_month_rounded,
                        size: 12, color: isOverdue ? Colors.red : workMuted),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat('dd MMM yy').format(task.dueDate),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isOverdue ? Colors.red : workMuted),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
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
  final Function(String, String, List<String>, DateTime, String?, String?, List<String>) onSubmit;

  @override
  State<_CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends State<_CreateTaskModal> {
  String? _formBrand;
  String? _formCategory;
  final List<String> _formAssignees = [];
  String  _formTitle    = '';
  String  _formDesc     = '';
  DateTime _formDue     = DateTime.now().add(const Duration(days: 1));
  final List<TextEditingController> _subControllers = [];
  bool _formLoading = false;

  void _addSubItem() => setState(() => _subControllers.add(TextEditingController()));
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
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: workText),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: workMuted, size: 20),
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
                Expanded(child: _buildDropdown(
                  label: 'แบรนด์',
                  icon: Icons.label_outline_rounded,
                  value: _formBrand,
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('— ไม่ระบุ —')),
                    ...widget.brands.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _formBrand = v),
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildDropdown(
                  label: 'หมวดหมู่',
                  icon: Icons.folder_outlined,
                  value: _formCategory,
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('— ไม่ระบุ —')),
                    ...widget.categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 13)))),
                  ],
                  onChanged: (v) => setState(() => _formCategory = v),
                )),
              ],
            ),
            const SizedBox(height: 16),

            // ── Row 2: Multi-assignee Selector Horizontal list with Avatars ──
            _fieldLabel('ผู้รับผิดชอบ * (เลือกได้มากกว่า 1 คน)', Icons.people_outline_rounded),
            const SizedBox(height: 4),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.users.length,
                itemBuilder: (context, i) {
                  final u = widget.users[i];
                  final isSelected = _formAssignees.contains(u.id);
                  final resolvedAvatar = u.avatarUrl != null && u.avatarUrl!.trim().isNotEmpty
                      ? (u.avatarUrl!.startsWith('r2://')
                          ? u.avatarUrl!.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
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
                      margin: const EdgeInsets.only(right: 10, top: 2, bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? workBlue : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? const [BoxShadow(color: Color(0x0F2563EB), blurRadius: 6, offset: Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                backgroundImage: resolvedAvatar != null ? NetworkImage(resolvedAvatar) : null,
                                radius: 16,
                                child: resolvedAvatar == null ? Text(u.firstName[0], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)) : null,
                              ),
                              if (isSelected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: const BoxDecoration(color: workBlue, shape: BoxShape.circle),
                                    child: const Icon(Icons.check, size: 7, color: Colors.white),
                                  ),
                                )
                            ],
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: workText)),
                              Text(u.position.isEmpty ? '-' : u.position, style: const TextStyle(fontSize: 9, color: workMuted)),
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
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _formDue,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (p != null) setState(() => _formDue = p);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(DateFormat('dd MMMM yyyy', 'th').format(_formDue), style: const TextStyle(fontSize: 13.5, color: workText))),
                        const Icon(Icons.calendar_month_rounded, color: workBlue, size: 18),
                      ],
                    ),
                  ),
                ),
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
                const Icon(Icons.view_kanban_rounded, color: workBlue, size: 16),
                const SizedBox(width: 6),
                const Text('การ์ดงาน', style: TextStyle(fontSize: 12, color: workText, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addSubItem,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+ เพิ่มการ์ดงาน', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: workBlue,
                    backgroundColor: const Color(0xFFEFF6FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(_subControllers.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                    child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 10, color: workBlue, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: _subControllers[i],
                    decoration: _inputDeco('ชื่อการ์ดงาน / สิ่งที่ต้องทำ...'),
                    style: const TextStyle(fontSize: 13),
                  )),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _removeSubItem(i),
                    icon: const Icon(Icons.close_rounded, color: workMuted, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.all(6),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            )),
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
                  )
                ],
              ),
              child: ElevatedButton(
                onPressed: _formLoading ? null : () async {
                  if (_formTitle.trim().isEmpty || _formAssignees.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่องานและเลือกผู้รับผิดชอบอย่างน้อย 1 คน')));
                    return;
                  }
                  setState(() => _formLoading = true);
                  try {
                    final subItems = _subControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
                  } finally {
                    if (mounted) setState(() => _formLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _formLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('มอบหมายงาน', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
          decoration: _inputDeco('').copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: workMuted, fontWeight: FontWeight.bold)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: workBlue, width: 1.5)),
    );
  }
}

// ─── Task Detail Bottom Sheet ────────────────────────────────────
class _TaskDetailSheet extends StatefulWidget {
  const _TaskDetailSheet({
    required this.task,
    required this.userMap,
    required this.brandMap,
    required this.catMap,
    required this.statusConfig,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final TaskRecord task;
  final Map<String, AppUser> userMap;
  final Map<String, BrandRecord> brandMap;
  final Map<String, TaskCategoryRecord> catMap;
  final Map<String, _StatusMeta> statusConfig;
  final ValueChanged<String> onChangeStatus;
  final VoidCallback onDelete;

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  final _commentController = TextEditingController();
  List<TaskEvent> _events = [];
  bool _isLoadingEvents = true;
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final authSvc = Provider.of<AuthFlowService>(context, listen: false);
      final events = await authSvc.fetchTaskEvents(widget.task.id);
      if (mounted) {
        setState(() {
          _events = events;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEvents = false);
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isPostingComment = true);
    try {
      final authSvc = Provider.of<AuthFlowService>(context, listen: false);
      final newEvent = await authSvc.addTaskComment(widget.task.id, text);
      if (mounted) {
        setState(() {
          _events.add(newEvent);
          _commentController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isPostingComment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user     = widget.userMap[widget.task.assignedTo];
    final brand    = widget.task.brandId != null ? widget.brandMap[widget.task.brandId] : null;
    final category = widget.task.categoryId != null ? widget.catMap[widget.task.categoryId] : null;
    final meta     = widget.statusConfig[widget.task.status]!;
    final isOverdue = widget.task.status != 'completed' && widget.task.dueDate.isBefore(DateTime.now());
    const otherStatuses = ['pending', 'in_progress', 'completed'];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // Tags
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // Status tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: meta.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: meta.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: meta.color)),
                    const SizedBox(width: 6),
                    Text(meta.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: meta.color)),
                  ]),
                ),
                if (brand != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.label_outline_rounded, size: 12, color: workBlue),
                      const SizedBox(width: 4),
                      Text(brand.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: workBlue)),
                    ]),
                  ),
                if (category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.folder_outlined, size: 12, color: Color(0xFFB45309)),
                      const SizedBox(width: 4),
                      Text(category.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(widget.task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: workText)),
            if (widget.task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.task.description, style: const TextStyle(fontSize: 14, color: workMuted, height: 1.6)),
            ],
            const SizedBox(height: 16),

            // Assignee + Due date
            Row(
              children: [
                Expanded(child: _infoCard(
                  icon: Icons.person_rounded,
                  label: 'ผู้รับผิดชอบ',
                  value: user?.fullName ?? 'ไม่ระบุ',
                )),
                const SizedBox(width: 12),
                Expanded(child: _infoCard(
                  icon: isOverdue ? Icons.warning_amber_rounded : Icons.calendar_month_rounded,
                  label: 'กำหนดส่ง',
                  value: DateFormat('dd MMMM yyyy', 'th').format(widget.task.dueDate),
                  valueColor: isOverdue ? Colors.red : workText,
                  iconColor: isOverdue ? Colors.red : workBlue,
                )),
              ],
            ),
            const SizedBox(height: 16),

            // Sub-items checklist
            if (widget.task.subItems.isNotEmpty) ...[
              const Text('CHECKLIST', style: TextStyle(fontSize: 11, color: workMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              ...widget.task.subItems.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(
                      item.isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: item.isDone ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      item.title,
                      style: TextStyle(fontSize: 13, color: item.isDone ? workMuted : workText, decoration: item.isDone ? TextDecoration.lineThrough : null),
                    )),
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],

            // Change status
            const Text('เปลี่ยนสถานะ', style: TextStyle(fontSize: 11, color: workMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: otherStatuses.where((s) => s != widget.task.status).map((s) {
                final m = widget.statusConfig[s]!;
                return OutlinedButton(
                  onPressed: () => widget.onChangeStatus(s),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: m.color,
                    side: BorderSide(color: m.border, width: 1.5),
                    backgroundColor: m.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text('→ ${m.label}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Timeline & Comments
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            const Text('TIMELINE & COMMENTS', style: TextStyle(fontSize: 11, color: workMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            
            if (_isLoadingEvents)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_events.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('ยังไม่มีประวัติการพูดคุย', style: TextStyle(color: workMuted, fontSize: 13))))
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final ev = _events[index];
                    final isSystem = ev.eventType == 'system';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: isSystem ? const Color(0xFFE2E8F0) : const Color(0xFFDBEAFE),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: isSystem
                              ? const Icon(Icons.smart_toy_rounded, size: 14, color: Color(0xFF64748B))
                              : (ev.userAvatarUrl != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(ev.userAvatarUrl!, width: 28, height: 28, fit: BoxFit.cover))
                                  : Text(ev.userFirstName?.isNotEmpty == true ? ev.userFirstName![0] : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: workBlue))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: isSystem ? 0 : 12, vertical: isSystem ? 4 : 10),
                              decoration: BoxDecoration(
                                color: isSystem ? Colors.transparent : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(isSystem ? 'ระบบ' : (ev.userFirstName ?? 'Unknown'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: workText)),
                                      Text(DateFormat('dd MMM HH:mm', 'th').format(ev.createdAt), style: const TextStyle(fontSize: 10, color: workMuted)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ev.content ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isSystem ? workMuted : workText,
                                      fontStyle: isSystem ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Comment Input
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'พิมพ์คอมเมนต์หรืออัปเดตงาน...',
                      hintStyle: const TextStyle(fontSize: 13, color: workMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: workBlue, width: 1.5)),
                    ),
                    style: const TextStyle(fontSize: 13),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _isPostingComment ? null : _postComment,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _isPostingComment ? workMuted : workBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: _isPostingComment
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Delete
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('ลบงานนี้', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  backgroundColor: const Color(0xFFFEF2F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({required IconData icon, required String label, required String value, Color? valueColor, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: iconColor ?? workBlue),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: workMuted)),
        ]),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: valueColor ?? workText)),
      ]),
    );
  }
}
