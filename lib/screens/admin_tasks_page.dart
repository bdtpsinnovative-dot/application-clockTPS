import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hr_management/services/auth_flow_service.dart';
import 'package:hr_management/models/app_user.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/widgets/work_ui.dart';
import 'package:hr_management/widgets/app_loading_view.dart';

class AdminTasksPage extends StatefulWidget {
  const AdminTasksPage({super.key, required this.service});

  final AuthFlowService service;

  @override
  State<AdminTasksPage> createState() => _AdminTasksPageState();
}

class _AdminTasksPageState extends State<AdminTasksPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TaskRecord> _tasks = [];
  List<AppUser> _users = [];
  Map<String, AppUser> _userMap = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load all tasks
      final tasks = await widget.service.getAdminTasks();
      
      // Load active users to map names
      final usersRaw = await widget.service.getAdminUsers();
      final activeUsers = usersRaw.where((u) => u.status == 'active').toList();

      final Map<String, AppUser> map = {};
      for (final u in activeUsers) {
        map[u.id] = u;
      }

      setState(() {
        _tasks = tasks;
        _users = activeUsers;
        _userMap = map;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteTask(TaskRecord task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบงาน'),
        content: Text('คุณต้องการลบงาน "${task.title}" ใช่หรือไม่?'),
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

    if (confirm != true) return;

    try {
      await widget.service.deleteTask(task.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบงานสำเร็จเรียบร้อยแล้ว'), backgroundColor: Colors.green),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบงานล้มเหลว: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddTaskBottomSheet() {
    if (_users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีรายชื่อพนักงานที่สามารถมอบหมายงานให้ได้'), backgroundColor: Colors.orange),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    String title = '';
    String description = '';
    String? selectedUserId = _users.first.id;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'มอบหมายงานใหม่',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: workText),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: workMuted),
                    ),
                  ],
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),
                // Employee Dropdown
                const Text('พนักงานผู้รับผิดชอบ', style: TextStyle(fontSize: 11, color: workMuted, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedUserId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  items: _users.map((u) {
                    final hasAvatar = u.avatarUrl != null && u.avatarUrl!.trim().isNotEmpty;
                    final avatarUrl = hasAvatar
                        ? (u.avatarUrl!.startsWith('r2://')
                            ? u.avatarUrl!.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                            : u.avatarUrl!)
                        : null;

                    return DropdownMenuItem(
                      value: u.id,
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade300, width: 0.5),
                            ),
                            child: ClipOval(
                              child: hasAvatar
                                  ? Image.network(
                                      avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.person_rounded,
                                        size: 14,
                                        color: workMuted,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 14,
                                      color: workMuted,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${u.fullName} (${u.position.isNotEmpty ? u.position : (u.role == 'admin' ? 'แอดมิน' : 'พนักงาน')})',
                            style: const TextStyle(fontSize: 13, color: workText),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setModalState(() {
                      selectedUserId = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Title Field
                const Text('หัวข้องาน', style: TextStyle(fontSize: 11, color: workMuted, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  decoration: InputDecoration(
                    hintText: 'กรอกหัวข้องาน/คำสั่งสั้นๆ',
                    hintStyle: const TextStyle(fontSize: 12, color: workMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  validator: (val) => val == null || val.trim().isEmpty ? 'กรุณากรอกหัวข้องาน' : null,
                  onSaved: (val) => title = val!.trim(),
                ),
                const SizedBox(height: 12),
                // Description Field
                const Text('รายละเอียดงาน', style: TextStyle(fontSize: 11, color: workMuted, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'ระบุรายละเอียดคำสั่งเพิ่มเติม',
                    hintStyle: const TextStyle(fontSize: 12, color: workMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSaved: (val) => description = val?.trim() ?? '',
                ),
                const SizedBox(height: 12),
                // Due Date DatePicker
                const Text('กำหนดส่งงาน', style: TextStyle(fontSize: 11, color: workMuted, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setModalState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMMM yyyy', 'th').format(selectedDate),
                          style: const TextStyle(fontSize: 13, color: workText),
                        ),
                        const Icon(Icons.calendar_month_rounded, color: workBlue, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      formKey.currentState!.save();
                      Navigator.pop(context);

                      try {
                        await widget.service.createTask(
                          title: title,
                          description: description,
                          assignedTo: selectedUserId!,
                          dueDate: selectedDate,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('มอบหมายงานสำเร็จ'), backgroundColor: Colors.green),
                        );
                        _loadData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('มอบหมายงานล้มเหลว: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: workBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('บันทึกการมอบหมาย', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingTasks = _tasks.where((t) => t.status == 'pending').toList();
    final progressTasks = _tasks.where((t) => t.status == 'in_progress').toList();
    final completedTasks = _tasks.where((t) => t.status == 'completed').toList();

    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: const Text('มอบหมายงานพนักงาน (Task Board)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            onPressed: _showAddTaskBottomSheet,
            icon: const Icon(Icons.add_task_rounded, color: workBlue),
            tooltip: 'มอบหมายงานใหม่',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: workBlue,
          unselectedLabelColor: workMuted,
          indicatorColor: workBlue,
          tabs: [
            Tab(text: 'รอทำ (${pendingTasks.length})'),
            Tab(text: 'กำลังทำ (${progressTasks.length})'),
            Tab(text: 'เสร็จสิ้น (${completedTasks.length})'),
          ],
        ),
      ),
      body: _loading
          ? const AppLoadingView(message: 'กำลังโหลดข้อมูลงาน...')
          : _error != null
              ? Center(
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
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList(pendingTasks),
                    _buildTaskList(progressTasks),
                    _buildTaskList(completedTasks),
                  ],
                ),
    );
  }

  Widget _buildTaskList(List<TaskRecord> tasks) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          'ไม่มีรายการงานในสถานะนี้',
          style: TextStyle(color: workMuted, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final t = tasks[index];
        final user = _userMap[t.assignedTo];
        final userName = user?.fullName ?? 'ไม่ระบุพนักงาน';
        final hasAvatar = user?.avatarUrl != null && user!.avatarUrl!.trim().isNotEmpty;
        final avatarUrl = hasAvatar
            ? (user.avatarUrl!.startsWith('r2://')
                ? user.avatarUrl!.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                : user.avatarUrl!)
            : '';

        Color statusColor;
        if (t.status == 'in_progress') {
          statusColor = const Color(0xFFEA580C);
        } else if (t.status == 'completed') {
          statusColor = const Color(0xFF10B981);
        } else {
          statusColor = const Color(0xFF94A3B8);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      t.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: workText),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteTask(t),
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                ],
              ),
              if (t.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  t.description,
                  style: const TextStyle(fontSize: 11, color: workMuted),
                ),
              ],
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Employee row
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF1F5F9),
                          image: hasAvatar
                              ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: hasAvatar ? null : const Icon(Icons.person_rounded, color: workMuted, size: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        userName,
                        style: const TextStyle(fontSize: 11, color: workText, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  // Due Date
                  Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        'ส่ง: ${DateFormat('dd MMM yy').format(t.dueDate)}',
                        style: TextStyle(fontSize: 10.5, color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
