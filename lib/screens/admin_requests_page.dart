import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../services/fcm_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/skeleton_loading.dart';

class AdminRequestsPage extends StatefulWidget {
  const AdminRequestsPage({
    super.key,
    required this.service,
    required this.onMenu,
    required this.isActive,
    this.targetRequestId,
    this.onClearTargetRequest,
  });

  final AuthFlowService service;
  final VoidCallback onMenu;
  final bool isActive;
  final String? targetRequestId;
  final VoidCallback? onClearTargetRequest;

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  bool _loading = true;
  List<WorkRequestRecord> _requests = [];
  Map<String, AppUser> _userMap = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void didUpdateWidget(covariant AdminRequestsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadRequestsBackground();
    } else if (widget.isActive && widget.targetRequestId != oldWidget.targetRequestId) {
      _checkTargetRequest();
    }
  }

  Future<void> _checkTargetRequest() async {
    if (widget.targetRequestId == null || !widget.isActive) return;

    // 1. ลองหาในลิสต์คำขอที่รอนุมัติก่อน
    var targetIdx = _requests.indexWhere((r) => r.id == widget.targetRequestId);
    WorkRequestRecord? target;

    if (targetIdx != -1) {
      target = _requests[targetIdx];
    } else {
      // 2. ถ้าไม่พบ (อาจถูกอนุมัติหรือปฏิเสธไปแล้ว) ให้ลองดึงข้อมูลคำขอทั้งหมดมาหา
      try {
        final allReqs = await widget.service.getAdminAllRequests();
        targetIdx = allReqs.indexWhere((r) => r.id == widget.targetRequestId);
        if (targetIdx != -1) {
          target = allReqs[targetIdx];
        }
      } catch (_) {}
    }

    if (target != null) {
      final targetUser = _userMap[target.userId];

      // ล้างค่า target เพื่อไม่ให้เปิดซ้ำเมื่อมีการ rebuild
      widget.onClearTargetRequest?.call();

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showRequestDetailsBottomSheet(target!, targetUser);
        });
      }
    }
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.service.getAdminUsers(),
        widget.service.getAdminPendingRequests(),
      ]);

      final users = results[0] as List<AppUser>;
      final reqs = results[1] as List<WorkRequestRecord>;

      if (mounted) {
        setState(() {
          _userMap = {for (var u in users) u.id: u};
          _requests = reqs;
          _loading = false;
        });
        _checkTargetRequest();
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

  Future<void> _loadRequestsBackground() async {
    try {
      final results = await Future.wait([
        widget.service.getAdminUsers(),
        widget.service.getAdminPendingRequests(),
      ]);

      final users = results[0] as List<AppUser>;
      final reqs = results[1] as List<WorkRequestRecord>;

      if (mounted) {
        setState(() {
          _userMap = {for (var u in users) u.id: u};
          _requests = reqs;
        });
        _checkTargetRequest();
      }
    } catch (_) {}
  }

  Future<void> _handleAction(WorkRequestRecord r, String status) async {
    final statusText = status == 'approved' ? 'อนุมัติ' : 'ปฏิเสธ';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการ$statusText'),
        content: Text('ต้องการ$statusTextคำขอของ ${_userMap[r.userId]?.fullName ?? 'พนักงาน'} หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: status == 'approved' ? workBlue : Colors.red),
            child: Text('ยืนยัน$statusText'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (r.isOffsite) {
        await widget.service.updateOffsiteStatusAdmin(r.id, status);
      } else {
        await widget.service.updateLeaveStatusAdmin(r.id, status);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$statusTextคำขอสำเร็จเรียบร้อยแล้ว'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.orange,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('การประมวลผลล้มเหลว: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAttachmentPreview(String url) {
    final hasUrl = url.trim().isNotEmpty;
    final httpUrl = hasUrl
        ? (url.startsWith('r2://')
            ? url.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
            : url)
        : '';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (httpUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  httpUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(24),
                    child: const Column(
                      children: [
                        Icon(Icons.broken_image_rounded, color: Colors.red, size: 48),
                        SizedBox(height: 8),
                        Text('ไม่สามารถโหลดรูปภาพหลักฐานได้', style: TextStyle(color: workText)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetailsBottomSheet(WorkRequestRecord r, AppUser? user) {
    final userName = user?.fullName ?? 'ไม่ระบุชื่อพนักงาน';
    final department = user?.department.isEmpty == false ? user!.department : 'ไม่ระบุแผนก';
    final position = user?.position.isEmpty == false ? user!.position : 'ไม่ระบุตำแหน่ง';
    final hasAvatar = user?.avatarUrl != null && user!.avatarUrl!.trim().isNotEmpty;
    final avatarUrl = hasAvatar
        ? (user.avatarUrl!.startsWith('r2://')
            ? user.avatarUrl!.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
            : user.avatarUrl!)
        : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'รายละเอียดคำขออนุมัติ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: workText),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: workMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Employee Info
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF1F5F9),
                          image: hasAvatar
                              ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: hasAvatar ? null : const Icon(Icons.person_rounded, color: workMuted, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: workText),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'แผนก: $department · ตำแหน่ง: $position',
                              style: const TextStyle(fontSize: 11, color: workMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Request Details Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('ประเภทคำขอ', r.type, isHighlight: true),
                        const SizedBox(height: 8),
                        _buildDetailRow('วันที่ขอลา/ไปงาน', DateFormat('dd MMMM yyyy', 'th').format(r.date)),
                        if (r.duration != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow('ระยะเวลา', r.duration!),
                        ],
                        const SizedBox(height: 8),
                        _buildDetailRow('เหตุผลที่ขอ', r.reason.isEmpty ? 'ไม่ระบุเหตุผล' : r.reason),
                      ],
                    ),
                  ),
                  if (r.attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'เอกสารแนบประกอบ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: workText),
                    ),
                    const SizedBox(height: 8),
                    ...r.attachments.map((url) => InkWell(
                      onTap: () => _showAttachmentPreview(url),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.image_search_rounded, color: workBlue, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ใบรับรองแพทย์ / เอกสารหลักฐาน',
                                    style: TextStyle(fontSize: 12, color: workBlue, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'คลิกเพื่อเปิดดูรูปภาพหลักฐาน',
                                    style: TextStyle(fontSize: 10, color: workMuted),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: workBlue, size: 12),
                          ],
                        ),
                      ),
                    )),
                  ],
                  const SizedBox(height: 24),
                  // Action Buttons
                  if (r.status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _handleAction(r, 'rejected');
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('ปฏิเสธคำขอ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _handleAction(r, 'approved');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: workBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('อนุมัติคำขอ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: r.status == 'approved' ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: r.status == 'approved' ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Text(
                          r.status == 'approved' ? '✓ คำขอนี้ได้รับการอนุมัติเรียบร้อยแล้ว' : '✗ คำขอนี้ได้รับการปฏิเสธเรียบร้อยแล้ว',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: r.status == 'approved' ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: workMuted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? workBlue : workText,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: workBackground,
      child: RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            WorkHeader(
              title: 'จัดการคำขออนุมัติ',
              subtitle: 'คำขอการลาและปฏิบัติงานนอกสถานที่',
              onMenu: widget.onMenu,
              bottomPadding: 58,
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'กล่องข้อความคำขอแอดมิน',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: WorkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WorkCardTitle(
                        icon: Icons.mark_email_unread_rounded,
                        title: 'คำขอที่รอการอนุมัติ',
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 12),
                      if (_loading && _requests.isEmpty)
                        const RequestListSkeleton()
                      else if (_error != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                const Icon(Icons.cloud_off_rounded, color: Colors.red, size: 36),
                                const SizedBox(height: 8),
                                Text('เกิดข้อผิดพลาด: $_error', style: const TextStyle(fontSize: 12, color: workText)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _loadRequests, child: const Text('ลองอีกครั้ง')),
                              ],
                            ),
                          ),
                        )
                      else if (_requests.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'ไม่มีใบคำขอค้างอนุมัติในระบบ 🎉',
                              style: TextStyle(color: workMuted, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _requests.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 16,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final r = _requests[index];
                            final user = _userMap[r.userId];
                            final userName = user?.fullName ?? 'ไม่ระบุชื่อพนักงาน';
                            final department = user?.department.isEmpty == false ? ' (${user?.department})' : '';

                            return InkWell(
                              onTap: () => _showRequestDetailsBottomSheet(r, user),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: r.isOffsite ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        r.isOffsite ? Icons.directions_car_rounded : Icons.event_busy_rounded,
                                        color: r.isOffsite ? workBlue : const Color(0xFFEF4444),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.type,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: workText),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '$userName$department',
                                            style: const TextStyle(fontSize: 11, color: workMuted, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _showRequestDetailsBottomSheet(r, user),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('ดูรายละเอียด', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: workBlue)),
                                          SizedBox(width: 2),
                                          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: workBlue),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
