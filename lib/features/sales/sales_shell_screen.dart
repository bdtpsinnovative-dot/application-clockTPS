import 'package:flutter/material.dart';

import 'sales_auth_adapter.dart';
import 'dispatch/dispatch_screen.dart';
import 'pos/pos_screen.dart';

const _ink = Color(0xFF292524);
const _muted = Color(0xFF78716C);
const _primaryBlue = Color(0xFF2563EB);
const _primaryDark = Color(0xFF1D4ED8);
const _blueTintBg = Color(0xFFEFF6FF);
const _blueTintBorder = Color(0xFFBFDBFE);
const _orange = Color(0xFFEA580C);

class SalesShellScreen extends StatefulWidget {
  const SalesShellScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.onSignOut,
  });

  final AuthenticatedUser user;
  final AuthService authService;
  final Future<void> Function() onSignOut;

  @override
  State<SalesShellScreen> createState() => _SalesShellScreenState();
}

class _SalesShellScreenState extends State<SalesShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<SalePosScreenState> _posKey = GlobalKey<SalePosScreenState>();

  int _currentIndex = 0;
  int _dispatchTasksCount = 0;

  void _onTasksCountChanged(int count) {
    if (mounted) setState(() => _dispatchTasksCount = count);
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _navigateToTab(int index) {
    Navigator.of(context).pop(); // Close drawer
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  void _navigateToQuote() {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildAppDrawer(),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            SalePosScreen(
              key: _posKey,
              user: widget.user,
              authService: widget.authService,
              onSignOut: widget.onSignOut,
              onOpenDrawer: _openDrawer,
              onNavigateToDispatch: () => setState(() => _currentIndex = 1),
            ),
            VanguardDispatchScreen(
              user: widget.user,
              authService: widget.authService,
              onTasksCountChanged: _onTasksCountChanged,
              onOpenDrawer: _openDrawer,
              onNavigateToQuote: _navigateToQuote,
              onBackToPos: () => setState(() => _currentIndex = 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer() {
    final staffName = widget.user.fullName?.trim().isNotEmpty == true
        ? widget.user.fullName!.trim()
        : widget.user.email ?? 'พนักงานขาย';
    final roleName = widget.user.role.toUpperCase();

    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Profile & Brand Card (Light, Clean & Modern)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF8FAFC),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE7E5E4)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _blueTintBg,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: _blueTintBorder),
                        ),
                        child: const Icon(
                          Icons.point_of_sale_rounded,
                          color: _primaryBlue,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sale Ops',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'ระบบปฏิบัติการงานขายและจัดส่ง',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 19),
                        tooltip: 'ปิดเมนู',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F5F4),
                          foregroundColor: _muted,
                          minimumSize: const Size(34, 34),
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE7E5E4)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _blueTintBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: _blueTintBorder),
                          ),
                          child: const Icon(Icons.person_rounded, color: _primaryBlue, size: 20),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staffName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    'สาขา #${widget.user.branchId}',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: _blueTintBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _blueTintBorder),
                                    ),
                                    child: Text(
                                      roleName,
                                      style: const TextStyle(
                                        color: _primaryBlue,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Text(
                'เมนูหลัก (MAIN MENU)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: _muted.withAlpha(180),
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // Menu Item 1: POS ขายสินค้า & สร้างใบเสนอราคา
            _drawerMenuItem(
              index: 0,
              icon: Icons.point_of_sale_rounded,
              title: 'ขายสินค้า (POS)',
              subtitle: 'เลือกสินค้า & สร้างใบเสนอราคา',
              isSelected: _currentIndex == 0,
              onTap: () => _navigateToTab(0),
            ),

            // Menu Item 2: มอนิเตอร์ค้างส่ง (Vanguard Dispatch & ตัดสต็อก)
            _drawerMenuItem(
              index: 1,
              icon: Icons.local_shipping_rounded,
              title: 'มอนิเตอร์ค้างส่ง',
              subtitle: 'ยืนยันรับชำระเงิน & ตัดสต็อก',
              isSelected: _currentIndex == 1,
              badgeCount: _dispatchTasksCount,
              onTap: () => _navigateToTab(1),
            ),

            const Spacer(),

            // Back to HR button
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Material(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: _ink, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'กลับหน้าหลัก HR',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              Text(
                                'กลับไปยังระบบ Clock in TPS',
                                style: TextStyle(fontSize: 10, color: _muted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Wallcraft Sale Ops v1.0.0',
                  style: TextStyle(fontSize: 10, color: Color(0xFFA8A29E)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerMenuItem({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected ? _blueTintBg : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _blueTintBorder : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryBlue : const Color(0xFFF5F5F4),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : _ink,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          color: isSelected ? _primaryDark : _ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isSelected ? _primaryBlue : _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount งาน',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isSelected)
                  const Icon(Icons.check_rounded, color: _primaryBlue, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
