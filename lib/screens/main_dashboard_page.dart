import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/user_avatar.dart';
import '../widgets/app_loading_view.dart';
import '../services/fcm_service.dart';
import 'admin_websites_page.dart';
import 'admin_tasks_page.dart';
import 'admin_users_page.dart';
import 'admin_locations_page.dart';
import 'admin_attendance_history_page.dart';
import 'admin_holidays_page.dart';
import 'admin_daily_board_page.dart';

class MainDashboardPage extends StatefulWidget {
  const MainDashboardPage({
    super.key,
    required this.user,
    required this.service,
    required this.onSelectTab,
    required this.isActive,
    this.onOpenProfile,
  });

  final AppUser user;
  final AuthFlowService service;
  final ValueChanged<int> onSelectTab;
  final bool isActive;
  final VoidCallback? onOpenProfile;

  @override
  State<MainDashboardPage> createState() => _MainDashboardPageState();
}

class _MainDashboardPageState extends State<MainDashboardPage> {
  bool _loading = true;
  AttendanceRecord? _todayAttendance;
  int _totalEmployees = 0;
  int _attendedToday = 0;
  int _lateToday = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    FcmService.instance.registerDevice(widget.service);
  }

  @override
  void didUpdateWidget(covariant MainDashboardPage oldWidget) {
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
        widget.service.getAttendance(now),
        widget.service.getAttendanceSummary(now),
      ]);

      if (mounted) {
        setState(() {
          _todayAttendance = results[0] as AttendanceRecord?;

          final summary = results[1] as AttendanceSummary;
          _totalEmployees = summary.totalEmployees;
          _attendedToday = summary.attendedToday;
          _lateToday = summary.lateToday;

          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading employee dashboard: $e');
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
        widget.service.getAttendance(now),
        widget.service.getAttendanceSummary(now),
      ]);

      if (mounted) {
        setState(() {
          _todayAttendance = results[0] as AttendanceRecord?;

          final summary = results[1] as AttendanceSummary;
          _totalEmployees = summary.totalEmployees;
          _attendedToday = summary.attendedToday;
          _lateToday = summary.lateToday;
        });
      }
    } catch (_) {}
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'สวัสดีตอนเช้า';
    } else if (hour < 17) {
      return 'สวัสดีตอนบ่าย';
    } else {
      return 'สวัสดีตอนเย็น';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: workBackground,
        body: AppLoadingView(message: 'กำลังโหลดข้อมูลแดชบอร์ด...'),
      );
    }

    final avatarUrl = widget.user.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    final httpAvatarUrl = hasAvatar
        ? (avatarUrl.startsWith('r2://')
              ? avatarUrl.replaceFirst(
                  'r2://',
                  'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/',
                )
              : avatarUrl)
        : '';

    // Role-based avatar decoration styling (Solid Sharp Colors)
    final role = widget.user.role;
    BoxDecoration borderDecoration;

    if (role == 'admin') {
      borderDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1F5F9),
        border: Border.all(
          color: const Color(0xFFFFD700),
          width: 2.5,
        ), // Solid Gold
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
        border: Border.all(
          color: const Color(0xFFA855F7),
          width: 2.5,
        ), // Solid Purple
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
      );
    }

    return Scaffold(
      backgroundColor: workBackground,
      body: RefreshIndicator(
        color: workBlue,
        backgroundColor: Colors.white,
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _buildHeroHeader(
              borderDecoration: borderDecoration,
              hasAvatar: hasAvatar,
              avatarUrl: httpAvatarUrl,
            ),
            // 2. 2 Big Buttons (เหมือนแอดมิน)
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
                          title: 'Project หลัก',
                          sub: 'จัดการและมอบหมายงาน',
                          badgeCount: 0,
                          icon: Icons.assignment_rounded,
                          color: workBlue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminTasksPage(service: widget.service),
                            ),
                          ),
                        ),
                        _buildTodoCard(
                          title: 'Project รายวัน',
                          sub: 'ดูงานที่เลยกำหนดและวันนี้',
                          badgeCount: 0,
                          icon: Icons.view_kanban_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AdminDailyBoardPage(service: widget.service)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth - 16) / 3;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: itemWidth,
                              child: Center(
                                child: _buildCircularMenu(
                                  label: 'พนักงาน',
                                  icon: Icons.people_alt_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AdminUsersPage(
                                        service: widget.service,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: Center(
                                child: _buildCircularMenu(
                                  label: 'จุดทำงาน',
                                  icon: Icons.map_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AdminLocationsPage(
                                        service: widget.service,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: Center(
                                child: _buildCircularMenu(
                                  label: 'บันทึกเวลา',
                                  icon: Icons.menu_book_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AdminAttendanceHistoryPage(
                                            service: widget.service,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: Center(
                                child: _buildCircularMenu(
                                  label: 'วันหยุด',
                                  icon: Icons.edit_calendar_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AdminHolidaysPage(
                                        service: widget.service,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: Center(
                                child: _buildCircularMenu(
                                  label: 'เว็บไซต์บริษัท\nและระบบหลังบ้าน',
                                  icon: Icons.language_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CompanyWebsitesPage(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: Center(
                                child: _buildCircularMenu(
                                  label: 'มอบหมายงาน',
                                  icon: Icons.task_alt_rounded,
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                        title: const Row(
                                          children: [
                                            Icon(Icons.build_circle_rounded,
                                                color: Colors.orange, size: 28),
                                            SizedBox(width: 10),
                                            Text('แจ้งเตือน',
                                                style: TextStyle(fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        content: const Text(
                                          'กำลังปรับปรุงโมดูล\nกรุณาเข้าใช้งานผ่านเมนูใหม่ด้านบน',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('ตกลง',
                                                style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _StaggeredFadeIn(
              delayIndex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTodayCompanySummaryCard(),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader({
    required BoxDecoration borderDecoration,
    required bool hasAvatar,
    required String avatarUrl,
  }) {
    return ClipRRect(
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
            colors: [Color(0xFF172B62), workBlue, Color(0xFF0C8FA8)],
            stops: [0, 0.56, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -36,
              right: -20,
              child: _AmbientBlob(size: 148, color: Color(0x1FFFFFFF)),
            ),
            const Positioned(
              bottom: -52,
              left: -28,
              child: _AmbientBlob(size: 128, color: Color(0x14FFFFFF)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 12,
                20,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      Semantics(
                        label: 'รูปโปรไฟล์ของ ${widget.user.fullName}',
                        image: true,
                        child: GestureDetector(
                          onTap: widget.onOpenProfile,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: borderDecoration,
                            child: UserAvatar(
                              avatarUrl: widget.user.avatarUrl,
                              name: widget.user.nickname.isNotEmpty
                                  ? widget.user.nickname
                                  : widget.user.firstName,
                              radius: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getGreeting(),
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.user.position.isEmpty
                        ? 'พนักงานทั่วไป'
                        : widget.user.position,
                    style: const TextStyle(
                      color: Color(0xBFFFFFFF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey.shade400),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: workText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: workMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$title: $sub',
      child: Container(
        width: 178,
        margin: const EdgeInsets.only(right: 12),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: color.withValues(alpha: 0.12),
            highlightColor: color.withValues(alpha: 0.05),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EEF5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: color, size: 20),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: workText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: workMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularMenu({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: workBlue.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                Ink(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFDCE7F3)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A0F172A),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: workBlue, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: workText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCompanySummaryCard() {
    return WorkCard(
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
                  value: '$_totalEmployees',
                  color: workText,
                ),
              ),
              Expanded(
                child: _buildAttendanceStatBox(
                  label: 'มาทำงานแล้ว',
                  value: '$_attendedToday',
                  color: const Color(0xFF10B981),
                ),
              ),
              Expanded(
                child: _buildAttendanceStatBox(
                  label: 'มาสายวันนี้',
                  value: '$_lateToday',
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
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

// ─── Dashboard Support Widgets ───

class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: workText,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: workMuted)),
      ],
    );
  }
}

class _StaggeredFadeIn extends StatelessWidget {
  const _StaggeredFadeIn({required this.child, required this.delayIndex});

  final Widget child;
  final int delayIndex;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (delayIndex * 120)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1.0 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}
