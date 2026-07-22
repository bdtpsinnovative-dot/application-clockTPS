import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/app_loading_view.dart';
import '../services/fcm_service.dart';
import 'admin_websites_page.dart';
import 'admin_tasks_page.dart';


class MainDashboardPage extends StatefulWidget {
  const MainDashboardPage({
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
                    // Foreground content (Aligned Horizontally using Row)
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
                                Text(
                                  _getGreeting(),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.user.fullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.user.position.isEmpty ? 'พนักงานทั่วไป' : widget.user.position,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 14,
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

            // 2. Quick Actions (การ์ดเลื่อนแนวนอน)
            _StaggeredFadeIn(
              delayIndex: 1,
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'เมนูด่วนสำหรับวันนี้',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: workText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 110,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildQuickActionCard(
                              title: 'ลงเวลาทำงาน',
                              sub: _todayAttendance != null
                                  ? (_todayAttendance!.checkOutAt != null
                                      ? 'ลงเวลาเสร็จสิ้นวันนี้'
                                      : 'เข้างานแล้ว / รอเช็คเอาท์')
                                  : 'เช็คอิน / เช็คเอาท์',
                              icon: Icons.fingerprint_rounded,
                              color: workBlue,
                              onTap: () => widget.onSelectTab(1),
                            ),
                            _buildQuickActionCard(
                              title: 'ยื่นคำขอใบลา',
                              sub: 'ลาป่วย, ลากิจ, ลาพักร้อน',
                              icon: Icons.event_busy_rounded,
                              color: const Color(0xFFEF4444),
                              onTap: () => widget.onSelectTab(2),
                            ),
                            _buildQuickActionCard(
                              title: 'ขอออกหน้างาน',
                              sub: 'ปฏิบัติหน้าที่นอกสถานที่',
                              icon: Icons.directions_car_rounded,
                              color: const Color(0xFF10B981),
                              onTap: () => widget.onSelectTab(2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Frequently Used (ปุ่มวงกลมเรียงแถว)
            _StaggeredFadeIn(
              delayIndex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ฟังก์ชันที่ใช้งานบ่อย',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: workText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildCircularMenu(
                          label: 'มอบหมายงาน',
                          icon: Icons.task_alt_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminTasksPage(service: widget.service),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
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
            const SizedBox(height: 20),
            _StaggeredFadeIn(
              delayIndex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTodayCompanySummaryCard(),
              ),
            ),
            const SizedBox(height: 100),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
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

