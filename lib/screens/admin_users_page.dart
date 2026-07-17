import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/app_loading_view.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    required this.service,
  });

  final AuthFlowService service;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  List<AppUser> _allUsers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        content: Text('ต้องการปลดล็อกอุปกรณ์มือถือของ ${user.fullName} หรือไม่? พนักงานจะสามารถเชื่อมโยงอุปกรณ์เครื่องใหม่ได้เมื่อล็อกอินครั้งถัดไป'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
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
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _disableUser(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการปิดใช้งานบัญชี'),
        content: Text('ต้องการระงับการใช้งานบัญชีของ ${user.fullName} หรือไม่? พนักงานคนนี้จะไม่สามารถลงชื่อเข้าใช้งานแอปพลิเคชันได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
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
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _enableUser(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการเปิดใช้งานบัญชี'),
        content: Text('ต้องการยกเลิกการระงับและเปิดใช้งานบัญชีของ ${user.fullName} หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
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
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingUsers = _allUsers.where((u) => u.status == 'pending').toList();
    final activeUsers = _allUsers.where((u) => u.status == 'active' || u.status == 'disabled').toList();

    return Scaffold(
      backgroundColor: workBackground,
      appBar: AppBar(
        title: const Text('จัดการข้อมูลพนักงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: workBlue,
          unselectedLabelColor: workMuted,
          indicatorColor: workBlue,
          tabs: [
            Tab(text: 'รออนุมัติ (${pendingUsers.length})'),
            Tab(text: 'พนักงานทั้งหมด (${activeUsers.length})'),
          ],
        ),
      ),
      body: _loading
          ? const AppLoadingView(message: 'กำลังโหลดข้อมูลพนักงาน...')
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('โหลดข้อมูลล้มเหลว: $_error', style: const TextStyle(color: workText)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadUsers, child: const Text('ลองอีกครั้ง')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingList(pendingUsers),
                    _buildActiveList(activeUsers),
                  ],
                ),
    );
  }

  Widget _buildPendingList(List<AppUser> users) {
    if (users.isEmpty) {
      return const Center(
        child: Text(
          'ไม่มีพนักงานที่รอการอนุมัติในขณะนี้ 🎉',
          style: TextStyle(color: workMuted, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final u = users[index];
        final avatarUrl = u.avatarUrl;
        final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
        final httpAvatarUrl = hasAvatar
            ? (avatarUrl.startsWith('r2://')
                ? avatarUrl.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                : avatarUrl)
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 1))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9),
                  image: hasAvatar
                      ? DecorationImage(image: NetworkImage(httpAvatarUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: hasAvatar ? null : const Icon(Icons.person_rounded, color: workMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: workText),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      u.email,
                      style: const TextStyle(fontSize: 11, color: workMuted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'แผนก: ${u.department.isEmpty ? 'ไม่ระบุ' : u.department} · ตำแหน่ง: ${u.position.isEmpty ? 'ไม่ระบุ' : u.position}',
                      style: const TextStyle(fontSize: 10, color: workMuted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => _approveUser(u),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: workBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('อนุมัติบัญชี', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
        final avatarUrl = u.avatarUrl;
        final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
        final httpAvatarUrl = hasAvatar
            ? (avatarUrl.startsWith('r2://')
                ? avatarUrl.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                : avatarUrl)
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [BoxShadow(color: Color(0x040F172A), blurRadius: 6, offset: Offset(0, 1))],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9),
                  image: hasAvatar
                      ? DecorationImage(image: NetworkImage(httpAvatarUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: hasAvatar ? null : const Icon(Icons.person_rounded, color: workMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          u.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: u.status == 'disabled' ? workMuted : workText,
                            decoration: u.status == 'disabled' ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (u.status == 'disabled') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200, width: 0.5),
                            ),
                            child: const Text(
                              'ระงับการใช้งาน',
                              style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      u.email,
                      style: const TextStyle(fontSize: 11, color: workMuted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ตำแหน่ง: ${u.position.isEmpty ? 'ไม่ระบุ' : u.position}',
                      style: const TextStyle(fontSize: 10, color: workMuted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'unbind') {
                    _unbindDevice(u);
                  } else if (value == 'disable') {
                    _disableUser(u);
                  } else if (value == 'enable') {
                    _enableUser(u);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'unbind',
                    child: Row(
                      children: [
                        Icon(Icons.phonelink_erase_rounded, color: Colors.amber, size: 16),
                        SizedBox(width: 8),
                        Text('ปลดล็อกเครื่องโทรศัพท์', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  if (u.status == 'disabled')
                    const PopupMenuItem(
                      value: 'enable',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Text('เปิดใช้งานบัญชี', style: TextStyle(fontSize: 11, color: Colors.green)),
                        ],
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'disable',
                      child: Row(
                        children: [
                          Icon(Icons.block_rounded, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('ระงับการใช้งานบัญชี', style: TextStyle(fontSize: 11, color: Colors.red)),
                        ],
                      ),
                    ),
                ],
                icon: const Icon(Icons.more_vert_rounded, color: workMuted, size: 20),
              )
            ],
          ),
        );
      },
    );
  }
}
