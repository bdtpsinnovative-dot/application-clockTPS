import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../sales_auth_adapter.dart';
import '../dispatch/dispatch_screen.dart';
import 'pos_service.dart';

const _ink = Color(0xFF000000);
const _muted = Color(0xFF71717A);
const _canvas = Colors.white;
const _line = Color(0xFFE4E4E7);
const _blue = Color(0xFF2563EB);
const _green = Color(0xFF16A34A);
const _emerald = Color(0xFF000000); // Pure Black theme for accents
const _orange = Color(0xFFEA580C);

enum PosTab { sale, quote }

class SalePosScreen extends StatefulWidget {
  const SalePosScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.onSignOut,
    this.onOpenDrawer,
    this.onNavigateToDispatch,
    this.initialTab = PosTab.sale,
  });

  final AuthenticatedUser user;
  final AuthService authService;
  final Future<void> Function() onSignOut;
  final VoidCallback? onOpenDrawer;
  final void Function([String? orderCode])? onNavigateToDispatch;
  final PosTab initialTab;

  @override
  State<SalePosScreen> createState() => SalePosScreenState();
}

class SalePosScreenState extends State<SalePosScreen>
    with SingleTickerProviderStateMixin {
  late final PosService _posService;
  late final AnimationController _cartBounceController;
  late final Animation<double> _cartBounceAnimation;

  final _categoryScrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _companyController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _customOrderCodeController = TextEditingController();
  final _companyNameEnController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _couponController = TextEditingController();
  final _specialDiscountBahtController = TextEditingController();
  final _specialDiscountPercentController = TextEditingController();

  final List<CartLineItem> _cart = [];
  StateSetter? _mobileCartSheetStateSetter;

  void _syncState([VoidCallback? fn]) {
    if (fn != null) fn();
    if (mounted) {
      setState(() {});
      _mobileCartSheetStateSetter?.call(() {});
    }
  }

  void switchToTab(PosTab tab) {
    if (mounted) {
      _syncState();
    }
  }
  String _saleMode = 'TAKE_AWAY'; // 'TAKE_AWAY' | 'DELIVERY'
  static const _paymentMethod = 'CASH';

  int _currentBranchId = 1;
  String _currentBranchName = 'สาขาเรา';
  List<BranchInfo> _branches = const [];

  // Filter & Sort state
  int? _filterLocation; // null = ทุกสาขา (ALL), or branchId
  String _filterStockMode = 'ALL'; // 'ALL', 'OWN_IN_STOCK', 'ANY_IN_STOCK', 'OUT_OF_STOCK'
  String _selectedBrand = 'ทุกแบรนด์';
  List<String> _serverBrands = const [];
  bool _filterOnlyDiscount = false;
  String _sortBy = 'DEFAULT'; // 'DEFAULT', 'PRICE_ASC', 'PRICE_DESC', 'STOCK_DESC'

  PosCoupon? _appliedCoupon;
  bool _isValidatingCoupon = false;

  List<PosProduct> _products = const [];
  String _category = 'ทั้งหมด';
  String _search = '';
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _loadError;

  // แคตตาล็อก: 'PROP', 'FURNITURE', 'SLAB'
  String _catalogType = 'PROP';
  List<PosProduct> _furnitureProducts = const [];
  bool _isLoadingFurniture = false;
  String? _furnitureLoadError;

  List<PosProduct> _slabProducts = const [];
  bool _isLoadingSlabs = false;
  String? _slabsLoadError;

  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _posService = PosService(widget.authService);
    _cartBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _cartBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.07).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.07, end: 0.98).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_cartBounceController);

    _searchController.addListener(
      () => setState(() => _search = _searchController.text),
    );
    _searchFocusNode.addListener(() => setState(() {}));
    _loadProducts();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _cartBounceController.dispose();
    _categoryScrollController.dispose();
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _companyController.dispose();
    _taxIdController.dispose();
    _customOrderCodeController.dispose();
    _companyNameEnController.dispose();
    _companyAddressController.dispose();
    _couponController.dispose();
    _specialDiscountBahtController.dispose();
    _specialDiscountPercentController.dispose();
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final catalog = await _posService.loadCatalog();
      if (mounted) {
        setState(() {
          _products = catalog.products;
          _serverBrands = catalog.brands;
          _branches = catalog.branches;
          _currentBranchId = catalog.currentBranchId;
          _currentBranchName = catalog.currentBranchName;
        });
      }
      _loadFurnitureProducts();
      _loadSlabsProducts();
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'ไม่สามารถเชื่อมต่อเพื่อโหลดสินค้าได้');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFurnitureProducts({bool force = false}) async {
    if (_isLoadingFurniture) return;
    if (!force && _furnitureProducts.isNotEmpty) return;
    setState(() {
      _isLoadingFurniture = true;
      _furnitureLoadError = null;
    });
    try {
      final items = await _posService.loadFurnitureCatalog();
      if (mounted) {
        setState(() {
          _furnitureProducts = items.products;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _furnitureLoadError = 'ไม่สามารถโหลดเฟอร์นิเจอร์ได้');
      }
    } finally {
      if (mounted) setState(() => _isLoadingFurniture = false);
    }
  }

  Future<void> _loadSlabsProducts({bool force = false}) async {
    if (_isLoadingSlabs) return;
    if (!force && _slabProducts.isNotEmpty) return;
    setState(() {
      _isLoadingSlabs = true;
      _slabsLoadError = null;
    });
    try {
      final items = await _posService.loadSlabsCatalog();
      if (mounted) {
        setState(() {
          _slabProducts = items.products;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _slabsLoadError = 'ไม่สามารถโหลดแผ่นไม้/สแลปได้');
      }
    } finally {
      if (mounted) setState(() => _isLoadingSlabs = false);
    }
  }

  static String _cleanCat(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s*\([^)]*à[¸¹][^)]*\)'), '').trim();
    return cleaned.isNotEmpty ? cleaned : 'อื่น ๆ';
  }

  List<PosProduct> get _activeProducts {
    if (_catalogType == 'FURNITURE') return _furnitureProducts;
    if (_catalogType == 'SLAB') return _slabProducts;
    return _products;
  }

  List<String> get _categories => [
    'ทั้งหมด',
    ...{for (final product in _activeProducts) _cleanCat(product.category)}.toList()..sort(),
  ];

  List<String> get _brands {
    final set = <String>{};
    for (final p in _activeProducts) {
      final b = p.brand.trim();
      if (b.isNotEmpty && b != 'ทั่วไป' && b != 'ไม่มีแบรนด์') {
        set.add(b);
      }
    }
    for (final b in _serverBrands) {
      final s = b.trim();
      if (s.isNotEmpty && s != 'ทั่วไป' && s != 'ไม่มีแบรนด์') {
        set.add(s);
      }
    }
    final sorted = set.toList()..sort();
    final hasGeneral = _activeProducts.any((p) => p.brand.trim() == 'ทั่วไป');
    if (hasGeneral && _catalogType == 'PROP') {
      sorted.add('ทั่วไป');
    }
    return ['ทุกแบรนด์', ...sorted];
  }

  bool get _hasActiveFilters =>
      _category != 'ทั้งหมด' ||
      _selectedBrand != 'ทุกแบรนด์' ||
      _filterLocation != null ||
      _filterStockMode != 'ALL' ||
      _filterOnlyDiscount ||
      _sortBy != 'DEFAULT';

  int get _activeFilterCount {
    int count = 0;
    if (_category != 'ทั้งหมด') count++;
    if (_selectedBrand != 'ทุกแบรนด์') count++;
    if (_filterLocation != null) count++;
    if (_filterStockMode != 'ALL') count++;
    if (_filterOnlyDiscount) count++;
    if (_sortBy != 'DEFAULT') count++;
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _category = 'ทั้งหมด';
      _selectedBrand = 'ทุกแบรนด์';
      _filterLocation = null;
      _filterStockMode = 'ALL';
      _filterOnlyDiscount = false;
      _sortBy = 'DEFAULT';
    });
  }

  String get _currentFilterBranchName {
    if (_filterLocation == null) return 'ทุกสาขา';
    if (_filterLocation == _currentBranchId) return 'สาขาเรา';
    final found = _branches.where((b) => b.id == _filterLocation).firstOrNull;
    return found?.name ?? 'สาขา #$_filterLocation';
  }

  List<PosProduct> get _visibleProducts {
    final query = _search.trim().toLowerCase();
    var list = _activeProducts.where((product) {
      if (_category != 'ทั้งหมด' && _cleanCat(product.category) != _category) {
        return false;
      }
      if (_selectedBrand != 'ทุกแบรนด์' && product.brand.toLowerCase() != _selectedBrand.toLowerCase()) {
        return false;
      }
      if (query.isNotEmpty) {
        final searchable = '${product.name} ${product.sku} ${product.barcode} ${product.brand} ${product.category}'.toLowerCase();
        final compactQuery = query.replaceAll(RegExp(r'[-_\s]'), '');
        final compactSearchable = searchable.replaceAll(RegExp(r'[-_\s]'), '');
        if (!searchable.contains(query) && (compactQuery.length < 2 || !compactSearchable.contains(compactQuery))) {
          return false;
        }
      }
      if (_filterLocation != null) {
        if (!product.isFurniture && !product.isSlab) {
          final bStock = product.stocks.where((s) => s.branchId == _filterLocation).firstOrNull;
          final qty = bStock?.qty ?? (_filterLocation == _currentBranchId ? product.ownBranchQty : 0);
          if (qty <= 0) return false;
        }
      }
      if (_filterStockMode == 'OWN_IN_STOCK' && product.ownBranchQty <= 0 && !product.isFurniture && !product.isSlab) {
        return false;
      } else if (_filterStockMode == 'ANY_IN_STOCK' && product.totalStock <= 0 && !product.isFurniture && !product.isSlab) {
        return false;
      } else if (_filterStockMode == 'OUT_OF_STOCK' && (product.totalStock > 0 || product.isFurniture || product.isSlab)) {
        return false;
      }
      if (_filterOnlyDiscount && !product.hasDiscount) {
        return false;
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'PRICE_ASC':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'PRICE_DESC':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'STOCK_DESC':
        list.sort((a, b) => b.totalStock.compareTo(a.totalStock));
        break;
      default:
        list.sort((a, b) {
          final aTier = a.ownBranchQty > 0 ? 0 : (a.otherBranchQty > 0 ? 1 : 2);
          final bTier = b.ownBranchQty > 0 ? 0 : (b.otherBranchQty > 0 ? 1 : 2);
          if (aTier != bTier) return aTier - bTier;
          final aHasPrice = a.price > 0 ? 0 : 1;
          final bHasPrice = b.price > 0 ? 0 : 1;
          if (aHasPrice != bHasPrice) return aHasPrice - bHasPrice;
          if (a.totalStock != b.totalStock) return b.totalStock.compareTo(a.totalStock);
          return a.name.compareTo(b.name);
        });
        break;
    }

    return list;
  }

  bool get _hasSlabInCart => _cart.any((it) {
    final sku = it.product.sku.toUpperCase();
    final cat = it.product.category.toLowerCase();
    final name = it.product.name.toLowerCase();
    return it.product.isSlab ||
        sku.startsWith('ZLB-') ||
        sku.startsWith('WOOD-') ||
        cat.contains('slab') ||
        name.contains('slab') ||
        name.contains('แผ่นไม้') ||
        name.contains('ไม้แผ่น');
  });

  int get _itemCount => _cart.fold(0, (sum, item) => sum + item.quantity);

  int get _localItemCount =>
      _cart.where((i) => !i.isCrossBranch).fold(0, (s, i) => s + i.quantity);

  int get _crossItemCount =>
      _cart.where((i) => i.isCrossBranch).fold(0, (s, i) => s + i.quantity);

  double get _subtotal =>
      _cart.fold(0, (sum, item) => sum + item.product.price * item.quantity);

  double get _couponDiscount => _appliedCoupon?.discountAmount ?? 0;

  double get _priceAfterCoupon => math.max(0, _subtotal - _couponDiscount);

  double get _specialDiscountBaht =>
      double.tryParse(_specialDiscountBahtController.text.trim()) ?? 0;

  double get _specialDiscountPercent =>
      double.tryParse(_specialDiscountPercentController.text.trim()) ?? 0;

  double get _afterBaht => math.max(0, _priceAfterCoupon - _specialDiscountBaht);

  double get _discountPercentAmount =>
      _afterBaht * (_specialDiscountPercent / 100);

  double get _totalSpecialDiscountAmount =>
      _specialDiscountBaht + _discountPercentAmount;

  double get _netTotal =>
      math.max(0, (_afterBaht - _discountPercentAmount).roundToDouble());

  double get _vatAmount => _netTotal - (_netTotal / 1.07);

  String get _customerName => _customerNameController.text.trim();

  void _handleAddToCart(
    PosProduct product, {
    int? fulfillBranchId,
    String? fulfillBranchName,
    int quantityToAdd = 1,
  }) {
    // 1. ตรวจสอบกฎการรวมสินค้า: พรอพ ห้ามรวมกับ เฟอร์นิเจอร์ หรือ ไม้ (แต่ ไม้ กับ เฟอร์ รวมกันได้)
    final isAddingFurnOrWood = product.isFurniture ||
        product.isSlab ||
        _catalogType == 'FURNITURE' ||
        _catalogType == 'SLAB';
    final cartHasProp =
        _cart.any((item) => !item.product.isFurniture && !item.product.isSlab);
    final cartHasFurnOrWood =
        _cart.any((item) => item.product.isFurniture || item.product.isSlab);

    if (!isAddingFurnOrWood && cartHasFurnOrWood) {
      _showMessage(
          'ไม่สามารถรวมสินค้าพรอพ กับเฟอร์นิเจอร์หรือแผ่นไม้ในบิลเดียวกันได้ (กรุณาแยกบิลครับ)');
      return;
    }
    if (isAddingFurnOrWood && cartHasProp) {
      _showMessage(
          'บิลนี้มีสินค้าพรอพอยู่แล้ว ไม่สามารถรวมเฟอร์นิเจอร์หรือแผ่นไม้ในบิลเดียวกันได้ (กรุณาแยกบิลครับ)');
      return;
    }

    // 2. หากสินค้าราคา 0 บาท (งานสั่งผลิตหรือ Custom) ให้เปิดหน้าต่างระบุราคาก่อน
    if (product.price <= 0) {
      _showSetPriceDialog(
        product,
        fulfillBranchId: fulfillBranchId,
        fulfillBranchName: fulfillBranchName,
        quantityToAdd: quantityToAdd,
      );
      return;
    }

    // 3. สินค้าสั่งผลิต (เฟอร์นิเจอร์ หรือ แผ่นไม้ หรือ External)
    // ถ้าสาขาเราไม่มีสต็อก แต่สาขาอื่นมีสต็อก ให้ดึงจากสาขาที่มีของอัตโนมัติ (หรือให้เลือกสาขา) ก่อนเสมอ
    if (isAddingFurnOrWood || product.isExternal) {
      if (fulfillBranchId == null && product.ownBranchQty <= 0 && product.otherBranchQty > 0) {
        final otherBranches = product.stocks
            .where((s) => s.branchId != _currentBranchId && s.qty > 0)
            .toList();
        if (otherBranches.length == 1) {
          final ob = otherBranches.first;
          _addCartLine(
            product: product,
            fulfillBranchId: ob.branchId,
            fulfillBranchName: ob.branchName,
            isCrossBranch: true,
            quantityToAdd: quantityToAdd,
          );
          return;
        } else if (otherBranches.length > 1) {
          _showBranchPicker(product);
          return;
        }
      }
      final fBranchId = fulfillBranchId ?? _currentBranchId;
      final fBranchName = fulfillBranchName ??
          _branches.where((b) => b.id == fBranchId).firstOrNull?.name ??
          (fBranchId == _currentBranchId ? _currentBranchName : 'สาขา #$fBranchId');
      _addCartLine(
        product: product,
        fulfillBranchId: fBranchId,
        fulfillBranchName: fBranchName,
        isCrossBranch: fBranchId != _currentBranchId,
        quantityToAdd: quantityToAdd,
      );
      return;
    }

    if (fulfillBranchId != null) {
      final fBranchName = fulfillBranchName ??
          _branches.where((b) => b.id == fulfillBranchId).firstOrNull?.name ??
          (fulfillBranchId == _currentBranchId ? _currentBranchName : 'สาขา #$fulfillBranchId');
      _addCartLine(
        product: product,
        fulfillBranchId: fulfillBranchId,
        fulfillBranchName: fBranchName,
        isCrossBranch: fulfillBranchId != _currentBranchId,
        quantityToAdd: quantityToAdd,
      );
      return;
    }

    if (product.ownBranchQty > 0) {
      final currentInCart = _getCartQty(product.id, _currentBranchId);
      if (currentInCart < product.ownBranchQty) {
        _addCartLine(
          product: product,
          fulfillBranchId: _currentBranchId,
          fulfillBranchName: _currentBranchName,
          isCrossBranch: false,
          quantityToAdd: quantityToAdd,
        );
        return;
      }
    }

    if (product.otherBranchQty > 0) {
      _showBranchPicker(product);
      return;
    }

    _showMessage('สินค้า ${product.name} หมดสต็อกแล้วครับ');
  }

  Future<void> _showSetPriceDialog(
    PosProduct product, {
    int? fulfillBranchId,
    String? fulfillBranchName,
    int quantityToAdd = 1,
  }) async {
    final priceController = TextEditingController();
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    Widget content(void Function(void Function()) setModalState) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sell_outlined, color: _ink, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ระบุราคาขายสินค้า',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.sku.isNotEmpty ? "${product.sku} - " : ""}${product.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'สินค้านี้เป็นงานสั่งผลิตหรือยังไม่มีราคามาตรฐาน กรุณาระบุราคาขาย (บาท) ที่ตกลงกับลูกค้าก่อนเพิ่มลงตะกร้า',
                style: TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.4),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: priceController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink),
              decoration: InputDecoration(
                labelText: 'ราคาขายต่อชิ้น (บาท)',
                labelStyle: const TextStyle(fontSize: 13, color: _muted),
                prefixText: '฿ ',
                prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _ink, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final text = priceController.text.replaceAll(',', '').trim();
                      final enteredPrice = double.tryParse(text) ?? 0;
                      if (enteredPrice <= 0) {
                        _showMessage('กรุณาระบุราคาที่มากกว่า 0 บาทครับ');
                        return;
                      }
                      Navigator.pop(context);
                      final pricedProduct = product.copyWithPrice(enteredPrice);
                      _handleAddToCart(
                        pricedProduct,
                        fulfillBranchId: fulfillBranchId,
                        fulfillBranchName: fulfillBranchName,
                        quantityToAdd: quantityToAdd,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ยืนยันราคา',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (isTablet) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            backgroundColor: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(child: content(setModalState)),
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SingleChildScrollView(child: content(setModalState)),
          ),
        ),
      );
    }
  }

  int _getCartQty(int productId, int branchId) {
    final line = _cart
        .where((i) => i.product.id == productId && i.fulfillBranchId == branchId)
        .firstOrNull;
    return line?.quantity ?? 0;
  }

  void _addCartLine({
    required PosProduct product,
    required int fulfillBranchId,
    required String fulfillBranchName,
    required bool isCrossBranch,
    int quantityToAdd = 1,
  }) {
    final existingIndex = _cart.indexWhere(
      (i) => i.product.id == product.id && i.fulfillBranchId == fulfillBranchId,
    );

    if (existingIndex >= 0) {
      final item = _cart[existingIndex];
      final maxStock = _getStockForBranch(product, fulfillBranchId);
      if (item.quantity + quantityToAdd > maxStock) {
        _showMessage(
          'หยิบครบตามสต็อกของ $fulfillBranchName แล้ว ($maxStock ชิ้น)',
        );
        return;
      }
      setState(() {
        item.quantity += quantityToAdd;
        if (product.price > 0 && item.product.price <= 0) {
          _cart[existingIndex] = CartLineItem(
            product: product,
            quantity: item.quantity,
            fulfillBranchId: fulfillBranchId,
            fulfillBranchName: fulfillBranchName,
            isCrossBranch: isCrossBranch,
          );
        }
      });
    } else {
      setState(() {
        _cart.add(
          CartLineItem(
            product: product,
            quantity: quantityToAdd,
            fulfillBranchId: fulfillBranchId,
            fulfillBranchName: fulfillBranchName,
            isCrossBranch: isCrossBranch,
          ),
        );
      });
    }

    _cartBounceController.forward(from: 0.0);
    HapticFeedback.lightImpact();

    if (isCrossBranch && _saleMode == 'TAKE_AWAY') {
      setState(() => _saleMode = 'DELIVERY');
      _showMessage(
        'สลับเป็นโหมด "จัดส่งสินค้า" อัตโนมัติเนื่องจากมีรายการขายข้ามสาขา ($fulfillBranchName)',
      );
    }
  }

  int _getStockForBranch(PosProduct product, int branchId) {
    if (product.isExternal || product.isFurniture || product.isSlab) return 999;
    final row = product.stocks.where((s) => s.branchId == branchId).firstOrNull;
    return row?.qty ?? (branchId == _currentBranchId ? product.ownBranchQty : 0);
  }

  void _changeQuantity(CartLineItem item, int change) {
    final maxStock = _getStockForBranch(item.product, item.fulfillBranchId);
    final next = item.quantity + change;

    if (next <= 0) {
      _syncState(() => _cart.remove(item));
    } else if (next <= maxStock) {
      _syncState(() => item.quantity = next);
    } else {
      _showMessage(
        'สต็อกในสาขา ${item.fulfillBranchName} มีจำกัดเพียง $maxStock ชิ้น',
      );
    }
  }

  Future<void> _showBranchPicker(PosProduct product) async {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    if (isTablet) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
            child: _BranchSelectSheet(
              product: product,
              currentBranchId: _currentBranchId,
              currentBranchName: _currentBranchName,
              onSelectBranch: (branchId, branchName, isCross) {
                Navigator.pop(context);
                _addCartLine(
                  product: product,
                  fulfillBranchId: branchId,
                  fulfillBranchName: branchName,
                  isCrossBranch: isCross,
                );
              },
              isDialog: true,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _BranchSelectSheet(
          product: product,
          currentBranchId: _currentBranchId,
          currentBranchName: _currentBranchName,
          onSelectBranch: (branchId, branchName, isCross) {
            Navigator.pop(context);
            _addCartLine(
              product: product,
              fulfillBranchId: branchId,
              fulfillBranchName: branchName,
              isCrossBranch: isCross,
            );
          },
          isDialog: false,
        ),
      );
    }
  }

  void _showMessage(String message) {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastEntry = null;

    if (!mounted) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final isAlert = message.contains('หมดสต็อก') ||
        message.contains('ไม่พบ') ||
        message.contains('ไม่สำเร็จ') ||
        message.contains('ข้อผิดพลาด') ||
        message.contains('ครบตามสต็อก');
    final isSuccess = message.contains('สำเร็จ') ||
        message.contains('เรียบร้อย') ||
        message.contains('เพิ่ม');

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final topPadding = MediaQuery.paddingOf(ctx).top;
        return Positioned(
          top: topPadding + 8,
          left: 20,
          right: 20,
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, -10 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () {
                    _toastTimer?.cancel();
                    if (_toastEntry == entry) {
                      entry.remove();
                      _toastEntry = null;
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 340),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isAlert
                            ? const Color(0xFFFED7AA)
                            : (isSuccess
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFE2E8F0)),
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isAlert
                                ? const Color(0xFFFFF7ED)
                                : (isSuccess
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFF1F5F9)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isAlert
                                ? Icons.warning_amber_rounded
                                : (isSuccess
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded),
                            color: isAlert
                                ? const Color(0xFFEA580C)
                                : (isSuccess
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF475569)),
                            size: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isAlert
                                  ? const Color(0xFF9A3412)
                                  : (isSuccess
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF1E293B)),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _toastEntry = entry;
    overlay.insert(entry);

    _toastTimer = Timer(const Duration(milliseconds: 2000), () {
      if (_toastEntry == entry) {
        entry.remove();
        _toastEntry = null;
      }
    });
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      _showMessage('กรุณาระบุรหัสคูปอง');
      return;
    }
    if (_subtotal <= 0) {
      _showMessage('กรุณาเลือกสินค้าในตะกร้าก่อนใช้คูปอง');
      return;
    }

    setState(() => _isValidatingCoupon = true);
    try {
      final coupon = await _posService.validateCoupon(code, _subtotal);
      if (!mounted) return;
      setState(() {
        _appliedCoupon = coupon;
      });
      _showMessage('ใช้คูปองส่วนลด "${coupon.title}" สำเร็จ');
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('ไม่สามารถตรวจสอบคูปองได้');
    } finally {
      if (mounted) setState(() => _isValidatingCoupon = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
    });
    _showMessage('ยกเลิกคูปองแล้ว');
  }

  Future<void> _openCustomerForm() async {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    if (isTablet) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _CustomerSheet(
              nameController: _customerNameController,
              phoneController: _customerPhoneController,
              addressController: _customerAddressController,
              companyController: _companyController,
              taxIdController: _taxIdController,
              customOrderCodeController: _customOrderCodeController,
              companyNameEnController: _companyNameEnController,
              companyAddressController: _companyAddressController,
              saleMode: _saleMode,
              isDialog: true,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _CustomerSheet(
          nameController: _customerNameController,
          phoneController: _customerPhoneController,
          addressController: _customerAddressController,
          companyController: _companyController,
          taxIdController: _taxIdController,
          customOrderCodeController: _customOrderCodeController,
          companyNameEnController: _companyNameEnController,
          companyAddressController: _companyAddressController,
          saleMode: _saleMode,
          isDialog: false,
        ),
      );
    }
    if (mounted) _syncState();
  }

  Widget _discountSummaryBar() {
    final hasCoupon = _appliedCoupon != null;
    final hasSpecial = _totalSpecialDiscountAmount != 0;
    final hasAnyDiscount = hasCoupon || hasSpecial;
    final totalDiscount = _couponDiscount + _totalSpecialDiscountAmount;

    return InkWell(
      onTap: _openDiscountModal,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: hasAnyDiscount ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasAnyDiscount ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 16,
              color: hasAnyDiscount ? _green : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: hasAnyDiscount
                  ? Row(
                      children: [
                        if (hasCoupon) ...[
                          Text(
                            '${_appliedCoupon!.code} ',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                        Text(
                          'ส่วนลด -${_money(totalDiscount)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: _green,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'ใส่คูปอง / ส่วนลดพิเศษท้ายบิล',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
            ),
            if (hasAnyDiscount)
              InkWell(
                onTap: () {
                  setState(() {
                    _appliedCoupon = null;
                    _couponController.clear();
                    _specialDiscountBahtController.clear();
                    _specialDiscountPercentController.clear();
                  });
                  _showMessage('ล้างส่วนลดทั้งหมดแล้ว');
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                ),
              )
            else ...[
              const Text(
                'เพิ่มส่วนลด',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 15, color: Color(0xFF6366F1)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openDiscountModal() async {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    Widget content(StateSetter setModalState) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Icon(Icons.local_offer_outlined, color: _emerald, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ส่วนลดและโปรโมชั่น',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                      Text(
                        'กรอกคูปอง หรือระบุส่วนลดพิเศษท้ายบิล',
                        style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: _muted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: _line),
            const SizedBox(height: 14),

            // 1. Coupon Section
            const Text(
              'คูปองส่วนลด (COUPON)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            if (_appliedCoupon != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number_outlined, color: _green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_appliedCoupon!.code} — ${_appliedCoupon!.title}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                          ),
                          Text(
                            'ส่วนลด -${_money(_couponDiscount)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _green),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _removeCoupon();
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, size: 18, color: _muted),
                      tooltip: 'ลบคูปอง',
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _couponController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFFAFAFA),
                          hintText: 'กรอกรหัสคูปอง เช่น SAVE10',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFA1A1AA), fontWeight: FontWeight.w600),
                          prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 17, color: Color(0xFF71717A)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 1.2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black, width: 1.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: _isValidatingCoupon
                          ? null
                          : () async {
                              await _applyCoupon();
                              setModalState(() {});
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _isValidatingCoupon
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('ใช้โค้ด', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.white)),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // 2. Special Discount Section + Rounding Assistant
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.percent_rounded, size: 15, color: Colors.black),
                    SizedBox(width: 6),
                    Text(
                      'ส่วนลดพิเศษท้ายบิล',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                if (_cart.isNotEmpty)
                  InkWell(
                    onTap: () async {
                      await _openRoundingAssistantModal();
                      setModalState(() {});
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _line),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_fix_high_rounded, size: 13, color: Colors.black),
                          SizedBox(width: 4),
                          Text(
                            'ผู้ช่วยปัดเศษ',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // ระบุเป็นจำนวนเงิน (฿)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ระบุเป็นจำนวนเงิน (฿)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF52525B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 46,
                        child: TextField(
                          controller: _specialDiscountBahtController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          onChanged: (_) {
                            _syncState();
                            setModalState(() {});
                          },
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 14, right: 8),
                              child: Text(
                                '฿',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF71717A),
                                ),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            hintText: '0',
                            hintStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFA1A1AA),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 1.2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.black, width: 1.6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // ระบุเป็นเปอร์เซ็นต์ (%)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ระบุเป็นเปอร์เซ็นต์ (%)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF52525B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 46,
                        child: TextField(
                          controller: _specialDiscountPercentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          onChanged: (_) {
                            _syncState();
                            setModalState(() {});
                          },
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            suffixIcon: const Padding(
                              padding: EdgeInsets.only(right: 14, left: 8),
                              child: Text(
                                '%',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF71717A),
                                ),
                              ),
                            ),
                            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            hintText: '0',
                            hintStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFA1A1AA),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 1.2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.black, width: 1.6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'ปุ่มลัด:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF71717A)),
                ),
                const SizedBox(width: 8),
                ...[5, 10, 15, 20].map((pct) {
                  final isSel = _specialDiscountPercent == pct.toDouble() && _specialDiscountBaht == 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        _syncState(() {
                          if (isSel) {
                            _specialDiscountPercentController.clear();
                          } else {
                            _specialDiscountPercentController.text = pct.toString();
                            _specialDiscountBahtController.clear();
                          }
                        });
                        setModalState(() {});
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.black : const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? Colors.black : const Color(0xFFE4E4E7),
                          ),
                        ),
                        child: Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSel ? Colors.white : const Color(0xFF3F3F46),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 14),

            // 3. Live calculation preview card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _summaryLine('ยอดรวมสินค้า', _money(_subtotal)),
                  if (_couponDiscount > 0) ...[
                    const SizedBox(height: 4),
                    _summaryLine('ส่วนลดคูปอง', '-${_money(_couponDiscount)}', isDiscount: true),
                  ],
                  if (_totalSpecialDiscountAmount != 0) ...[
                    const SizedBox(height: 4),
                    _summaryLine(
                      _totalSpecialDiscountAmount > 0 ? 'ส่วนลดพิเศษท้ายบิล' : 'ปัดเศษเพิ่ม',
                      '${_totalSpecialDiscountAmount > 0 ? "-" : "+"}${_money(_totalSpecialDiscountAmount.abs())}',
                      isDiscount: _totalSpecialDiscountAmount > 0,
                    ),
                  ],
                  const SizedBox(height: 4),
                  _summaryLine('VAT 7% (รวมในยอด)', _money(_vatAmount)),
                  const Divider(height: 12, color: Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ยอดสุทธิใบขาย',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _ink),
                      ),
                      Text(
                        _money(_netTotal),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _ink),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons (50/50 equal width, single-line text, never wrapped!)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _syncState(() {
                        _appliedCoupon = null;
                        _couponController.clear();
                        _specialDiscountBahtController.clear();
                        _specialDiscountPercentController.clear();
                      });
                      setModalState(() {});
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: const BorderSide(color: _line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Colors.black),
                        SizedBox(width: 6),
                        Text(
                          'ล้างส่วนลด',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      _syncState();
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 17, color: Colors.white),
                    label: const Text(
                      'ตกลง / บันทึก',
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (isTablet) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            backgroundColor: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(child: content(setModalState)),
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SingleChildScrollView(child: content(setModalState)),
          ),
        ),
      );
    }
    if (mounted) _syncState();
  }

  Future<void> _openRoundingAssistantModal() async {
    final targetController = TextEditingController(
      text: _netTotal.floor().toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final target = double.tryParse(targetController.text.trim()) ?? 0;
          final baseSubtotal = _priceAfterCoupon;
          final totalDiscountNeeded = baseSubtotal - target;
          final targetPercentDiscount =
              baseSubtotal > 0 ? (totalDiscountNeeded / baseSubtotal) * 100 : 0.0;
          final targetPercentFormatted =
              double.parse(targetPercentDiscount.toStringAsFixed(4));
          final targetBahtFormatted =
              double.parse(totalDiscountNeeded.toStringAsFixed(2));

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F7FF),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text('✨', style: TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'ผู้ช่วยปัดเศษยอดสุทธิ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(dialogContext),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 17,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ยอดสุทธิปัจจุบัน (รวม VAT)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ยอดสุทธิปัจจุบัน (รวม VAT)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _netTotal.toStringAsFixed(2),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' ฿',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // คุณต้องการปัดเศษให้เหลือเท่าไหร่?
                          const Text(
                            'คุณต้องการปัดเศษให้เหลือเท่าไหร่?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: targetController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setModalState(() {}),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4338CA),
                            ),
                            decoration: InputDecoration(
                              hintText: 'เช่น 4980',
                              suffixText: '฿',
                              suffixStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFA1A1AA),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFC7D2FE),
                                  width: 1.8,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF6366F1),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'แนะนำ: กรอกตัวเลขกลมๆ ที่ต้องการ เช่น 4900 หรือ 4980',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          if (targetController.text.trim().isNotEmpty &&
                              target > 0) ...[
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE0E7FF)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16,
                                        color: Color(0xFF4338CA),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'คำนวณยอดเป้าหมาย ${target.toStringAsFixed(2)} ฿ สำเร็จ!',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF4338CA),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'ระบบช่วยคำนวณสัดส่วนภาษี (VAT 7%) เรียบร้อยแล้ว นายสามารถเลือกปรับแต่งรูปแบบส่วนลด/ส่วนเพิ่ม ได้ 2 รูปแบบดังนี้ครับ:',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF64748B),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // รูปแบบที่ 1: ปรับเป็นเปอร์เซ็นต์ (%)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'รูปแบบที่ 1: ปรับเป็นเปอร์เซ็นต์ (%)',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                            Text(
                                              '${targetPercentFormatted > 0 ? "-" : "+"} ${targetPercentFormatted.abs()} %',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                color: targetPercentFormatted > 0
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 36,
                                          child: FilledButton(
                                            onPressed: () {
                                              setState(() {
                                                _specialDiscountPercentController
                                                    .text = targetPercentFormatted
                                                        .toString();
                                                _specialDiscountBahtController
                                                    .text = '0';
                                              });
                                              Navigator.pop(dialogContext);
                                            },
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF4F46E5),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                              ),
                                            ),
                                            child: Text(
                                              'ใช้ส่วนลด ${targetPercentFormatted.abs()} % (ล้างช่องบาท)',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // รูปแบบที่ 2: ปรับเป็นบาท (฿)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'รูปแบบที่ 2: ปรับเป็นบาท (฿)',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                            Text(
                                              '${targetBahtFormatted > 0 ? "-" : "+"} ${targetBahtFormatted.abs()} ฿',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                color: targetBahtFormatted > 0
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 36,
                                          child: FilledButton(
                                            onPressed: () {
                                              setState(() {
                                                _specialDiscountBahtController
                                                    .text = targetBahtFormatted
                                                        .toString();
                                                _specialDiscountPercentController
                                                    .text = '0';
                                              });
                                              Navigator.pop(dialogContext);
                                            },
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF10B981),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                              ),
                                            ),
                                            child: Text(
                                              'ใช้ส่วนลด ${targetBahtFormatted.abs()} ฿ (ล้างช่อง %)',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleAction() async {
    if (_cart.isEmpty || _isProcessing) return;
    await _checkout();
  }

  Future<void> _checkout() async {
    final saleModeLabel = _saleMode == 'DELIVERY' ? 'ให้ร้านส่งให้' : 'รับหน้าร้าน';
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    final confirmed = await (isTablet
        ? showDialog<bool>(
            context: context,
            builder: (ctx) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _QuotationConfirmModalContent(
                  customerName: _customerName,
                  saleModeLabel: saleModeLabel,
                  isDelivery: _saleMode == 'DELIVERY',
                  hasSlab: _hasSlabInCart,
                  itemCount: _itemCount,
                  localItemCount: _localItemCount,
                  crossItemCount: _crossItemCount,
                  subtotal: _subtotal,
                  couponCode: _appliedCoupon?.code,
                  couponDiscount: _couponDiscount,
                  specialDiscountAmount: _totalSpecialDiscountAmount,
                  vatAmount: _vatAmount,
                  netTotal: _netTotal,
                  isDialog: true,
                  onConfirm: () => Navigator.pop(ctx, true),
                  onCancel: () => Navigator.pop(ctx, false),
                ),
              ),
            ),
          )
        : showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: _QuotationConfirmModalContent(
                  customerName: _customerName,
                  saleModeLabel: saleModeLabel,
                  isDelivery: _saleMode == 'DELIVERY',
                  hasSlab: _hasSlabInCart,
                  itemCount: _itemCount,
                  localItemCount: _localItemCount,
                  crossItemCount: _crossItemCount,
                  subtotal: _subtotal,
                  couponCode: _appliedCoupon?.code,
                  couponDiscount: _couponDiscount,
                  specialDiscountAmount: _totalSpecialDiscountAmount,
                  vatAmount: _vatAmount,
                  netTotal: _netTotal,
                  isDialog: false,
                  onConfirm: () => Navigator.pop(ctx, true),
                  onCancel: () => Navigator.pop(ctx, false),
                ),
              ),
            ),
          ));

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final result = await _posService.checkout(
        customer: QuoteCustomer(
          name: _customerNameController.text,
          phone: _customerPhoneController.text,
          address: _customerAddressController.text,
          companyName: _companyController.text,
          taxId: _taxIdController.text,
          customOrderCode: _customOrderCodeController.text,
          companyNameEn: _companyNameEnController.text,
          companyAddress: _companyAddressController.text,
        ),
        cartItems: _cart,
        saleMode: _saleMode,
        paymentMethod: _paymentMethod,
        couponCode: _appliedCoupon?.code,
        specialDiscountBaht: _specialDiscountBaht,
        specialDiscountPercent: _specialDiscountPercent,
      );

      if (!mounted) return;
      setState(() {
        _cart.clear();
        _appliedCoupon = null;
        _couponController.clear();
        _specialDiscountBahtController.clear();
        _specialDiscountPercentController.clear();
      });

      await (isTablet
          ? showDialog<void>(
              context: context,
              builder: (ctx) => Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                clipBehavior: Clip.antiAlias,
                backgroundColor: Colors.white,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _QuotationSuccessModalContent(
                    orderCode: result.orderCode,
                    totalAmount: result.totalAmount,
                    isDialog: true,
                    onClose: () => Navigator.pop(ctx),
                    onViewDispatch: () {
                      Navigator.pop(ctx);
                      _openDispatchScreen(result.orderCode);
                    },
                  ),
                ),
              ),
            )
          : showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (ctx) => SafeArea(
                child: _QuotationSuccessModalContent(
                  orderCode: result.orderCode,
                  totalAmount: result.totalAmount,
                  isDialog: false,
                  onClose: () => Navigator.pop(ctx),
                  onViewDispatch: () {
                    Navigator.pop(ctx);
                    _openDispatchScreen(result.orderCode);
                  },
                ),
              ),
            ));
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('ไม่สามารถสร้างใบเสนอราคาได้ กรุณาลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final content = isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 7, child: _catalogue()),
              const SizedBox(width: 20),
              SizedBox(width: 420, child: _cartPanel()),
            ],
          )
        : _catalogue();

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 24 : 12,
                14,
                isDesktop ? 24 : 12,
                12,
              ),
              child: Column(
                children: [
                  _topBar(isDesktop),
                  const SizedBox(height: 14),
                  Expanded(child: content),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: isDesktop ? null : _mobileCartBar(),
    );
  }

  Widget _topBar(bool isDesktop) {
    return SizedBox(
      height: isDesktop ? 72 : 54,
      child: Row(
        children: [
          // 0. ปุ่มย้อนกลับไปหน้าหลัก HR
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: isDesktop ? 42 : 38,
                height: isDesktop ? 42 : 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line, width: 1.2),
                ),
                child: Icon(Icons.arrow_back_rounded, color: _ink, size: isDesktop ? 20 : 18),
              ),
            ),
          ),
          SizedBox(width: isDesktop ? 8 : 6),

          // 1. Sale Ops Brand (บน Desktop)
          if (isDesktop) ...[
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sale Ops',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _currentBranchName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          // 0. ปุ่มเลือกแคตตาล็อกสินค้า (Catalog Dropdown: พรอพ vs เฟอร์นิเจอร์ vs สแลป)
          Tooltip(
            message: _catalogType == 'FURNITURE'
                ? 'แคตตาล็อก: เฟอร์นิเจอร์'
                : (_catalogType == 'SLAB' ? 'แคตตาล็อก: แผ่นไม้/สแลป' : 'แคตตาล็อก: พรอพ'),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _showCatalogPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: isDesktop ? null : 38,
                  height: isDesktop ? 48 : 38,
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 0),
                  decoration: BoxDecoration(
                    color: _catalogType != 'PROP' ? Colors.black : Colors.white,
                    border: Border.all(
                      color: _catalogType != 'PROP' ? Colors.black : _line,
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: isDesktop
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _catalogType == 'FURNITURE'
                                  ? Icons.chair_rounded
                                  : (_catalogType == 'SLAB'
                                      ? Icons.table_restaurant_rounded
                                      : Icons.inventory_2_outlined),
                              size: 16,
                              color: _catalogType != 'PROP' ? Colors.white : Colors.black,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _catalogType == 'FURNITURE'
                                  ? 'เฟอร์นิเจอร์'
                                  : (_catalogType == 'SLAB' ? 'แผ่นไม้/สแลป' : 'พรอพ'),
                              style: TextStyle(
                                color: _catalogType != 'PROP' ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: _catalogType != 'PROP' ? Colors.white : _muted,
                            ),
                          ],
                        )
                      : Icon(
                          _catalogType == 'FURNITURE'
                              ? Icons.chair_rounded
                              : (_catalogType == 'SLAB'
                                  ? Icons.table_restaurant_rounded
                                  : Icons.inventory_2_outlined),
                          size: 18,
                          color: _catalogType != 'PROP' ? Colors.white : Colors.black,
                        ),
                ),
              ),
            ),
          ),
          SizedBox(width: isDesktop ? 8 : 6),

          // 1. ปุ่มเลือกสาขาคลังสินค้าบน Header (Location Quick Picker)
          Tooltip(
            message: 'สาขา: $_currentFilterBranchName',
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _showBranchFilterPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: isDesktop ? null : 38,
                  height: isDesktop ? 48 : 38,
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 0),
                  decoration: BoxDecoration(
                    color: _filterLocation != null ? Colors.black : Colors.white,
                    border: Border.all(
                      color: _filterLocation != null ? Colors.black : _line,
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: isDesktop
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.store_rounded,
                              size: 16,
                              color: _filterLocation != null ? Colors.white : Colors.black,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                _currentFilterBranchName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _filterLocation != null ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: _filterLocation != null ? Colors.white : _muted,
                            ),
                          ],
                        )
                      : Icon(
                          Icons.store_rounded,
                          size: 18,
                          color: _filterLocation != null ? Colors.white : Colors.black,
                        ),
                ),
              ),
            ),
          ),
          SizedBox(width: isDesktop ? 8 : 6),

          // 2. ปุ่มเปิดตัวกรองและเรียงลำดับบน Header (Filter Sheet Modal with Badge)
          Tooltip(
            message: 'ตัวกรองและเรียงลำดับ',
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _showFilterSheet,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: isDesktop ? 48 : 38,
                  height: isDesktop ? 48 : 38,
                  decoration: BoxDecoration(
                    color: _activeFilterCount > 0 ? Colors.black : Colors.white,
                    border: Border.all(
                      color: _activeFilterCount > 0 ? Colors.black : _line,
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: isDesktop ? 18 : 17,
                        color: _activeFilterCount > 0 ? Colors.white : Colors.black,
                      ),
                      if (_activeFilterCount > 0)
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                            child: Center(
                              child: Text(
                                '$_activeFilterCount',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8.5,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isDesktop ? 8 : 6),

          // 3. ปุ่มทางลัดไปหน้าขนส่ง
          Tooltip(
            message: 'ไปที่หน้าขนส่งและจัดส่งสินค้า (Dispatch)',
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _openDispatchScreen,
                onLongPress: () => _showMenu(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: isDesktop ? null : 38,
                  height: isDesktop ? 48 : 38,
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _line, width: 1.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: isDesktop
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_shipping_rounded,
                              color: Colors.black,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'หน้าขนส่ง',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        )
                      : const Icon(
                          Icons.local_shipping_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _catalogue() => Container(
    clipBehavior: Clip.antiAlias,
    decoration: _panelDecoration(radius: 26),
    child: Column(
      children: [
        _searchAndFilterBar(),
        _categoryBar(),
        Expanded(child: _productGrid()),
      ],
    ),
  );

  void _showCatalogPicker() {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    if (isTablet) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _catalogPickerContent(ctx, isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: _catalogPickerContent(ctx, isDialog: false),
        ),
      );
    }
  }

  Widget _catalogPickerContent(BuildContext ctx, {required bool isDialog}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isDialog ? 20 : 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDialog)
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D3D1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.category_rounded, color: _ink, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เลือกประเภทแคตตาล็อก',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          Text(
                            'สลับระหว่างสินค้าพรอพ, เฟอร์นิเจอร์ และแผ่นไม้สแลป',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: _muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: _muted),
                onPressed: () => Navigator.pop(ctx),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _branchPickerTile(
            title: 'สินค้าพรอพ (PROPS)',
            subtitle: 'แจกัน, เซรามิก, ของตกแต่งบ้าน และของใช้ประดับ',
            badgeText: _catalogType == 'PROP'
                ? 'กำลังเลือก'
                : (_products.isNotEmpty ? '${_products.length} รายการ' : null),
            icon: Icons.inventory_2_outlined,
            iconColor: _ink,
            isSelected: _catalogType == 'PROP',
            onTap: () {
              if (_catalogType != 'PROP') {
                setState(() {
                  _catalogType = 'PROP';
                  _category = 'ทั้งหมด';
                  _selectedBrand = 'ทุกแบรนด์';
                });
              }
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 10),
          _branchPickerTile(
            title: 'สินค้าเฟอร์นิเจอร์ (FURNITURE)',
            subtitle: 'โต๊ะ, เก้าอี้, ตู้, โซฟา และเฟอร์นิเจอร์หลัก',
            badgeText: _catalogType == 'FURNITURE'
                ? 'กำลังเลือก'
                : (_furnitureProducts.isNotEmpty
                    ? '${_furnitureProducts.length} รายการ'
                    : (_isLoadingFurniture ? 'กำลังโหลด...' : null)),
            icon: Icons.chair_rounded,
            iconColor: const Color(0xFFB45309),
            isSelected: _catalogType == 'FURNITURE',
            onTap: () {
              if (_catalogType != 'FURNITURE') {
                setState(() {
                  _catalogType = 'FURNITURE';
                  _category = 'ทั้งหมด';
                  _selectedBrand = 'ทุกแบรนด์';
                });
                if (_furnitureProducts.isEmpty && !_isLoadingFurniture) {
                  _loadFurnitureProducts();
                }
              }
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 10),
          _branchPickerTile(
            title: 'สินค้าแผ่นไม้ / สแลป (SLABS)',
            subtitle: 'ไม้แผ่นท็อปโต๊ะ, ขาโต๊ะ, ขาตั้ง และสแลปธรรมชาติ',
            badgeText: _catalogType == 'SLAB'
                ? 'กำลังเลือก'
                : (_slabProducts.isNotEmpty
                    ? '${_slabProducts.length} รายการ'
                    : (_isLoadingSlabs ? 'กำลังโหลด...' : null)),
            icon: Icons.table_restaurant_rounded,
            iconColor: const Color(0xFF047857),
            isSelected: _catalogType == 'SLAB',
            onTap: () {
              if (_catalogType != 'SLAB') {
                setState(() {
                  _catalogType = 'SLAB';
                  _category = 'ทั้งหมด';
                  _selectedBrand = 'ทุกแบรนด์';
                });
                if (_slabProducts.isEmpty && !_isLoadingSlabs) {
                  _loadSlabsProducts();
                }
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showBranchFilterPicker() {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    if (isTablet) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
            child: _branchFilterPickerContent(ctx, isDialog: true),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: _branchFilterPickerContent(ctx, isDialog: false),
        ),
      );
    }
  }

  Widget _branchFilterPickerContent(BuildContext ctx, {required bool isDialog}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, isDialog ? 20 : 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDialog)
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D3D1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: _emerald, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เลือกสาขาคลังสินค้า',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          Text(
                            'แสดงสต็อกและยอดขายตามสาขาที่เลือก',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: _muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: _muted),
                onPressed: () => Navigator.pop(ctx),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _branchPickerTile(
                  title: 'ทุกสาขาทั่วประเทศ (ALL STOCKS)',
                  subtitle: 'แสดงสต็อกสินค้าทุกสาขารวมกัน',
                  icon: Icons.language_rounded,
                  iconColor: _ink,
                  isSelected: _filterLocation == null,
                  onTap: () {
                    setState(() => _filterLocation = null);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
                _branchPickerTile(
                  title: 'สาขาเรา ($_currentBranchName)',
                  subtitle: 'เฉพาะสินค้าที่มีสต็อกในสาขานี้',
                  badgeText: 'สาขาปัจจุบัน',
                  icon: Icons.store_rounded,
                  iconColor: _emerald,
                  isSelected: _filterLocation == _currentBranchId,
                  onTap: () {
                    setState(() => _filterLocation = _currentBranchId);
                    Navigator.pop(ctx);
                  },
                ),
                if (_branches.where((b) => b.id != _currentBranchId).isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          'สาขาอื่นๆ ในเครือ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _muted,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Divider(color: _line)),
                      ],
                    ),
                  ),
                  ..._branches
                      .where((b) => b.id != _currentBranchId)
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _branchPickerTile(
                            title: b.name,
                            subtitle: 'สาขาคลังสินค้า #${b.id}',
                            icon: Icons.location_on_outlined,
                            iconColor: _muted,
                            isSelected: _filterLocation == b.id,
                            onTap: () {
                              setState(() => _filterLocation = b.id);
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _branchPickerTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return Material(
      color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFFAFAF9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _emerald : const Color(0xFFE7E5E4),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFFF5F5F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: isSelected ? _emerald : iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isSelected ? const Color(0xFF1D4ED8) : _ink,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _emerald,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? const Color(0xFF047857) : _muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: _emerald, size: 20)
              else
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFD6D3D1), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showBrandPickerModal() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    if (isDesktop) {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
            child: _BrandPickerSheet(
              brands: _brands,
              selectedBrand: _selectedBrand,
              activeProducts: _activeProducts,
              isDialog: true,
              onSelect: (b) {
                setState(() => _selectedBrand = b);
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: _BrandPickerSheet(
            brands: _brands,
            selectedBrand: _selectedBrand,
            activeProducts: _activeProducts,
            isDialog: false,
            onSelect: (b) {
              setState(() => _selectedBrand = b);
              Navigator.pop(ctx);
            },
          ),
        ),
      );
    }
  }

  void _showFilterSheet() {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    if (isTablet) {
      showDialog<void>(
        context: context,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setModalState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
              child: _filterSheetContent(sheetContext, setModalState, isDialog: true),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) => _filterSheetContent(
                  sheetContext,
                  setModalState,
                  isDialog: false,
                  scrollController: scrollController,
                ),
              );
            },
          );
        },
      );
    }
  }

  Widget _filterSheetContent(
    BuildContext sheetContext,
    StateSetter setModalState, {
    required bool isDialog,
    ScrollController? scrollController,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isDialog)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD6D3D1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: isDialog ? 18 : 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded, color: _ink, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'ตัวกรองและจัดเรียงสินค้า',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _emerald,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasActiveFilters)
                    TextButton.icon(
                      onPressed: () {
                        _clearAllFilters();
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFFDC2626)),
                      label: const Text(
                        'รีเซ็ต',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (isDialog) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: _muted),
                      onPressed: () => Navigator.pop(sheetContext),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _line),

        // Scrollable filter options
        Flexible(
          child: ListView(
            controller: scrollController,
            shrinkWrap: isDialog,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            children: [
              // 1. หมวดหมู่สินค้า (3 คอลัมน์สมดุลเต็มจอ)
              const Text(
                'หมวดหมู่สินค้า',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _ink),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final colCount = (constraints.maxWidth / 105).floor().clamp(3, 6);
                  final itemWidth = (constraints.maxWidth - (colCount - 1) * 6) / colCount;
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _categories.map((cat) {
                      final isSelected = _category == cat;
                      return SizedBox(
                        width: itemWidth,
                        child: _gridOptionTile(
                          label: cat,
                          isSelected: isSelected,
                          fontSize: 10.5,
                          height: 36,
                          onTap: () {
                            setState(() => _category = cat);
                            setModalState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 1.5 แบรนด์สินค้า (BRAND)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'แบรนด์สินค้า (BRAND)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _ink),
                  ),
                  if (_selectedBrand != 'ทุกแบรนด์')
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedBrand = 'ทุกแบรนด์');
                        setModalState(() {});
                      },
                      child: const Text(
                        'ล้างแบรนด์',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final colCount = (constraints.maxWidth / 130).floor().clamp(2, 4);
                  final itemWidth = (constraints.maxWidth - (colCount - 1) * 6) / colCount;
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _brands.map((b) {
                      final isSelected = _selectedBrand == b;
                      final count = b == 'ทุกแบรนด์'
                          ? _activeProducts.length
                          : _activeProducts.where((p) => p.brand.toLowerCase() == b.toLowerCase()).length;
                      return SizedBox(
                        width: itemWidth,
                        child: _gridOptionTile(
                          label: '$b ($count)',
                          isSelected: isSelected,
                          selectedColor: Colors.black,
                          fontSize: 11,
                          height: 36,
                          onTap: () {
                            setState(() => _selectedBrand = b);
                            setModalState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 2. สาขาคลังสินค้า (LOCATION - 2 คอลัมน์สมดุลเต็มจอ)
              const Text(
                'สาขาคลังสินค้า (LOCATION)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _ink),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final colCount = (constraints.maxWidth / 150).floor().clamp(2, 4);
                  final itemWidth = (constraints.maxWidth - (colCount - 1) * 6) / colCount;
                  final branchItems = [
                    (id: null, name: 'ทุกสาขาทั่วประเทศ (ALL)'),
                    (id: _currentBranchId, name: 'สาขาเรา ($_currentBranchName)'),
                    ..._branches.where((b) => b.id != _currentBranchId).map((b) => (id: b.id as int?, name: b.name)),
                  ];
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: branchItems.map((b) {
                      final isSelected = _filterLocation == b.id;
                      return SizedBox(
                        width: itemWidth,
                        child: _gridOptionTile(
                          label: b.name,
                          isSelected: isSelected,
                          selectedColor: Colors.black,
                          fontSize: 11,
                          height: 36,
                          onTap: () {
                            setState(() => _filterLocation = b.id);
                            setModalState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 3. สถานะสต็อกสินค้า (2 คอลัมน์สมดุลเต็มจอ)
              const Text(
                'สถานะสต็อกสินค้า',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _ink),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final colCount = (constraints.maxWidth / 150).floor().clamp(2, 4);
                  final itemWidth = (constraints.maxWidth - (colCount - 1) * 6) / colCount;
                  final stockItems = [
                    (mode: 'ALL', label: 'ทั้งหมด'),
                    (mode: 'OWN_IN_STOCK', label: '🟢 มีของที่สาขาเรา'),
                    (mode: 'ANY_IN_STOCK', label: '📦 มีของในระบบ'),
                    (mode: 'OUT_OF_STOCK', label: '❌ สินค้าหมดทุกสาขา'),
                  ];
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: stockItems.map((s) {
                      final isSelected = _filterStockMode == s.mode;
                      return SizedBox(
                        width: itemWidth,
                        child: _gridOptionTile(
                          label: s.label,
                          isSelected: isSelected,
                          fontSize: 11,
                          height: 36,
                          onTap: () {
                            setState(() => _filterStockMode = s.mode);
                            setModalState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 4. สิทธิพิเศษ / โปรโมชั่น
              const Text(
                'ข้อเสนอพิเศษ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _ink),
              ),
              const SizedBox(height: 8),
              Material(
                color: const Color(0xFFFAFAF9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE7E5E4)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  value: _filterOnlyDiscount,
                  onChanged: (val) {
                    setState(() => _filterOnlyDiscount = val);
                    setModalState(() {});
                  },
                  activeThumbColor: _orange,
                  title: const Row(
                    children: [
                      Icon(Icons.local_offer_rounded, color: _orange, size: 18),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'เฉพาะสินค้ามีส่วนลด / โปรโมชั่น',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: _ink),
                        ),
                      ),
                    ],
                  ),
                  dense: true,
                ),
              ),
              const SizedBox(height: 18),

              // 5. เรียงลำดับตาม (2 คอลัมน์สมดุลเต็มจอ)
              const Text(
                'เรียงลำดับตาม',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _ink),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final colCount = (constraints.maxWidth / 150).floor().clamp(2, 4);
                  final itemWidth = (constraints.maxWidth - (colCount - 1) * 6) / colCount;
                  final sortItems = [
                    (mode: 'DEFAULT', label: 'ค่าเริ่มต้น (ของที่ร้านก่อน)'),
                    (mode: 'PRICE_ASC', label: 'ราคา: ต่ำ ➜ สูง'),
                    (mode: 'PRICE_DESC', label: 'ราคา: สูง ➜ ต่ำ'),
                    (mode: 'STOCK_DESC', label: 'สต็อกรวมมากสุด'),
                  ];
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: sortItems.map((s) {
                      final isSelected = _sortBy == s.mode;
                      return SizedBox(
                        width: itemWidth,
                        child: _gridOptionTile(
                          label: s.label,
                          isSelected: isSelected,
                          selectedColor: _blue,
                          fontSize: 11,
                          height: 36,
                          onTap: () {
                            setState(() => _sortBy = s.mode);
                            setModalState(() {});
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),

        // Apply Button at bottom
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _line)),
          ),
          child: SafeArea(
            child: FilledButton(
              onPressed: () => Navigator.pop(sheetContext),
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'ดูผลลัพธ์ (${_visibleProducts.length} รายการ)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gridOptionTile({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color selectedColor = _ink,
    double height = 36,
    double fontSize = 11,
    int maxLines = 2,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : const Color(0xFFF5F5F4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? selectedColor : const Color(0xFFE7E5E4),
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.white : _ink,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1.15,
          ),
        ),
      ),
    );
  }

  Widget _searchAndFilterBar() {
    final isFocused = _searchFocusNode.hasFocus;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFocused ? Colors.black : _line,
            width: isFocused ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isFocused
                  ? const Color(0x14000000)
                  : const Color(0x06000000),
              blurRadius: isFocused ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              Icons.search_rounded,
              color: isFocused ? Colors.black : _muted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                cursorColor: Colors.black,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Colors.black,
                ),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: _catalogType == 'FURNITURE'
                      ? 'ค้นหาเฟอร์นิเจอร์ หรือ SKU...'
                      : (_catalogType == 'SLAB'
                          ? 'ค้นหาแผ่นไม้ สแลป หรือ SKU...'
                          : 'ค้นหาสินค้า พรอพ หรือ SKU...'),
                  hintStyle: const TextStyle(
                    color: Color(0xFFA8A29E),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            if (_search.isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _search = '');
                },
                tooltip: 'ล้างคำค้นหา',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Container(
                  width: 19,
                  height: 19,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            // ปุ่มกล้องสแกนบาร์โค้ด / QR Code
            Padding(
              padding: const EdgeInsets.only(right: 6, left: 4),
              child: Tooltip(
                message: 'สแกนบาร์โค้ด / QR Code',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _openBarcodeScannerModal();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFF1E293B),
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBarcodeScannerModal() async {
    final result = await showDialog<({String code, bool autoAdd})>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => const _BarcodeScannerDialog(),
    );

    if (result == null || !mounted) return;
    _handleScannedCode(result.code, autoAddToCart: result.autoAdd);
  }

  void _handleScannedCode(String rawCode, {required bool autoAddToCart}) {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    final lower = code.toLowerCase();
    final exactMatch = _activeProducts.where((p) {
      return p.sku.trim().toLowerCase() == lower ||
          p.id.toString() == lower ||
          p.name.trim().toLowerCase() == lower;
    }).firstOrNull;

    final partialMatches = _activeProducts.where((p) {
      final searchable = '${p.sku} ${p.name} ${p.id}'.toLowerCase();
      return searchable.contains(lower);
    }).toList();

    if (autoAddToCart) {
      final target = exactMatch ?? (partialMatches.length == 1 ? partialMatches.first : null);
      if (target != null) {
        _handleAddToCart(target);
        _showMessage('สแกนพบสินค้า "${target.name}" (${target.sku.isEmpty ? "#${target.id}" : target.sku})');
        return;
      }
    }

    setState(() {
      _category = 'ทั้งหมด';
      _searchController.text = code;
    });

    if (partialMatches.isEmpty) {
      _showMessage('ไม่พบสินค้ารหัส "$code" ในระบบ');
    } else {
      _showMessage('ค้นพบรหัส "$code" จำนวน ${partialMatches.length} รายการ');
    }
  }

  Widget _categoryBar() => SizedBox(
    height: 42,
    child: Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && _categoryScrollController.hasClients) {
          final delta = event.scrollDelta.dy != 0
              ? event.scrollDelta.dy
              : event.scrollDelta.dx;
          final target = (_categoryScrollController.offset + delta).clamp(
            0.0,
            _categoryScrollController.position.maxScrollExtent,
          );
          _categoryScrollController.jumpTo(target);
        }
      },
      child: ListView(
        controller: _categoryScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        scrollDirection: Axis.horizontal,
        children: [
          // ปุ่มล้างตัวกรองด่วน (แสดงเมื่อมีการตั้งค่าตัวกรองอยู่)
          if (_hasActiveFilters) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                label: Text('ล้างตัวกรอง ($_activeFilterCount)'),
                onPressed: _clearAllFilters,
                backgroundColor: const Color(0xFFFEF2F2),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                labelStyle: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          // ปุ่มลัด: มีของที่ร้าน
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: _filterStockMode == 'OWN_IN_STOCK',
              label: const Text('มีของที่ร้าน'),
              avatar: Icon(
                Icons.check_circle_outline_rounded,
                size: 14,
                color: _filterStockMode == 'OWN_IN_STOCK' ? Colors.white : _muted,
              ),
              onSelected: (val) {
                setState(() {
                  _filterStockMode = val ? 'OWN_IN_STOCK' : 'ALL';
                });
              },
              selectedColor: Colors.black,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _filterStockMode == 'OWN_IN_STOCK' ? Colors.black : _line,
              ),
              labelStyle: TextStyle(
                color: _filterStockMode == 'OWN_IN_STOCK' ? Colors.white : _ink,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              showCheckmark: false,
            ),
          ),

          // ปุ่มลัด: ลดราคา / โปรโมชั่น
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: _filterOnlyDiscount,
              label: const Text('ลดราคา'),
              avatar: Icon(
                Icons.local_offer_outlined,
                size: 14,
                color: _filterOnlyDiscount ? Colors.white : _muted,
              ),
              onSelected: (val) {
                setState(() => _filterOnlyDiscount = val);
              },
              selectedColor: Colors.black,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _filterOnlyDiscount ? Colors.black : _line,
              ),
              labelStyle: TextStyle(
                color: _filterOnlyDiscount ? Colors.white : _ink,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              showCheckmark: false,
            ),
          ),

          // ปุ่มลัด: แบรนด์สินค้า (Brand Filter)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: _selectedBrand != 'ทุกแบรนด์',
              label: Text(
                _selectedBrand == 'ทุกแบรนด์' ? 'แบรนด์' : 'แบรนด์: $_selectedBrand',
              ),
              avatar: Icon(
                Icons.sell_outlined,
                size: 14,
                color: _selectedBrand != 'ทุกแบรนด์' ? Colors.white : _muted,
              ),
              onSelected: (_) => _showBrandPickerModal(),
              selectedColor: Colors.black,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _selectedBrand != 'ทุกแบรนด์' ? Colors.black : _line,
              ),
              labelStyle: TextStyle(
                color: _selectedBrand != 'ทุกแบรนด์' ? Colors.white : _ink,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              showCheckmark: false,
            ),
          ),

          // เส้นแบ่งบางๆ ระหว่างตัวกรองด่วนกับหมวดหมู่
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
            color: _line,
          ),

          // หมวดหมู่สินค้าทั้งหมด
          ..._categories.map((category) {
            final selected = category == _category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                label: Text(category),
                onSelected: (_) => setState(() => _category = category),
                selectedColor: _ink,
                backgroundColor: Colors.white,
                side: BorderSide(color: selected ? Colors.black : _line),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );

  Widget _productGrid() {
    if (_catalogType == 'FURNITURE') {
      if (_isLoadingFurniture && _furnitureProducts.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_furnitureLoadError != null && _furnitureProducts.isEmpty) {
        return _EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'โหลดเฟอร์นิเจอร์ไม่สำเร็จ',
          description: _furnitureLoadError!,
          actionLabel: 'ลองใหม่',
          onAction: () => _loadFurnitureProducts(force: true),
        );
      }
    } else if (_catalogType == 'SLAB') {
      if (_isLoadingSlabs && _slabProducts.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_slabsLoadError != null && _slabProducts.isEmpty) {
        return _EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'โหลดแผ่นไม้/สแลปไม่สำเร็จ',
          description: _slabsLoadError!,
          actionLabel: 'ลองใหม่',
          onAction: () => _loadSlabsProducts(force: true),
        );
      }
    } else {
      if (_isLoading) return const Center(child: CircularProgressIndicator());
      if (_loadError != null) {
        return _EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'โหลดสินค้าไม่สำเร็จ',
          description: _loadError!,
          actionLabel: 'ลองใหม่',
          onAction: _loadProducts,
        );
      }
    }
    if (_visibleProducts.isEmpty) {
      return _EmptyState(
        icon: _catalogType == 'FURNITURE'
            ? Icons.chair_outlined
            : (_catalogType == 'SLAB'
                ? Icons.table_restaurant_outlined
                : Icons.inventory_2_outlined),
        title: _catalogType == 'FURNITURE'
            ? 'ไม่พบเฟอร์นิเจอร์'
            : (_catalogType == 'SLAB' ? 'ไม่พบไม้แผ่น/สแลป' : 'ไม่พบสินค้า'),
        description: _hasActiveFilters
            ? 'ลองปรับเปลี่ยนหรือล้างตัวกรองสินค้า'
            : 'ลองเปลี่ยนคำค้นหาหรือหมวดหมู่',
        actionLabel: _hasActiveFilters ? 'ล้างตัวกรองทั้งหมด' : null,
        onAction: _hasActiveFilters ? _clearAllFilters : null,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = (constraints.maxWidth / 110).floor().clamp(4, 10);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.76,
          ),
          itemCount: _visibleProducts.length,
          itemBuilder: (context, index) => _ProductCard(
            product: _visibleProducts[index],
            onTap: () => _handleAddToCart(_visibleProducts[index]),
            onLongPress: () => _showBranchPicker(_visibleProducts[index]),
          ),
        );
      },
    );
  }

  Widget _cartPanel() => Container(
    decoration: _panelDecoration(radius: 22),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        _fulfillmentModeToggle(),
        _cartHeader(),
        const Divider(height: 1, color: _line),
        Expanded(
          child: _cart.isEmpty
              ? const _EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'ยังไม่มีสินค้าในใบเสนอราคา',
                  description: 'เลือกสินค้าจากรายการด้านซ้ายเพื่อทำรายการ',
                )
              : _cartItems(),
        ),
        const Divider(height: 1, color: _line),
        _cartSummary(),
      ],
    ),
  );

  Widget _fulfillmentModeToggle() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeChoiceChip(
              label: 'รับหน้าร้าน',
              icon: Icons.storefront_rounded,
              selected: _saleMode == 'TAKE_AWAY',
              onTap: () {
                if (_crossItemCount > 0) {
                  _showMessage('มีรายการขายข้ามสาขา ต้องจัดส่งสินค้าเท่านั้นครับ');
                  return;
                }
                _syncState(() => _saleMode = 'TAKE_AWAY');
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _modeChoiceChip(
              label: 'ให้ร้านส่งให้',
              icon: Icons.local_shipping_rounded,
              selected: _saleMode == 'DELIVERY',
              onTap: () => _syncState(() => _saleMode = 'DELIVERY'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1E293B),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'สรุปรายการใบเสนอราคา',
              style: TextStyle(
                fontSize: 16,
                color: _ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (_cart.isNotEmpty)
            IconButton(
              onPressed: () => _syncState(() {
                _cart.clear();
                _appliedCoupon = null;
                _couponController.clear();
                _specialDiscountBahtController.clear();
                _specialDiscountPercentController.clear();
              }),
              tooltip: 'ล้างรายการ',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFE11D48),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cartItems() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
    itemCount: _cart.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final item = _cart[index];
      return _CartItemWidget(
        item: item,
        onChange: (change) => _changeQuantity(item, change),
        onTapBranch: () => _showBranchPicker(item.product),
      );
    },
  );

  Widget _cartSummary() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    child: _cartSummaryContent(),
  );

  Widget _cartSummaryContent() {
    final hasCoupon = _appliedCoupon != null;
    final hasSpecial = _totalSpecialDiscountAmount != 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. ข้อมูลลูกค้า (ดีไซน์เรียบหรูตามแบบ Web POS)
        InkWell(
          onTap: _openCustomerForm,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _customerName.isNotEmpty ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _customerName.isNotEmpty ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _saleMode == 'DELIVERY' ? Icons.local_shipping_outlined : Icons.storefront_outlined,
                  size: 16,
                  color: _saleMode == 'DELIVERY' ? const Color(0xFFD97706) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _saleMode == 'DELIVERY' ? 'ข้อมูลสำหรับจัดส่ง' : 'ลูกค้ารับหน้าร้าน',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFA1A1AA),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _customerName.isEmpty ? 'ยังไม่ได้ระบุลูกค้า' : _customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _customerName.isNotEmpty ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _customerName.isEmpty ? 'ระบุลูกค้า' : 'แก้ไข',
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 15, color: Color(0xFFD97706)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 2. แถบปุ่มส่วนลด & คูปอง (แตะเพื่อเปิด Modal ส่วนลด)
        _discountSummaryBar(),

        // 3. แจ้งรายละเอียดส่วนลด (ถ้ามีส่วนลด)
        if (hasCoupon || hasSpecial) ...[
          const SizedBox(height: 8),
          _summaryLine('ยอดรวมสินค้า', _money(_subtotal)),
          if (hasCoupon) ...[
            const SizedBox(height: 4),
            _summaryLine('ส่วนลดคูปอง (${_appliedCoupon!.code})', '-${_money(_couponDiscount)}', isDiscount: true),
          ],
          if (hasSpecial) ...[
            const SizedBox(height: 4),
            _summaryLine(
              _totalSpecialDiscountAmount > 0 ? 'ส่วนลดพิเศษท้ายบิล' : 'ปัดเศษเพิ่ม',
              '${_totalSpecialDiscountAmount > 0 ? "-" : "+"}${_money(_totalSpecialDiscountAmount.abs())}',
              isDiscount: _totalSpecialDiscountAmount > 0,
            ),
          ],
        ],

        const SizedBox(height: 8),
        const Divider(height: 1, color: _line),
        const SizedBox(height: 8),

        // 4. ยอดสุทธิ + สรุปย่อ
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ยอดสุทธิใบขาย (Grand Total)',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'รวม $_itemCount ชิ้น • VAT 7% ${_money(_vatAmount)}',
                  style: const TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
            Text(
              _money(_netTotal),
              style: const TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 5. ปุ่มสร้างใบเสนอราคา
        SizedBox(
          width: double.infinity,
          height: 46,
          child: FilledButton.icon(
            onPressed: _cart.isEmpty || _isProcessing ? null : _handleAction,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.description_outlined, size: 17),
            label: Text(
              _isProcessing ? 'กำลังบันทึก...' : 'สร้างใบเสนอราคา',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeChoiceChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) => Material(
    color: selected ? const Color(0xFF1E293B) : Colors.white,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF334155),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _summaryLine(String label, String value, {bool isDiscount = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: isDiscount ? const Color(0xFFDC2626) : _muted,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: isDiscount ? const Color(0xFFDC2626) : _ink,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    ],
  );

  Widget _mobileCartBar() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      child: ScaleTransition(
        scale: _cartBounceAnimation,
        child: Material(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (sheetContext) => StatefulBuilder(
                  builder: (context, setSheetState) {
                    _mobileCartSheetStateSetter = setSheetState;
                    return DraggableScrollableSheet(
                      initialChildSize: .82,
                      minChildSize: .45,
                      maxChildSize: .95,
                      builder: (_, controller) => _mobileCartSheet(controller),
                    );
                  },
                ),
              );
              _mobileCartSheetStateSetter = null;
              if (mounted) setState(() {});
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: Colors.white,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_itemCount รายการ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _crossItemCount > 0
                              ? 'ข้ามสาขา $_crossItemCount ชิ้น'
                              : 'สร้างใบเสนอราคา / เช็คบิล',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontWeight: FontWeight.w500,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _money(_netTotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _mobileCartSheet(ScrollController controller) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(
      children: [
        Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFD6D3D1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        _fulfillmentModeToggle(),
        _cartHeader(),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              if (_cart.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: _EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'ยังไม่มีสินค้า',
                    description: 'เลือกสินค้าจากหน้า POS',
                  ),
                )
              else ...[
                for (final item in _cart)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CartItemWidget(
                      item: item,
                      onChange: (change) => _changeQuantity(item, change),
                      onTapBranch: () => _showBranchPicker(item.product),
                    ),
                  ),
              ],
              const Divider(height: 20, color: _line),
              _cartSummaryContent(),
            ],
          ),
        ),
      ],
    ),
  );

  void _showMenu(BuildContext anchorContext) {
    showModalBottomSheet<void>(
      context: anchorContext,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: _ink,
                child: Icon(Icons.person_rounded, color: Colors.white),
              ),
              title: Text(
                widget.user.fullName ?? widget.user.email ?? 'ผู้ใช้งาน',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${widget.user.role} • $_currentBranchName',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.arrow_back_rounded,
                color: _emerald,
              ),
              title: const Text(
                'กลับหน้าหลัก HR',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openDispatchScreen([String? orderCode]) {
    HapticFeedback.selectionClick();
    if (widget.onNavigateToDispatch != null) {
      widget.onNavigateToDispatch!(orderCode);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VanguardDispatchScreen(
            user: widget.user,
            authService: widget.authService,
            initialSearchCode: orderCode,
            onNavigateToQuote: () => Navigator.of(context).pop(),
            onBackToPos: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onLongPress,
  });

  final PosProduct product;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isCustomOrMadeToOrder =
        product.isFurniture || product.isSlab || product.isExternal;
    final hasOwnStock = product.ownBranchQty > 0 || isCustomOrMadeToOrder;
    final hasOtherStock = product.otherBranchQty > 0;
    final hasAnyStock = product.hasAnyStock || isCustomOrMadeToOrder;

    return AnimatedScale(
      scale: _isPressed ? 0.93 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(
                color: isCustomOrMadeToOrder
                    ? const Color(0xFFE2E8F0)
                    : (!hasAnyStock
                        ? const Color(0xFFFEE2E2)
                        : (hasOwnStock ? const Color(0xFFE2E8F0) : const Color(0xFFFED7AA))),
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: Container(
                          color: const Color(0xFFFBFBFA),
                          child: _ProductImage(
                            imageUrl: product.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                product.price > 0 ? _formatCardPrice(product.price) : 'ระบุราคาตอนขาย',
                                maxLines: 1,
                                style: TextStyle(
                                  color: product.hasDiscount
                                      ? const Color(0xFFE11D48)
                                      : (product.price > 0 ? _ink : const Color(0xFF2563EB)),
                                  fontWeight: FontWeight.w900,
                                  fontSize: product.price > 0 ? 10.0 : 8.0,
                                  letterSpacing: -0.2,
                                  height: 1.1,
                                ),
                              ),
                              if (product.hasDiscount) ...[
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    _formatCardPrice(product.effectiveOriginalPrice),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 7.5,
                                      decoration: TextDecoration.lineThrough,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Top-Right Stock Status Badge
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCustomOrMadeToOrder
                          ? const Color(0xFFECFDF5)
                          : (!hasAnyStock
                              ? const Color(0xFFFEF2F2)
                              : (hasOwnStock ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB))),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCustomOrMadeToOrder
                            ? const Color(0xFFA7F3D0)
                            : (!hasAnyStock
                                ? const Color(0xFFFECACA)
                                : (hasOwnStock ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A))),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: isCustomOrMadeToOrder
                        ? const Text(
                            'สั่งผลิต',
                            style: TextStyle(
                              color: _green,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          )
                        : (!hasAnyStock
                            ? const Text(
                                'หมด',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              )
                            : hasOwnStock
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${product.ownBranchQty}',
                                        style: const TextStyle(
                                          color: _green,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          height: 1,
                                        ),
                                      ),
                                      if (hasOtherStock) ...[
                                        const SizedBox(width: 2),
                                        Text(
                                          '(+${product.otherBranchQty})',
                                          style: const TextStyle(
                                            color: _orange,
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.w800,
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Text(
                                    '+${product.otherBranchQty}',
                                    style: const TextStyle(
                                      color: _orange,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  )),
                  ),
                ),
                // Top-Left Discount Tag Badge or Brand Badge
                if (product.hasDiscount)
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x20000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        product.discountLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageUrl, this.fit = BoxFit.cover});
  final String? imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFF5F5F4),
      alignment: Alignment.center,
      child: const Icon(
        Icons.chair_alt_outlined,
        color: Color(0xFFD6D3D1),
        size: 34,
      ),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: Image.network(
        imageUrl!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

class _CartItemWidget extends StatelessWidget {
  const _CartItemWidget({
    required this.item,
    required this.onChange,
    required this.onTapBranch,
  });

  final CartLineItem item;
  final ValueChanged<int> onChange;
  final VoidCallback onTapBranch;

  @override
  Widget build(BuildContext context) {
    final isCross = item.isCrossBranch;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCross ? const Color(0xFFFFFBEB) : const Color(0xFFFCFCFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCross ? const Color(0xFFFDE68A) : const Color(0xFFF0EEEB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clear Fulfillment Indicator Badge
          Row(
            children: [
              Flexible(
                child: InkWell(
                  onTap: onTapBranch,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCross ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCross ? const Color(0xFFF59E0B) : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCross ? Icons.swap_horiz_rounded : Icons.storefront_rounded,
                          size: 11,
                          color: isCross ? const Color(0xFFB45309) : const Color(0xFF065F46),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isCross
                                ? '⚡ ขายข้ามสาขา (ดึงจาก: ${item.fulfillBranchName})'
                                : '✓ ขายที่ร้านตัวเอง (${item.fulfillBranchName})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: isCross ? const Color(0xFFB45309) : const Color(0xFF065F46),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 13,
                          color: isCross ? const Color(0xFFB45309) : const Color(0xFF065F46),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _ProductImage(imageUrl: item.product.imageUrl),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _money(item.product.price * item.quantity),
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        if (item.product.hasDiscount) ...[
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _money(item.product.effectiveOriginalPrice * item.quantity),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD6D3D1)),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _qtyButton(Icons.remove_rounded, () => onChange(-1)),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _qtyButton(Icons.add_rounded, () => onChange(1)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: SizedBox(
      width: 26,
      height: 30,
      child: Icon(icon, size: 15, color: _muted),
    ),
  );
}

class _BrandPickerSheet extends StatefulWidget {
  const _BrandPickerSheet({
    required this.brands,
    required this.selectedBrand,
    required this.activeProducts,
    required this.isDialog,
    required this.onSelect,
  });

  final List<String> brands;
  final String selectedBrand;
  final List<PosProduct> activeProducts;
  final bool isDialog;
  final ValueChanged<String> onSelect;

  @override
  State<_BrandPickerSheet> createState() => _BrandPickerSheetState();
}

class _BrandPickerSheetState extends State<_BrandPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final Map<String, int> _counts;

  @override
  void initState() {
    super.initState();
    _counts = {};
    for (final b in widget.brands) {
      if (b == 'ทุกแบรนด์') {
        _counts[b] = widget.activeProducts.length;
      } else {
        _counts[b] = widget.activeProducts
            .where((p) => p.brand.toLowerCase() == b.toLowerCase())
            .length;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final specificBrands = widget.brands
        .where((b) => b != 'ทุกแบรนด์')
        .where((b) => query.isEmpty || b.toLowerCase().contains(query))
        .toList(growable: false);

    final isAllSelected = widget.selectedBrand == 'ทุกแบรนด์';
    final allCount = _counts['ทุกแบรนด์'] ?? widget.activeProducts.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.isDialog)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(18, widget.isDialog ? 18 : 6, 18, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sell_rounded, color: _ink, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'เลือกแบรนด์สินค้า',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'มีทั้งหมด ${widget.brands.length - 1} แบรนด์ (${widget.activeProducts.length} ชิ้น)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isAllSelected)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => widget.onSelect('ทุกแบรนด์'),
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFFDC2626)),
                      label: const Text(
                        'ล้างตัวกรอง',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (widget.isDialog)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: _muted),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Quick Search Bar (if brands > 6)
        if (widget.brands.length > 6)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 42,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 42),
                          splashRadius: 18,
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 42,
                  ),
                  hintText: 'ค้นหาชื่อแบรนด์...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),

        const Divider(height: 1, color: _line),

        // Content Area with LayoutBuilder
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // Responsive column count based on available screen width!
              final int crossAxisCount = (width / 165).floor().clamp(2, 5);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  // Full-width Hero Card for "ทุกแบรนด์ (ALL BRANDS)"
                  if (query.isEmpty) ...[
                    Material(
                      color: isAllSelected ? _ink : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => widget.onSelect('ทุกแบรนด์'),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isAllSelected ? _ink : const Color(0xFFE2E8F0),
                              width: isAllSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isAllSelected
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.grid_view_rounded,
                                  size: 16,
                                  color: isAllSelected ? Colors.white : _ink,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ทุกแบรนด์ (แสดงทั้งหมด)',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: isAllSelected ? Colors.white : _ink,
                                      ),
                                    ),
                                    Text(
                                      'ดูสินค้าทุกรายการ ไม่จำกัดแบรนด์',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isAllSelected
                                            ? Colors.white.withValues(alpha: 0.75)
                                            : _muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isAllSelected
                                      ? Colors.white
                                      : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$allCount ชิ้น',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: isAllSelected ? _ink : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                              if (isAllSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (specificBrands.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 8),
                            Text(
                              'ไม่พบแบรนด์ที่ตรงกับ "$_searchQuery"',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // Responsive Grid for Brands
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        mainAxisExtent: 48,
                      ),
                      itemCount: specificBrands.length,
                      itemBuilder: (context, index) {
                        final b = specificBrands[index];
                        final isSelected = widget.selectedBrand.toLowerCase() == b.toLowerCase();
                        final count = _counts[b] ?? 0;

                        return Material(
                          color: isSelected ? _ink : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => widget.onSelect(b),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? _ink : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.4 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      b,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.22)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BranchSelectSheet extends StatelessWidget {
  const _BranchSelectSheet({
    required this.product,
    required this.currentBranchId,
    required this.currentBranchName,
    required this.onSelectBranch,
    this.isDialog = false,
  });

  final PosProduct product;
  final int currentBranchId;
  final String currentBranchName;
  final void Function(int branchId, String branchName, bool isCross) onSelectBranch;
  final bool isDialog;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, isDialog ? 20 : 14, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isDialog
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDialog)
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D3D1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _ProductImage(imageUrl: product.imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'เลือกสาขาที่ต้องการขายหรือเบิกสินค้า',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (isDialog)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: _muted),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
            ],
          ),
          const Divider(height: 24),
          // Option 1: Own store
          _branchCard(
            branchName: currentBranchName,
            isOwn: true,
            qty: product.ownBranchQty,
            onTap: product.ownBranchQty > 0
                ? () => onSelectBranch(currentBranchId, currentBranchName, false)
                : null,
          ),
          const SizedBox(height: 12),
          const Text(
            'สาขาอื่นที่มีสต็อก (ขายข้ามสาขา / Drop Ship):',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _muted),
          ),
          const SizedBox(height: 6),
          if (product.crossBranchStocks.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ไม่มีสต็อกในสาขาอื่น',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            )
          else
            ...product.crossBranchStocks.map(
              (stock) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _branchCard(
                  branchName: stock.branchName,
                  isOwn: false,
                  qty: stock.qty,
                  onTap: () => onSelectBranch(stock.branchId, stock.branchName, true),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _branchCard({
    required String branchName,
    required bool isOwn,
    required int qty,
    required VoidCallback? onTap,
  }) {
    final available = qty > 0;
    return Material(
      color: isOwn ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOwn ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOwn ? Icons.storefront_rounded : Icons.swap_horiz_rounded,
                color: isOwn ? _green : _orange,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOwn ? 'ขายที่ร้านตัวเอง ($branchName)' : 'ขายข้ามสาขา ($branchName)',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: isOwn ? const Color(0xFF14532D) : const Color(0xFF78350F),
                      ),
                    ),
                    Text(
                      available ? 'คงเหลือพร้อมจำหน่าย: $qty ชิ้น' : 'สินค้าหมดในสาขานี้',
                      style: TextStyle(
                        fontSize: 10,
                        color: available ? _muted : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: isOwn ? _green : _orange,
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  available ? (isOwn ? 'ขายที่ร้าน' : 'ดึงข้ามสาขา') : 'หมด',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerSheet extends StatefulWidget {
  const _CustomerSheet({
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.companyController,
    required this.taxIdController,
    this.customOrderCodeController,
    this.companyNameEnController,
    this.companyAddressController,
    this.saleMode = 'TAKE_AWAY',
    this.isDialog = false,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController companyController;
  final TextEditingController taxIdController;
  final TextEditingController? customOrderCodeController;
  final TextEditingController? companyNameEnController;
  final TextEditingController? companyAddressController;
  final String saleMode;
  final bool isDialog;

  @override
  State<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<_CustomerSheet> {
  bool _showTaxSection = false;

  @override
  void initState() {
    super.initState();
    if (widget.companyController.text.isNotEmpty ||
        widget.taxIdController.text.isNotEmpty ||
        widget.companyNameEnController?.text.isNotEmpty == true ||
        widget.companyAddressController?.text.isNotEmpty == true) {
      _showTaxSection = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDelivery = widget.saleMode == 'DELIVERY';

    final content = Padding(
      padding: EdgeInsets.fromLTRB(20, widget.isDialog ? 20 : 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.isDialog)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D3D1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isDelivery ? Icons.local_shipping_rounded : Icons.storefront_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDelivery ? 'ระบุข้อมูลสำหรับจัดส่งสินค้า' : 'ระบุข้อมูลลูกค้ารับหน้าร้าน',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            isDelivery
                                ? 'กรอกที่อยู่ปลายทาง สำหรับออกบิลและจัดส่งสินค้า'
                                : 'บันทึกชื่อลูกค้าและข้อมูลสำหรับออกบิลขาย',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: _muted),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ⚡ ปุ่มลัดด่วน: ไม่ระบุเบอร์โทร/ที่อยู่ (ลูกค้าทั่วไป ใส่ "-")
          InkWell(
            onTap: () {
              if (widget.nameController.text.trim().isEmpty) {
                widget.nameController.text = 'ลูกค้าทั่วไป';
              }
              widget.phoneController.text = '-';
              widget.addressController.text = '-';
              setState(() {});
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: Colors.black),
                  SizedBox(width: 6),
                  Text(
                    '⚡ ไม่ระบุเบอร์โทร/ที่อยู่ (ลูกค้าทั่วไป ใส่ "-")',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 1. เลข Invoice / รหัสบิล (ถ้ามี)
          if (widget.customOrderCodeController != null) ...[
            _field(
              widget.customOrderCodeController!,
              'เลข Invoice / รหัสบิล',
              Icons.receipt_long_outlined,
              hintText: 'เว้นว่างเพื่อให้ระบบสร้างเลขอัตโนมัติ',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
          ],

          // 2. ชื่อลูกค้า / ผู้ติดต่อ
          _field(
            widget.nameController,
            'ชื่อลูกค้า / ผู้ติดต่อ *',
            Icons.person_outline_rounded,
            hintText: 'ระบุชื่อลูกค้า...',
          ),
          const SizedBox(height: 10),

          // 3. เบอร์โทรศัพท์
          _field(
            widget.phoneController,
            'เบอร์โทรศัพท์ติดต่อ *',
            Icons.phone_outlined,
            keyboard: TextInputType.phone,
            hintText: 'ระบุเบอร์โทร...',
          ),
          const SizedBox(height: 10),

          // 4. ที่อยู่จัดส่ง
          _field(
            widget.addressController,
            isDelivery ? 'ที่อยู่จัดส่งสินค้า *' : 'ที่อยู่ลูกค้า / รับหน้าร้าน *',
            Icons.location_on_outlined,
            lines: 3,
            hintText: 'บ้านเลขที่, ซอย, ถนน, ตำบล, อำเภอ, จังหวัด, รหัสไปรษณีย์...',
          ),

          // 5. ส่วนข้อมูลสำหรับออกใบกำกับภาษี (Toggle Expandable)
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _showTaxSection = !_showTaxSection),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _showTaxSection ? const Color(0xFFF4F4F5) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_outlined, size: 16, color: Colors.black),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ข้อมูลสำหรับออกใบกำกับภาษี (ถ้ามี)',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black),
                    ),
                  ),
                  Icon(
                    _showTaxSection ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),

          if (_showTaxSection) ...[
            const SizedBox(height: 12),
            _field(
              widget.companyController,
              'ชื่อบริษัท (ภาษาไทย)',
              Icons.domain_rounded,
              hintText: 'ระบุชื่อบริษัทภาษาไทย...',
            ),
            if (widget.companyNameEnController != null) ...[
              const SizedBox(height: 10),
              _field(
                widget.companyNameEnController!,
                'ชื่อบริษัท (ภาษาอังกฤษ - ถ้ามี)',
                Icons.language_rounded,
                hintText: 'Company Name in English...',
              ),
            ],
            const SizedBox(height: 10),
            // เลขผู้เสียภาษี 13 หลัก พร้อมตัวนับ 0/13 และ format เฉพาะตัวเลข
            _field(
              widget.taxIdController,
              'เลขประจำตัวผู้เสียภาษี (13 หลัก)',
              Icons.badge_outlined,
              keyboard: TextInputType.number,
              maxLength: 13,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              hintText: 'ระบุเลขประจำตัวผู้เสียภาษี 13 หลัก...',
              suffix: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  widthFactor: 1.0,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.taxIdController,
                    builder: (context, val, _) {
                      final len = val.text.length;
                      final isComplete = len == 13;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isComplete ? const Color(0xFFDCFCE7) : const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$len/13',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isComplete ? const Color(0xFF16A34A) : _muted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (widget.companyAddressController != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ที่อยู่บริษัทสำหรับออกใบกำกับภาษี',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      widget.companyAddressController!.text = widget.addressController.text;
                      setState(() {});
                    },
                    icon: const Icon(Icons.copy_rounded, size: 12, color: Colors.black),
                    label: const Text('ใช้ที่อยู่เดียวกับที่จัดส่ง', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.black)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _field(
                widget.companyAddressController!,
                'ที่อยู่บริษัท',
                Icons.location_city_outlined,
                lines: 2,
                hintText: 'ระบุที่อยู่บริษัทสำหรับออกใบกำกับภาษี...',
              ),
            ],
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: _line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'บันทึกข้อมูลลูกค้า',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.isDialog) {
      return SingleChildScrollView(child: content);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(child: content),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int lines = 1,
    int? maxLength,
    List<TextInputFormatter>? formatters,
    Widget? suffix,
    String? hintText,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) => TextField(
    controller: controller,
    keyboardType: keyboard,
    minLines: lines,
    maxLines: lines,
    maxLength: maxLength,
    inputFormatters: formatters,
    textCapitalization: textCapitalization,
    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black),
    decoration: InputDecoration(
      labelText: label,
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFA1A1AA)),
      labelStyle: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, size: 18, color: _muted),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFD6D3D1), size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          if (onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel ?? 'ลองใหม่'),
            ),
          ],
        ],
      ),
    ),
  );
}

BoxDecoration _panelDecoration({required double radius}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: _line),
  boxShadow: const [
    BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 5)),
  ],
);

String _money(double value) {
  final isNeg = value < 0;
  final parts = value.abs().toStringAsFixed(2).split('.');
  final intPart = parts[0].replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',');
  return '${isNeg ? "-" : ""}฿$intPart.${parts[1]}';
}

String _formatCardPrice(double value) {
  if (value <= 0) return '฿0';
  if (value % 1 == 0) {
    final intVal = value.toInt();
    final str = intVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '฿$str';
  }
  final parts = value.toStringAsFixed(2).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
  return '฿$intPart.${parts[1]}';
}

class _BarcodeScannerDialog extends StatefulWidget {
  const _BarcodeScannerDialog();

  @override
  State<_BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<_BarcodeScannerDialog> {
  late final MobileScannerController _scannerController;
  final TextEditingController _manualCodeController = TextEditingController();
  bool _autoAddToCart = true;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.all],
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  void _submitCode(String raw) {
    if (_hasScanned) return;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    _hasScanned = true;
    Navigator.of(context).pop((code: trimmed, autoAdd: _autoAddToCart));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header (Light & Clean) ──
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE7E5E4))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: _emerald,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'สแกนบาร์โค้ด / QR Code',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'รองรับทั้ง Barcode 1D และ QR Code สินค้า',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: _muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _scannerController.switchCamera(),
                      tooltip: 'สลับกล้องหน้า/หลัง',
                      icon: const Icon(Icons.cameraswitch_rounded, size: 19),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F4),
                        foregroundColor: _ink,
                        minimumSize: const Size(34, 34),
                        padding: const EdgeInsets.all(7),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => _scannerController.toggleTorch(),
                      tooltip: 'เปิด/ปิดไฟฉาย',
                      icon: const Icon(Icons.flashlight_on_rounded, size: 19),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F4),
                        foregroundColor: _ink,
                        minimumSize: const Size(34, 34),
                        padding: const EdgeInsets.all(7),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'ปิดหน้าต่าง',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F4),
                        foregroundColor: _muted,
                        minimumSize: const Size(34, 34),
                        padding: const EdgeInsets.all(7),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Live Camera Scanner Box
                    SizedBox(
                      height: 270,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: const Color(0xFF18181B)),
                            MobileScanner(
                              controller: _scannerController,
                              onDetect: (capture) {
                                for (final barcode in capture.barcodes) {
                                  final raw = barcode.rawValue;
                                  if (raw != null && raw.trim().isNotEmpty) {
                                    _submitCode(raw);
                                    break;
                                  }
                                }
                              },
                              errorBuilder: (context, error) {
                                return Container(
                                  color: const Color(0xFFF8FAFC),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFBFDBFE)),
                                        ),
                                        child: const Icon(
                                          Icons.videocam_off_outlined,
                                          color: _emerald,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'ยังไม่สามารถเข้าถึงกล้องได้',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: _ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'กรุณาอนุญาตสิทธิ์การใช้กล้องในเบราว์เซอร์/อุปกรณ์ หรือใช้ช่องพิมพ์รหัสบาร์โค้ดด้านล่าง (${error.errorCode.name})',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: _muted,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: () => _scannerController.start(),
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('ลองเปิดกล้องอีกครั้ง'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _emerald,
                                          side: const BorderSide(color: _emerald),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            // Scanner Target Frame Overlay
                            IgnorePointer(
                              child: Center(
                                child: Container(
                                  width: 210,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF10B981),
                                      width: 2.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Bottom instruction pill inside camera
                            Positioned(
                              bottom: 12,
                              left: 16,
                              right: 16,
                              child: IgnorePointer(
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.62),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.center_focus_strong_rounded, size: 14, color: Colors.white),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'จัดวางบาร์โค้ด หรือ QR Code ให้อยู่ในกรอบสีเขียว',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Scan Action Mode Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE7E5E4)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _autoAddToCart = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _autoAddToCart ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _autoAddToCart
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x12000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 15,
                                      color: _autoAddToCart ? _emerald : _muted,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'หยิบใส่ตะกร้าทันที',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: _autoAddToCart ? _emerald : _muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _autoAddToCart = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_autoAddToCart ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: !_autoAddToCart
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x12000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      size: 15,
                                      color: !_autoAddToCart ? _ink : _muted,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        'ค้นหาสินค้าอย่างเดียว',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: !_autoAddToCart ? _ink : _muted,
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

                    const SizedBox(height: 14),

                    // 3. Manual / USB Scanner Code Entry
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _manualCodeController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: _submitCode,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                hintText: 'หรือพิมพ์ / ยิงบาร์โค้ด SKU ที่นี่...',
                                hintStyle: const TextStyle(fontSize: 12, color: _muted),
                                prefixIcon: const Icon(Icons.keyboard_alt_outlined, size: 18, color: _muted),
                                filled: true,
                                fillColor: const Color(0xFFFAFAF9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE7E5E4)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: _emerald, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: () => _submitCode(_manualCodeController.text),
                            style: FilledButton.styleFrom(
                              backgroundColor: _emerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 17),
                            label: const Text(
                              'ตกลง',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
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
      ),
    );
  }
}


// =========================================================================
// 10. QUOTATION CONFIRMATION & SUCCESS BOTTOM SHEETS / DIALOGS
// =========================================================================

class _QuotationConfirmModalContent extends StatelessWidget {
  const _QuotationConfirmModalContent({
    required this.customerName,
    required this.saleModeLabel,
    required this.isDelivery,
    this.hasSlab = false,
    required this.itemCount,
    required this.localItemCount,
    required this.crossItemCount,
    required this.subtotal,
    required this.couponCode,
    required this.couponDiscount,
    required this.specialDiscountAmount,
    required this.vatAmount,
    required this.netTotal,
    required this.isDialog,
    required this.onConfirm,
    required this.onCancel,
  });

  final String customerName;
  final String saleModeLabel;
  final bool isDelivery;
  final bool hasSlab;
  final int itemCount;
  final int localItemCount;
  final int crossItemCount;
  final double subtotal;
  final String? couponCode;
  final double couponDiscount;
  final double specialDiscountAmount;
  final double vatAmount;
  final double netTotal;
  final bool isDialog;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDialog)
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: _ink, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'ยืนยันสร้างใบเสนอราคา',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'ตรวจสอบข้อมูลรายการและยอดสุทธิก่อนบันทึก',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 20, color: _muted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _line),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // การ์ดข้อมูลลูกค้าและการจัดส่ง
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          const Text(
                            'ลูกค้า:',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Expanded(
                            flex: 2,
                            child: Text(
                              customerName.isEmpty ? 'ลูกค้าทั่วไป (Walk-in)' : customerName,
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      Row(
                        children: [
                          Icon(
                            isDelivery ? Icons.local_shipping_outlined : Icons.storefront_outlined,
                            size: 16,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'การรับสินค้า:',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDelivery ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDelivery ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              saleModeLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isDelivery ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          const Text(
                            'จำนวนสินค้า:',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$itemCount ชิ้น',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ที่ร้าน: $localItemCount',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                ),
                              ),
                              if (crossItemCount > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ข้ามสาขา: $crossItemCount',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (crossItemCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFD97706)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'มีสินค้าข้ามสาขา ระบบจะสร้างใบเบิกแพ็คให้อัตโนมัติ',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // การ์ดสรุปยอดเงิน
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ยอดรวมสินค้า', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          Text(_money(subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                        ],
                      ),
                      if (couponDiscount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ส่วนลดคูปอง ${couponCode != null && couponCode!.isNotEmpty ? "($couponCode)" : ""}',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '-${_money(couponDiscount)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      ],
                      if (specialDiscountAmount != 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              specialDiscountAmount > 0 ? 'ส่วนลดพิเศษท้ายบิล' : 'ปัดเศษเพิ่ม',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: specialDiscountAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${specialDiscountAmount > 0 ? "-" : "+"}${_money(specialDiscountAmount.abs())}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: specialDiscountAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (vatAmount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('VAT 7% (รวมในยอดแล้ว)', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                            Text(_money(vatAmount), style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                      if (hasSlab) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('ค่าใบกำกับไม้ (Slab)', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            Text(_money(5000.0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                          ],
                        ),
                        const Divider(height: 18, color: Color(0xFFE2E8F0)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF9C3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFACC15), width: 1.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total (รวมใบกำกับไม้)',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF713F12)),
                              ),
                              Text(
                                _money(netTotal + 5000.0),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF713F12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDD6FE).withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC4B5FD)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'ยอดมัดจำ',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E1065)),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFB4A5D9),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          '50%',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2E1065)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _money((netTotal + 5000.0) * 0.5),
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF2E1065)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'ยอดคงเหลือ (ก่อนส่งมอบ)',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF5B21B6)),
                                  ),
                                  Text(
                                    _money((netTotal + 5000.0) * 0.5),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const Divider(height: 18, color: Color(0xFFE2E8F0)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              'ยอดสุทธิใบเสนอราคา',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _ink),
                            ),
                            Text(
                              _money(netTotal),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _ink,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // ข้อความแจ้งเตือนสต็อก
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: hasSlab ? const Color(0xFFFAF5FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: hasSlab ? const Color(0xFFE9D5FF) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: hasSlab ? const Color(0xFF7E22CE) : const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasSlab
                              ? 'บิลนี้มีสินค้าไม้แผ่น Slab: ยืนยันการจองสต็อกเมื่อลูกค้าชำระมัดจำ 50% เข้า บจก. ทีพีเอส การ์เด้น เฟอร์นิเจอร์ (กสิกรไทย 033-1-08813-7)'
                              : 'ยังไม่ตัดสต็อกในขั้นตอนนี้ ระบบจะตัดสต็อกเมื่อกดยืนยันรับชำระเงินในหน้าสินค้ารอจัดส่ง',
                          style: TextStyle(fontSize: 11.5, color: hasSlab ? const Color(0xFF6B21A8) : const Color(0xFF64748B), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text(
                      'ยืนยันสร้างใบเสนอราคา',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuotationSuccessModalContent extends StatelessWidget {
  const _QuotationSuccessModalContent({
    required this.orderCode,
    required this.totalAmount,
    required this.isDialog,
    required this.onClose,
    this.onViewDispatch,
  });

  final String orderCode;
  final double totalAmount;
  final bool isDialog;
  final VoidCallback onClose;
  final VoidCallback? onViewDispatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDialog)
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 36),
              ),
              const SizedBox(height: 14),
              const Text(
                'สร้างใบเสนอราคาสำเร็จ!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'เอกสารถูกบันทึกเข้าระบบเรียบร้อยแล้ว',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'เลขที่เอกสาร:',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        Row(
                          children: [
                            Text(
                              orderCode,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: orderCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('คัดลอกเลขที่เอกสารแล้ว'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              tooltip: 'คัดลอก',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ยอดรวมสุทธิ:',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _money(totalAmount),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'บิลถูกส่งเข้าหน้า "ระบบจัดการสินค้ารอจัดส่ง" แล้ว สามารถพิมพ์ใบเสนอราคา หรือกดยืนยันรับชำระเงิน & ตัดสต็อกได้ในหน้านั้นครับ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.35),
                ),
              ),
              const SizedBox(height: 18),
              if (onViewDispatch != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onViewDispatch,
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.local_shipping_rounded, size: 18),
                    label: const Text(
                      'เปิดดูบิลในระบบจัดส่งทันที',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'ตกลง / ทำรายการต่อ (หน้า POS)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
