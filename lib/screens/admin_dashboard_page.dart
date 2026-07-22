import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/app_loading_view.dart';
import '../services/fcm_service.dart';
import 'admin_users_page.dart';
import 'admin_locations_page.dart';
import 'admin_holidays_page.dart';
import 'admin_attendance_history_page.dart';
import 'admin_tasks_page.dart';
import 'admin_websites_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.user,
    required this.service,
    required this.onMenu,
    required this.onSelectTab,
    required this.isActive,
  });

  final AppUser user;
  final AuthFlowService service;
  final VoidCallback onMenu;
  final ValueChanged<int> onSelectTab;
  final bool isActive;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _MainStat {
  const _MainStat({
    required this.totalEmployees,
    required this.pendingUsersCount,
    required this.attendedToday,
    required this.lateToday,
    required this.pendingRequestsCount,
  });

  final int totalEmployees;
  final int pendingUsersCount;
  final int attendedToday;
  final int lateToday;
  final int pendingRequestsCount;
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  _MainStat? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
    FcmService.instance.registerDevice(widget.service);
  }

  @override
  void didUpdateWidget(covariant AdminDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadDataBackground();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });

    try {
      final now = DateTime.now();
      
      final results = await Future.wait([
        widget.service.getAdminUsers(),
        widget.service.getAdminPendingRequests(),
        widget.service.getAdminAttendance(now),
      ]);

      final allUsers = results[0] as List<AppUser>;
      final pendingReqs = results[1] as List<WorkRequestRecord>;
      final todayAtts = results[2] as List<AttendanceRecord>;

      final activeUsers = allUsers.where((u) => u.status == 'active').toList();
      final pendingUsers = allUsers.where((u) => u.status == 'pending').toList();
      final lateAtts = todayAtts.where((a) => a.status == 'late').toList();

      if (mounted) {
        setState(() {
          _stats = _MainStat(
            totalEmployees: activeUsers.length,
            pendingUsersCount: pendingUsers.length,
            attendedToday: todayAtts.length,
            lateToday: lateAtts.length,
            pendingRequestsCount: pendingReqs.length,
          );
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin dashboard: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadDataBackground() async {
    try {
      final now = DateTime.now();
      
      final results = await Future.wait([
        widget.service.getAdminUsers(),
        widget.service.getAdminPendingRequests(),
        widget.service.getAdminAttendance(now),
      ]);

      final allUsers = results[0] as List<AppUser>;
      final pendingReqs = results[1] as List<WorkRequestRecord>;
      final todayAtts = results[2] as List<AttendanceRecord>;

      final activeUsers = allUsers.where((u) => u.status == 'active').toList();
      final pendingUsers = allUsers.where((u) => u.status == 'pending').toList();
      final lateAtts = todayAtts.where((a) => a.status == 'late').toList();

      if (mounted) {
        setState(() {
          _stats = _MainStat(
            totalEmployees: activeUsers.length,
            pendingUsersCount: pendingUsers.length,
            attendedToday: todayAtts.length,
            lateToday: lateAtts.length,
            pendingRequestsCount: pendingReqs.length,
          );
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (_loading) {
        return const Scaffold(
          backgroundColor: workBackground,
          body: AppLoadingView(message: 'กำลังโหลดข้อมูลแอดมิน...'),
        );
      }

      if (_stats == null) {
        return Scaffold(
          backgroundColor: workBackground,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: workText),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'กรุณาตรวจสอบว่าคุณได้รัน Go Backend แล้ว และมือถืออยู่ในวง Wi-Fi เดียวกัน',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: workMuted),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('ลองใหม่อีกครั้ง'),
                    style: FilledButton.styleFrom(
                      backgroundColor: workBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final avatarUrl = widget.user.avatarUrl;
      final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
      final httpAvatarUrl = hasAvatar
          ? (avatarUrl.startsWith('r2://')
              ? avatarUrl.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
              : avatarUrl)
          : '';

      // Role-based avatar decoration styling (Solid Sharp Colors)
      final role = widget.user.role;
      BoxDecoration borderDecoration;
      
      if (role == 'admin') {
        borderDecoration = BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF1F5F9),
          border: Border.all(color: const Color(0xFFFFD700), width: 2.5), // Solid Gold
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        );
      } else if (role == 'hr') {
        borderDecoration = BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF1F5F9),
          border: Border.all(color: const Color(0xFFA855F7), width: 2.5), // Solid Purple
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA855F7).withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        );
      } else {
        borderDecoration = BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF1F5F9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        );
      }

      return Scaffold(
        backgroundColor: workBackground,
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 1. Premium Gradient Header with Liquid Floating Animation
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [workBlue, workSky],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Moving background blob 1
                      Positioned(
                        top: -30,
                        left: -20,
                        child: _FloatingBubble(
                          size: 130,
                          color: Colors.white.withValues(alpha: 0.12),
                          duration: const Duration(seconds: 10),
                        ),
                      ),
                      // Moving background blob 2
                      Positioned(
                        bottom: -40,
                        right: -30,
                        child: _FloatingBubble(
                          size: 160,
                          color: Colors.white.withValues(alpha: 0.08),
                          duration: const Duration(seconds: 14),
                        ),
                      ),
                      // Foreground content
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          MediaQuery.paddingOf(context).top + 16,
                          20,
                          32,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'แผงควบคุมผู้ดูแลระบบ',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.user.fullName} (HR / Admin)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Custom Bordered Avatar (Role-Based & Solid Color)
                            Container(
                              width: 44,
                              height: 44,
                              decoration: borderDecoration.copyWith(
                                image: hasAvatar
                                    ? DecorationImage(
                                        image: NetworkImage(httpAvatarUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: hasAvatar
                                  ? null
                                  : const Icon(
                                      Icons.person_rounded,
                                      color: workMuted,
                                      size: 24,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. 2 Big Buttons (คำขอรออนุมัติ / อนุมัติพนักงานใหม่) - ขยับขึ้นชิดบนทับส่วนหัว
              _StaggeredFadeIn(
                delayIndex: 1,
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: SizedBox(
                      height: 110,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildTodoCard(
                            title: 'คำขอรออนุมัติ',
                            sub: _stats!.pendingRequestsCount > 0
                                ? 'มี ${_stats!.pendingRequestsCount} คำขอค้างพิจารณา'
                                : 'ไม่มีคำขอใหม่',
                            badgeCount: 0,
                            icon: Icons.assignment_late_rounded,
                            color: workBlue,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminAttendanceHistoryPage(service: widget.service),
                              ),
                            ),
                          ),
                          _buildTodoCard(
                            title: 'อนุมัติพนักงานใหม่',
                            sub: _stats!.pendingUsersCount > 0
                                ? 'มี ${_stats!.pendingUsersCount} บัญชีรอการยืนยัน'
                                : 'อนุมัติครบทั้งหมดแล้ว',
                            badgeCount: _stats!.pendingUsersCount,
                            icon: Icons.group_add_rounded,
                            color: const Color(0xFFF59E0B),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminUsersPage(service: widget.service)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Circular Actions for Management
              _StaggeredFadeIn(
                delayIndex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'การจัดการข้อมูล',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: workText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCircularMenu(
                            label: 'พนักงาน',
                            icon: Icons.people_alt_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminUsersPage(service: widget.service)),
                            ),
                          ),
                          _buildCircularMenu(
                            label: 'จุดทำงาน',
                            icon: Icons.map_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminLocationsPage(service: widget.service)),
                            ),
                          ),
                          _buildCircularMenu(
                            label: 'บันทึกเวลา',
                            icon: Icons.menu_book_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminAttendanceHistoryPage(service: widget.service)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCircularMenu(
                            label: 'ตั้งวันหยุด',
                            icon: Icons.edit_calendar_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminHolidaysPage(service: widget.service)),
                            ),
                          ),
                          _buildCircularMenu(
                            label: 'มอบหมายงาน',
                            icon: Icons.assignment_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminTasksPage(service: widget.service)),
                            ),
                          ),
                          _buildCircularMenu(
                            label: 'เว็บไซต์บริษัท',
                            icon: Icons.language_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CompanyWebsitesPage()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 4. สรุปการมาทำงานพนักงานวันนี้ (Attendance Overview) + รายชื่อพนักงาน
              _StaggeredFadeIn(
                delayIndex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: WorkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const WorkCardTitle(
                          icon: Icons.donut_large_rounded,
                          title: 'สรุปการมาทำงานวันนี้',
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildAttendanceStatBox(
                                label: 'พนักงานทั้งหมด',
                                value: '${_stats!.totalEmployees}',
                                color: workText,
                              ),
                            ),
                            Expanded(
                              child: _buildAttendanceStatBox(
                                label: 'มาทำงานแล้ว',
                                value: '${_stats!.attendedToday}',
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            Expanded(
                              child: _buildAttendanceStatBox(
                                label: 'มาสายวันนี้',
                                value: '${_stats!.lateToday}',
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      );
    } catch (e, stack) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bug_report_rounded, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'เกิดข้อผิดพลาดในการสร้างหน้าจอ แอดมิน',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  Text('ข้อผิดพลาด: $e', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('ตำแหน่งที่ล่ม:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('$stack', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildTodoCard({
    required String title,
    required String sub,
    required int badgeCount,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 190,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      )
                  ],
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: workMuted, size: 12),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: workText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: workMuted,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCircularMenu({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Icon(icon, color: workBlue, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: workText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceStatBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: workMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Premium Animation Helper Widgets ───

class _FloatingBubble extends StatefulWidget {
  const _FloatingBubble({
    required this.size,
    required this.color,
    required this.duration,
  });

  final double size;
  final Color color;
  final Duration duration;

  @override
  State<_FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<_FloatingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            20 * _animation.value,
            30 * (1.0 - _animation.value),
          ),
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
        ),
      ),
    );
  }
}

class _StaggeredFadeIn extends StatelessWidget {
  const _StaggeredFadeIn({
    required this.child,
    required this.delayIndex,
  });

  final Widget child;
  final int delayIndex;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (delayIndex * 120)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1.0 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

