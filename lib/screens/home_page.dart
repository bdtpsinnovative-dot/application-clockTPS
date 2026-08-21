import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_flow_service.dart';
import '../services/fcm_service.dart';
import '../widgets/work_ui.dart';
import 'calendar_page.dart';
import 'dashboard_page.dart';
import 'requests_page.dart';
import 'admin_requests_page.dart';
import 'user_profile_page.dart';
import 'main_dashboard_page.dart';
import 'admin_dashboard_page.dart';
import 'notifications_page.dart';
import 'task_board_page.dart';
import '../models/work_models.dart';
import '../widgets/user_avatar.dart';
import '../widgets/sign_out_confirm_sheet.dart';
import '../widgets/attendance_nav_fab.dart';

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
  int _notificationCount = 0;
  AttendanceRecord? _todayAttendance;
  late AppUser _currentUser;
  String? _targetRequestId;
  StreamSubscription<FcmNotificationTarget>? _notificationTapSubscription;
  bool _openingNotificationTarget = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _animatingSelectedIndex = _selectedIndex;
    if (_currentUser.role == 'admin') {
      _loadPendingCount();
    }
    _loadNotificationCount();
    _loadTodayAttendance();
    _notificationTapSubscription = FcmService.instance.notificationTaps.listen(
      _openNotificationTarget,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingTarget = FcmService.instance.takePendingTarget();
      if (pendingTarget != null) _openNotificationTarget(pendingTarget);
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openNotificationTarget(FcmNotificationTarget target) async {
    if (!mounted || _openingNotificationTarget) return;
    final taskId = target.taskId;
    if (taskId == null || taskId.isEmpty) {
      _selectPage(4);
      return;
    }

    _openingNotificationTarget = true;
    try {
      final tasks = await widget.service.getMyTasks();
      if (!mounted) return;
      final task = tasks.where((item) => item.id == taskId).firstOrNull;
      if (task == null) {
        _selectPage(4);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบงานจากการแจ้งเตือนนี้')),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TaskBoardPage(
            task: task,
            service: widget.service,
            initialListId: target.listId,
            onRefreshNeeded: () {},
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _selectPage(4);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปิดงานจากการแจ้งเตือนไม่สำเร็จ')),
        );
      }
    } finally {
      _openingNotificationTarget = false;
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

  Future<void> _loadNotificationCount() async {
    try {
      final notifications = await widget.service.getMyNotifications();
      if (mounted) {
        setState(() {
          _notificationCount = notifications.where((item) {
            final isRead = item['is_read'] as bool? ?? item['read'] as bool?;
            return isRead != true;
          }).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTodayAttendance() async {
    try {
      final att = await widget.service.getAttendance(DateTime.now());
      if (mounted) {
        setState(() {
          _todayAttendance = att;
        });
      }
    } catch (_) {}
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  void _openProfile() {
    Navigator.maybePop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          user: _currentUser,
          service: widget.service,
          onMenu: _openMenu,
          onSignOut: widget.onSignOut,
          isActive: true,
          onProfileUpdated: _refreshUser,
        ),
      ),
    );
  }

  void _selectPage(int index, {String? targetRequestId}) {
    if (index == 5) {
      _openProfile();
      return;
    }
    if (_animatingSelectedIndex == index) {
      if (targetRequestId != null) {
        setState(() {
          _targetRequestId = targetRequestId;
        });
      }
      return;
    }
    Navigator.maybePop(context);

    // Immediately switch both capsule and page at the same time
    setState(() {
      _animatingSelectedIndex = index;
      _selectedIndex = index;
      if (targetRequestId != null) {
        _targetRequestId = targetRequestId;
      }
    });

    _loadTodayAttendance();

    if (widget.user.role == 'admin') {
      _loadPendingCount();
    }
    if (index == 4) {
      _loadNotificationCount();
    }
  }

  Widget _buildScoopedBottomBar() {
    final rawBottomPadding = math.max(
      MediaQuery.paddingOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    // Enforce a minimum 14.0px bottom padding so navbar items are NEVER obscured by Android 3-button navigation bar (3 dots / soft keys)
    final double bottomInset = math.max(rawBottomPadding, 14.0);
    const double barHeight = 64.0;
    final double totalHeight = barHeight + bottomInset;

    return SizedBox(
      height: totalHeight + 18.0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Full-width Canvas with Scooped Notch Cutout
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: totalHeight,
            child: CustomPaint(
              painter: const _ScoopedNotchPainter(
                color: Colors.white,
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: SizedBox(
                  height: barHeight,
                  child: Row(
                    children: [
                      // Left 2 items (Home, Requests)
                      _buildModernNavItem(
                        0,
                        Icons.home_outlined,
                        Icons.home_rounded,
                        'หน้าหลัก',
                      ),
                      _buildModernNavItem(
                        2,
                        Icons.assignment_outlined,
                        Icons.assignment_rounded,
                        'คำขอ',
                        badgeCount: _pendingCount,
                      ),

                      // Gap reserved for the scooped center cradle
                      const SizedBox(width: 82),

                      // Right 2 items (Calendar, Notifications)
                      _buildModernNavItem(
                        3,
                        Icons.calendar_month_outlined,
                        Icons.calendar_month_rounded,
                        'ปฏิทิน',
                      ),
                      _buildModernNavItem(
                        4,
                        Icons.notifications_none_rounded,
                        Icons.notifications_rounded,
                        'แจ้งเตือน',
                        badgeCount: _notificationCount,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Center Floating Action Button (FAB) with Live Animation States inside the Scoop
          Positioned(
            top: 0,
            child: AttendanceNavFab(
              attendance: _todayAttendance,
              isSelected: _selectedIndex == 1,
              onTap: () => _selectPage(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernNavItem(
    int index,
    IconData unselectedIcon,
    IconData selectedIcon,
    String label, {
    int badgeCount = 0,
  }) {
    final isSelected = _selectedIndex == index;

    final Widget iconWidget = Icon(
      isSelected ? selectedIcon : unselectedIcon,
      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
      size: 24,
    );

    final Widget badgeIcon = badgeCount > 0
        ? Badge(
            label: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
              style: const TextStyle(
                fontSize: 8.5,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFFEF4444),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: iconWidget,
          )
        : iconWidget;

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectPage(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              badgeIcon,
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
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
          onOpenProfile: _openProfile,
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
                    onOpenProfile: _openProfile,
                  )
                : MainDashboardPage(
                    key: const PageStorageKey('main_dashboard'),
                    user: _currentUser,
                    service: widget.service,
                    onSelectTab: _selectPage,
                    isActive: _selectedIndex == 0,
                    onOpenProfile: _openProfile,
                  ),
            // Index 1: ลงเวลาเข้างาน
            DashboardPage(
              key: const PageStorageKey('dashboard'),
              user: _currentUser,
              service: widget.service,
              onMenu: _openMenu,
              onSignOut: widget.onSignOut,
              isActive: _selectedIndex == 1,
              onAttendanceChanged: (att) {
                if (mounted) {
                  setState(() {
                    _todayAttendance = att;
                  });
                }
              },
            ),
            // Index 2: คำขอ
            isAdmin
                ? AdminRequestsPage(
                    key: const PageStorageKey('admin_requests'),
                    service: widget.service,
                    onMenu: _openMenu,
                    isActive: _selectedIndex == 2,
                    targetRequestId: _targetRequestId,
                    onClearTargetRequest: () => setState(() {
                      _targetRequestId = null;
                    }),
                  )
                : RequestsPage(
                    key: const PageStorageKey('requests'),
                    service: widget.service,
                    onMenu: _openMenu,
                    isActive: _selectedIndex == 2,
                    targetRequestId: _targetRequestId,
                    onClearTargetRequest: () => setState(() {
                      _targetRequestId = null;
                    }),
                  ),
            // Index 3: ปฏิทิน
            WorkCalendarPage(
              key: const PageStorageKey('calendar'),
              service: widget.service,
              onMenu: _openMenu,
              onOpenRequests: () =>
                  _selectPage(2),
              isActive: _selectedIndex == 3,
            ),
            // Index 4: แจ้งเตือน
            NotificationsPage(
              key: const PageStorageKey('notifications'),
              onMenu: _openMenu,
              isActive: _selectedIndex == 4,
              service: widget.service,
              onNavigateToRequests: (targetId) =>
                  _selectPage(2, targetRequestId: targetId),
              onUnreadCountChanged: (count) {
                if (mounted && _notificationCount != count) {
                  setState(() => _notificationCount = count);
                }
              },
            ),
          ],
        ),
        bottomNavigationBar: _buildScoopedBottomBar(),
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
                  const Icon(
                    Icons.bug_report_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'เกิดข้อผิดพลาดในการสร้างหน้าจอ HomePage',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ข้อผิดพลาด: $e',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ตำแหน่งที่ล่ม:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$stack',
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.grey,
                    ),
                  ),
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
    required this.onOpenProfile,
    required this.onSignOut,
  });

  final AppUser user;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenProfile;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == 'admin';

    return Drawer(
      child: Column(
        children: [
          InkWell(
            onTap: onOpenProfile,
            child: Container(
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
                  UserAvatar(
                    avatarUrl: user.avatarUrl,
                    name: user.fullName,
                    radius: 31,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ],
                  ),
                  Text(
                    user.position.isEmpty ? user.role : user.position,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.76)),
                  ),
                ],
              ),
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
            label: 'โปรไฟล์ของฉัน',
            selected: false,
            onTap: onOpenProfile,
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
            onTap: () {
              Navigator.pop(context); // Close drawer
              showSignOutConfirmSheet(
                context,
                onConfirm: onSignOut,
              );
            },
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
  const FacebookHomeIcon({
    super.key,
    required this.color,
    required this.isFilled,
    this.size = 22,
  });

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
      final combinedPath = Path.combine(
        PathOperation.difference,
        housePath,
        doorPath,
      );
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
  const ClockInIcon({
    super.key,
    required this.color,
    required this.isFilled,
    this.size = 22,
  });

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
      canvas.drawLine(
        Offset(w * 0.5, h * 0.5),
        Offset(w * 0.5, h * 0.22),
        linePaint,
      );
      canvas.drawLine(
        Offset(w * 0.5, h * 0.5),
        Offset(w * 0.70, h * 0.5),
        linePaint,
      );
    } else {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
      canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.45, paint);

      // วาดเฉพาะเข็มนาฬิกาด้านใน (ไม่เอาวงกลมซ้อน)
      canvas.drawLine(
        Offset(w * 0.5, h * 0.5),
        Offset(w * 0.5, h * 0.22),
        paint,
      );
      canvas.drawLine(
        Offset(w * 0.5, h * 0.5),
        Offset(w * 0.70, h * 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClockInPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isFilled != isFilled;
  }
}

class _ScoopedNotchPainter extends CustomPainter {
  final Color color;

  const _ScoopedNotchPainter({
    required this.color,
  });

  static const double fabRadius = 28.0;
  static const double notchMargin = 7.0;
  static const double shoulderRadius = 16.0;
  static const Color shadowColor = Color(0x18000000);

  Path _createPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final r = fabRadius + notchMargin;
    final s = shoulderRadius;

    // Start at top-left
    path.moveTo(0, 0);

    // Straight line to start of left shoulder
    path.lineTo(cx - r - s, 0);

    // Left shoulder curve curving down into the notch
    path.cubicTo(
      cx - r - s * 0.45, 0,
      cx - r, r * 0.28,
      cx - r, r * 0.58,
    );

    // Center circular cradle arc under the FAB
    path.arcToPoint(
      Offset(cx + r, r * 0.58),
      radius: Radius.circular(r),
      clockwise: false,
    );

    // Right shoulder curve curving back up to flat top line
    path.cubicTo(
      cx + r, r * 0.28,
      cx + r + s * 0.45, 0,
      cx + r + s, 0,
    );

    // Straight line to top-right
    path.lineTo(w, 0);

    // Down to bottom-right
    path.lineTo(w, h);

    // Across to bottom-left
    path.lineTo(0, h);

    // Close shape
    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _createPath(size);

    // 1. Draw smooth ambient shadow
    canvas.drawShadow(path, shadowColor, 8.0, false);

    // 2. Draw solid surface
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 3. Draw top hairline border
    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2 - (fabRadius + notchMargin + shoulderRadius), 0)
      ..cubicTo(
        size.width / 2 - (fabRadius + notchMargin + shoulderRadius * 0.45), 0,
        size.width / 2 - (fabRadius + notchMargin), (fabRadius + notchMargin) * 0.28,
        size.width / 2 - (fabRadius + notchMargin), (fabRadius + notchMargin) * 0.58,
      )
      ..arcToPoint(
        Offset(size.width / 2 + (fabRadius + notchMargin), (fabRadius + notchMargin) * 0.58),
        radius: Radius.circular(fabRadius + notchMargin),
        clockwise: false,
      )
      ..cubicTo(
        size.width / 2 + (fabRadius + notchMargin), (fabRadius + notchMargin) * 0.28,
        size.width / 2 + (fabRadius + notchMargin + shoulderRadius * 0.45), 0,
        size.width / 2 + (fabRadius + notchMargin + shoulderRadius), 0,
      )
      ..lineTo(size.width, 0);

    final strokePaint = Paint()
      ..color = const Color(0x10000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(borderPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ScoopedNotchPainter oldDelegate) =>
      oldDelegate.color != color;
}
