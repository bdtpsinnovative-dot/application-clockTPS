import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sales_config.dart';
import '../sales_auth_adapter.dart';

class ProductBranchStock {
  const ProductBranchStock({
    required this.branchId,
    required this.branchName,
    required this.qty,
    required this.isOwnBranch,
  });

  final int branchId;
  final String branchName;
  final int qty;
  final bool isOwnBranch;

  factory ProductBranchStock.fromJson(Map<String, dynamic> json) =>
      ProductBranchStock(
        branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
        branchName: json['branch_name'] as String? ?? '',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
        isOwnBranch: json['is_own_branch'] as bool? ?? false,
      );
}

class BranchInfo {
  const BranchInfo({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory BranchInfo.fromJson(Map<String, dynamic> json) => BranchInfo(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['branch_name'] as String? ?? '',
  );
}

class PosProduct {
  const PosProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    this.originalPrice,
    this.discountLabel,
    this.discountId,
    this.discountName,
    required this.imageUrl,
    required this.category,
    this.brand = 'ทั่วไป',
    required this.availableQty,
    this.ownBranchQty = 0,
    this.otherBranchQty = 0,
    this.totalStock = 0,
    this.isFurniture = false,
    this.isSlab = false,
    this.isExternal = false,
    this.stocks = const [],
  });

  final int id;
  final String name;
  final String sku;
  final double price;
  final double? originalPrice;
  final String? discountLabel;
  final int? discountId;
  final String? discountName;
  final String? imageUrl;
  final String category;
  final String brand;
  final int availableQty;
  final int ownBranchQty;
  final int otherBranchQty;
  final int totalStock;
  final bool isFurniture;
  final bool isSlab;
  final bool isExternal;
  final List<ProductBranchStock> stocks;

  PosProduct copyWithPrice(double newPrice) {
    return PosProduct(
      id: id,
      name: name,
      sku: sku,
      price: newPrice,
      originalPrice: newPrice,
      discountLabel: null,
      discountId: null,
      discountName: null,
      imageUrl: imageUrl,
      category: category,
      brand: brand,
      availableQty: availableQty,
      ownBranchQty: ownBranchQty,
      otherBranchQty: otherBranchQty,
      totalStock: totalStock,
      isFurniture: isFurniture,
      isSlab: isSlab,
      isExternal: isExternal,
      stocks: stocks,
    );
  }

  bool get hasDiscount =>
      discountLabel != null &&
      discountLabel!.isNotEmpty &&
      effectiveOriginalPrice > price;

  double get effectiveOriginalPrice => originalPrice ?? price;

  bool get isAvailableInOwnBranch => ownBranchQty > 0;
  bool get isAvailableCrossBranch => otherBranchQty > 0;
  bool get hasAnyStock => totalStock > 0;

  List<ProductBranchStock> get crossBranchStocks =>
      stocks.where((s) => !s.isOwnBranch && s.qty > 0).toList(growable: false);

  factory PosProduct.fromJson(Map<String, dynamic> json) {
    final rawStocks = json['stocks'] as List<dynamic>? ?? const [];
    final parsedStocks = rawStocks
        .whereType<Map<String, dynamic>>()
        .map(ProductBranchStock.fromJson)
        .toList(growable: false);

    final ownQty = (json['own_branch_qty'] as num?)?.toInt() ??
        (json['available_qty'] as num?)?.toInt() ??
        0;
    final otherQty = (json['other_branch_qty'] as num?)?.toInt() ?? 0;
    final total = (json['total_stock'] as num?)?.toInt() ?? (ownQty + otherQty);

    final rawCategory = (json['product_sup'] as String? ?? '').trim();
    final cleanedCategory = rawCategory
        .replaceAll(RegExp(r'\s*\([^)]*à[¸¹][^)]*\)'), '')
        .trim();

    final rawName = json['name'] as String? ?? '-';
    final cleanedName = rawName.replaceFirst(RegExp(r'^Furniture\s*-\s*', caseSensitive: false), '').trim();

    final skuStr = (json['sku'] as String? ?? '').toUpperCase();
    final isFurn = (json['is_furniture'] as bool? ?? false) || skuStr.startsWith('EMBER');
    final isSlab = (json['is_slab'] as bool? ?? false) || skuStr.startsWith('WOOD');

    final rawBrand = (json['brand'] as String? ?? '').trim();
    final brand = rawBrand.isNotEmpty
        ? rawBrand
        : (isFurn ? 'Ember & Ash' : (isSlab ? 'ZENSLABS' : 'ทั่วไป'));

    return PosProduct(
      id: (json['id'] as num).toInt(),
      name: cleanedName.isNotEmpty && cleanedName != '-' ? cleanedName : rawName,
      sku: json['sku'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      discountLabel: json['discount_label'] as String?,
      discountId: (json['discount_id'] as num?)?.toInt(),
      discountName: json['discount_name'] as String?,
      imageUrl: json['image_url'] as String?,
      category: cleanedCategory.isNotEmpty ? cleanedCategory : 'อื่น ๆ',
      brand: brand,
      availableQty: ownQty,
      ownBranchQty: ownQty,
      otherBranchQty: otherQty,
      totalStock: total,
      isFurniture: isFurn,
      isSlab: isSlab,
      isExternal: json['is_external'] as bool? ?? false,
      stocks: parsedStocks,
    );
  }
}

class PosCatalogResult {
  const PosCatalogResult({
    required this.products,
    required this.categories,
    this.brands = const [],
    required this.branches,
    required this.currentBranchId,
    required this.currentBranchName,
  });

  final List<PosProduct> products;
  final List<String> categories;
  final List<String> brands;
  final List<BranchInfo> branches;
  final int currentBranchId;
  final String currentBranchName;
}

class PosCoupon {
  const PosCoupon({
    required this.code,
    required this.title,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    this.source = '',
  });

  final String code;
  final String title;
  final String discountType;
  final double discountValue;
  final double discountAmount;
  final String source;

  factory PosCoupon.fromJson(Map<String, dynamic> json) => PosCoupon(
    code: json['code'] as String? ?? '',
    title: json['title'] as String? ?? '',
    discountType: json['discount_type'] as String? ?? '',
    discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
    discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
    source: json['source'] as String? ?? '',
  );
}

class CheckoutResult {
  const CheckoutResult({
    required this.orderCode,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.vatAmount,
    required this.status,
    required this.saleMode,
    required this.paymentMethod,
  });

  final String orderCode;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final double vatAmount;
  final String status;
  final String saleMode;
  final String paymentMethod;

  factory CheckoutResult.fromJson(Map<String, dynamic> json) => CheckoutResult(
    orderCode: json['order_code'] as String? ?? '',
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
    totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
    vatAmount: (json['vat_amount'] as num?)?.toDouble() ?? 0,
    status: json['status'] as String? ?? 'PENDING',
    saleMode: json['sale_mode'] as String? ?? 'TAKE_AWAY',
    paymentMethod: json['payment_method'] as String? ?? 'CASH',
  );
}

class CartLineItem {
  CartLineItem({
    required this.product,
    required this.quantity,
    required this.fulfillBranchId,
    required this.fulfillBranchName,
    required this.isCrossBranch,
  });

  final PosProduct product;
  int quantity;
  int fulfillBranchId;
  String fulfillBranchName;
  bool isCrossBranch;

  String get cartItemId => '${product.id}_$fulfillBranchId';
}

class QuoteCustomer {
  const QuoteCustomer({
    this.name = '',
    this.phone = '',
    this.address = '',
    this.companyName = '',
    this.taxId = '',
    this.customOrderCode = '',
    this.companyNameEn = '',
    this.companyAddress = '',
  });

  final String name;
  final String phone;
  final String address;
  final String companyName;
  final String taxId;
  final String customOrderCode;
  final String companyNameEn;
  final String companyAddress;
}

class QuoteResult {
  const QuoteResult(this.orderCode);

  final String orderCode;
}

class PosService {
  PosService(this._authService, {http.Client? client})
    : _client = client ?? http.Client();

  final AuthService _authService;
  final http.Client _client;

  Future<PosCatalogResult> loadCatalog() async {
    final uri = SalesConfig.endpoint('products');
    final headers = await _headers();
    final response = await _client.get(
      uri,
      headers: headers,
    );
    final data = _readResponse(response);
    final products = (data['products'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PosProduct.fromJson)
        .toList(growable: false);
    final categories = (data['categories'] as List<dynamic>? ?? const [])
        .map((c) => c.toString())
        .toList(growable: false);
    final brands = (data['brands'] as List<dynamic>? ?? const [])
        .map((b) => b.toString().trim())
        .where((b) => b.isNotEmpty)
        .toList(growable: false);
    final branches = (data['branches'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BranchInfo.fromJson)
        .toList(growable: false);

    return PosCatalogResult(
      products: products,
      categories: categories,
      brands: brands,
      branches: branches,
      currentBranchId: (data['branch_id'] as num?)?.toInt() ?? 1,
      currentBranchName: data['branch_name'] as String? ?? 'สาขาเรา',
    );
  }

  Future<List<PosProduct>> loadProducts() async {
    final result = await loadCatalog();
    return result.products;
  }

  Future<PosCatalogResult> loadFurnitureCatalog() async {
    final uri = SalesConfig.endpoint('furniture');
    final headers = await _headers();
    final response = await _client.get(
      uri,
      headers: headers,
    );
    final data = _readResponse(response);
    final products = (data['products'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PosProduct.fromJson)
        .toList(growable: false);
    final categories = (data['categories'] as List<dynamic>? ?? const [])
        .map((c) => c.toString())
        .toList(growable: false);
    final brands = (data['brands'] as List<dynamic>? ?? const [])
        .map((b) => b.toString().trim())
        .where((b) => b.isNotEmpty)
        .toList(growable: false);
    final branches = (data['branches'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BranchInfo.fromJson)
        .toList(growable: false);

    return PosCatalogResult(
      products: products,
      categories: categories,
      brands: brands.isNotEmpty ? brands : const ['Ember & Ash'],
      branches: branches,
      currentBranchId: (data['branch_id'] as num?)?.toInt() ?? 1,
      currentBranchName: data['branch_name'] as String? ?? 'สาขาเรา',
    );
  }

  Future<PosCatalogResult> loadSlabsCatalog() async {
    final uri = SalesConfig.endpoint('slabs');
    final headers = await _headers();
    final response = await _client.get(
      uri,
      headers: headers,
    );
    final data = _readResponse(response);
    final products = (data['products'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PosProduct.fromJson)
        .toList(growable: false);
    final categories = (data['categories'] as List<dynamic>? ?? const [])
        .map((c) => c.toString())
        .toList(growable: false);
    final brands = (data['brands'] as List<dynamic>? ?? const [])
        .map((b) => b.toString().trim())
        .where((b) => b.isNotEmpty)
        .toList(growable: false);
    final branches = (data['branches'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BranchInfo.fromJson)
        .toList(growable: false);

    return PosCatalogResult(
      products: products,
      categories: categories,
      brands: brands.isNotEmpty ? brands : const ['ZENSLABS'],
      branches: branches,
      currentBranchId: (data['branch_id'] as num?)?.toInt() ?? 1,
      currentBranchName: data['branch_name'] as String? ?? 'สาขาเรา',
    );
  }

  Future<PosProduct> createCustomProduct({
    required String name,
    required double price,
    String? sku,
    String? categoryLabel,
    String? note,
    int? branchId,
  }) async {
    final response = await _client.post(
      SalesConfig.endpoint('custom-product'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name.trim(),
        'price': price,
        'sku': sku?.trim().isNotEmpty == true ? sku!.trim() : '',
        'category_label': categoryLabel?.trim() ?? 'เฟอร์นิเจอร์สั่งทำ',
        'note': note?.trim() ?? '',
        'branch_id': branchId ?? 1,
      }),
    );
    final data = _readResponse(response);
    final productJson = data['product'] as Map<String, dynamic>?;
    if (productJson == null) {
      throw const AuthApiException('ไม่สามารถสร้างสินค้านอกระบบได้');
    }
    return PosProduct.fromJson(productJson);
  }

  Future<PosCoupon> validateCoupon(String code, double subtotal) async {
    final response = await _client.post(
      SalesConfig.endpoint('coupons/validate'),
      headers: await _headers(),
      body: jsonEncode({'code': code.trim(), 'subtotal': subtotal}),
    );
    final data = _readResponse(response);
    final couponData = data['coupon'] as Map<String, dynamic>?;
    if (couponData == null) {
      throw const AuthApiException('ข้อมูลคูปองไม่ถูกต้อง');
    }
    return PosCoupon.fromJson(couponData);
  }

  Future<CheckoutResult> checkout({
    required QuoteCustomer customer,
    required List<CartLineItem> cartItems,
    String saleMode = 'TAKE_AWAY',
    String paymentMethod = 'CASH',
    String? couponCode,
    double? specialDiscountBaht,
    double? specialDiscountPercent,
  }) async {
    final response = await _client.post(
      SalesConfig.endpoint('checkout'),
      headers: await _headers(),
      body: jsonEncode({
        'customer_name': customer.name.trim().isNotEmpty ? customer.name.trim() : null,
        'customer_phone': customer.phone.trim().isNotEmpty ? customer.phone.trim() : null,
        'customer_address': customer.address.trim().isNotEmpty ? customer.address.trim() : null,
        'company_name': customer.companyName.trim().isNotEmpty ? customer.companyName.trim() : null,
        'company_name_en': customer.companyNameEn.trim().isNotEmpty ? customer.companyNameEn.trim() : null,
        'company_address': customer.companyAddress.trim().isNotEmpty ? customer.companyAddress.trim() : null,
        'tax_id': customer.taxId.trim().isNotEmpty ? customer.taxId.trim() : null,
        'custom_order_code': customer.customOrderCode.trim().isNotEmpty ? customer.customOrderCode.trim() : null,
        'sale_mode': saleMode,
        'payment_method': paymentMethod,
        'coupon_code': couponCode?.trim().isNotEmpty == true ? couponCode!.trim() : null,
        'special_discount_baht': specialDiscountBaht ?? 0,
        'special_discount_percent': specialDiscountPercent ?? 0,
        'items': cartItems
            .map(
              (item) => {
                'product_id': item.product.id,
                'quantity': item.quantity,
                'fulfill_branch_id': item.fulfillBranchId,
              },
            )
            .toList(growable: false),
      }),
    );
    final data = _readResponse(response);
    return CheckoutResult.fromJson(data);
  }

  Future<QuoteResult> createQuote({
    required QuoteCustomer customer,
    required List<CartLineItem> cartItems,
  }) async {
    final response = await _client.post(
      SalesConfig.endpoint('quotes'),
      headers: await _headers(),
      body: jsonEncode({
        'customer_name': customer.name,
        'customer_phone': customer.phone,
        'customer_address': customer.address,
        'company_name': customer.companyName,
        'company_name_en': customer.companyNameEn,
        'company_address': customer.companyAddress,
        'tax_id': customer.taxId,
        'custom_order_code': customer.customOrderCode,
        'items': cartItems
            .map(
              (item) => {
                'product_id': item.product.id,
                'quantity': item.quantity,
                'fulfill_branch_id': item.fulfillBranchId,
              },
            )
            .toList(growable: false),
      }),
    );
    final data = _readResponse(response);
    final orderCode = data['order_code'] as String?;
    if (orderCode == null || orderCode.isEmpty) {
      throw const AuthApiException('ระบบไม่ได้ส่งเลขใบเสนอราคากลับมา');
    }
    return QuoteResult(orderCode);
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
