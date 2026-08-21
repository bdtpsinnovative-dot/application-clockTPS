import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/user_avatar.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, required this.service});

  final AuthFlowService service;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  bool _loading = true;
  List<AppUser> _allUsers = [];
  String? _error;

  bool get _isAdmin => widget.service.currentUser?.role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await widget.service.getAdminUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _approveUser(AppUser user) async {
    if (widget.service.currentUser?.role != 'admin') return;
    try {
      await widget.service.approveUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อนุมัติบัญชี ${user.fullName} สำเร็จแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อนุมัติบัญชีล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unbindDevice(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการปลดล็อกอุปกรณ์'),
        content: Text(
          'ต้องการปลดล็อกอุปกรณ์มือถือของ ${user.fullName} หรือไม่? พนักงานจะสามารถเชื่อมโยงอุปกรณ์เครื่องใหม่ได้เมื่อล็อกอินครั้งถัดไป',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ยืนยันปลดล็อก'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.service.unbindDevice(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ปลดล็อกอุปกรณ์ของ ${user.fullName} สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disableUser(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการปิดใช้งานบัญชี'),
        content: Text(
          'ต้องการระงับการใช้งานบัญชีของ ${user.fullName} หรือไม่? พนักงานคนนี้จะไม่สามารถลงชื่อเข้าใช้งานแอปพลิเคชันได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ยืนยันปิดใช้งาน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.service.disableUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ปิดใช้งานบัญชี ${user.fullName} สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _enableUser(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการเปิดใช้งานบัญชี'),
        content: Text(
          'ต้องการยกเลิกการระงับและเปิดใช้งานบัญชีของ ${user.fullName} หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('เปิดใช้งาน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.service.approveUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เปิดใช้งานบัญชี ${user.fullName} สำเร็จแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  TimeOfDay _parseTime(String value, TimeOfDay fallback) {
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeValue(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<TimeOfDay?> _pickCupertinoTime(
    BuildContext context, {
    required TimeOfDay initialTime,
  }) async {
    var selectedTime = initialTime;
    final now = DateTime.now();
    var initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      initialTime.hour,
      initialTime.minute,
    );

    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    const Text(
                      'เลือกเวลา',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, selectedTime),
                      child: const Text(
                        'ตกลง',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initialDateTime,
                  use24hFormat: true,
                  onDateTimeChanged: (dateTime) {
                    selectedTime = TimeOfDay(
                      hour: dateTime.hour,
                      minute: dateTime.minute,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result;
  }

  Future<void> _editWorkSchedule(AppUser user) async {
    var start = _parseTime(
      user.workStartTime,
      const TimeOfDay(hour: 9, minute: 0),
    );
    var end = _parseTime(
      user.workEndTime,
      const TimeOfDay(hour: 18, minute: 0),
    );
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFF2563EB),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'แก้ไขเวลาทำงาน',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${user.fullName} · ใช้วันจันทร์–ศุกร์',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _ScheduleTimeTile(
                          label: 'เวลาเริ่มงาน',
                          value: _timeValue(start),
                          icon: Icons.login_rounded,
                          accentColor: const Color(0xFF2563EB),
                          onTap: () async {
                            final picked = await _pickCupertinoTime(
                              context,
                              initialTime: start,
                            );
                            if (picked != null) {
                              setSheetState(() => start = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ScheduleTimeTile(
                          label: 'เวลาเลิกงาน',
                          value: _timeValue(end),
                          icon: Icons.logout_rounded,
                          accentColor: const Color(0xFF7C3AED),
                          onTap: () async {
                            final picked = await _pickCupertinoTime(
                              context,
                              initialTime: end,
                            );
                            if (picked != null) {
                              setSheetState(() => end = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final startMinutes = start.hour * 60 + start.minute;
                            final endMinutes = end.hour * 60 + end.minute;
                            if (endMinutes <= startMinutes) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'เวลาเลิกงานต้องอยู่หลังเวลาเริ่มงาน',
                                  ),
                                ),
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            try {
                              await widget.service.updateUserWorkSchedule(
                                userId: user.id,
                                workStartTime: _timeValue(start),
                                workEndTime: _timeValue(end),
                              );
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              await _loadUsers();
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('บันทึกเวลาทำงานแล้ว'),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text('$error')));
                                setSheetState(() => saving = false);
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'บันทึกเวลาทำงาน',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin;
    final pendingUsers = _allUsers.where((u) => u.status == 'pending').toList();

    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: Text(
          isAdmin ? 'จัดการข้อมูลพนักงาน' : 'พนักงานทั้งหมด',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (isAdmin)
            Badge(
              isLabelVisible: pendingUsers.isNotEmpty,
              label: Text('${pendingUsers.length}'),
              backgroundColor: const Color(0xFFEF4444),
              child: IconButton(
                onPressed: () => _showPendingApprovals(pendingUsers),
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'คำขอสมัครสมาชิกที่รออนุมัติ',
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading && _allUsers.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(top: 8),
              child: EmployeeListSkeleton(),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'โหลดข้อมูลล้มเหลว: $_error',
                    style: const TextStyle(color: workText),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUsers,
                    child: const Text('ลองอีกครั้ง'),
                  ),
                ],
              ),
            )
          : _buildActiveList(_allUsers),
    );
  }

  Widget _buildActiveList(List<AppUser> users) {
    if (users.isEmpty) {
      return const Center(
        child: Text(
          'ไม่พบรายชื่อพนักงานในระบบ',
          style: TextStyle(color: workMuted, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x040F172A),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              UserAvatar(avatarUrl: u.avatarUrl, name: u.fullName, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            u.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: u.status == 'disabled'
                                  ? workMuted
                                  : workText,
                              decoration: u.status == 'disabled'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (u.status == 'disabled') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.red.shade200,
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              'ระงับการใช้งาน',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (u.status == 'pending') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFED7AA),
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              'รออนุมัติ',
                              style: TextStyle(
                                color: Color(0xFFC2410C),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      u.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: workMuted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ตำแหน่ง: ${u.position.isEmpty ? 'ไม่ระบุ' : u.position}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: workMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'เวลาทำงาน ${u.workStartTime}–${u.workEndTime}',
                      style: const TextStyle(fontSize: 10, color: workMuted),
                    ),
                  ],
                ),
              ),
              if (_isAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'schedule') {
                      _editWorkSchedule(u);
                    } else if (value == 'unbind') {
                      _unbindDevice(u);
                    } else if (value == 'disable') {
                      _disableUser(u);
                    } else if (value == 'enable') {
                      _enableUser(u);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'schedule',
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: workBlue,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'แก้ไขเวลาทำงาน',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'unbind',
                      child: Row(
                        children: [
                          Icon(
                            Icons.phonelink_erase_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ปลดล็อกเครื่องโทรศัพท์',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (u.status == 'disabled')
                      const PopupMenuItem(
                        value: 'enable',
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.green,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'เปิดใช้งานบัญชี',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'disable',
                        child: Row(
                          children: [
                            Icon(
                              Icons.block_rounded,
                              color: Colors.red,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'ระงับการใช้งานบัญชี',
                              style: TextStyle(fontSize: 11, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                  ],
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: workMuted,
                    size: 20,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showPendingApprovals(List<AppUser> users) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
            ),
            decoration: const BoxDecoration(
              color: workBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'พนักงานรออนุมัติ',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: workText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (users.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'ไม่มีบัญชีที่รออนุมัติ',
                        style: TextStyle(color: workMuted),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                avatarUrl: user.avatarUrl,
                                name: user.fullName,
                                radius: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: workText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: workMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () async {
                                  await _approveUser(user);
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: workBlue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text(
                                  'อนุมัติ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScheduleTimeTile extends StatelessWidget {
  const _ScheduleTimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.accentColor = workBlue,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: accentColor),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  'น.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
