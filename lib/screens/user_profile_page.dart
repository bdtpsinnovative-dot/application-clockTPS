import 'package:flutter/material.dart';

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
  });

  final AppUser user;
  final AuthFlowService service;
  final VoidCallback onMenu;
  final Future<void> Function() onSignOut;
  final bool isActive;

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
          physics: const NeverScrollableScrollPhysics(),
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
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
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
                                          size: 34,
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
                    const SizedBox(height: 24),
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
