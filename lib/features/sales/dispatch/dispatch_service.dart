import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sales_config.dart';
import '../sales_auth_adapter.dart';

class DispatchProduct {
  const DispatchProduct({
    required this.id,
    required this.name,
    required this.sku,
    this.categoryId,
    this.imageUrl,
    required this.price,
    this.productSup,
    this.material,
    this.sizeStr,
    this.isWoodSlab = false,
  });

  final int id;
  final String name;
  final String sku;
  final String? categoryId;
  final String? imageUrl;
  final double price;
  final String? productSup;
  final String? material;
  final String? sizeStr;
  final bool isWoodSlab;

  factory DispatchProduct.fromJson(Map<String, dynamic> json) {
    final sku = (json['sku'] as String? ?? '').toUpperCase();
    final name = (json['name'] as String? ?? '').toLowerCase();
    final sup = (json['product_sup'] as String? ?? '').toLowerCase();
    final cat = (json['category_id'] as String? ?? '').toUpperCase();
    final mat = (json['material'] as String? ?? '').toLowerCase();
    final serverIsWoodSlab = json['is_wood_slab'] as bool?;

    final clientDetectedSlab = cat == 'SLABS' ||
        cat == 'WOODSLAB' ||
        cat == 'SLAB' ||
        sku.startsWith('ZLB-') ||
        sku.startsWith('WOOD-') ||
        sku.startsWith('LEG-') ||
        sku.startsWith('SLB-') ||
        sku.startsWith('SLAB-') ||
        sup.contains('slab') ||
        sup.contains('แผ่นไม้') ||
        name.contains('slab') ||
        name.contains('สแลป') ||
        name.contains('แผ่นไม้') ||
        name.contains('stand') ||
        name.contains('ขาโต๊ะ') ||
        name.contains('ขาตั้ง') ||
        mat.contains('wood') ||
        mat.contains('ไม้');

    final detectedSlab = (serverIsWoodSlab == true) || clientDetectedSlab;

    return DispatchProduct(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      categoryId: json['category_id'] as String?,
      imageUrl: json['image_url'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      productSup: json['product_sup'] as String?,
      material: json['material'] as String?,
      sizeStr: json['size_str'] as String?,
      isWoodSlab: detectedSlab,
    );
  }
}

class DispatchOrderItem {
  const DispatchOrderItem({
    required this.id,
    required this.qty,
    required this.itemStatus,
    required this.priceAtSale,
    required this.fulfillBranchId,
    required this.fulfillBranchName,
    required this.isCrossBranch,
    required this.availableStock,
    required this.product,
  });

  final int id;
  final int qty;
  final String itemStatus;
  final double priceAtSale;
  final int fulfillBranchId;
  final String fulfillBranchName;
  final bool isCrossBranch;
  final int availableStock;
  final DispatchProduct product;

  double get total => priceAtSale * qty;

  bool get isWoodSlab => product.isWoodSlab;
  bool get isOutOfStock => availableStock < qty;
  bool get isBlockedSlab => false;
  bool get isPreOrder => isOutOfStock;

  factory DispatchOrderItem.fromJson(Map<String, dynamic> json) => DispatchOrderItem(
    id: (json['id'] as num?)?.toInt() ?? 0,
    qty: (json['qty'] as num?)?.toInt() ?? 0,
    itemStatus: json['item_status'] as String? ?? 'PENDING_SHIPMENT',
    priceAtSale: (json['price_at_sale'] as num?)?.toDouble() ?? 0.0,
    fulfillBranchId: (json['fulfill_branch_id'] as num?)?.toInt() ?? 0,
    fulfillBranchName: json['fulfill_branch_name'] as String? ?? 'สาขา',
    isCrossBranch: json['is_cross_branch'] as bool? ?? false,
    availableStock: (json['available_stock'] as num?)?.toInt() ?? 0,
    product: DispatchProduct.fromJson(
      (json['product'] as Map<String, dynamic>?) ?? const {},
    ),
  );
}

class DispatchOrder {
  const DispatchOrder({
    required this.id,
    required this.orderCode,
    required this.createdAt,
    required this.shippingName,
    required this.shippingPhone,
    required this.shippingAddress,
    this.latitude,
    this.longitude,
    required this.status,
    required this.totalAmount,
    required this.discountAmount,
    required this.isTakeaway,
    required this.items,
  });

  final int id;
  final String orderCode;
  final String createdAt;
  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final double? latitude;
  final double? longitude;
  final String status;
  final double totalAmount;
  final double discountAmount;
  final bool isTakeaway;
  final List<DispatchOrderItem> items;

  bool get hasCoordinates => latitude != null && longitude != null;
  int get totalItemQty => items.fold(0, (sum, it) => sum + it.qty);

  bool get hasBlockedWoodSlab =>
      status == 'PENDING' && items.any((it) => it.isBlockedSlab);
  bool get hasPreOrderItems =>
      status == 'PENDING' && items.any((it) => it.isPreOrder);
  bool get isAnyItemOutOfStock =>
      status == 'PENDING' && items.any((it) => it.isOutOfStock);

  bool get isSlabOrder => items.any((it) => it.isWoodSlab);

  bool get isZenslabOrder => isSlabOrder || items.any((it) {
    final sku = it.product.sku.toUpperCase();
    final name = it.product.name.toLowerCase();
    final sup = (it.product.productSup ?? '').toLowerCase();
    final mat = (it.product.material ?? '').toLowerCase();
    final cat = (it.product.categoryId ?? '').toUpperCase();
    return sku.startsWith('WOOD') ||
        sku.startsWith('EMBER') ||
        sku.startsWith('LEG-') ||
        sku.startsWith('SLB-') ||
        sku.startsWith('SLAB-') ||
        cat == 'SLABS' ||
        cat == 'WOODSLAB' ||
        sup.contains('slab') ||
        sup.contains('wood') ||
        sup.contains('เฟอร์นิเจอร์') ||
        name.contains('slab') ||
        name.contains('wood') ||
        name.contains('แผ่นไม้') ||
        name.contains('ไม้') ||
        name.contains('stand') ||
        mat.contains('wood') ||
        mat.contains('ไม้');
  });

  bool get requiresSlabTemplate => isSlabOrder || isZenslabOrder;

  double get woodPermitFee => requiresSlabTemplate ? 5000.0 : 0.0;
  double get depositPercent => requiresSlabTemplate ? 50.0 : 100.0;
  double get grandTotalWithSlab => requiresSlabTemplate ? (totalAmount + woodPermitFee) : totalAmount;
  double get depositAmount => requiresSlabTemplate ? (grandTotalWithSlab * (depositPercent / 100)) : grandTotalWithSlab;
  double get remainingBalance => requiresSlabTemplate ? (grandTotalWithSlab - depositAmount) : 0.0;

  factory DispatchOrder.fromJson(Map<String, dynamic> json) => DispatchOrder(
    id: (json['id'] as num?)?.toInt() ?? 0,
    orderCode: json['order_code'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    shippingName: json['shipping_name'] as String? ?? '',
    shippingPhone: json['shipping_phone'] as String? ?? '',
    shippingAddress: json['shipping_address'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    status: json['status'] as String? ?? 'PENDING',
    totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
    isTakeaway: json['is_takeaway'] as bool? ?? false,
    items: ((json['items'] as List<dynamic>?) ?? const [])
        .map((e) => DispatchOrderItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );
}

class DispatchCounts {
  const DispatchCounts({
    this.overview = 0,
    this.myTasks = 0,
    this.followUps = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.pendingApproval = 0,
  });

  final int overview;
  final int myTasks;
  final int followUps;
  final int completed;
  final int cancelled;
  final int pendingApproval;

  factory DispatchCounts.fromJson(Map<String, dynamic> json) => DispatchCounts(
    overview: (json['overview'] as num?)?.toInt() ?? 0,
    myTasks: (json['myTasks'] as num?)?.toInt() ?? 0,
    followUps: (json['followUps'] as num?)?.toInt() ?? 0,
    completed: (json['completed'] as num?)?.toInt() ?? 0,
    cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
    pendingApproval: (json['pendingApproval'] as num?)?.toInt() ?? 0,
  );
}

class GroupedDispatches {
  const GroupedDispatches({
    required this.overviewTasks,
    required this.myTasks,
    required this.followUpTasks,
    required this.completedTasks,
    required this.cancelledTasks,
    required this.pendingApprovalTasks,
    required this.counts,
  });

  final List<DispatchOrder> overviewTasks;
  final List<DispatchOrder> myTasks;
  final List<DispatchOrder> followUpTasks;
  final List<DispatchOrder> completedTasks;
  final List<DispatchOrder> cancelledTasks;
  final List<DispatchOrder> pendingApprovalTasks;
  final DispatchCounts counts;

  factory GroupedDispatches.fromJson(Map<String, dynamic> json) {
    List<DispatchOrder> parseList(String key) =>
        ((json[key] as List<dynamic>?) ?? const [])
            .map((e) => DispatchOrder.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);

    return GroupedDispatches(
      overviewTasks: parseList('overviewTasks'),
      myTasks: parseList('myTasks'),
      followUpTasks: parseList('followUpTasks'),
      completedTasks: parseList('completedTasks'),
      cancelledTasks: parseList('cancelledTasks'),
      pendingApprovalTasks: parseList('pendingApprovalTasks'),
      counts: DispatchCounts.fromJson(
        (json['counts'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

class DispatchService {
  DispatchService(this._authService, {http.Client? client})
      : _client = client ?? http.Client();

  final AuthService _authService;
  final http.Client _client;

  Future<GroupedDispatches> loadDispatches() async {
    final response = await _client.get(
      SalesConfig.endpoint('dispatches'),
      headers: await _headers(),
    );
    final data = _readResponse(response);
    final innerData = (data['data'] as Map<String, dynamic>?) ?? const {};
    return GroupedDispatches.fromJson(innerData);
  }

  Future<void> approveAndCutStock({
    required int orderId,
    String? customOrderCode,
  }) async {
    final response = await _client.post(
      SalesConfig.endpoint('dispatches/approve'),
      headers: await _headers(),
      body: jsonEncode({
        'order_id': orderId,
        'custom_order_code': customOrderCode?.trim().isNotEmpty == true
            ? customOrderCode!.trim()
            : null,
      }),
    );
    _readResponse(response);
  }

  Future<void> markShipped({
    required int orderId,
    List<int>? itemIds,
  }) async {
    final response = await _client.post(
      SalesConfig.endpoint('dispatches/ship'),
      headers: await _headers(),
      body: jsonEncode({
        'order_id': orderId,
        'item_ids': itemIds,
      }),
    );
    _readResponse(response);
  }

  Future<void> cancelOrder({
    required int orderId,
    String? reason,
  }) async {
    final response = await _client.post(
      SalesConfig.endpoint('dispatches/cancel'),
      headers: await _headers(),
      body: jsonEncode({
        'order_id': orderId,
        'reason': reason?.trim().isNotEmpty == true ? reason!.trim() : null,
      }),
    );
    _readResponse(response);
  }

  Future<void> updateCustomer({
    required int orderId,
    String? shippingName,
    String? shippingPhone,
    String? shippingAddress,
  }) async {
    final response = await _client.post(
      SalesConfig.endpoint('dispatches/update-customer'),
      headers: await _headers(),
      body: jsonEncode({
        'order_id': orderId,
        'shipping_name': shippingName,
        'shipping_phone': shippingPhone,
        'shipping_address': shippingAddress,
      }),
    );
    _readResponse(response);
  }

  Future<Map<String, String>> _headers() async {
    final token = await _authService.accessToken();
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'ไม่พบเซสชัน กรุณาเข้าสู่ระบบใหม่',
        statusCode: 401,
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _readResponse(http.Response response) {
    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      throw const AuthApiException('เซิร์ฟเวอร์ตอบกลับในรูปแบบที่ไม่ถูกต้อง');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] != true) {
      final msg = (data['message'] as String?) ??
          (data['error'] as String?) ??
          (response.statusCode == 401
              ? 'กรุณาล็อกอินใหม่ (401)'
              : 'เกิดข้อผิดพลาดในการโหลดข้อมูล (${response.statusCode})');
      throw AuthApiException(
        msg,
        statusCode: response.statusCode,
      );
    }
    return data;
  }
}
