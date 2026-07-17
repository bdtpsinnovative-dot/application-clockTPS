import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/work_models.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import '../widgets/app_loading_view.dart';
import '../services/fcm_service.dart';

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
  List<LeaveBalanceRecord> _leaveBalances = [];
  List<HolidayRecord> _holidays = [];
  List<TaskRecord> _myTasks = [];

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
      final year = now.year;

      final results = await Future.wait([
        widget.service.getAttendance(now),
        widget.service.getLeaveBalances(year),
        widget.service.getHolidays(year),
        widget.service.getMyTasks(),
      ]);

      if (mounted) {
        setState(() {
          _todayAttendance = results[0] as AttendanceRecord?;
          _leaveBalances = results[1] as List<LeaveBalanceRecord>;
          
          final allHols = results[2] as List<HolidayRecord>;
          // กรองเอาเฉพาะวันหยุดที่กำลังจะถึง
          final today = DateTime(now.year, now.month, now.day);
          _holidays = allHols.where((h) => h.date.isAfter(today) || h.date.isAtSameMomentAs(today)).toList();
          _holidays.sort((a, b) => a.date.compareTo(b.date));
          if (_holidays.length > 3) {
            _holidays = _holidays.sublist(0, 3);
          }

          _myTasks = results[3] as List<TaskRecord>;
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
      final year = now.year;

      final results = await Future.wait([
        widget.service.getAttendance(now),
        widget.service.getLeaveBalances(year),
        widget.service.getHolidays(year),
        widget.service.getMyTasks(),
      ]);

      if (mounted) {
        setState(() {
          _todayAttendance = results[0] as AttendanceRecord?;
          _leaveBalances = results[1] as List<LeaveBalanceRecord>;
          
          final allHols = results[2] as List<HolidayRecord>;
          final today = DateTime(now.year, now.month, now.day);
          _holidays = allHols.where((h) => h.date.isAfter(today) || h.date.isAtSameMomentAs(today)).toList();
          _holidays.sort((a, b) => a.date.compareTo(b.date));
          if (_holidays.length > 3) {
            _holidays = _holidays.sublist(0, 3);
          }
          _myTasks = results[3] as List<TaskRecord>;
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
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCircularMenu(
                          label: 'ประวัติเวลา',
                          icon: Icons.history_toggle_off_rounded,
                          onTap: () => widget.onSelectTab(3),
                        ),
                        _buildCircularMenu(
                          label: 'ปฏิทินงาน',
                          icon: Icons.calendar_month_rounded,
                          onTap: () => widget.onSelectTab(3),
                        ),
                        _buildCircularMenu(
                          label: 'กล่องคำขอ',
                          icon: Icons.assignment_rounded,
                          onTap: () => widget.onSelectTab(2),
                        ),
                        _buildCircularMenu(
                          label: 'แก้ไขข้อมูล',
                          icon: Icons.manage_accounts_rounded,
                          onTap: () => widget.onSelectTab(5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 4. Leave Balance Quotas (สไตล์ To-Do / Grid)
            _StaggeredFadeIn(
              delayIndex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: WorkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WorkCardTitle(
                        icon: Icons.analytics_rounded,
                        title: 'โควต้าวันลาคงเหลือปีนี้',
                      ),
                      const SizedBox(height: 16),
                      if (_leaveBalances.isEmpty)
                        const Center(
                          child: Text(
                            'ไม่มีโควต้าการลาสำหรับปีนี้',
                            style: TextStyle(color: workMuted, fontSize: 13),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: _leaveBalances.length,
                          itemBuilder: (context, index) {
                            final b = _leaveBalances[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    b.leaveType,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: workText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${b.remaining.toInt()} / ${b.quota.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: workBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'คงเหลือ (วัน)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: workMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 4.5. Assigned Tasks (งานที่ได้รับมอบหมาย)
            _StaggeredFadeIn(
              delayIndex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: WorkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WorkCardTitle(
                        icon: Icons.task_alt_rounded,
                        title: 'งานที่ได้รับมอบหมาย (My Tasks)',
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(height: 12),
                      if (_myTasks.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'ไม่มีงานค้างสำหรับคุณในวันนี้ 🎉',
                              style: TextStyle(color: workMuted, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _myTasks.length,
                          separatorBuilder: (context, index) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final t = _myTasks[index];
                            
                            Color statusColor;
                            String statusText;
                            if (t.status == 'in_progress') {
                              statusColor = const Color(0xFFEA580C);
                              statusText = 'กำลังทำ';
                            } else if (t.status == 'completed') {
                              statusColor = const Color(0xFF10B981);
                              statusText = 'เสร็จสิ้น';
                            } else {
                              statusColor = const Color(0xFF94A3B8);
                              statusText = 'รอทำ';
                            }

                            return InkWell(
                              onTap: () => _showTaskDetailsBottomSheet(t),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: workText),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ส่ง: ${DateFormat('dd MMM yy').format(t.dueDate)}',
                                            style: const TextStyle(fontSize: 10, color: workMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
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

            const SizedBox(height: 20),

            // 5. เว็บไซต์ของบริษัท
            _StaggeredFadeIn(
              delayIndex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.language_rounded, color: workBlue, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'เว็บไซต์ของบริษัท',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: workText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 185,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildBannerCard(
                          imagePath: 'assets/images/banner_zenslab.webp',
                          url: 'https://www.zen-slab.com',
                          title: 'Zen Slab',
                          description: 'เราเริ่มต้นจากแก่นแท้ของต้นไม้ คุณค่าที่สำคัญที่สุดคือความเป็นธรรมชาติ...',
                        ),
                        _buildBannerCard(
                          imagePath: 'assets/images/banner_wallcraft.webp',
                          url: 'https://wallcraftthailand.com',
                          title: 'Wallcraft Thailand',
                          description: 'Wallcraft ศูนย์รวมสินค้าผนังและระแนงไม้คุณภาพสูง',
                        ),
                        _buildBannerCard(
                          imagePath: 'assets/images/banner_terrahome.webp',
                          url: 'https://terrahome-studio.com',
                          title: 'Terra Home Studio',
                          description: 'ของตกแต่งบ้าน ดีไซน์มินิมอล สไตล์ wabi-sabi',
                        ),
                        _buildBannerCard(
                          imagePath: 'assets/images/banner_emberash.webp',
                          url: 'https://emberandashliving.vercel.app/',
                          title: 'Ember & Ash Living',
                          description: 'เฟอร์นิเจอร์ดีไซน์พรีเมียม สไตล์โมเดิร์นร่วมสมัย',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildBannerCard({
    required String imagePath,
    required String url,
    required String title,
    required String description,
  }) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        width: 175,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  imagePath,
                  width: 175,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: workText,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: workMuted,
                height: 1.3,
              ),
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

  void _showTaskDetailsBottomSheet(TaskRecord task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'รายละเอียดงาน',
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
            Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: workText),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                style: const TextStyle(fontSize: 12, color: workMuted),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 14, color: workMuted),
                const SizedBox(width: 6),
                Text(
                  'กำหนดส่ง: ${DateFormat('dd MMMM yyyy', 'th').format(task.dueDate)}',
                  style: const TextStyle(fontSize: 12, color: workText, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (task.status != 'completed') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final nextStatus = task.status == 'pending' ? 'in_progress' : 'completed';
                    try {
                      await widget.service.updateTaskStatus(task.id, nextStatus);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('อัปเดตสถานะงานสำเร็จ'), backgroundColor: Colors.green),
                      );
                      _loadData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('อัปเดตสถานะงานล้มเหลว: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: task.status == 'pending' ? const Color(0xFFEA580C) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    task.status == 'pending' ? 'เริ่มทำงาน (Start Task)' : 'เสร็จสิ้นงาน (Complete Task)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ] else ...[
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'งานนี้เสร็จสมบูรณ์แล้ว',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
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

