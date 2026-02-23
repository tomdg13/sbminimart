// lib/pages/stock/stock_in_out_page.dart
//
// UPDATES:
//   1. Dark Blue theme (replaces StockTheme indigo with blue palette)
//   2. History quantity fix — tries multiple field names:
//      quantity / qty / amount / count  (+ before/after stock variants)

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

// ─── LOCAL BLUE PALETTE (mirrors dashboard_page.dart) ────────────────────────
const _blue1 = Color(0xFF1D4ED8);
const _blue2 = Color(0xFF2563EB);
const _blue3 = Color(0xFF3B82F6);
const _blue4 = Color(0xFF60A5FA);
const _bgCard   = Color(0xFF0D2045);
const _bgDarker = Color(0xFF071022);
const _surface  = Color(0xFF0F2A4A);
const _textPrimary   = Color(0xFFE2E8F0);
const _textSecondary = Color(0xFF94A3B8);
const _textMuted     = Color(0xFF475569);
// ─────────────────────────────────────────────────────────────────────────────

class StockInOutPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final int initialTab;

  const StockInOutPage({
    super.key,
    required this.currentUser,
    this.initialTab = 0,
  });

  @override
  State<StockInOutPage> createState() => _StockInOutPageState();
}

class _StockInOutPageState extends State<StockInOutPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animCtrl;

  bool _isLoading        = false;
  bool _isHistoryLoading = false;

  final List<Map<String, dynamic>> _products   = [];
  final List<Map<String, dynamic>> _categories = [];
  final List<Map<String, dynamic>> _history    = [];

  final TextEditingController _searchCtrl  = TextEditingController();
  final TextEditingController _hSearchCtrl = TextEditingController();

  String _searchKeyword  = '';
  String _hSearchKeyword = '';
  int?   _selectedCatId;

  String?        _hFilterType;
  DateTimeRange? _hDateRange;

  String get _me => widget.currentUser['username']?.toString() ?? 'unknown';

  // ── product computed ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    var list = List<Map<String, dynamic>>.from(_products);
    if (_selectedCatId != null) {
      list = list
          .where((p) => (p['category_id'] ?? p['categoryId']) == _selectedCatId)
          .toList();
    }
    if (_searchKeyword.isNotEmpty) {
      final kw = _searchKeyword.toLowerCase();
      list = list
          .where((p) =>
              (p['product_name'] ?? '').toString().toLowerCase().contains(kw) ||
              (p['product_code'] ?? '').toString().toLowerCase().contains(kw) ||
              (p['barcode']      ?? '').toString().toLowerCase().contains(kw))
          .toList();
    }
    return list;
  }

  // ── history computed ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredHistory {
    var list = List<Map<String, dynamic>>.from(_history);
    if (_hFilterType != null) {
      list = list.where((h) => h['type'] == _hFilterType).toList();
    }
    if (_hSearchKeyword.isNotEmpty) {
      final kw = _hSearchKeyword.toLowerCase();
      list = list.where((h) =>
          (h['product_name'] ?? '').toString().toLowerCase().contains(kw) ||
          (h['product_code'] ?? '').toString().toLowerCase().contains(kw) ||
          (h['created_by']   ?? '').toString().toLowerCase().contains(kw) ||
          (h['reason']       ?? '').toString().toLowerCase().contains(kw),
      ).toList();
    }
    if (_hDateRange != null) {
      list = list.where((h) {
        final raw = h['created_at'] ?? h['date'] ?? '';
        final dt  = DateTime.tryParse(raw.toString());
        if (dt == null) return false;
        return dt.isAfter(
                _hDateRange!.start.subtract(const Duration(days: 1))) &&
            dt.isBefore(_hDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    return list;
  }

  // ── FIX: parse decimal strings like "3.00" → 3 ──────────────────────────────
  // int.tryParse("3.00") = null  ← this was the bug
  // double.tryParse("3.00") = 3.0 → .round() = 3  ← correct
  int _hQty(Map<String, dynamic> h) {
    for (final key in ['quantity', 'qty', 'amount', 'count', 'stock_change', 'change_qty']) {
      final v = h[key];
      if (v != null) {
        final n = double.tryParse(v.toString()); // handles "3.00", "3", 3
        if (n != null && n != 0) return n.abs().round();
      }
    }
    // last resort: diff between after and before (also decimal strings)
    final after  = double.tryParse((h['stock_after']  ?? h['after_stock']  ?? h['new_stock']  ?? '').toString());
    final before = double.tryParse((h['stock_before'] ?? h['before_stock'] ?? h['old_stock']  ?? '').toString());
    if (after != null && before != null) return (after - before).abs().round();
    return 0;
  }

  // Strip ".00" for clean display: "7998.00" → "7998"
  String _fmtStock(dynamic v) {
    if (v == null) return '-';
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    return d == d.roundToDouble() ? d.round().toString() : d.toStringAsFixed(1);
  }

  int get _hTotalIn => _filteredHistory
      .where((h) => h['type'] == 'in')
      .fold(0, (s, h) => s + _hQty(h));

  int get _hTotalOut => _filteredHistory
      .where((h) => h['type'] == 'out')
      .fold(0, (s, h) => s + _hQty(h));

  // ── product helpers ────────────────────────────────────────────────────────
  int _getStock(Map<String, dynamic> p) =>
      int.tryParse((p['current_stock'] ?? p['stock'] ?? '0').toString()) ?? 0;

  int _getReorder(Map<String, dynamic> p) =>
      int.tryParse((p['reorder_point'] ?? p['reorder'] ?? '10').toString()) ?? 10;

  String _status(Map<String, dynamic> p) {
    final s = _getStock(p);
    final r = _getReorder(p);
    if (s == 0) return 'out';
    if (s <= r)  return 'low';
    return 'ok';
  }

  Color _statusColor(String s) {
    if (s == 'out') return StockTheme.error;
    if (s == 'low') return StockTheme.warning;
    return StockTheme.success;
  }

  int get _lowCount => _products.where((p) => _status(p) == 'low').length;
  int get _outCount => _products.where((p) => _status(p) == 'out').length;

  // ── history helpers ────────────────────────────────────────────────────────
  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/'
        '${l.year}  '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  Color    _typeColor(String? t) => t == 'in' ? StockTheme.success : StockTheme.error;
  String   _typeLabel(String? t) => t == 'in' ? 'ຮັບເຂົ້າ' : 'ຈ່າຍອອກ';
  IconData _typeIcon(String? t) =>
      t == 'in' ? Icons.add_box_rounded : Icons.indeterminate_check_box_rounded;

  // ── lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();

    _tabController.addListener(() {
      if (_tabController.index == 2 && _history.isEmpty && !_isHistoryLoading) {
        _fetchHistory();
      }
    });

    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animCtrl.dispose();
    _searchCtrl.dispose();
    _hSearchCtrl.dispose();
    super.dispose();
  }

  // ── fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.wait([_fetchProducts(), _fetchCategories()]);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _fetchProducts() async {
    try {
      final data = await ApiService.getProducts();
      if (!mounted) return;
      setState(() {
        _products.clear();
        _products.addAll(data.cast<Map<String, dynamic>>());
      });
    } catch (e) {
      debugPrint('fetchProducts error: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await ApiService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories.clear();
        _categories.addAll(data.cast<Map<String, dynamic>>());
      });
    } catch (e) {
      debugPrint('fetchCategories error: $e');
    }
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => _isHistoryLoading = true);
    try {
      final data = await ApiService.getStockHistory();
      debugPrint('=== StockHistory: ${data.length} records ===');
      if (data.isNotEmpty) {
        // Debug: print first record to identify field names
        debugPrint('=== First history record keys: ${data.first.keys.toList()} ===');
        debugPrint('=== First history record: ${data.first} ===');
      }
      if (!mounted) return;
      setState(() {
        _history.clear();
        _history.addAll(data.cast<Map<String, dynamic>>());
      });
    } catch (e) {
      debugPrint('fetchHistory error: $e');
    }
    if (!mounted) return;
    setState(() => _isHistoryLoading = false);
  }

  // ── date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _hDateRange,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: _blue3,
            onPrimary: Colors.white,
            surface: _bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _hDateRange = picked);
  }

  // ── adjust dialog ──────────────────────────────────────────────────────────
  void _showAdjustDialog(Map<String, dynamic> p, String type) {
    final qtyCtrl    = TextEditingController();
    final reasonCtrl = TextEditingController();
    final formKey    = GlobalKey<FormState>();
    final isIn       = type == 'in';
    final name       = p['product_name'] ?? '-';
    final current    = _getStock(p);
    bool saving      = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final qty        = int.tryParse(qtyCtrl.text) ?? 0;
          final newQty     = isIn ? current + qty : (current - qty).clamp(0, 999999);
          final accentColor = isIn ? StockTheme.success : StockTheme.error;

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 440,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _bgCard.withOpacity(0.97),
                    _bgDarker.withOpacity(0.98),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: _blue2.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          accentColor.withOpacity(0.12),
                          Colors.transparent
                        ]),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                              isIn ? Icons.add_box_rounded
                                   : Icons.indeterminate_check_box_rounded,
                              color: accentColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isIn ? 'ຮັບສິນຄ້າເຂົ້າ' : 'ຈ່າຍສິນຄ້າອອກ',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _textPrimary),
                              ),
                              Text(
                                isIn ? 'Stock In' : 'Stock Out',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded,
                              color: _textSecondary),
                        ),
                      ]),
                    ),

                    // product info card
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _surface.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _blue1.withOpacity(0.15)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: _blue2.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.inventory_2_rounded,
                              size: 20, color: _blue3),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(p['product_code'] ?? '-',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _textSecondary.withOpacity(0.6))),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('ສາງປັດຈຸບັນ',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: _textSecondary.withOpacity(0.5))),
                            Text('$current',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: _statusColor(_status(p)))),
                          ],
                        ),
                      ]),
                    ),

                    // form fields
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(children: [
                        TextFormField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: 'ຈຳນວນ *',
                            labelStyle: TextStyle(
                                color: _textSecondary.withOpacity(0.7),
                                fontSize: 13),
                            prefixIcon: Icon(
                                isIn ? Icons.add_circle_outline_rounded
                                     : Icons.remove_circle_outline_rounded,
                                color: accentColor, size: 20),
                            filled: true,
                            fillColor: _surface.withOpacity(0.4),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: accentColor.withOpacity(0.3))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _blue1.withOpacity(0.2))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: accentColor.withOpacity(0.6))),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'ກະລຸນາໃສ່ຈຳນວນ';
                            final n = int.tryParse(v);
                            if (n == null || n <= 0)
                              return 'ຈຳນວນຕ້ອງຫຼາຍກວ່າ 0';
                            if (!isIn && n > current)
                              return 'ສາງບໍ່ພໍ (ມີ $current)';
                            return null;
                          },
                          onChanged: (_) => setS(() {}),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: reasonCtrl,
                          style: const TextStyle(
                              color: _textPrimary, fontSize: 13),
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'ເຫດຜົນ / ໝາຍເຫດ',
                            labelStyle: TextStyle(
                                color: _textSecondary.withOpacity(0.7),
                                fontSize: 13),
                            prefixIcon: const Icon(Icons.edit_note_rounded,
                                color: _textSecondary, size: 20),
                            filled: true,
                            fillColor: _surface.withOpacity(0.4),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _blue1.withOpacity(0.15))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _blue1.withOpacity(0.15))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: _blue3.withOpacity(0.5))),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (qty > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: accentColor.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ສາງຫຼັງ${isIn ? 'ຮັບ' : 'ຈ່າຍ'}:',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: _textSecondary.withOpacity(0.7)),
                                ),
                                Row(children: [
                                  Text('$current',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: _textSecondary.withOpacity(0.5))),
                                  const SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded,
                                      size: 14, color: accentColor),
                                  const SizedBox(width: 6),
                                  Text('$newQty',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: accentColor)),
                                ]),
                              ],
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // footer buttons
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(
                                color: _blue1.withOpacity(0.12))),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('ຍົກເລີກ',
                                style: TextStyle(color: _textSecondary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    setS(() => saving = true);

                                    final qtyVal = int.tryParse(qtyCtrl.text) ?? 0;
                                    final body = {
                                      'type':       type,
                                      'quantity':   qtyVal,
                                      'reason':     reasonCtrl.text.trim(),
                                      'created_by': _me,
                                    };

                                    final productId = p['id'] ??
                                        p['product_id'] ??
                                        p['productId'];
                                    final res = await ApiService.adjustStock(
                                        productId, body);

                                    setS(() => saving = false);
                                    Navigator.pop(ctx);
                                    if (!mounted) return;

                                    if (res['responseCode'] == '00') {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(isIn
                                            ? 'ຮັບສິນຄ້າເຂົ້າສຳເລັດ (+$qtyVal)'
                                            : 'ຈ່າຍສິນຄ້າອອກສຳເລັດ (-$qtyVal)'),
                                        backgroundColor: isIn
                                            ? StockTheme.success
                                            : StockTheme.warning,
                                      ));
                                      _fetchProducts();
                                      if (_tabController.index == 2) {
                                        _fetchHistory();
                                      } else {
                                        _history.clear();
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(res['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'),
                                        backgroundColor: StockTheme.error,
                                      ));
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: saving
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Text(isIn ? 'ຮັບເຂົ້າ' : 'ຈ່າຍອອກ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animCtrl,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StockPageHeader(
              titleLa: 'ຮັບ-ຈ່າຍສາງ',
              titleEn: 'Stock In / Out',
              actions: [
                StockRefreshButton(
                  isLoading: _isLoading || _isHistoryLoading,
                  onTap: () {
                    _fetchAll();
                    if (_tabController.index == 2) _fetchHistory();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Stats ──
            Row(children: [
              Expanded(child: _BlueStatCard(
                  label: 'ສິນຄ້າທັງໝົດ',
                  value: '${_products.length}',
                  icon: Icons.inventory_2_rounded,
                  color: _blue3)),
              const SizedBox(width: 12),
              Expanded(child: _BlueStatCard(
                  label: 'ໃກ້ໝົດ',
                  value: '$_lowCount',
                  icon: Icons.warning_amber_rounded,
                  color: StockTheme.warning)),
              const SizedBox(width: 12),
              Expanded(child: _BlueStatCard(
                  label: 'ໝົດສາງ',
                  value: '$_outCount',
                  icon: Icons.remove_shopping_cart_rounded,
                  color: StockTheme.error)),
              const SizedBox(width: 12),
              Expanded(child: _BlueStatCard(
                  label: 'ທັງໝົດ (ປະຫວັດ)',
                  value: '${_history.length}',
                  icon: Icons.history_rounded,
                  color: _blue4)),
            ]),
            const SizedBox(height: 20),

            // ── TabBar ──
            TabBar(
              controller: _tabController,
              tabAlignment: TabAlignment.start,
              isScrollable: true,
              dividerColor: _blue1.withOpacity(0.15),
              dividerHeight: 1,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: LinearGradient(colors: [_blue2, _blue1]),
                borderRadius: BorderRadius.circular(8),
              ),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              labelColor: Colors.white,
              unselectedLabelColor: _textSecondary,
              padding: EdgeInsets.zero,
              tabs: const [
                Tab(child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_box_rounded, size: 15),
                    SizedBox(width: 6),
                    Text('ຮັບເຂົ້າ (Stock In)'),
                  ]),
                )),
                Tab(child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.indeterminate_check_box_rounded, size: 15),
                    SizedBox(width: 6),
                    Text('ຈ່າຍອອກ (Stock Out)'),
                  ]),
                )),
                Tab(child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history_rounded, size: 15),
                    SizedBox(width: 6),
                    Text('ປະຫວັດ (History)'),
                  ]),
                )),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProductTab(type: 'in'),
                  _buildProductTab(type: 'out'),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1 & 2: product list ────────────────────────────────────────────────
  Widget _buildProductTab({required String type}) {
    return Column(
      children: [
        Row(children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 40,
              child: DropdownButtonFormField<int>(
                value: _selectedCatId,
                dropdownColor: _bgCard,
                style: const TextStyle(color: _textPrimary, fontSize: 13),
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'ທຸກໝວດ',
                  hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5), fontSize: 13),
                  prefixIcon: const Icon(Icons.category_rounded, color: _textSecondary, size: 16),
                  filled: true,
                  fillColor: _surface.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _blue1.withOpacity(0.2))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _blue1.withOpacity(0.18))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _blue3.withOpacity(0.5))),
                ),
                items: [
                  DropdownMenuItem<int>(
                      value: null,
                      child: Text('ທຸກໝວດ',
                          style: TextStyle(color: _textSecondary.withOpacity(0.7), fontSize: 13))),
                  ..._categories.map((c) => DropdownMenuItem<int>(
                      value: c['id'] ?? c['category_id'],
                      child: Text(c['category_name'] ?? '-',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _textPrimary, fontSize: 13)))),
                ],
                onChanged: (v) => setState(() => _selectedCatId = v),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: _textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ຄົ້ນຫາສິນຄ້າ...',
                  hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 18),
                  filled: true,
                  fillColor: _surface.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _blue1.withOpacity(0.2))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _blue1.withOpacity(0.18))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _blue3.withOpacity(0.5))),
                ),
                onChanged: (v) => setState(() => _searchKeyword = v),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(child: _buildProductList(type: type)),
      ],
    );
  }

  Widget _buildProductList({required String type}) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _blue3));
    }
    if (_filtered.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inventory_2_outlined, size: 56,
              color: _textSecondary.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text('ບໍ່ພົບສິນຄ້າ',
              style: TextStyle(fontSize: 14, color: _textSecondary.withOpacity(0.4))),
        ]),
      );
    }
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (context, i) => _buildProductRow(_filtered[i], type: type),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> p, {required String type}) {
    final isIn       = type == 'in';
    final name       = p['product_name'] ?? '-';
    final code       = p['product_code'] ?? '-';
    final stock      = _getStock(p);
    final status     = _status(p);
    final sColor     = _statusColor(status);
    final catName    = p['category_name'] ?? p['category'] ?? '';
    final statusLabel = status == 'out' ? 'ໝົດສາງ'
                      : status == 'low' ? 'ໃກ້ໝົດ'
                      : 'ປົກກະຕິ';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _bgCard.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blue1.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () => _showAdjustDialog(p, type),
        borderRadius: BorderRadius.circular(14),
        hoverColor: (isIn ? StockTheme.success : StockTheme.error).withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _blue2.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inventory_2_rounded, size: 22, color: _blue3),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(code,
                        style: TextStyle(fontSize: 11, color: _textSecondary.withOpacity(0.6))),
                    if (catName.isNotEmpty) ...[
                      Text(' · ', style: TextStyle(color: _textSecondary.withOpacity(0.3))),
                      Flexible(
                        child: Text(catName,
                            style: TextStyle(fontSize: 11, color: _textSecondary.withOpacity(0.5)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: sColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sColor.withOpacity(0.3)),
                ),
                child: Text('$stock',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: sColor)),
              ),
              const SizedBox(height: 3),
              Text(statusLabel,
                  style: TextStyle(fontSize: 10, color: sColor.withOpacity(0.7), fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(width: 12),
            Container(
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isIn
                      ? [StockTheme.success, StockTheme.success.withOpacity(0.8)]
                      : [StockTheme.error, StockTheme.error.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton.icon(
                onPressed: () => _showAdjustDialog(p, type),
                icon: Icon(isIn ? Icons.add_rounded : Icons.remove_rounded,
                    color: Colors.white, size: 16),
                label: Text(isIn ? 'ຮັບເຂົ້າ' : 'ຈ່າຍອອກ',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Tab 3: History ─────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    return Column(
      children: [
        // mini summary cards
        Row(children: [
          _MiniStat(
              label: 'ທັງໝົດ',
              value: '${_filteredHistory.length}',
              color: _blue3,
              icon: Icons.receipt_long_rounded),
          const SizedBox(width: 10),
          _MiniStat(
              label: 'ຮັບເຂົ້າ',
              value: '+$_hTotalIn',
              color: StockTheme.success,
              icon: Icons.add_box_rounded),
          const SizedBox(width: 10),
          _MiniStat(
              label: 'ຈ່າຍອອກ',
              value: '-$_hTotalOut',
              color: StockTheme.error,
              icon: Icons.indeterminate_check_box_rounded),
        ]),
        const SizedBox(height: 12),

        // filter row
        Row(children: [
          _HFilterChip(
              label: 'ທັງໝົດ',
              selected: _hFilterType == null,
              color: _blue3,
              onTap: () => setState(() => _hFilterType = null)),
          const SizedBox(width: 8),
          _HFilterChip(
              label: 'ຮັບເຂົ້າ',
              icon: Icons.add_box_rounded,
              selected: _hFilterType == 'in',
              color: StockTheme.success,
              onTap: () => setState(
                  () => _hFilterType = _hFilterType == 'in' ? null : 'in')),
          const SizedBox(width: 8),
          _HFilterChip(
              label: 'ຈ່າຍອອກ',
              icon: Icons.indeterminate_check_box_rounded,
              selected: _hFilterType == 'out',
              color: StockTheme.error,
              onTap: () => setState(
                  () => _hFilterType = _hFilterType == 'out' ? null : 'out')),
          const SizedBox(width: 12),

          // date range picker
          GestureDetector(
            onTap: _pickDateRange,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _hDateRange != null
                    ? _blue2.withOpacity(0.15)
                    : _surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _hDateRange != null
                      ? _blue3.withOpacity(0.5)
                      : _blue1.withOpacity(0.15),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range_rounded,
                    size: 15,
                    color: _hDateRange != null ? _blue3 : _textSecondary),
                const SizedBox(width: 6),
                Text(
                  _hDateRange == null
                      ? 'ເລືອກວັນທີ'
                      : '${_hDateRange!.start.day}/${_hDateRange!.start.month}'
                          ' – ${_hDateRange!.end.day}/${_hDateRange!.end.month}',
                  style: TextStyle(
                      fontSize: 12,
                      color: _hDateRange != null ? _blue3 : _textSecondary),
                ),
                if (_hDateRange != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _hDateRange = null),
                    child: Icon(Icons.close_rounded, size: 14, color: _blue3),
                  ),
                ],
              ]),
            ),
          ),

          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _hSearchCtrl,
                style: const TextStyle(color: _textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'ຄົ້ນຫາ ສິນຄ້າ / ຜູ້ໃຊ້ / ເຫດຜົນ...',
                  hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 18),
                  filled: true,
                  fillColor: _surface.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _blue1.withOpacity(0.2))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _blue1.withOpacity(0.18))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _blue3.withOpacity(0.5))),
                ),
                onChanged: (v) => setState(() => _hSearchKeyword = v),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _blue2.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _blue1.withOpacity(0.1)),
          ),
          child: const Row(children: [
            SizedBox(width: 44),
            SizedBox(width: 12),
            Expanded(flex: 3, child: _HCol('ສິນຄ້າ')),
            Expanded(flex: 2, child: _HCol('ຜູ້ດຳເນີນການ')),
            Expanded(flex: 2, child: _HCol('ວັນທີ / ເວລາ')),
            SizedBox(width: 80, child: _HCol('ຈຳນວນ', center: true)),
            SizedBox(width: 80, child: _HCol('ກ່ອນ', center: true)),
            SizedBox(width: 80, child: _HCol('ຫຼັງ', center: true)),
            Expanded(flex: 2, child: _HCol('ເຫດຜົນ')),
          ]),
        ),
        const SizedBox(height: 8),

        Expanded(child: _buildHistoryList()),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_isHistoryLoading) {
      return Center(child: CircularProgressIndicator(color: _blue3));
    }
    if (_filteredHistory.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history_rounded, size: 56, color: _textSecondary.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text('ບໍ່ມີຂໍ້ມູນການເຄື່ອນໄຫວ',
              style: TextStyle(fontSize: 14, color: _textSecondary.withOpacity(0.4))),
        ]),
      );
    }
    return ListView.builder(
      itemCount: _filteredHistory.length,
      itemBuilder: (context, i) => _buildHistoryRow(_filteredHistory[i]),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> h) {
    final type        = h['type']?.toString();
    final tColor      = _typeColor(type);
    // ── FIX: use robust qty reader ──
    final qty         = _hQty(h);
    // ── FIX: try all stock before/after field name variants ──
    final stockBefore = _fmtStock(h['stock_before'] ?? h['before_stock'] ?? h['old_stock']  ?? h['qty_before']);
    final stockAfter  = _fmtStock(h['stock_after']  ?? h['after_stock']  ?? h['new_stock']  ?? h['qty_after']);
    final createdBy   = h['created_by'] ?? h['user'] ?? h['username'] ?? '-';
    final reason      = h['reason'] ?? h['note'] ?? h['remark'] ?? '';
    final date        = _formatDate(
        (h['created_at'] ?? h['date'] ?? h['movement_date'] ?? '').toString());
    // product name: prefer Lao
    final productName = h['product_name_la'] ?? h['product_name'] ?? '-';
    final productCode = h['product_code'] ?? h['barcode'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _bgCard.withOpacity(0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // type icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: tColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_typeIcon(type), size: 20, color: tColor),
          ),
          const SizedBox(width: 12),

          // product
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(productCode,
                    style: TextStyle(fontSize: 11, color: _textSecondary.withOpacity(0.5))),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: tColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(_typeLabel(type),
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w800, color: tColor)),
                ),
              ],
            ),
          ),

          // who
          Expanded(
            flex: 2,
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _blue2.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    createdBy.isNotEmpty ? createdBy[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: _blue4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(createdBy,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),

          // when
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date.contains('  ') ? date.split('  ')[0] : date,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                if (date.contains('  '))
                  Text(date.split('  ')[1],
                      style: TextStyle(
                          fontSize: 11, color: _textSecondary.withOpacity(0.6))),
              ],
            ),
          ),

          // qty — shows 0 if truly 0, shows ? if unresolvable
          SizedBox(
            width: 80,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tColor.withOpacity(0.3)),
                ),
                child: Text(
                  qty == 0 ? '—' : '${type == 'in' ? '+' : '-'}$qty',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: tColor),
                ),
              ),
            ),
          ),

          // before
          SizedBox(
            width: 80,
            child: Center(
              child: Text('$stockBefore',
                  style: TextStyle(
                      fontSize: 13, color: _textSecondary.withOpacity(0.6))),
            ),
          ),

          // after
          SizedBox(
            width: 80,
            child: Center(
              child: Text('$stockAfter',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary)),
            ),
          ),

          // reason
          Expanded(
            flex: 2,
            child: Text(
              reason.isEmpty ? '—' : reason,
              style: TextStyle(fontSize: 12, color: _textSecondary.withOpacity(0.6)),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────────

// Blue-themed stat card (replaces StockStatCard with indigo)
class _BlueStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _BlueStatCard({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0D2045).withOpacity(0.7),
            const Color(0xFF0F2A4A).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF94A3B8))),
        ]),
      ]),
    );
  }
}

class _HCol extends StatelessWidget {
  final String text;
  final bool center;
  const _HCol(this.text, {this.center = false});
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5),
      );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _MiniStat({
    required this.label, required this.value,
    required this.color, required this.icon,
  });
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF94A3B8))),
            ]),
          ]),
        ),
      );
}

class _HFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _HFilterChip({
    required this.label, this.icon,
    required this.selected, required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.15)
                : const Color(0xFF0D2045).withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? color.withOpacity(0.5)
                  : const Color(0xFF1D4ED8).withOpacity(0.15),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 13,
                  color: selected ? color : const Color(0xFF94A3B8)),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : const Color(0xFF94A3B8))),
          ]),
        ),
      );
}