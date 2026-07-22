import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/avatar_picker.dart';

import '../models/app_user.dart';
import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.user,
    required this.service,
    required this.onMenu,
    required this.onSignOut,
    required this.isActive,
    required this.onProfileUpdated,
  });

  final AppUser user;
  final AuthFlowService service;
  final VoidCallback onMenu;
  final Future<void> Function() onSignOut;
  final bool isActive;
  final VoidCallback onProfileUpdated;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late Future<List<LeaveBalanceRecord>> _leaveBalancesFuture;

  @override
  void initState() {
    super.initState();
    _leaveBalancesFuture = widget.service.getLeaveBalances(DateTime.now().year);
  }

  @override
  void didUpdateWidget(covariant UserProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      setState(() {
        _leaveBalancesFuture = widget.service.getLeaveBalances(DateTime.now().year);
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _leaveBalancesFuture = widget.service.getLeaveBalances(DateTime.now().year);
    });
    await _leaveBalancesFuture;
  }

  void _showEditProfileBottomSheet(BuildContext context) {
    final firstCtrl = TextEditingController(text: widget.user.firstName);
    final lastCtrl = TextEditingController(text: widget.user.lastName);
    File? selectedFile;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'แก้ไขข้อมูลโปรไฟล์',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: workText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    AvatarPicker(
                      initialImageUrl: widget.user.avatarUrl != null && widget.user.avatarUrl!.trim().isNotEmpty
                          ? (widget.user.avatarUrl!.startsWith('r2://')
                              ? widget.user.avatarUrl!.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                              : widget.user.avatarUrl!)
                          : null,
                      onImagePicked: (file) {
                        setModalState(() {
                          selectedFile = file;
                        });
                      },
                      onError: (msg) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: Colors.red),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ชื่อจริง',
                      style: TextStyle(
                        fontSize: 11,
                        color: workMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: firstCtrl,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'นามสกุล',
                      style: TextStyle(
                        fontSize: 11,
                        color: workMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: lastCtrl,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final fName = firstCtrl.text.trim();
                              final lName = lastCtrl.text.trim();
                              if (fName.isEmpty || lName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('กรุณากรอกชื่อและนามสกุล'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setModalState(() {
                                saving = true;
                              });

                              try {
                                String finalAvatarUrl = widget.user.avatarUrl ?? '';
                                if (selectedFile != null) {
                                  final uploadedUrl = await widget.service.uploadImage(selectedFile!);
                                  finalAvatarUrl = uploadedUrl;
                                }

                                await widget.service.updateProfileInfo(
                                  firstName: fName,
                                  lastName: lName,
                                  avatarUrl: finalAvatarUrl,
                                );

                                if (context.mounted) {
                                  widget.onProfileUpdated();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('อัปเดตข้อมูลโปรไฟล์เรียบร้อยแล้ว'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                setModalState(() {
                                  saving = false;
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: workBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('บันทึกข้อมูล', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeaveBalancesList(List<LeaveBalanceRecord> balances) {
    if (balances.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'ไม่มีข้อมูลโควตาวันลา',
            style: TextStyle(color: workMuted, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: balances.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final b = balances[index];
        Color progressColor;
        switch (b.leaveType) {
          case 'ลาป่วย':
            progressColor = const Color(0xFFEF4444);
            break;
          case 'ลากิจ':
            progressColor = const Color(0xFFF59E0B);
            break;
          case 'ลาพักร้อน':
            progressColor = const Color(0xFF10B981);
            break;
          default:
            progressColor = workBlue;
        }

        final total = b.quota.toInt();
        final remaining = b.remaining.toInt();
        final used = b.used.toInt();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  b.leaveType,
                  style: const TextStyle(
                    color: workText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'ใช้ $used / ทั้งหมด $total วัน (เหลือ $remaining)',
                  style: const TextStyle(
                    color: workMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : used / total,
                minHeight: 6,
                color: progressColor,
                backgroundColor: const Color(0xFFF1F5F9),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: workBackground,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            WorkHeader(
              title: 'โปรไฟล์ของฉัน',
              subtitle: widget.user.email,
              bottomPadding: 56,
            ),
            Transform.translate(
              offset: const Offset(0, -42),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    WorkCard(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Compact Avatar Image
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _showEditProfileBottomSheet(context),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.08),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                          image: widget.user.avatarUrl != null && widget.user.avatarUrl!.trim().isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(
                                                    widget.user.avatarUrl!.startsWith('r2://')
                                                        ? widget.user.avatarUrl!.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                                                        : widget.user.avatarUrl!,
                                                  ),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: widget.user.avatarUrl != null && widget.user.avatarUrl!.trim().isNotEmpty
                                            ? null
                                            : const Icon(
                                                Icons.person_rounded,
                                                color: workMuted,
                                                size: 38,
                                              ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: workBlue,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.user.fullName,
                                  style: const TextStyle(
                                    color: workText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.user.position.isEmpty ? 'พนักงานทั่วไป' : widget.user.position,
                                  style: const TextStyle(
                                    color: workMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                StatusBadge(status: widget.user.status),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 8),
                          _ProfileRow(
                            icon: Icons.email_outlined,
                            label: 'อีเมล',
                            value: widget.user.email,
                          ),
                          _ProfileRow(
                            icon: Icons.business_outlined,
                            label: 'แผนก',
                            value: widget.user.department.isEmpty
                                ? 'ยังไม่ระบุ'
                                : widget.user.department,
                          ),
                          _ProfileRow(
                            icon: Icons.badge_outlined,
                            label: 'ตำแหน่ง',
                            value: widget.user.position.isEmpty
                                ? 'ยังไม่ระบุ'
                                : widget.user.position,
                          ),
                          _ProfileRow(
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'สิทธิ์การใช้งาน',
                            value: widget.user.role == 'admin' ? 'ผู้ดูแลระบบ (Admin)' : 'พนักงาน (Employee)',
                          ),
                          _ProfileRow(
                            icon: Icons.face_retouching_natural_outlined,
                            label: 'ข้อมูลใบหน้า',
                            value: widget.user.hasFaceEmbedding ? 'ลงทะเบียนแล้ว' : 'ยังไม่ได้ลงทะเบียน',
                            valueColor: widget.user.hasFaceEmbedding ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                          
                          // Divide profile and leave quotas inside the same card!
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.pie_chart_outline_rounded,
                                  color: workBlue,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'สิทธิ์วันลาคงเหลือ',
                                style: TextStyle(
                                  color: workText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder<List<LeaveBalanceRecord>>(
                            future: _leaveBalancesFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: workBlue,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (snapshot.hasError) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: Text(
                                      'ไม่สามารถโหลดข้อมูลสิทธิ์วันลาได้',
                                      style: TextStyle(color: Colors.red, fontSize: 13),
                                    ),
                                  ),
                                );
                              }
                              return _buildLeaveBalancesList(snapshot.data ?? []);
                            },
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton.icon(
                              onPressed: widget.onSignOut,
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFEF4444),
                                size: 16,
                              ),
                              label: const Text(
                                'ออกจากระบบ',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
       ),
      );
    }
  }

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: workMuted, size: 18),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: workMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: valueColor ?? workText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
