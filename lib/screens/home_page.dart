import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import 'calendar_page.dart';
import 'dashboard_page.dart';
import 'requests_page.dart';
import 'admin_requests_page.dart';
import 'user_profile_page.dart';
import 'main_dashboard_page.dart';
import 'admin_dashboard_page.dart';
import 'notifications_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    required this.service,
    required this.onSignOut,
  });

  final AppUser user;
  final AuthFlowService service;
  final Future<void> Function() onSignOut;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  int _animatingSelectedIndex = 0;
  int _pendingCount = 0;
  late AppUser _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _animatingSelectedIndex = _selectedIndex;
    if (_currentUser.role == 'admin') {
      _loadPendingCount();
    }
  }

  Future<void> _refreshUser() async {
    try {
      final fresh = await widget.service.getMe();
      if (mounted) {
        setState(() {
          _currentUser = fresh;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPendingCount() async {
    try {
      final reqs = await widget.service.getAdminPendingRequests();
      if (mounted) {
        setState(() {
          _pendingCount = reqs.length;
        });
      }
    } catch (_) {}
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  void _selectPage(int index) {
    if (_animatingSelectedIndex == index) return;
    Navigator.maybePop(context);
    
    // 1. Immediately slide the bottom capsule
    setState(() {
      _animatingSelectedIndex = index;
    });

    // 2. Wait for the slide to finish before rebuilding/switching pages (240ms)
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted) {
        setState(() {
          _selectedIndex = index;
        });
        if (widget.user.role == 'admin') {
          _loadPendingCount();
        }
      }
    });
  }

  Widget _buildGlassBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        height: 62,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Stack(
                children: [
                  // 1. Sliding capsule background
                  Positioned.fill(
                    child: AnimatedAlign(
                      alignment: Alignment(-1.0 + (_animatingSelectedIndex * (2.0 / 5.0)), 0.0),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: FractionallySizedBox(
                        widthFactor: 1.0 / 6.0,
                        heightFactor: 0.75, // Capsule height relative to nav bar height
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 2. Clickable Tab items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildGlassNavItem(0, Icons.home_outlined, Icons.home_rounded, 'หน้าหลัก'),
                      _buildGlassNavItem(1, Icons.fingerprint_rounded, Icons.fingerprint_rounded, 'ลงเวลา'),
                      _buildGlassNavItem(2, Icons.assignment_outlined, Icons.assignment_rounded, 'คำขอ'),
                      _buildGlassNavItem(3, Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'ปฏิทิน'),
                      _buildGlassNavItem(4, Icons.notifications_none_rounded, Icons.notifications_rounded, 'แจ้งเตือน'),
                      _buildGlassProfileNavItem(5, 'โปรไฟล์'),
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

  Widget _buildGlassNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final isSelected = _animatingSelectedIndex == index;
    
    final Widget iconWidget;
    if (index == 0) {
      iconWidget = FacebookHomeIcon(
        color: isSelected ? workBlue : workMuted,
        isFilled: isSelected,
        size: 20,
      );
    } else if (index == 1) {
      iconWidget = ClockInIcon(
        color: isSelected ? workBlue : workMuted,
        isFilled: isSelected,
        size: 20,
      );
    } else {
      iconWidget = Icon(
        isSelected ? selectedIcon : unselectedIcon,
        color: isSelected ? workBlue : workMuted,
        size: 20,
      );
    }

    final Widget badgeIcon = (index == 2 && _pendingCount > 0)
        ? Badge(
            label: Text('$_pendingCount', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFFEF4444),
            child: iconWidget,
          )
        : iconWidget;

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectPage(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
          padding: const EdgeInsets.symmetric(vertical: 4),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              badgeIcon,
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? workBlue : workMuted,
                  fontSize: 8.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassProfileNavItem(int index, String label) {
    final isSelected = _animatingSelectedIndex == index;
    final avatarUrl = _currentUser.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectPage(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 1),
          padding: const EdgeInsets.symmetric(vertical: 4),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? workBlue : Colors.grey.shade400,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: ClipOval(
                  child: hasAvatar
                      ? Image.network(
                          avatarUrl.startsWith('r2://')
                            ? avatarUrl.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                            : avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.person_rounded,
                            size: 11,
                            color: workMuted,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 11,
                          color: workMuted,
                        ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? workBlue : workMuted,
                  fontSize: 8.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    try {
      final isAdmin = _currentUser.role == 'admin';

      return Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        drawer: _AppDrawer(
          user: _currentUser,
          selectedIndex: _selectedIndex,
          onSelect: _selectPage,
          onSignOut: widget.onSignOut,
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            // Index 0: หน้าหลัก (แยกตามสิทธิ์)
            isAdmin
                ? AdminDashboardPage(
                    key: const PageStorageKey('admin_dashboard'),
                    user: _currentUser,
                    service: widget.service,
                    onMenu: _openMenu,
                    onSelectTab: _selectPage,
                    isActive: _selectedIndex == 0,
                  )
                : MainDashboardPage(
                    key: const PageStorageKey('main_dashboard'),
                    user: _currentUser,
                    service: widget.service,
                    onMenu: _openMenu,
                    onSelectTab: _selectPage,
                    isActive: _selectedIndex == 0,
                  ),
            // Index 1: ลงเวลาเข้างาน
            DashboardPage(
              key: const PageStorageKey('dashboard'),
              user: _currentUser,
              service: widget.service,
              onMenu: _openMenu,
              onSignOut: widget.onSignOut,
              isActive: _selectedIndex == 1,
            ),
            // Index 2: คำขอ
            isAdmin
                ? AdminRequestsPage(
                    key: const PageStorageKey('admin_requests'),
                    service: widget.service,
                    onMenu: _openMenu,
                    isActive: _selectedIndex == 2,
                  )
                : RequestsPage(
                    key: const PageStorageKey('requests'),
                    service: widget.service,
                    onMenu: _openMenu,
                    isActive: _selectedIndex == 2,
                  ),
            // Index 3: ปฏิทิน
            WorkCalendarPage(
              key: const PageStorageKey('calendar'),
              service: widget.service,
              onMenu: _openMenu,
              onOpenRequests: () => _selectPage(2), // เปิดแท็บ 2 (คำขอ) แทนแท็บ 1 เดิม
              isActive: _selectedIndex == 3,
            ),
            // Index 4: แจ้งเตือน
            NotificationsPage(
              key: const PageStorageKey('notifications'),
              onMenu: _openMenu,
              isActive: _selectedIndex == 4,
            ),
            // Index 5: โปรไฟล์
            UserProfilePage(
              key: const PageStorageKey('profile'),
              user: _currentUser,
              service: widget.service,
              onMenu: _openMenu,
              onSignOut: widget.onSignOut,
              isActive: _selectedIndex == 5,
              onProfileUpdated: _refreshUser,
            ),
          ],
        ),
        bottomNavigationBar: _buildGlassBottomBar(),
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
                    'เกิดข้อผิดพลาดในการสร้างหน้าจอ HomePage',
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
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.user,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSignOut,
  });

  final AppUser user;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == 'admin';

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.paddingOf(context).top + 28,
              24,
              26,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [workBlue, workSky]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 2,
                    ),
                    image: user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(
                              user.avatarUrl!.startsWith('r2://')
                                  ? user.avatarUrl!.replaceFirst('r2://', 'https://pub-2a877f7cc07b481ca09dec82cb240465.r2.dev/')
                                  : user.avatarUrl!,
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty
                      ? null
                      : const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  user.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  user.position.isEmpty ? user.role : user.position,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.76)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _DrawerItem(
            icon: Icons.home_outlined,
            label: 'หน้าหลัก',
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          _DrawerItem(
            icon: Icons.fingerprint_rounded,
            label: 'ลงเวลาทำงาน',
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          _DrawerItem(
            icon: Icons.mail_outline_rounded,
            label: isAdmin ? 'จัดการคำขอ' : 'คำขอของฉัน',
            selected: selectedIndex == 2,
            onTap: () => onSelect(2),
          ),
          _DrawerItem(
            icon: Icons.calendar_month_outlined,
            label: 'ปฏิทินตารางงาน',
            selected: selectedIndex == 3,
            onTap: () => onSelect(3),
          ),
          _DrawerItem(
            icon: Icons.notifications_none_rounded,
            label: 'การแจ้งเตือน',
            selected: selectedIndex == 4,
            onTap: () => onSelect(4),
          ),
          _DrawerItem(
            icon: Icons.person_outline_rounded,
            label: 'โปรไฟล์',
            selected: selectedIndex == 5,
            onTap: () => onSelect(5),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            title: const Text(
              'ออกจากระบบ',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: onSignOut,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? workBlue : workMuted),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? workBlue : workText,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      selected: selected,
      selectedTileColor: const Color(0xFFEFF6FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: onTap,
    );
  }
}

class FacebookHomeIcon extends StatelessWidget {
  const FacebookHomeIcon({super.key, required this.color, required this.isFilled, this.size = 22});

  final Color color;
  final bool isFilled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HomePainter(color: color, isFilled: isFilled),
    );
  }
}

class _HomePainter extends CustomPainter {
  const _HomePainter({required this.color, required this.isFilled});

  final Color color;
  final bool isFilled;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final housePath = Path();
    housePath.moveTo(w * 0.18, h * 0.92);
    housePath.lineTo(w * 0.18, h * 0.48);
    housePath.lineTo(w * 0.08, h * 0.48);
    housePath.lineTo(w * 0.46, h * 0.12);
    housePath.quadraticBezierTo(w * 0.5, h * 0.08, w * 0.54, h * 0.12);
    housePath.lineTo(w * 0.92, h * 0.48);
    housePath.lineTo(w * 0.82, h * 0.48);
    housePath.lineTo(w * 0.82, h * 0.92);
    housePath.close();

    final doorPath = Path();
    doorPath.moveTo(w * 0.38, h * 0.92);
    doorPath.lineTo(w * 0.38, h * 0.60);
    doorPath.quadraticBezierTo(w * 0.38, h * 0.55, w * 0.43, h * 0.55);
    doorPath.lineTo(w * 0.57, h * 0.55);
    doorPath.quadraticBezierTo(w * 0.62, h * 0.55, w * 0.62, h * 0.60);
    doorPath.lineTo(w * 0.62, h * 0.92);
    doorPath.close();

    if (isFilled) {
      paint.style = PaintingStyle.fill;
      final combinedPath = Path.combine(PathOperation.difference, housePath, doorPath);
      canvas.drawPath(combinedPath, paint);
    } else {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
      canvas.drawPath(housePath, paint);
      canvas.drawPath(doorPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HomePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isFilled != isFilled;
  }
}

class ClockInIcon extends StatelessWidget {
  const ClockInIcon({super.key, required this.color, required this.isFilled, this.size = 22});

  final Color color;
  final bool isFilled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ClockInPainter(color: color, isFilled: isFilled),
    );
  }
}

class _ClockInPainter extends CustomPainter {
  const _ClockInPainter({required this.color, required this.isFilled});

  final Color color;
  final bool isFilled;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    if (isFilled) {
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.5, paint);

      final linePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      // วาดเฉพาะเข็มนาฬิกาด้านใน (ไม่เอาวงกลมซ้อน)
      canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5, h * 0.22), linePaint);
      canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.70, h * 0.5), linePaint);
    } else {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
      canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.45, paint);

      // วาดเฉพาะเข็มนาฬิกาด้านใน (ไม่เอาวงกลมซ้อน)
      canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5, h * 0.22), paint);
      canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.70, h * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ClockInPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isFilled != isFilled;
  }
}
