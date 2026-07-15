import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_flow_service.dart';
import '../widgets/work_ui.dart';
import 'calendar_page.dart';
import 'dashboard_page.dart';
import 'requests_page.dart';
import 'user_profile_page.dart';

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

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  void _selectPage(int index) {
    Navigator.maybePop(context);
    setState(() => _selectedIndex = index);
  }

  Widget _buildNavIcon(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final isSelected = _selectedIndex == index;
    
    final Widget iconWidget = index == 0
        ? FacebookHomeIcon(
            color: isSelected ? workBlue : workMuted,
            isFilled: isSelected,
            size: 22,
          )
        : Icon(
            isSelected ? selectedIcon : unselectedIcon,
            color: isSelected ? workBlue : workMuted,
            size: 22,
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? workBlue : workMuted,
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileNavIcon(int index, String label) {
    final isSelected = _selectedIndex == index;
    final avatarUrl = widget.user.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
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
                      size: 14,
                      color: workMuted,
                    ),
                  )
                : const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: workMuted,
                  ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isSelected ? workBlue : workMuted,
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _AppDrawer(
        user: widget.user,
        selectedIndex: _selectedIndex,
        onSelect: _selectPage,
        onSignOut: widget.onSignOut,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardPage(
            key: const PageStorageKey('dashboard'),
            user: widget.user,
            service: widget.service,
            onMenu: _openMenu,
            isActive: _selectedIndex == 0,
          ),
          RequestsPage(
            key: const PageStorageKey('requests'),
            service: widget.service,
            onMenu: _openMenu,
            isActive: _selectedIndex == 1,
          ),
          WorkCalendarPage(
            key: const PageStorageKey('calendar'),
            service: widget.service,
            onMenu: _openMenu,
            onOpenRequests: () => _selectPage(1),
            isActive: _selectedIndex == 2,
          ),
          UserProfilePage(
            key: const PageStorageKey('profile'),
            user: widget.user,
            service: widget.service,
            onMenu: _openMenu,
            onSignOut: widget.onSignOut,
            isActive: _selectedIndex == 3,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          overlayColor: MaterialStateProperty.all(Colors.transparent),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          height: 54,
          backgroundColor: Colors.white,
          indicatorColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          onDestinationSelected: _selectPage,
          destinations: [
            NavigationDestination(
              icon: _buildNavIcon(0, Icons.home_outlined, Icons.home_rounded, 'หน้าหลัก'),
              label: '',
            ),
            NavigationDestination(
              icon: _buildNavIcon(1, Icons.assignment_outlined, Icons.assignment_rounded, 'คำขอ'),
              label: '',
            ),
            NavigationDestination(
              icon: _buildNavIcon(2, Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'ปฏิทิน'),
              label: '',
            ),
            NavigationDestination(
              icon: _buildProfileNavIcon(3, 'โปรไฟล์'),
              label: '',
            ),
          ],
        ),
      ),
    );
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
            icon: Icons.mail_outline_rounded,
            label: 'คำขอของฉัน',
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          _DrawerItem(
            icon: Icons.calendar_month_outlined,
            label: 'ปฏิทินตารางงาน',
            selected: selectedIndex == 2,
            onTap: () => onSelect(2),
          ),
          _DrawerItem(
            icon: Icons.person_outline_rounded,
            label: 'โปรไฟล์',
            selected: selectedIndex == 3,
            onTap: () => onSelect(3),
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

    // Draw house path (with overhang eaves and inset walls)
    final housePath = Path();
    housePath.moveTo(w * 0.18, h * 0.92); // bottom-left wall
    housePath.lineTo(w * 0.18, h * 0.48); // wall-roof junction
    housePath.lineTo(w * 0.08, h * 0.48); // left eave overhang
    housePath.lineTo(w * 0.46, h * 0.12); // left roof slope
    housePath.quadraticBezierTo(w * 0.5, h * 0.08, w * 0.54, h * 0.12); // rounded roof peak
    housePath.lineTo(w * 0.92, h * 0.48); // right roof slope to eave
    housePath.lineTo(w * 0.82, h * 0.48); // right eave overhang
    housePath.lineTo(w * 0.82, h * 0.92); // bottom-right wall
    housePath.close();

    // Door path (cutout at the bottom center)
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
      // Draw house minus door
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
