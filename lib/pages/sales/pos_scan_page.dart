// lib/pages/sales/pos_scan_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/sale_api_service.dart';
import '../../services/receipt_printer.dart';
import '../../widgets/stock_ui_helpers.dart';

const _blue1 = Color(0xFF1D4ED8);
const _blue2 = Color(0xFF2563EB);
const _blue3 = Color(0xFF3B82F6);
const _blue4 = Color(0xFF60A5FA);
const _bgDeep = Color(0xFF020817);
const _bgBase = Color(0xFF0A1628);
const _bgCard = Color(0xFF0D2045);
const _bgDarker = Color(0xFF071022);
const _surface = Color(0xFF0F2A4A);
const _textPrimary = Color(0xFFE2E8F0);
const _textSecondary = Color(0xFF94A3B8);

class PosScanPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final VoidCallback? onBack;
  const PosScanPage({super.key, required this.currentUser, this.onBack});
  @override
  State<PosScanPage> createState() => _PosScanPageState();
}

class _PosScanPageState extends State<PosScanPage>
    with SingleTickerProviderStateMixin {
  final _barcodeCtrl = TextEditingController();
  final _barcodeFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  final _discountCtrl = TextEditingController(text: '0');
  late AnimationController _animCtrl;

  final List<Map<String, dynamic>> _cartItems = [];
  bool _isSearching = false;
  String? _errorMsg;
  Map<String, dynamic>? _lastScanned;
  Map<String, dynamic>? _scannedProduct;
  String _paymentMethod = 'cash';
  double _discount = 0;

  // ── Printer / Drawer status ──────────────────────────────────────────
  bool _printerPaired = false;
  String _printerLabel = 'ບໍ່ໄດ້ເຊື່ອມ';

  String get _me => widget.currentUser['username']?.toString() ?? 'unknown';
  double get _subtotal => _cartItems.fold<double>(
    0.0,
    (s, i) =>
        s +
        ((num.tryParse(i['unit_price'].toString()) ?? 0) *
            (i['quantity'] as int? ?? 1)),
  );
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);

  String _fmt(dynamic v) {
    final num val = num.tryParse(v.toString()) ?? 0;
    return '₭ ${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  // ── LIFECYCLE ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();

    // Register status callback
    ReceiptPrinter.setStatusCallback((paired, label) {
      if (mounted)
        setState(() {
          _printerPaired = paired;
          _printerLabel = label;
        });
    });

    // Auto-connect on page open
    ReceiptPrinter.refreshStatus();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _barcodeFocus.requestFocus(),
    );
    _discountCtrl.addListener(
      () => setState(
        () => _discount = (num.tryParse(_discountCtrl.text) ?? 0).toDouble(),
      ),
    );
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _barcodeFocus.dispose();
    _scrollCtrl.dispose();
    _discountCtrl.dispose();
    _animCtrl.dispose();
    ReceiptPrinter.stopPolling();
    super.dispose();
  }

  // ── BARCODE LOOKUP ────────────────────────────────────────────────────
  Future<void> _onBarcodeSubmit() async {
    final code = _barcodeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _isSearching = true;
      _errorMsg = null;
      _lastScanned = null;
      _scannedProduct = null;
    });
    debugPrint('=== SCAN BARCODE: $code ===');
    try {
      final res = await SaleApiService.getProductByBarcode(code);
      debugPrint('=== BARCODE RESPONSE: $res ===');
      if (!mounted) return;
      if (res['responseCode'] == '00') {
        final product = res['data'] as Map<String, dynamic>;
        setState(() => _scannedProduct = product);
        _addToCart(product);
        _barcodeCtrl.clear();
        _barcodeFocus.requestFocus();
      } else {
        setState(
          () => _errorMsg = res['message'] ?? 'Product not found: $code',
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _errorMsg = null);
        });
        _barcodeCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _barcodeCtrl.text.length,
        );
        _barcodeFocus.requestFocus();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    final productId = product['product_id'] ?? product['id'];
    final existingIdx = _cartItems.indexWhere(
      (i) => i['product_id'] == productId,
    );
    final unitPrice =
        num.tryParse(
          (product['selling_price'] ??
                  product['sale_price'] ??
                  product['price'] ??
                  0)
              .toString(),
        ) ??
        0;
    final name = product['product_name_la'] ?? product['product_name'] ?? '-';
    final code = product['product_code'] ?? product['barcode'] ?? '';
    final stock = product['current_stock'] ?? 0;
    setState(() {
      if (existingIdx >= 0) {
        _cartItems[existingIdx]['quantity'] =
            (_cartItems[existingIdx]['quantity'] as int) + 1;
        _lastScanned = _cartItems[existingIdx];
      } else {
        final item = {
          'product_id': productId,
          'product_code': code,
          'product_name': product['product_name'] ?? '-',
          'product_name_la':
              product['product_name_la'] ?? product['product_name'] ?? '-',
          'display_name': name,
          'unit_price': unitPrice,
          'unit_name': product['unit_name'] ?? '',
          'category_name':
              product['category_name_la'] ?? product['category_name'] ?? '',
          'current_stock': stock,
          'quantity': 1,
        };
        _cartItems.insert(0, item);
        _lastScanned = item;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients)
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
    });
  }

  void _updateQty(int index, int newQty) {
    if (newQty <= 0)
      setState(() => _cartItems.removeAt(index));
    else
      setState(() => _cartItems[index]['quantity'] = newQty);
  }

  void _removeItem(int index) => setState(() => _cartItems.removeAt(index));

  // ── SUBMIT SALE ───────────────────────────────────────────────────────
  Future<void> _submitSale() async {
    if (_cartItems.isEmpty) return;
    final confirmed = await showStockConfirmDialog(
      context,
      title: 'ຢືນຢັນການຂາຍ',
      message: 'ຍອດລວມ: ${_fmt(_total)}\nຊຳລະດ້ວຍ: $_paymentMethod',
      confirmLabel: 'ຢືນຢັນ',
      confirmColor: StockTheme.success,
    );
    if (!confirmed) return;

    final body = {
      'payment_method': _paymentMethod,
      'discount_amount': _discount,
      'total_amount': _total,
      'created_by': _me,
      'cashier_id': widget.currentUser['user_id'] ?? widget.currentUser['id'],
      'cashier': widget.currentUser['full_name'] ?? _me,
      'items': _cartItems
          .map(
            (item) => {
              'product_id': item['product_id'],
              'product_code': item['product_code'] ?? '',
              'product_name': item['product_name'] ?? '',
              'quantity': item['quantity'],
              'unit_price': item['unit_price'],
              'subtotal':
                  (num.tryParse(item['unit_price'].toString()) ?? 0) *
                  (item['quantity'] as int? ?? 1),
            },
          )
          .toList(),
    };

    debugPrint('=== POS SUBMIT: $body ===');
    try {
      final res = await SaleApiService.createSale(body);
      debugPrint('=== POS RESPONSE: $res ===');
      if (!mounted) return;
      if (res['responseCode'] == '00') {
        _showSuccessDialog(res['data']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'),
            backgroundColor: StockTheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: StockTheme.error,
        ),
      );
    }
  }

  // ── SUCCESS DIALOG ────────────────────────────────────────────────────
  void _showSuccessDialog(Map<String, dynamic>? data) {
    final printItems = List<Map<String, dynamic>>.from(_cartItems);
    final printSale = {
      'sale_number': data?['sale_number'] ?? '',
      'cashier': widget.currentUser['full_name'] ?? _me,
      'created_by': _me,
      'sale_date':
          data?['created_at'] ??
          data?['sale_date'] ??
          DateTime.now().toIso8601String(),
      'payment_method': _paymentMethod,
      'discount_amount': _discount,
      'total_amount': _total,
      'items': printItems,
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgCard.withOpacity(0.98), _surface.withOpacity(0.98)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: StockTheme.success.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: _blue2.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: StockTheme.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: StockTheme.success.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: StockTheme.success,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ການຂາຍສຳເລັດ!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (data?['sale_number'] != null)
                Text(
                  'ເລກທີ: ${data!['sale_number']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondary.withOpacity(0.7),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                _fmt(_total),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: StockTheme.success,
                ),
              ),
              const SizedBox(height: 28),
              // Print button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ReceiptPrinter.printReceipt(
                      sale: printSale,
                      items: printItems,
                      shopName: 'iShop',
                      shopAddress: 'ວຽງຈັນ, ລາວ',
                    );
                    // Open cash drawer after print
                    Future.delayed(
                      const Duration(milliseconds: 800),
                      () => ReceiptPrinter.openCashDrawer(),
                    );
                  },
                  icon: const Icon(
                    Icons.print_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'ພິມໃບຮັບເງິນ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue2,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: _blue2.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _cartItems.clear();
                          _discount = 0;
                          _discountCtrl.text = '0';
                          _lastScanned = null;
                          _scannedProduct = null;
                          _paymentMethod = 'cash';
                        });
                        _barcodeFocus.requestFocus();
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _blue3.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'ຂາຍໃໝ່',
                        style: TextStyle(
                          color: _blue4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onBack?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StockTheme.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ກັບໜ້າຫຼັກ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animCtrl,
      child: Container(
        color: _bgDeep,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StockPageHeader(
              titleLa: 'ສະແກນຂາຍ',
              titleEn: 'POS — Scan & Sell',
              actions: [
                // ── Printer + Drawer status indicator ──────────────────
                _buildStatusBadge(),
                const SizedBox(width: 8),
                // ── Cart badge ──────────────────────────────────────────
                if (_cartItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _blue2.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _blue2.withOpacity(0.35)),
                    ),
                    child: Text(
                      '${_cartItems.length} item${_cartItems.length > 1 ? 's' : ''}  •  ${_fmt(_total)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _blue4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildScanField(),
                        if (_scannedProduct != null) ...[
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: SingleChildScrollView(
                              child: _buildProductInfoCard(),
                            ),
                          ),
                        ],
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 8),
                          _buildErrorBanner(),
                        ],
                        const SizedBox(height: 8),
                        Expanded(child: _buildCartList()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Right
                  SizedBox(width: 300, child: _buildSummaryPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STATUS BADGE ──────────────────────────────────────────────────────
  Widget _buildStatusBadge() {
    final color = _printerPaired
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final icon = _printerPaired
        ? Icons.print_rounded
        : Icons.print_disabled_rounded;
    final label = _printerPaired ? _printerLabel : 'ບໍ່ໄດ້ເຊື່ອມ';

    return Tooltip(
      message: _printerPaired
          ? 'Printer Ready — ກົດເພື່ອ test drawer'
          : 'ກົດເພື່ອ Pair Printer',
      child: InkWell(
        onTap: () {
          if (_printerPaired) {
            // Test open drawer
            ReceiptPrinter.openCashDrawer();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(
                      Icons.point_of_sale_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('ເປີດ Cash Drawer...'),
                  ],
                ),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ReceiptPrinter.pairPrinter();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: _printerPaired
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 4),
              // Drawer icon
              Icon(
                Icons.kitchen_rounded,
                size: 13,
                color: color.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SCAN FIELD ────────────────────────────────────────────────────────
  Widget _buildScanField() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bgCard.withOpacity(0.6), _surface.withOpacity(0.4)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue1.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: _blue2.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _blue2.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 20,
                  color: _blue3,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'ສະແກນ / ປ້ອນລະຫັດສິນຄ້າ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Scan or type barcode + Enter',
                style: TextStyle(
                  fontSize: 11,
                  color: _textSecondary.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeCtrl,
                  focusNode: _barcodeFocus,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: '_ _ _ _ _ _ _ _ _ _ _',
                    hintStyle: TextStyle(
                      color: _textSecondary.withOpacity(0.3),
                      fontSize: 18,
                      letterSpacing: 4,
                    ),
                    filled: true,
                    fillColor: _bgDarker.withOpacity(0.5),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.barcode_reader,
                        color: _isSearching
                            ? _blue3
                            : _textSecondary.withOpacity(0.5),
                      ),
                    ),
                    suffixIcon: _isSearching
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _blue3,
                              ),
                            ),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _blue1.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _blue1.withOpacity(0.18)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _blue3.withOpacity(0.7),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (_) => _onBarcodeSubmit(),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9\-_]'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSearching ? null : _onBarcodeSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue2,
                  disabledBackgroundColor: _blue2.withOpacity(0.35),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  shadowColor: _blue2.withOpacity(0.4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ຊອກຫາ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── PRODUCT INFO CARD ─────────────────────────────────────────────────
  Widget _buildProductInfoCard() {
    final p = _scannedProduct!;
    final sellingPrice = p['selling_price'] ?? '0';
    final costPrice = p['cost_price'] ?? '0';
    final wholesalePrice = p['wholesale_price'] ?? '0';
    final stock = p['current_stock'] ?? 0;
    final minStock = p['min_stock'] ?? 0;
    final isLowStock =
        (stock is int ? stock : int.tryParse(stock.toString()) ?? 0) <=
        (minStock is int ? minStock : int.tryParse(minStock.toString()) ?? 0);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, 12 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_blue2.withOpacity(0.07), _bgCard.withOpacity(0.5)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _blue2.withOpacity(0.28)),
          boxShadow: [
            BoxShadow(
              color: _blue2.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _blue2.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _blue2.withOpacity(0.2)),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    size: 22,
                    color: _blue3,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['product_name_la'] ?? p['product_name'] ?? '-',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      if ((p['product_name'] ?? '').toString().isNotEmpty &&
                          p['product_name'] != p['product_name_la'])
                        Text(
                          p['product_name'],
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary.withOpacity(0.6),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _infoBadge(p['product_code'] ?? '', _blue3),
                          const SizedBox(width: 6),
                          if ((p['barcode'] ?? '').toString().isNotEmpty)
                            _infoBadge('🔖 ${p['barcode']}', _textSecondary),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isLowStock
                        ? StockTheme.error.withOpacity(0.12)
                        : StockTheme.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLowStock
                          ? StockTheme.error.withOpacity(0.3)
                          : StockTheme.success.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$stock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isLowStock
                              ? StockTheme.error
                              : StockTheme.success,
                        ),
                      ),
                      Text(
                        'in stock',
                        style: TextStyle(
                          fontSize: 9,
                          color: isLowStock
                              ? StockTheme.error.withOpacity(0.7)
                              : StockTheme.success.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: _blue1.withOpacity(0.12)),
            const SizedBox(height: 10),
            Row(
              children: [
                _infoColumn(
                  'ໝວດ',
                  p['category_name_la'] ?? p['category_name'] ?? '-',
                ),
                _infoColumn('ຍີ່ຫໍ້', p['brand_name'] ?? '-'),
                _infoColumn(
                  'ຫົວໜ່ວຍ',
                  '${p['unit_name'] ?? '-'} (${p['unit_short'] ?? ''})',
                ),
                _infoColumn('Min Stock', '$minStock'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _bgDarker.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _blue1.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  _priceColumn(
                    'ລາຄາຕົ້ນທຶນ',
                    costPrice,
                    _textSecondary.withOpacity(0.6),
                  ),
                  _priceDivider(),
                  _priceColumn(
                    'ລາຄາຂາຍຍ່ອຍ',
                    sellingPrice,
                    StockTheme.success,
                    large: true,
                  ),
                  _priceDivider(),
                  _priceColumn('ລາຄາຂາຍສົ່ງ', wholesalePrice, _blue4),
                  if ((p['discount_percent'] ?? '0') != '0') ...[
                    _priceDivider(),
                    _priceColumn(
                      'ສ່ວນຫຼຸດ',
                      '${p['discount_percent']}%',
                      StockTheme.warning,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );

  Widget _infoColumn(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: _textSecondary.withOpacity(0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _priceColumn(
    String label,
    dynamic value,
    Color color, {
    bool large = false,
  }) {
    final price = num.tryParse(value.toString()) ?? 0;
    final display = value.toString().endsWith('%')
        ? value.toString()
        : _fmt(price);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: _textSecondary.withOpacity(0.5),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            display,
            style: TextStyle(
              fontSize: large ? 16 : 12,
              fontWeight: large ? FontWeight.w900 : FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _priceDivider() =>
      Container(width: 1, height: 32, color: _blue1.withOpacity(0.1));

  // ── ERROR BANNER ──────────────────────────────────────────────────────
  Widget _buildErrorBanner() => TweenAnimationBuilder<double>(
    duration: const Duration(milliseconds: 200),
    tween: Tween(begin: 0.0, end: 1.0),
    builder: (context, v, child) => Opacity(opacity: v, child: child),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: StockTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StockTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: StockTheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMsg!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: StockTheme.error,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMsg = null),
            child: Icon(
              Icons.close_rounded,
              color: StockTheme.error.withOpacity(0.5),
              size: 18,
            ),
          ),
        ],
      ),
    ),
  );

  // ── CART LIST ─────────────────────────────────────────────────────────
  Widget _buildCartList() {
    if (_cartItems.isEmpty)
      return Container(
        decoration: BoxDecoration(
          color: _bgCard.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _blue1.withOpacity(0.1)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 56,
                color: _textSecondary.withOpacity(0.2),
              ),
              const SizedBox(height: 14),
              Text(
                'ສະແກນສິນຄ້າເພື່ອເພີ່ມ',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Scan barcode to add items',
                style: TextStyle(
                  fontSize: 12,
                  color: _textSecondary.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      );

    return Container(
      decoration: BoxDecoration(
        color: _bgCard.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue1.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _blue1.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_rounded, size: 16, color: _blue3),
                const SizedBox(width: 8),
                Text(
                  'ລາຍການ (${_cartItems.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const Spacer(),
                if (_cartItems.isNotEmpty)
                  InkWell(
                    onTap: () async {
                      final ok = await showStockConfirmDialog(
                        context,
                        title: 'ລ້າງລາຍການ',
                        message: 'ລ້າງສິນຄ້າທັງໝົດ?',
                        confirmLabel: 'ລ້າງ',
                        confirmColor: StockTheme.error,
                      );
                      if (ok) setState(() => _cartItems.clear());
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: StockTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ລ້າງທັງໝົດ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: StockTheme.error.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(8),
              itemCount: _cartItems.length,
              itemBuilder: (ctx, i) => _buildCartItem(i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(int index) {
    final item = _cartItems[index];
    final qty = item['quantity'] as int? ?? 1;
    final price = num.tryParse(item['unit_price'].toString()) ?? 0;
    final lineTotal = price * qty;
    final isLatest =
        _lastScanned != null &&
        _lastScanned!['product_id'] == item['product_id'];

    return TweenAnimationBuilder<double>(
      key: ValueKey(item['product_id']),
      duration: const Duration(milliseconds: 250),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (ctx, v, child) => Transform.translate(
        offset: Offset(-20 * (1 - v), 0),
        child: Opacity(opacity: v, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isLatest
              ? StockTheme.success.withOpacity(0.06)
              : _bgDarker.withOpacity(0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLatest
                ? StockTheme.success.withOpacity(0.25)
                : _blue1.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['display_name'] ?? item['product_name'] ?? '-',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isLatest ? StockTheme.success : _textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      if ((item['product_code'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                        Text(
                          item['product_code'],
                          style: TextStyle(
                            fontSize: 10,
                            color: _textSecondary.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if ((item['category_name'] ?? '').toString().isNotEmpty)
                        Text(
                          '• ${item['category_name']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: _textSecondary.withOpacity(0.4),
                          ),
                        ),
                      if ((item['current_stock'] ?? 0) > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          'stock: ${item['current_stock']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: _blue4.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                _fmt(price),
                style: const TextStyle(fontSize: 12, color: _textSecondary),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                _qtyBtn(
                  icon: Icons.remove_rounded,
                  onTap: () => _updateQty(index, qty - 1),
                  color: qty <= 1 ? StockTheme.error : _textSecondary,
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '$qty',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                ),
                _qtyBtn(
                  icon: Icons.add_rounded,
                  onTap: () => _updateQty(index, qty + 1),
                  color: _blue3,
                ),
              ],
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: Text(
                _fmt(lineTotal),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: StockTheme.success,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _removeItem(index),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: StockTheme.error.withOpacity(0.6),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Icon(icon, size: 14, color: color),
    ),
  );

  // ── SUMMARY PANEL ─────────────────────────────────────────────────────
  Widget _buildSummaryPanel() {
    final paymentOptions = [
      {'value': 'cash', 'label': 'ເງິນສົດ', 'icon': Icons.payments_rounded},
      {'value': 'card', 'label': 'ບັດ', 'icon': Icons.credit_card_rounded},
      {'value': 'transfer', 'label': 'ໂອນ', 'icon': Icons.swap_horiz_rounded},
      {
        'value': 'credit',
        'label': 'ສິນເຊື່ອ',
        'icon': Icons.receipt_long_rounded,
      },
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgCard.withOpacity(0.65), _bgDarker.withOpacity(0.5)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue1.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: _blue2.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_rounded, size: 18, color: _blue3),
                      const SizedBox(width: 8),
                      const Text(
                        'ສະຫຼຸບ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sumRow('ລາຄາລວມ', _fmt(_subtotal)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'ສ່ວນຫຼຸດ',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textSecondary.withOpacity(0.7),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 100,
                        height: 36,
                        child: TextField(
                          controller: _discountCtrl,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            prefixText: '₭ ',
                            prefixStyle: TextStyle(
                              color: _textSecondary.withOpacity(0.6),
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: _bgDarker.withOpacity(0.5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _blue1.withOpacity(0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _blue1.withOpacity(0.18),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: _blue3.withOpacity(0.6),
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: _blue1.withOpacity(0.12)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'ຍອດລວມທັງໝົດ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(_total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: StockTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ຮູບແບບການຊຳລະ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    physics: const NeverScrollableScrollPhysics(),
                    children: paymentOptions.map((opt) {
                      final selected = _paymentMethod == opt['value'];
                      return InkWell(
                        onTap: () => setState(
                          () => _paymentMethod = opt['value'] as String,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: selected
                                ? _blue2.withOpacity(0.2)
                                : _bgDarker.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? _blue3.withOpacity(0.55)
                                  : _blue1.withOpacity(0.12),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                opt['icon'] as IconData,
                                size: 14,
                                color: selected
                                    ? _blue4
                                    : _textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? _blue4
                                      : _textSecondary.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Pinned checkout
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cartItems.isEmpty ? null : _submitSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: StockTheme.success,
                  disabledBackgroundColor: StockTheme.success.withOpacity(0.25),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: _cartItems.isEmpty ? 0 : 4,
                  shadowColor: StockTheme.success.withOpacity(0.35),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: _cartItems.isEmpty
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _cartItems.isEmpty
                          ? 'ສະແກນສິນຄ້າກ່ອນ'
                          : 'ສຳເລັດ — ${_fmt(_total)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _cartItems.isEmpty
                            ? Colors.white.withOpacity(0.3)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value) => Row(
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 13, color: _textSecondary.withOpacity(0.7)),
      ),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
        ),
      ),
    ],
  );
}
