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
          ),
          RequestsPage(
            key: const PageStorageKey('requests'),
            service: widget.service,
            onMenu: _openMenu,
          ),
          WorkCalendarPage(
            key: const PageStorageKey('calendar'),
            service: widget.service,
            onMenu: _openMenu,
            onOpenRequests: () => _selectPage(1),
          ),
          UserProfilePage(
            key: const PageStorageKey('profile'),
            user: widget.user,
            onMenu: _openMenu,
            onSignOut: widget.onSignOut,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDBEAFE),
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'หน้าหลัก',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline_rounded),
            selectedIcon: Icon(Icons.mail_rounded),
            label: 'คำขอ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'ปฏิทิน',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle_rounded),
            label: 'โปรไฟล์',
          ),
        ],
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
                  ),
                  child: const Icon(
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
