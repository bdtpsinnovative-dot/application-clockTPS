import 'package:flutter/material.dart';

import '../sales_auth_adapter.dart';
import 'dispatch_service.dart';
import 'terra_logo_data.dart';
import 'zenslab_logo_data.dart';

const _ink = Color(0xFF292524);
const _muted = Color(0xFF78716C);
const _canvas = Color(0xFFF8FAFC);
const _line = Color(0xFFE2E8F0);
const _emerald = Color(0xFF2563EB); // Royal Blue theme
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFEA580C);
const _red = Color(0xFFDC2626);
const _stone100 = Color(0xFFF5F5F4);
const _stone200 = Color(0xFFE7E5E4);
const _stone300 = Color(0xFFD6D3D1);
const _stone400 = Color(0xFFA8A29E);
const _stone500 = Color(0xFF78716C);
const _stone700 = Color(0xFF44403C);
const _stone800 = Color(0xFF292524);
const _stone900 = Color(0xFF1C1917);

enum DispatchTab {
  overview,
  myTasks,
  followUps,
  completed,
  cancelled,
}

class VanguardDispatchScreen extends StatefulWidget {
  const VanguardDispatchScreen({
    super.key,
    required this.user,
    required this.authService,
    this.onTasksCountChanged,
    this.onOpenDrawer,
    this.onNavigateToQuote,
    this.onBackToPos,
  });

  final AuthenticatedUser user;
  final AuthService authService;
  final ValueChanged<int>? onTasksCountChanged;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onNavigateToQuote;
  final VoidCallback? onBackToPos;

  @override
  State<VanguardDispatchScreen> createState() => _VanguardDispatchScreenState();
}

class _VanguardDispatchScreenState extends State<VanguardDispatchScreen> {
  late final DispatchService _dispatchService;
  final _searchController = TextEditingController();

  DispatchTab _currentTab = DispatchTab.overview;
  GroupedDispatches? _dispatches;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  final Set<int> _expandedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _dispatchService = DispatchService(widget.authService);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _dispatchService.loadDispatches();
      if (!mounted) return;
      setState(() {
        _dispatches = res;
        _isLoading = false;
      });
      widget.onTasksCountChanged?.call(res.counts.myTasks + res.counts.pendingApproval);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูลระบบจัดส่งได้';
        _isLoading = false;
      });
    }
  }

  List<DispatchOrder> _getFilteredOrders() {
    if (_dispatches == null) return const [];

    List<DispatchOrder> list;
    switch (_currentTab) {
      case DispatchTab.overview:
        list = _dispatches!.overviewTasks;
        break;
      case DispatchTab.myTasks:
        list = _dispatches!.myTasks;
        break;
      case DispatchTab.followUps:
        list = _dispatches!.followUpTasks;
        break;
      case DispatchTab.completed:
        list = _dispatches!.completedTasks;
        break;
      case DispatchTab.cancelled:
        list = _dispatches!.cancelledTasks;
        break;
    }

    if (_searchQuery.isEmpty) return list;

    return list.where((order) {
      final matchCode = order.orderCode.toLowerCase().contains(_searchQuery);
      final matchName = order.shippingName.toLowerCase().contains(_searchQuery);
      final matchPhone = order.shippingPhone.toLowerCase().contains(_searchQuery);
      final matchAddress = order.shippingAddress.toLowerCase().contains(_searchQuery);
      final matchItem = order.items.any(
        (it) =>
            it.product.name.toLowerCase().contains(_searchQuery) ||
            it.product.sku.toLowerCase().contains(_searchQuery),
      );
      return matchCode || matchName || matchPhone || matchAddress || matchItem;
    }).toList();
  }

  Future<void> _handleApproveStock(DispatchOrder order) async {
    final codeController = TextEditingController(text: order.orderCode);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline_rounded, color: _emerald, size: 40),
        title: const Text('ยืนยันรับชำระเงินและตัดสต็อก?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('บิล: ${order.orderCode}'),
            Text('ลูกค้า: ${order.shippingName.isEmpty ? "-" : order.shippingName}'),
            Text('ยอดสุทธิ: ฿${_formatMoney(order.totalAmount)}'),
            const SizedBox(height: 12),
            const Text('เลข Invoice / รหัสบิล (แก้ไขได้):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _muted)),
            const SizedBox(height: 4),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            const Text(
              '⚠️ ระบบจะทำการบันทึกตัดสต็อกออกจากคลังสินค้าทันที',
              style: TextStyle(color: _orange, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _emerald),
            child: const Text('ยืนยันตัดสต็อก'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dispatchService.approveAndCutStock(
        orderId: order.id,
        customOrderCode: codeController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อนุมัติและตัดสต็อกเรียบร้อยแล้ว'), backgroundColor: _emerald),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _red),
      );
    }
  }

  Future<void> _handleCompleteOrder(DispatchOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.local_shipping_outlined, color: _blue, size: 40),
        title: const Text('ยืนยันส่งมอบสินค้าแล้ว?'),
        content: Text('ยืนยันว่าได้ส่งมอบสินค้าตามบิล ${order.orderCode} เรียบร้อยแล้ว'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _blue),
            child: const Text('ยืนยันส่งมอบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dispatchService.markShipped(orderId: order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกการส่งมอบสินค้าสำเร็จ'), backgroundColor: _blue),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _red),
      );
    }
  }

  Future<void> _handleCancelOrder(DispatchOrder order) async {
    final reasonController = TextEditingController();
    final isPending = order.status == 'PENDING';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cancel_outlined, color: _red, size: 40),
        title: const Text('ยืนยันยกเลิกบิล?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPending
                  ? 'คุณต้องการยกเลิกบิล ${order.orderCode} ใช่หรือไม่?'
                  : 'บิล ${order.orderCode} นี้เคยตัดสต็อกไปแล้ว หากยกเลิกระบบจะคืนสต็อกเข้าคลังให้อัตโนมัติ',
              style: TextStyle(
                fontSize: 12,
                color: isPending ? _ink : _orange,
                fontWeight: isPending ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text('ระบุเหตุผลการยกเลิก (ถ้ามี):', style: TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 4),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'เช่น ลูกค้ายกเลิก, เปลี่ยนใจ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ปิด')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _red),
            child: const Text('ยืนยันยกเลิกบิล'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _dispatchService.cancelOrder(orderId: order.id, reason: reasonController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยกเลิกบิลและจัดการสต็อกเรียบร้อยแล้ว'), backgroundColor: _red),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _red),
      );
    }
  }

  Future<void> _handleEditCustomer(DispatchOrder order) async {
    final nameCtrl = TextEditingController(text: order.shippingName);
    final phoneCtrl = TextEditingController(text: order.shippingPhone);
    final addressCtrl = TextEditingController(text: order.shippingAddress);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'แก้ไขข้อมูลลูกค้า / ที่อยู่จัดส่ง',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'ชื่อผู้รับ',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'เบอร์โทรศัพท์',
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'ที่อยู่จัดส่ง',
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: _emerald,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('บันทึกการแก้ไข', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      await _dispatchService.updateCustomer(
        orderId: order.id,
        shippingName: nameCtrl.text,
        shippingPhone: phoneCtrl.text,
        shippingAddress: addressCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปเดตข้อมูลลูกค้าเรียบร้อยแล้ว'), backgroundColor: _emerald),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: _red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _getFilteredOrders();

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _tabAndSearchRow(),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: _emerald))
                            : _errorMessage != null
                                ? _errorWidget()
                                : RefreshIndicator(
                                    onRefresh: _loadData,
                                    color: _emerald,
                                    child: filteredOrders.isEmpty
                                        ? _emptyWidget()
                                        : ListView.builder(
                                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                                            itemCount: filteredOrders.length,
                                            itemBuilder: (context, index) {
                                              final order = filteredOrders[index];
                                              final isExpanded = _expandedOrderIds.contains(order.id);
                                              return _buildOrderCard(order, isExpanded);
                                            },
                                          ),
                                  ),
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

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 600;
                return Row(
                  children: [
                    // ปุ่มย้อนกลับไปหน้าหลัก HR
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          if (widget.onBackToPos != null) {
                            widget.onBackToPos!();
                          } else if (widget.onNavigateToQuote != null) {
                            widget.onNavigateToQuote!();
                          } else if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _line),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: _ink, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ระบบจัดการสินค้ารอจัดส่ง',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isCompact ? 14.5 : 16.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'ตรวจสอบรายการบิลค้างส่งและติดตามสถานะสินค้าข้ามสาขา',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: widget.onNavigateToQuote,
                      icon: const Icon(Icons.post_add_rounded, size: 17),
                      label: Text(
                        isCompact ? '+ ใบเสนอราคา' : '+ สร้างใบเสนอราคา',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: isCompact ? 11.5 : 12.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: Size(0, isCompact ? 36 : 40),
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 10 : 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: _loadData,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 38,
                          padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.refresh_rounded, color: Color(0xFF475569), size: 16),
                              if (!isCompact) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  'รีเฟรชข้อมูล',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

  Widget _tabAndSearchRow() {
    final counts = _dispatches?.counts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;
          final tabsWidget = Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: isWide
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tabChip(
                          tab: DispatchTab.overview,
                          icon: Icons.format_list_bulleted_rounded,
                          label: 'ภาพรวมทั้งหมด',
                          count: counts?.overview ?? 0,
                          activeColor: const Color(0xFF1E293B),
                          isMobile: false,
                        ),
                        const SizedBox(width: 4),
                        _tabChip(
                          tab: DispatchTab.myTasks,
                          icon: Icons.inventory_2_outlined,
                          label: 'คลังเราต้องจัดส่ง',
                          count: counts?.myTasks ?? 0,
                          activeColor: const Color(0xFF059669),
                          isMobile: false,
                        ),
                        const SizedBox(width: 4),
                        _tabChip(
                          tab: DispatchTab.followUps,
                          icon: Icons.show_chart_rounded,
                          label: 'ติดตามสาขาอื่น',
                          count: counts?.followUps ?? 0,
                          activeColor: const Color(0xFFF59E0B),
                          isMobile: false,
                        ),
                        const SizedBox(width: 4),
                        _tabChip(
                          tab: DispatchTab.completed,
                          icon: Icons.archive_outlined,
                          label: 'ประวัติสำเร็จ',
                          count: counts?.completed ?? 0,
                          activeColor: const Color(0xFF059669),
                          isMobile: false,
                        ),
                        const SizedBox(width: 4),
                        _tabChip(
                          tab: DispatchTab.cancelled,
                          icon: Icons.cancel_outlined,
                          label: 'ยกเลิกแล้ว',
                          count: counts?.cancelled ?? 0,
                          activeColor: const Color(0xFFEF4444),
                          isMobile: false,
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _tabChip(
                          tab: DispatchTab.overview,
                          icon: Icons.format_list_bulleted_rounded,
                          label: 'ภาพรวมทั้งหมด',
                          count: counts?.overview ?? 0,
                          activeColor: const Color(0xFF1E293B),
                          isMobile: true,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _tabChip(
                          tab: DispatchTab.myTasks,
                          icon: Icons.inventory_2_outlined,
                          label: 'คลังเราต้องจัดส่ง',
                          count: counts?.myTasks ?? 0,
                          activeColor: const Color(0xFF059669),
                          isMobile: true,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _tabChip(
                          tab: DispatchTab.followUps,
                          icon: Icons.show_chart_rounded,
                          label: 'ติดตามสาขาอื่น',
                          count: counts?.followUps ?? 0,
                          activeColor: const Color(0xFFF59E0B),
                          isMobile: true,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _tabChip(
                          tab: DispatchTab.completed,
                          icon: Icons.archive_outlined,
                          label: 'ประวัติสำเร็จ',
                          count: counts?.completed ?? 0,
                          activeColor: const Color(0xFF059669),
                          isMobile: true,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _tabChip(
                          tab: DispatchTab.cancelled,
                          icon: Icons.cancel_outlined,
                          label: 'ยกเลิกแล้ว',
                          count: counts?.cancelled ?? 0,
                          activeColor: const Color(0xFFEF4444),
                          isMobile: true,
                        ),
                      ),
                    ],
                  ),
          );

          final searchWidget = Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: 'ค้นหาเลขที่บิล, ชื่อลูกค้า, เบอร์โทร, SKU สินค้า...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 15),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          );

          if (isWide) {
            return Row(
              children: [
                Flexible(flex: 3, child: tabsWidget),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: searchWidget),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tabsWidget,
              const SizedBox(height: 8),
              searchWidget,
            ],
          );
        },
      ),
    );
  }

  Widget _tabChip({
    required DispatchTab tab,
    required IconData icon,
    required String label,
    required int count,
    required Color activeColor,
    bool isMobile = false,
  }) {
    final isSelected = _currentTab == tab;

    Widget iconWidget = Icon(
      icon,
      size: isMobile ? 18 : 14,
      color: isSelected ? Colors.white : const Color(0xFF64748B),
    );

    if (isMobile && count > 0) {
      iconWidget = Badge.count(
        count: count,
        backgroundColor: isSelected ? Colors.white : activeColor,
        textColor: isSelected ? activeColor : Colors.white,
        textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
        child: iconWidget,
      );
    }

    return Tooltip(
      message: '$label ($count)',
      child: Material(
        color: isSelected ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: () => setState(() => _currentTab = tab),
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 4 : 12,
              vertical: isMobile ? 8.5 : 7.5,
            ),
            child: isMobile
                ? Center(child: iconWidget)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconWidget,
                      const SizedBox(width: 6),
                      Text(
                        '$label ($count)',
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(DispatchOrder order, bool isExpanded) {
    final isStorefrontTakeaway = order.isTakeaway;
    final isMyTask = (_dispatches?.myTasks.any((t) => t.id == order.id) ?? false) ||
        order.items.any((it) => !it.isCrossBranch);
    final isAnyItemOutOfStock =
        order.status == 'PENDING' && order.items.any((it) => it.availableStock < it.qty);

    // Status pill colors & labels matching vanguard-dispatch/page.tsx
    Color pillBg;
    Color pillBorder;
    Color pillText;
    IconData pillIcon;
    String pillLabel;

    if (order.status == 'PENDING') {
      pillBg = const Color(0xFFFFF1F2); // rose-50
      pillBorder = const Color(0xFFFECDD3); // rose-200
      pillText = const Color(0xFFE11D48); // rose-600
      pillIcon = Icons.payments_outlined;
      pillLabel = 'รอชำระเงิน';
    } else if (order.status == 'COMPLETED') {
      pillBg = const Color(0xFFECFDF5); // emerald-50
      pillBorder = const Color(0xFFA7F3D0); // emerald-200
      pillText = const Color(0xFF059669); // emerald-600
      pillIcon = Icons.check_circle_outline_rounded;
      pillLabel = 'สำเร็จแล้ว';
    } else if (order.status == 'CANCELLED') {
      pillBg = const Color(0xFFFEF2F2); // red-50
      pillBorder = const Color(0xFFFECACA); // red-200
      pillText = const Color(0xFFDC2626); // red-600
      pillIcon = Icons.cancel_outlined;
      pillLabel = 'ยกเลิกแล้ว';
    } else if (isStorefrontTakeaway) {
      pillBg = const Color(0xFFEEF2FF); // indigo-50
      pillBorder = const Color(0xFFC7D2FE); // indigo-200
      pillText = const Color(0xFF4F46E5); // indigo-600
      pillIcon = Icons.storefront_outlined;
      pillLabel = 'รอส่งมอบ';
    } else {
      pillBg = const Color(0xFFFFFBEB); // amber-50
      pillBorder = const Color(0xFFFDE68A); // amber-200
      pillText = const Color(0xFFD97706); // amber-600
      pillIcon = Icons.inventory_2_outlined;
      pillLabel = 'รอจัดส่ง';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAnyItemOutOfStock ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Order Header (Clickable to toggle expand/collapse) ──
          Material(
            color: Colors.white,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedOrderIds.remove(order.id);
                  } else {
                    _expandedOrderIds.add(order.id);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Row 1: Code + Tags + Status Badge + Chevron ──
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              // Mini Icon
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isStorefrontTakeaway
                                      ? const Color(0xFFEEF2FF)
                                      : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isStorefrontTakeaway
                                        ? const Color(0xFFE0E7FF)
                                        : const Color(0xFFD1FAE5),
                                  ),
                                ),
                                child: Icon(
                                  isStorefrontTakeaway
                                      ? Icons.storefront_outlined
                                      : Icons.local_shipping_outlined,
                                  size: 13,
                                  color: isStorefrontTakeaway
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(width: 7),
                              // Order Code
                              Flexible(
                                child: Text(
                                  order.orderCode,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              // Type Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isStorefrontTakeaway
                                      ? const Color(0xFFEEF2FF)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isStorefrontTakeaway
                                        ? const Color(0xFFC7D2FE)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  isStorefrontTakeaway ? 'หน้าร้าน' : 'จัดส่ง',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isStorefrontTakeaway
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              if (_currentTab == DispatchTab.overview) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isMyTask
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isMyTask
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFFFEF3C7),
                                  ),
                                ),
                                child: Text(
                                  isMyTask ? 'คลังเรา' : 'สาขาอื่น',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isMyTask
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Right side: Out of stock badge (if any) + Status Badge + Chevron
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAnyItemOutOfStock) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 10, color: Color(0xFFDC2626)),
                                  SizedBox(width: 2),
                                  Text(
                                    'ขาดสต็อก',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: pillBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: pillBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(pillIcon, size: 11, color: pillText),
                                const SizedBox(width: 3.5),
                                Text(
                                  pillLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: pillText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // ── Row 2: Customer + Phone + Date + Total Money ──
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 12.5, color: Color(0xFF64748B)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                order.shippingName.isEmpty ? 'ลูกค้าทั่วไป' : order.shippingName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            if (order.shippingPhone.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${order.shippingPhone})',
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '฿${_formatMoney(order.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // ── Row 3: Items quantity + Date + Summary of products ──
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 10.5, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 3),
                      Text(
                        _formatThaiShortDate(order.createdAt),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('·', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ),
                      const Icon(Icons.shopping_bag_outlined, size: 11, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 3),
                      Text(
                        '${order.totalItemQty} ชิ้น',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Text(':', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.items.map((i) => i.product.name.isNotEmpty ? i.product.name : 'สินค้า #${i.product.id}').join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ],
                ),
              ),
            ),
          ),

          // ── Expanded Body (2-Column Grid on Tablet/iPad, Stacked on Narrow Phone) ──
          if (isExpanded)
            Container(
              decoration: const BoxDecoration(
                color: Color(0x80F8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isTwoColumn = constraints.maxWidth >= 660;
                  final leftColumn = _buildExpandedItemsColumn(order);
                  final rightColumn = _buildExpandedActionsColumn(
                    order: order,
                    isStorefrontTakeaway: isStorefrontTakeaway,
                    isMyTask: isMyTask,
                    isAnyItemOutOfStock: isAnyItemOutOfStock,
                  );

                  if (isTwoColumn) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: leftColumn),
                        const SizedBox(width: 24),
                        Expanded(flex: 1, child: rightColumn),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftColumn,
                      const SizedBox(height: 12),
                      rightColumn,
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedItemsColumn(DispatchOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'รายการสินค้าในความรับผิดชอบ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...order.items.map((item) => _buildItemRow(item, orderStatus: order.status)),
      ],
    );
  }

  Widget _buildExpandedActionsColumn({
    required DispatchOrder order,
    required bool isStorefrontTakeaway,
    required bool isMyTask,
    required bool isAnyItemOutOfStock,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Customer / Takeaway Info Card
        Container(
          padding: isStorefrontTakeaway
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
              : const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: isStorefrontTakeaway
              ? Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        size: 17,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'ลูกค้ารับสินค้าหน้าร้าน',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E1B4B),
                                ),
                              ),
                              if (order.shippingName.isNotEmpty && order.shippingName != '-') ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '(${order.shippingName})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'กรุณาพิมพ์เอกสารให้ลูกค้าก่อนส่งมอบ',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _handleEditCustomer(order),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 12, color: Color(0xFF334155)),
                            SizedBox(width: 4),
                            Text(
                              'แก้ไขข้อมูล',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 6),
                              Text(
                                'ข้อมูลจัดส่งลูกค้า',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          Material(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => _handleEditCustomer(order),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_outlined, size: 13, color: _blue),
                                    SizedBox(width: 4),
                                    Text(
                                      'แก้ไขข้อมูลผู้รับ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _shippingDetailRow('ชื่อผู้รับ:', order.shippingName.isEmpty ? '-' : order.shippingName),
                    const SizedBox(height: 8),
                    _shippingDetailRow('เบอร์โทร:', order.shippingPhone.isEmpty ? '-' : order.shippingPhone),
                    const SizedBox(height: 8),
                    const Text(
                      'ที่อยู่จัดส่ง:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.shippingAddress.isEmpty ? '-' : order.shippingAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 10),

        // 2. Payment Slip Box (when PENDING or PROCESSING)
        if (order.status == 'PENDING' || order.status == 'PROCESSING') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'หลักฐานการชำระเงิน (ไม่บังคับ)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'แนบภายหลังได้',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ฟีเจอร์แนบสลิปกำลังเชื่อมต่อคลังรูปภาพ'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        'แนบสลิป',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 3. Primary Status / Action Button
        if (order.status == 'CANCELLED')
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                SizedBox(width: 6),
                Text(
                  'บิลนี้ถูกยกเลิกแล้ว',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          )
        else if (order.status == 'COMPLETED')
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF059669)),
                SizedBox(width: 6),
                Text(
                  'บิลนี้ปิดงาน/ส่งมอบสำเร็จแล้ว',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          )
        else if (order.status == 'PENDING')
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              onPressed: isAnyItemOutOfStock ? null : () => _handleApproveStock(order),
              icon: Icon(
                isAnyItemOutOfStock ? Icons.warning_amber_rounded : Icons.payments_outlined,
                size: 16,
              ),
              label: Text(
                isAnyItemOutOfStock
                    ? 'ไม่สามารถอนุมัติได้ (สินค้าหมด)'
                    : 'ยืนยันรับชำระเงิน & ตัดสต็อก',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                disabledBackgroundColor: const Color(0xFFF87171),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )
        else if (!isMyTask)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.show_chart_rounded, size: 16, color: Color(0xFF64748B)),
                SizedBox(width: 6),
                Text(
                  'รอสาขาปลายทางจัดส่งสินค้า',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              onPressed: () => _handleCompleteOrder(order),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
              label: Text(
                isStorefrontTakeaway ? 'ส่งมอบลูกค้าหน้าร้านแล้ว' : 'จัดส่งเรียบร้อยแล้ว',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isStorefrontTakeaway
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF059669),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // 4. Print Document + PDF + Excel Row
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: () => _showDocumentModal(order),
                  icon: const Icon(Icons.print_outlined, size: 16, color: Color(0xFF334155)),
                  label: const Text(
                    'พิมพ์เอกสาร',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // PDF Square Button
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => _showDocumentModal(order),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PDF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Excel Square Button
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => _showDocumentModal(order),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF107C41),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'X',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // 5. Edit Bill Button (when PENDING)
        if (order.status == 'PENDING') ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: widget.onNavigateToQuote,
              icon: const Icon(Icons.edit_note_rounded, size: 17, color: Color(0xFFEA580C)),
              label: const Text(
                'แก้ไขบิล (เพิ่ม/ลดสินค้า)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEA580C),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFFF7ED),
                side: const BorderSide(color: Color(0xFFFED7AA)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],

        // 6. Cancel Order Button (when not CANCELLED and not COMPLETED)
        if (order.status != 'CANCELLED' && order.status != 'COMPLETED') ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () => _handleCancelOrder(order),
              icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
              label: const Text(
                'ยกเลิกออเดอร์นี้',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFFECACA)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _shippingDetailRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  static const TextStyle _tableHeaderStyle = TextStyle(
    fontSize: 8,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: Color(0xFFA3A3A3),
  );

  String _money2(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$whole.${parts[1]}';
  }

  String _formatDateEn(String isoString) {
    if (isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      return '$day/$month/$year';
    } catch (_) {
      return isoString;
    }
  }

  static const Map<String, String> _productSubThaiMap = {
    'figure': 'Figure (ตุ๊กตาตกแต่ง)',
    'doll animal': 'Animal Figure (ตุ๊กตาสัตว์)',
    'animal': 'Animal Figure (ตุ๊กตาสัตว์)',
    'animal figure': 'Animal Figure (ตุ๊กตาสัตว์)',
    'doll human': 'Human Figure (ตุ๊กตามนุษย์)',
    'human': 'Human Figure (ตุ๊กตามนุษย์)',
    'human figure': 'Human Figure (ตุ๊กตามนุษย์)',
    'doll plant': 'Plant Figure (ตุ๊กตาผลไม้และพืช)',
    'plant': 'Plant Figure (ตุ๊กตาผลไม้และพืช)',
    'plant figure': 'Plant Figure (ตุ๊กตาผลไม้และพืช)',
    'doll object': 'Others Figure (ตุ๊กตาอื่น ๆ)',
    'others figure': 'Others Figure (ตุ๊กตาอื่น ๆ)',
    'art object': 'Art Object (ของตกแต่ง)',
    'others': 'Others (ของตกแต่งอื่น ๆ)',
    'ceramic vases': 'Ceramic Vases (แจกันเซรามิก)',
    'ceramic handmade': 'Ceramic Handmade (แจกันเซรามิก)',
    'ceramic 3d': 'Ceramic 3D (แจกันเซรามิก 3D)',
    'glass vases': 'Glass Vases (แจกันแก้ว)',
    'glass handmade': 'Glass Handmade (แจกันแก้ว)',
    'vessels': 'Vessels (ภาชนะ)',
    'vase': 'Vase (แจกัน)',
    'vase normal': 'Vase Normal (แจกัน)',
    'others vase': 'Others Vase (แจกันอื่น ๆ)',
    'sculpture': 'Sculpture (ประติมากรรมตกแต่ง)',
    'booked': 'BOOKED (ตกแต่งชั้นหนังสือ)',
    'book end': 'Book End (ตกแต่งชั้นหนังสือ)',
    'candle holder': 'Candle Holder (เชิงเทียน)',
    'candle holders': 'Candle Holders (เชิงเทียน)',
    'box': 'Box (ภาชนะตกแต่ง)',
    'decorative box': 'Decorative Box (ภาชนะตกแต่ง)',
    'trays': 'Trays (ถาดตกแต่ง)',
    'tray': 'Tray (ถาดตกแต่ง)',
    'toy': 'Toy (ของเล่นตกแต่ง)',
    'decorative toy': 'Decorative Toy (ของเล่นตกแต่ง)',
    'plates & dishes': 'Plates & Dishes (จานตกแต่ง)',
    'bowls': 'Bowls (ชาม)',
    'glassware': 'Glassware (แก้วน้ำ, แก้วไวน์)',
    'cups & mugs': 'Cups & Mugs (ถ้วย, แก้วกาแฟ)',
    'trays & servingware': 'Trays & Servingware (ภาชนะเสิร์ฟ)',
    'kitchenware': 'Kitchenware (เครื่องใช้ในครัว)',
    'other dining & tableware': 'Other Dining & Tableware (เครื่องใช้บนโต๊ะอาหารอื่น ๆ)',
    'bath': 'Bath Room (ห้องน้ำ)',
    'bath room': 'Bath Room (ห้องน้ำ)',
    'dressing room': 'Dressing Room (ห้องแต่งตัว)',
    'decorative bath': 'Decorative Bath (ของใช้ในห้องน้ำ)',
    'handmade': 'Handmade (ภาพวาด Handmade 100%)',
    '3d handmade': '3D Handmade (ภาพตกแต่ง Handmade 3 มิติ)',
    'digital print': 'Digital Print (ภาพดิจิตอลปริ้น)',
    'wall art digital print': 'Wall Art Digital Print (ภาพดิจิตอลปริ้น)',
    'wall art hand craft 50%': 'Wall Art Hand Craft 50% (ภาพวาด Handmade 50%)',
    'mixed media art': 'Mixed Media Art (ภาพวาด Handmade ผสมดิจิตอลปริ้น)',
    'frame': 'Photo Frame (กรอบรูป)',
    'photo frame': 'Photo Frame (กรอบรูป)',
    'coffee table': 'Coffee Table (โต๊ะกลาง)',
    'dining table': 'Dining Table (โต๊ะอาหาร)',
    'working table': 'Working Table (โต๊ะทำงาน)',
    'side table': 'Side Table (โต๊ะข้าง)',
    'night table': 'Night Table (โต๊ะข้างเตียง)',
    'table': 'Table (โต๊ะ)',
    'leg coffee table': 'Leg Coffee Table (ขาโต๊ะกลาง)',
    'leg dining table': 'Leg Dining Table (ขาโต๊ะอาหาร)',
    'dining chair': 'Dining Chair (เก้าอี้ทานข้าว)',
    'arm chair': 'Arm Chair (เก้าอี้มีที่วางแขน)',
    'lounge chair': 'Lounge Chair (เก้าอี้พักผ่อน)',
    'bar stool': 'Bar Stool (เก้าอี้บาร์)',
    'sofa': 'Sofa (โซฟา)',
    'modular sofa': 'Modular Sofa (โซฟาโมดูลาร์)',
    'shelf': 'Shelf (ชั้นวางของ)',
    'clothes rack': 'Clothes Rack (ราวแขวนเสื้อผ้า)',
    'bedroom collection': 'Bedroom Collection (ชุดห้องนอน)',
    'all': 'All (สินค้าทั้งหมด)',
  };

  String? _formatProductSup(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '-') return null;
    final trimmed = raw.trim();
    return _productSubThaiMap[trimmed.toLowerCase()] ?? trimmed;
  }

  /// Splits order items into A4 pages matching browser @media print (Images 4 & 5):
  /// - Page 1 (includes Company Header + Customer Info + Table Header) holds up to 7 items
  /// - Page 2+ (starts directly with Table Header, no repeated logo/customer block) holds up to 8 items
  /// - Footer (Terms + Totals + Signatures) sits on the last item page if it has room
  ///   (<= 4 items on Page 1, or <= 5 items on Page 2+); otherwise it flows onto a final page.
  List<({List<MapEntry<int, DispatchOrderItem>> items, bool isFirstPage, bool hasFooter})> _buildA4Pages(
    List<DispatchOrderItem> items,
  ) {
    final indexed = items.asMap().entries.toList();
    if (indexed.isEmpty) {
      return [(items: <MapEntry<int, DispatchOrderItem>>[], isFirstPage: true, hasFooter: true)];
    }

    const int maxPage1Items = 7;
    const int maxPage1WithFooter = 4;
    const int maxNextPageItems = 8;
    const int maxNextPageWithFooter = 5;

    final List<List<MapEntry<int, DispatchOrderItem>>> itemChunks = [];
    int cursor = 0;
    bool first = true;
    while (cursor < indexed.length) {
      final cap = first ? maxPage1Items : maxNextPageItems;
      final end = (cursor + cap < indexed.length) ? cursor + cap : indexed.length;
      itemChunks.add(indexed.sublist(cursor, end));
      cursor = end;
      first = false;
    }

    final List<({List<MapEntry<int, DispatchOrderItem>> items, bool isFirstPage, bool hasFooter})> result = [];
    for (int i = 0; i < itemChunks.length; i++) {
      final isFirst = i == 0;
      final isLastChunk = i == itemChunks.length - 1;
      final chunk = itemChunks[i];

      if (!isLastChunk) {
        result.add((items: chunk, isFirstPage: isFirst, hasFooter: false));
      } else {
        final maxWithFooter = isFirst ? maxPage1WithFooter : maxNextPageWithFooter;
        if (chunk.length <= maxWithFooter) {
          result.add((items: chunk, isFirstPage: isFirst, hasFooter: true));
        } else {
          // Items fill this page completely; Footer flows onto the top of the next A4 page
          result.add((items: chunk, isFirstPage: isFirst, hasFooter: false));
          result.add((items: <MapEntry<int, DispatchOrderItem>>[], isFirstPage: false, hasFooter: true));
        }
      }
    }
    return result;
  }

  void _showDocumentModal(DispatchOrder order) {
    // Canonical A4 print canvas (660 × 933 = exact 1 : 1.4142 A4 ratio matching browser @media print scale)
    const double kA4Width = 660.0;
    const double kA4Height = 933.0;

    final pages = _buildA4Pages(order.items);
    final totalPages = pages.length;
    final docTypeTitle = order.status == 'PENDING' ? 'ใบเสนอราคา (Quotation)' : 'ใบเสร็จรับเงิน / ใบจัดส่ง';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.zero,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 640;
              final outerMarginH = isMobile ? 12.0 : 28.0;
              final outerMarginV = isMobile ? 12.0 : 24.0;
              final canvasPadH = isMobile ? 14.0 : 32.0;
              final canvasPadV = isMobile ? 16.0 : 24.0;

              final modalMaxWidth = (constraints.maxWidth - (outerMarginH * 2)).clamp(300.0, 860.0);
              final modalMaxHeight = (constraints.maxHeight - (outerMarginV * 2)).clamp(400.0, 960.0);
              final displayPaperWidth = (modalMaxWidth - (canvasPadH * 2)).clamp(260.0, 740.0);

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: modalMaxWidth,
                    maxHeight: modalMaxHeight,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.42),
                          blurRadius: 40,
                          spreadRadius: 2,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── 1. MODAL HEADER BAR ──
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 14 : 22,
                            vertical: isMobile ? 12 : 14,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(bottom: BorderSide(color: _stone200)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: isMobile ? 38 : 42,
                                height: isMobile ? 38 : 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Icon(
                                  Icons.description_outlined,
                                  size: 20,
                                  color: _emerald,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            docTypeTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: isMobile ? 14.5 : 16,
                                              fontWeight: FontWeight.w800,
                                              color: _stone900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: Text(
                                            'A4 • $totalPages หน้า',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: _emerald,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${order.orderCode} • ${order.shippingName.isEmpty ? "ไม่ระบุชื่อลูกค้า" : order.shippingName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _stone500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close_rounded, size: 20),
                                tooltip: 'ปิดหน้าต่าง',
                                style: IconButton.styleFrom(
                                  backgroundColor: _stone100,
                                  foregroundColor: _stone700,
                                  padding: const EdgeInsets.all(8),
                                  minimumSize: const Size(36, 36),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── 2. MODAL BODY: LIGHT STUDIO A4 VIEWER CANVAS ──
                        Expanded(
                          child: Container(
                            color: const Color(0xFFF1F5F9),
                            child: InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 3.5,
                              child: SingleChildScrollView(
                                padding: EdgeInsets.symmetric(
                                  horizontal: canvasPadH,
                                  vertical: canvasPadV,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: displayPaperWidth,
                                    child: Column(
                                      children: List.generate(totalPages, (pageIndex) {
                                        final page = pages[pageIndex];
                                        final pageItems = page.items;
                                        final isFirstPage = page.isFirstPage;
                                        final hasFooter = page.hasFooter;

                                        return Padding(
                                          padding: EdgeInsets.only(top: pageIndex == 0 ? 0 : 18),
                                          child: FittedBox(
                                            fit: BoxFit.contain,
                                            child: Container(
                                              width: kA4Width,
                                              height: kA4Height,
                                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.08),
                                                    blurRadius: 24,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  // ─── HEADER & INFO (Only on Page 1) ───
                                                  if (isFirstPage) ...[
                                                    Container(
                                                      padding: const EdgeInsets.only(bottom: 12),
                                                      decoration: const BoxDecoration(
                                                        border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          // Left: Real Terra Logo & Company Info
                                                          Flexible(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Image.memory(
                                                                  order.isZenslabOrder
                                                                      ? kZenslabLogoBytes
                                                                      : kTerraHomeLogoBytes,
                                                                  height: order.isZenslabOrder ? 34 : 42,
                                                                  fit: BoxFit.contain,
                                                                  alignment: Alignment.centerLeft,
                                                                ),
                                                                const SizedBox(height: 6),
                                                                const Text(
                                                                  'OPERATED BY TPS GARDEN FURNITURE CO., LTD',
                                                                  style: TextStyle(
                                                                    fontSize: 8,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Color(0xFF262626),
                                                                    letterSpacing: 0.3,
                                                                    height: 1.25,
                                                                  ),
                                                                ),
                                                                const Text(
                                                                  '351/7-8 Soi Bangkok-Nonthaburi 13, Bangkok-Nonthaburi Road,\nBang Sue Subdistrict, Bang Sue District, Bangkok 10800',
                                                                  style: TextStyle(
                                                                    fontSize: 8,
                                                                    color: Color(0xFF737373),
                                                                    letterSpacing: 0.2,
                                                                    height: 1.3,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 2),
                                                                const Text(
                                                                  'TAX ID: 0105541075911',
                                                                  style: TextStyle(
                                                                    fontSize: 8,
                                                                    color: Color(0xFFA3A3A3),
                                                                    letterSpacing: 0.2,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          // Right: QUOTE & Status
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.end,
                                                            children: [
                                                              Text(
                                                                order.status == 'PENDING' ? 'QUOTE' : 'RECEIPT',
                                                                style: const TextStyle(
                                                                  fontSize: 30,
                                                                  fontWeight: FontWeight.w300,
                                                                  letterSpacing: 6.0,
                                                                  color: Color(0xFFE5E5E5),
                                                                  height: 1.0,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 4),
                                                              Text(
                                                                order.status == 'PENDING'
                                                                    ? 'PENDING PAYMENT'
                                                                    : (order.status == 'COMPLETED'
                                                                        ? 'COMPLETED / DELIVERED'
                                                                        : (order.status == 'CANCELLED'
                                                                            ? 'CANCELLED'
                                                                            : 'PAID / PROCESSING')),
                                                                style: TextStyle(
                                                                  fontSize: 8.5,
                                                                  fontWeight: FontWeight.bold,
                                                                  letterSpacing: 1.4,
                                                                  color: order.status == 'PENDING'
                                                                      ? const Color(0xFF737373)
                                                                      : (order.status == 'COMPLETED'
                                                                          ? const Color(0xFF059669)
                                                                          : (order.status == 'CANCELLED'
                                                                              ? const Color(0xFFDC2626)
                                                                              : const Color(0xFF2563EB))),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    // ─── INFO SECTION ────────────────────────────────
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                      child: Row(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          // Left: Prepared For
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                const Text(
                                                                  'PREPARED FOR',
                                                                  style: TextStyle(
                                                                    fontSize: 8,
                                                                    fontWeight: FontWeight.bold,
                                                                    letterSpacing: 1.2,
                                                                    color: Color(0xFFA3A3A3),
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 4),
                                                                Text(
                                                                  order.shippingName.isEmpty ? 'ไม่ระบุชื่อลูกค้า' : order.shippingName,
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: const TextStyle(
                                                                    fontSize: 14,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: Color(0xFF171717),
                                                                    height: 1.2,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 2),
                                                                Text(
                                                                  order.shippingAddress.isNotEmpty
                                                                      ? order.shippingAddress
                                                                      : (order.isTakeaway ? '[รับหน้าร้าน] -' : 'ไม่ระบุที่อยู่'),
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: const TextStyle(
                                                                    fontSize: 9,
                                                                    color: Color(0xFF737373),
                                                                    height: 1.3,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 2),
                                                                RichText(
                                                                  text: TextSpan(
                                                                    style: const TextStyle(fontSize: 9, color: Color(0xFF737373)),
                                                                    children: [
                                                                      const TextSpan(text: 'Tel: '),
                                                                      TextSpan(
                                                                        text: order.shippingPhone.isEmpty ? '-' : order.shippingPhone,
                                                                        style: const TextStyle(color: Color(0xFF171717)),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          // Right: 2-Column Aligned Table (Doc No., Date, Valid Until)
                                                          Table(
                                                            defaultColumnWidth: const IntrinsicColumnWidth(),
                                                            children: [
                                                              _docMetaTableRow('Doc No.', order.orderCode),
                                                              _docMetaTableRow('Date', _formatDateEn(order.createdAt)),
                                                              _docMetaTableRow('Valid Until', '30 Days', isLast: true),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],

                                                  // ─── ITEMS TABLE HEADER (Shown if page has items) ───
                                                  if (pageItems.isNotEmpty) ...[
                                                    Container(
                                                      padding: const EdgeInsets.only(bottom: 8),
                                                      decoration: const BoxDecoration(
                                                        border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
                                                      ),
                                                      child: const Row(
                                                        children: [
                                                          SizedBox(width: 28, child: Text('#', textAlign: TextAlign.center, style: _tableHeaderStyle)),
                                                          SizedBox(width: 78, child: Text('IMAGE', textAlign: TextAlign.center, style: _tableHeaderStyle)),
                                                          Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('DESCRIPTION', style: _tableHeaderStyle))),
                                                          SizedBox(width: 36, child: Text('QTY', textAlign: TextAlign.center, style: _tableHeaderStyle)),
                                                          SizedBox(width: 58, child: Text('PRICE', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                                                          SizedBox(width: 58, child: Text('VAT (7%)', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                                                          SizedBox(width: 72, child: Text('AMOUNT', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                                                        ],
                                                      ),
                                                    ),

                                                    // ─── ITEMS TABLE BODY ────────────────────────────
                                                    ...pageItems.map((entry) {
                                                      final globalIndex = entry.key;
                                                      final item = entry.value;
                                                      final preVatUnit = item.priceAtSale / 1.07;
                                                      final lineTotal = item.total;
                                                      final lineVat = lineTotal - (lineTotal / 1.07);

                                                      final formattedSup = _formatProductSup(item.product.productSup);
                                                      final sizeStr = item.product.sizeStr;
                                                      final material = item.product.material;

                                                      return Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 7.0),
                                                        decoration: const BoxDecoration(
                                                          border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
                                                        ),
                                                        child: Row(
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            // #
                                                            SizedBox(
                                                              width: 28,
                                                              child: Text(
                                                                '${globalIndex + 1}',
                                                                textAlign: TextAlign.center,
                                                                style: const TextStyle(fontSize: 9, color: Color(0xFFD4D4D4)),
                                                              ),
                                                            ),

                                                            // Image (64x64 rounded-lg box)
                                                            SizedBox(
                                                              width: 78,
                                                              child: Center(
                                                                child: Container(
                                                                  width: 64,
                                                                  height: 64,
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFFF8F8F8),
                                                                    borderRadius: BorderRadius.circular(8),
                                                                    border: Border.all(color: const Color(0xFFE5E5E5)),
                                                                  ),
                                                                  padding: const EdgeInsets.all(3),
                                                                  child: item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty
                                                                      ? Image.network(
                                                                          item.product.imageUrl!,
                                                                          fit: BoxFit.contain,
                                                                          errorBuilder: (_, _, _) => const Icon(
                                                                            Icons.image_not_supported_outlined,
                                                                            size: 20,
                                                                            color: Color(0xFFD4D4D4),
                                                                          ),
                                                                        )
                                                                      : const Icon(Icons.image_outlined, size: 20, color: Color(0xFFD4D4D4)),
                                                                ),
                                                              ),
                                                            ),

                                                            // Description (Name + SKU • ชนิด • ขนาด • วัสดุ + Fulfill by)
                                                            Expanded(
                                                              child: Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Text(
                                                                      item.product.name.isEmpty ? 'รหัส #${item.product.id}' : item.product.name,
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                      style: const TextStyle(
                                                                        fontSize: 11.5,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: Color(0xFF171717),
                                                                        height: 1.25,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 2),
                                                                    RichText(
                                                                      maxLines: 2,
                                                                      overflow: TextOverflow.ellipsis,
                                                                      text: TextSpan(
                                                                        style: const TextStyle(fontSize: 8.2, color: Color(0xFF737373), height: 1.35),
                                                                        children: [
                                                                          const TextSpan(text: 'SKU: ', style: TextStyle(color: Color(0xFFA3A3A3))),
                                                                          TextSpan(text: item.product.sku.isEmpty ? '-' : item.product.sku),
                                                                          if (formattedSup != null) ...[
                                                                            const TextSpan(text: '  •  ', style: TextStyle(color: Color(0xFFD4D4D4))),
                                                                            const TextSpan(text: 'ชนิด: ', style: TextStyle(color: Color(0xFFA3A3A3))),
                                                                            TextSpan(text: formattedSup),
                                                                          ],
                                                                          if (sizeStr != null && sizeStr.isNotEmpty) ...[
                                                                            const TextSpan(text: '  •  ', style: TextStyle(color: Color(0xFFD4D4D4))),
                                                                            const TextSpan(text: 'ขนาด: ', style: TextStyle(color: Color(0xFFA3A3A3))),
                                                                            TextSpan(text: sizeStr),
                                                                          ],
                                                                          if (material != null && material.isNotEmpty) ...[
                                                                            const TextSpan(text: '  •  ', style: TextStyle(color: Color(0xFFD4D4D4))),
                                                                            const TextSpan(text: 'วัสดุ: ', style: TextStyle(color: Color(0xFFA3A3A3))),
                                                                            TextSpan(text: material),
                                                                          ],
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 2),
                                                                    Text(
                                                                      'Fulfill by: ${item.fulfillBranchName}',
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                      style: const TextStyle(fontSize: 7.5, color: Color(0xFFA3A3A3)),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),

                                                            // Qty
                                                            SizedBox(
                                                              width: 36,
                                                              child: Text(
                                                                '${item.qty}',
                                                                textAlign: TextAlign.center,
                                                                style: const TextStyle(fontSize: 10, color: Color(0xFF525252)),
                                                              ),
                                                            ),

                                                            // Price
                                                            SizedBox(
                                                              width: 58,
                                                              child: Text(
                                                                _money2(preVatUnit),
                                                                textAlign: TextAlign.right,
                                                                style: const TextStyle(fontSize: 10, color: Color(0xFF525252)),
                                                              ),
                                                            ),

                                                            // VAT (7%)
                                                            SizedBox(
                                                              width: 58,
                                                              child: Text(
                                                                _money2(lineVat),
                                                                textAlign: TextAlign.right,
                                                                style: const TextStyle(fontSize: 10, color: Color(0xFF525252)),
                                                              ),
                                                            ),

                                                            // Amount
                                                            SizedBox(
                                                              width: 72,
                                                              child: Text(
                                                                _money2(lineTotal),
                                                                textAlign: TextAlign.right,
                                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF262626)),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }),
                                                  ],

                                                  // ─── FOOTER SECTION ───
                                                  if (hasFooter) ...[
                                                    if (pageItems.isNotEmpty) const SizedBox(height: 18),
                                                    if (order.isSlabOrder)
                                                      _buildSlabSummaryFooter(order)
                                                    else
                                                      Container(
                                                        padding: const EdgeInsets.only(top: 12),
                                                        decoration: const BoxDecoration(
                                                          border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
                                                        ),
                                                        child: Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            const Expanded(
                                                              child: Padding(
                                                                padding: EdgeInsets.only(right: 24),
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      'TERMS & CONDITIONS',
                                                                      style: TextStyle(
                                                                        fontSize: 8,
                                                                        fontWeight: FontWeight.bold,
                                                                        letterSpacing: 1.2,
                                                                        color: Color(0xFFA3A3A3),
                                                                      ),
                                                                    ),
                                                                    SizedBox(height: 4),
                                                                    Text(
                                                                      '1. ใบเสนอราคานี้มีผล 30 วันนับจากวันที่ออกเอกสาร\n2. กรุณาตรวจสอบรายการสินค้าให้ถูกต้องก่อนยืนยันการสั่งซื้อ\n3. สินค้าซื้อแล้วไม่รับเปลี่ยนหรือคืน ยกเว้นกรณีชำรุดจากการผลิต',
                                                                      style: TextStyle(fontSize: 7.5, color: Color(0xFF737373), height: 1.45),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 224,
                                                              child: Column(
                                                                children: [
                                                                  _totalRow('Subtotal (Before VAT)', _money2(order.totalAmount / 1.07)),
                                                                  if (order.discountAmount > 0) ...[
                                                                    const SizedBox(height: 3),
                                                                    _totalRow('Special Discount', '-${_money2(order.discountAmount)}', isDiscount: true),
                                                                  ],
                                                                  const SizedBox(height: 3),
                                                                  _totalRow('VAT (7%)', _money2(order.totalAmount - (order.totalAmount / 1.07))),
                                                                  const SizedBox(height: 6),
                                                                  Container(
                                                                    padding: const EdgeInsets.only(top: 6),
                                                                    decoration: const BoxDecoration(
                                                                      border: Border(top: BorderSide(color: Color(0xFF171717), width: 1.2)),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                      children: [
                                                                        const Text(
                                                                          'TOTAL (THB)',
                                                                          style: TextStyle(
                                                                            fontSize: 10,
                                                                            fontWeight: FontWeight.bold,
                                                                            letterSpacing: 1.5,
                                                                            color: Color(0xFF171717),
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          _money2(order.totalAmount),
                                                                          style: const TextStyle(
                                                                            fontSize: 16,
                                                                            fontWeight: FontWeight.bold,
                                                                            color: Color(0xFF171717),
                                                                          ),
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
                                                    const SizedBox(height: 18),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            children: [
                                                              const SizedBox(height: 18),
                                                              Container(height: 1, color: const Color(0xFFD4D4D4)),
                                                              const SizedBox(height: 4),
                                                              const Text(
                                                                'AUTHORIZED SIGNATURE',
                                                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: Color(0xFF171717)),
                                                              ),
                                                              const SizedBox(height: 2),
                                                              const Text('Terra Home Studio', style: TextStyle(fontSize: 7, color: Color(0xFFA3A3A3))),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 48),
                                                        Expanded(
                                                          child: Column(
                                                            children: [
                                                              const SizedBox(height: 18),
                                                              Container(height: 1, color: const Color(0xFFD4D4D4)),
                                                              const SizedBox(height: 4),
                                                              const Text(
                                                                'ACCEPTED BY',
                                                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: Color(0xFF171717)),
                                                              ),
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                order.shippingName.isNotEmpty ? order.shippingName : 'Customer / Client',
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFF525252)),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    const Center(
                                                      child: Text(
                                                        'THANK YOU FOR YOUR BUSINESS',
                                                        style: TextStyle(fontSize: 7, letterSpacing: 2.0, color: Color(0xFFD4D4D4)),
                                                      ),
                                                    ),
                                                  ],

                                                  const Spacer(),
                                                  // Subtle bottom page number indicator
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Text(
                                                      'Page ${pageIndex + 1} of $totalPages',
                                                      style: const TextStyle(
                                                        fontSize: 7.5,
                                                        color: Color(0xFFA3A3A3),
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ── 3. MODAL FOOTER ACTION BAR ──
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 22,
                            vertical: isMobile ? 10 : 12,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: _stone200)),
                          ),
                          child: isMobile
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            SnackBar(
                                              content: Text('บันทึกใบเสนอราคา ${order.orderCode} (A4) เรียบร้อยแล้ว'),
                                              backgroundColor: _emerald,
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.download_rounded, size: 16),
                                        label: const Text(
                                          'บันทึก',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _stone800,
                                          side: const BorderSide(color: _stone300),
                                          padding: const EdgeInsets.symmetric(vertical: 11),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            SnackBar(
                                              content: Text('กำลังเปิดเมนูแชร์เอกสาร ${order.orderCode}...'),
                                              backgroundColor: _blue,
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.ios_share_rounded, size: 15),
                                        label: const Text(
                                          'แชร์',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 11),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            const SnackBar(
                                              content: Text('ส่งคำสั่งพิมพ์เอกสารไปยังเครื่องพิมพ์เรียบร้อยแล้ว'),
                                              backgroundColor: _emerald,
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.print_outlined, size: 16),
                                        label: const Text(
                                          'พิมพ์',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF171717),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 11),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    const Icon(Icons.zoom_in_rounded, size: 16, color: _stone400),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'สามารถซูมดูรายละเอียดเอกสาร หรือเลื่อนดูหน้าถัดไปได้',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: _stone500),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          SnackBar(
                                            content: Text('บันทึกใบเสนอราคา ${order.orderCode} (A4) เรียบร้อยแล้ว'),
                                            backgroundColor: _emerald,
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.download_rounded, size: 16),
                                      label: const Text(
                                        'บันทึก PDF',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _stone800,
                                        side: const BorderSide(color: _stone300),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FilledButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          SnackBar(
                                            content: Text('กำลังเปิดเมนูแชร์เอกสาร ${order.orderCode}...'),
                                            backgroundColor: _blue,
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.ios_share_rounded, size: 16),
                                      label: const Text(
                                        'แชร์เอกสาร',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 40),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FilledButton.icon(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          const SnackBar(
                                            content: Text('ส่งคำสั่งพิมพ์เอกสารไปยังเครื่องพิมพ์เรียบร้อยแล้ว'),
                                            backgroundColor: _emerald,
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.print_outlined, size: 16),
                                      label: const Text(
                                        'พิมพ์เอกสาร',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF171717),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(0, 40),
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  TableRow _docMetaTableRow(String label, String value, {bool isLast = false}) {
    final bottomPad = isLast ? 0.0 : 4.0;
    return TableRow(
      children: [
        Padding(
          padding: EdgeInsets.only(right: 12, bottom: bottomPad),
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Color(0xFFA3A3A3),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: bottomPad),
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF171717),
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: isDiscount ? const Color(0xFFDC2626) : const Color(0xFF737373),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: isDiscount ? const Color(0xFFDC2626) : const Color(0xFF525252),
          ),
        ),
      ],
    );
  }

  Widget _buildSlabSummaryFooter(DispatchOrder order) {
    final preVat = order.totalAmount / 1.07;
    final vat = order.totalAmount - preVat;
    final goodsTotal = order.totalAmount;
    final woodFee = order.woodPermitFee;
    final grandTotal = order.grandTotalWithSlab;
    final deposit = order.depositAmount;
    final remaining = order.remainingBalance;

    Widget cell(String label, String value, {bool isYellow = false, Widget? badge}) {
      return Container(
        decoration: BoxDecoration(
          color: isYellow ? const Color(0xFFFDE047) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isYellow ? 8.5 : 8,
                    fontWeight: isYellow ? FontWeight.bold : FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  badge,
                ],
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: isYellow ? 9.5 : 8.5,
                fontWeight: isYellow ? FontWeight.w900 : FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Terms & Conditions
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'TERMS & CONDITIONS',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFFA3A3A3),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '1. ใบเสนอราคานี้มีผล 30 วันนับจากวันที่ออกเอกสาร\n2. กรุณาตรวจสอบรายการสินค้าให้ถูกต้องก่อนยืนยันการสั่งซื้อ\n3. สินค้าซื้อแล้วไม่รับเปลี่ยนหรือคืน ยกเว้นกรณีชำรุดจากการผลิต\n4. สินค้าแผ่นไม้เป็นสินค้าเฉพาะตัว (One of a kind) ยืนยันการจองสต็อกเมื่อชำระมัดจำ 50% เรียบร้อยแล้ว',
                  style: TextStyle(fontSize: 7.5, color: Color(0xFF737373), height: 1.45),
                ),
              ],
            ),
          ),
        ),

        // Right: Slab Summary Table + Bank Card
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF94A3B8), width: 0.8),
                ),
                child: Column(
                  children: [
                    cell('Total (ราคารวมก่อน VAT)', _money2(preVat)),
                    Container(height: 6, color: const Color(0xFFB4A5D9).withValues(alpha: 0.5)),
                    cell('Total (ราคารวมก่อน VAT)', _money2(preVat)),
                    cell('ภาษีมูลค่าเพิ่ม VAT 7%', _money2(vat)),
                    cell('ราคา(สินค้า)ทั้งหมด รวมภาษี', _money2(goodsTotal)),
                    cell('ค่าขนส่งสินค้า', '-'),
                    cell('ค่าใบกำกับไม้', _money2(woodFee)),
                    Container(
                      height: 5,
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 0.8)),
                      ),
                    ),
                    cell('Grand Total', _money2(grandTotal), isYellow: true),
                    cell(
                      'ยอดเปอร์เซ็นการมัดจำ',
                      _money2(deposit),
                      badge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB4A5D9),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '${order.depositPercent.toInt()}%',
                          style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF2E1065)),
                        ),
                      ),
                    ),
                    cell('ยอดส่วนต่างที่เหลือ', _money2(remaining)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFB4A5D9).withValues(alpha: 0.55),
                  border: Border.all(color: const Color(0xFF9884C6), width: 0.8),
                ),
                child: Column(
                  children: const [
                    Text(
                      'กรุณาโอนเข้าบัญชี:',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF2E1065)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'ชื่อบัญชี : ทีพีเอส การ์เด้น เฟอร์นิเจอร์ จำกัด',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2E1065)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'ธนาคารกสิกรไทย  สาขา บางโพ',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF2E1065)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'เลขที่บัญชี : 033 1 08813 7 (กระแสรายวัน)',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2E1065)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _shortenBranchName(String name) {
    var s = name.trim();
    s = s.replaceFirst('Showroom Terra ', '');
    s = s.replaceFirst('Showroom ', '');
    s = s.replaceFirst('Terra Home ', '');
    s = s.replaceFirst('สาขา ', '');
    return s.isEmpty ? name : s;
  }

  Widget _buildItemRow(DispatchOrderItem item, {String orderStatus = 'PENDING'}) {
    final isOutOfStock = orderStatus == 'PENDING' && item.availableStock < item.qty;
    final hasBranch = item.fulfillBranchName.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isOutOfStock ? const Color(0x66FEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOutOfStock ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isOutOfStock ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isOutOfStock ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
                    ),
                  ),
                  child: item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty
                      ? Opacity(
                          opacity: isOutOfStock ? 0.5 : 1.0,
                          child: Image.network(
                            item.product.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Text(
                                'No Img',
                                style: TextStyle(fontSize: 8.5, color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'No Img',
                            style: TextStyle(fontSize: 8.5, color: Color(0xFFCBD5E1)),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(right: hasBranch ? 14 : 0),
                        child: Text(
                          item.product.name.isEmpty ? 'รหัส #${item.product.id}' : item.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                            decoration: isOutOfStock ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'SKU: ${item.product.sku}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (isOutOfStock) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    const WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding: EdgeInsets.only(right: 3),
                                        child: Icon(
                                          Icons.warning_amber_rounded,
                                          size: 10,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'โดนซื้อตัดหน้า (เหลือ ${item.availableStock})',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasBranch) const SizedBox(height: 9),
                    Text(
                      'x${item.qty}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${_formatMoney(item.priceAtSale)} ฿',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // แท็กคลังสินค้าติดมุมขวาบนแบบไมโครจิ๋ว (Ultra-Compact Micro Corner Badge)
          if (hasBranch)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(5),
                  ),
                  border: Border(
                    left: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 8,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 2.5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: Text(
                        _shortenBranchName(item.fulfillBranchName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorWidget() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 48),
          const SizedBox(height: 12),
          Text(_errorMessage ?? 'เกิดข้อผิดพลาด', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadData,
            style: FilledButton.styleFrom(backgroundColor: _ink),
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    ),
  );

  Widget _emptyWidget() => ListView(
    children: const [
      SizedBox(height: 80),
      Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFCBD5E1)),
      SizedBox(height: 12),
      Center(
        child: Text(
          'ไม่มีรายการบิลในหมวดหมู่นี้',
          style: TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    ],
  );

  String _formatThaiShortDate(String isoString) {
    if (isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final buddhistYear = dt.year + 543;
      return '${dt.day}/${dt.month}/$buddhistYear';
    } catch (_) {
      return isoString;
    }
  }

  String _formatMoney(double value) {
    final fixed = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }
}
