// lib/pages/sales/my_history_page.dart
import 'package:flutter/material.dart';
import '../../services/sale_api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

class MyHistoryPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const MyHistoryPage({super.key, required this.currentUser});

  @override
  State<MyHistoryPage> createState() => _MyHistoryPageState();
}

class _MyHistoryPageState extends State<MyHistoryPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _statusFilter = 'all';
  String _searchKeyword = '';
  late AnimationController _animationController;

  final List<Map<String, dynamic>> _allSales = [];
  Map<String, dynamic> _summary = {};

  final TextEditingController _searchCtrl = TextEditingController();

  // ── Current user info ────────────────────────────────────────────────────
  String get _myUsername =>
      widget.currentUser['username']?.toString() ?? '';
  String get _myFullName =>
      widget.currentUser['full_name']?.toString() ?? '';
  int? get _myCashierId =>
      widget.currentUser['user_id'] ?? widget.currentUser['id'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fetchAll();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── FETCH ─────────────────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchMySales(), _fetchSummary()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchMySales() async {
    try {
      final data = await SaleApiService.getSales();
      // Filter: only sales where cashier matches current user
      final mySales = data.where((s) {
        final cashier    = (s['cashier']    ?? '').toString().toLowerCase();
        final createdBy  = (s['created_by'] ?? '').toString().toLowerCase();
        final cashierId  = s['cashier_id'];

        final matchName  = cashier   == _myFullName.toLowerCase() ||
                           cashier   == _myUsername.toLowerCase() ||
                           createdBy == _myUsername.toLowerCase();
        final matchId    = _myCashierId != null &&
                           cashierId != null &&
                           cashierId.toString() == _myCashierId.toString();

        return matchName || matchId;
      }).toList();

      debugPrint('=== MY HISTORY: ${mySales.length} / ${data.length} total ===');
      setState(() {
        _allSales.clear();
        _allSales.addAll(mySales);
      });
    } catch (e) {
      debugPrint('Error fetching my sales: $e');
    }
  }

  Future<void> _fetchSummary() async {
    try {
      final data = await SaleApiService.getSalesSummary();
      setState(() => _summary = data['data'] ?? {});
    } catch (e) {
      debugPrint('Error fetching summary: $e');
    }
  }

  // ── FILTER ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredSales {
    var list = _allSales;
    if (_statusFilter != 'all') {
      list = list.where((s) => s['status'] == _statusFilter).toList();
    }
    if (_searchKeyword.isNotEmpty) {
      final kw = _searchKeyword.toLowerCase();
      list = list.where((s) =>
        (s['sale_number'] ?? '').toString().toLowerCase().contains(kw),
      ).toList();
    }
    return list;
  }

  // ── MY STATS (computed from _allSales) ───────────────────────────────────
  double get _myTotalAmount => _allSales.fold(
      0.0, (sum, s) => sum + (num.tryParse(s['total_amount']?.toString() ?? '0') ?? 0));

  double get _myTodayAmount {
    final today = DateTime.now();
    return _allSales
        .where((s) {
          final raw = s['sale_date'] ?? s['created_at'] ?? '';
          try {
            final d = DateTime.parse(raw.toString());
            return d.year == today.year &&
                   d.month == today.month &&
                   d.day == today.day;
          } catch (_) { return false; }
        })
        .fold(0.0, (sum, s) =>
            sum + (num.tryParse(s['total_amount']?.toString() ?? '0') ?? 0));
  }

  int get _myCompletedCount =>
      _allSales.where((s) => s['status'] == 'completed').length;

  int get _myCancelledCount =>
      _allSales.where((s) => s['status'] == 'cancelled').length;

  // ── FORMAT ────────────────────────────────────────────────────────────────
  String _formatCurrency(dynamic value) {
    if (value == null) return '₭ 0';
    final num v = num.tryParse(value.toString()) ?? 0;
    return '₭ ${v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            StockPageHeader(
              titleLa: 'ປະຫວັດການຂາຍຂອງຂ້ອຍ',
              titleEn: 'My Sales History',
              actions: [
                StockRefreshButton(isLoading: _isLoading, onTap: _fetchAll),
              ],
            ),

            // ── User badge ──
            const SizedBox(height: 12),
            _buildUserBadge(),

            // ── Stats ──
            const SizedBox(height: 20),
            _buildStats(),

            // ── Filters ──
            const SizedBox(height: 20),
            _buildFiltersRow(),

            // ── List ──
            const SizedBox(height: 20),
            Expanded(child: _buildSalesList()),
          ],
        ),
      ),
    );
  }

  // ── USER BADGE ────────────────────────────────────────────────────────────
  Widget _buildUserBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: StockTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StockTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: StockTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_rounded,
                size: 18, color: StockTheme.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _myFullName.isNotEmpty ? _myFullName : _myUsername,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: StockTheme.textPrimary),
              ),
              Text(
                '@$_myUsername',
                style: TextStyle(
                    fontSize: 11,
                    color: StockTheme.textSecondary.withOpacity(0.6)),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: StockTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_allSales.length} ລາຍການ',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: StockTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── STATS ─────────────────────────────────────────────────────────────────
  Widget _buildStats() {
    return Row(
      children: [
        Expanded(child: StockStatCard(
            label: 'ຍອດຂາຍທັງໝົດ',
            value: _formatCurrency(_myTotalAmount),
            icon: Icons.account_balance_wallet_rounded,
            color: StockTheme.primary)),
        const SizedBox(width: 16),
        Expanded(child: StockStatCard(
            label: 'ຍອດຂາຍມື້ນີ້',
            value: _formatCurrency(_myTodayAmount),
            icon: Icons.today_rounded,
            color: StockTheme.success)),
        const SizedBox(width: 16),
        Expanded(child: StockStatCard(
            label: 'ສຳເລັດ',
            value: '$_myCompletedCount',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981))),
        const SizedBox(width: 16),
        Expanded(child: StockStatCard(
            label: 'ຍົກເລີກ',
            value: '$_myCancelledCount',
            icon: Icons.cancel_rounded,
            color: StockTheme.error)),
      ],
    );
  }

  // ── FILTERS ROW ───────────────────────────────────────────────────────────
  Widget _buildFiltersRow() {
    final statusFilters = [
      {'value': 'all',       'label': 'ທັງໝົດ'},
      {'value': 'pending',   'label': 'ລໍຖ້າ'},
      {'value': 'completed', 'label': 'ສຳເລັດ'},
      {'value': 'cancelled', 'label': 'ຍົກເລີກ'},
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statusFilters.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: StockFilterChip(
                  value: f['value']!,
                  label: f['label']!,
                  isSelected: _statusFilter == f['value'],
                  onTap: () => setState(() => _statusFilter = f['value']!),
                ),
              )).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 240,
          height: 40,
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: StockTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ຄົ້ນຫາເລກທີ...',
              hintStyle: TextStyle(
                  color: StockTheme.textSecondary.withOpacity(0.5), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: StockTheme.textSecondary, size: 18),
              filled: true,
              fillColor: StockTheme.bgCard.withOpacity(0.5),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: StockTheme.primary.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: StockTheme.primary.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: StockTheme.primary.withOpacity(0.5)),
              ),
            ),
            onChanged: (v) => setState(() => _searchKeyword = v),
          ),
        ),
      ],
    );
  }

  // ── SALES LIST ────────────────────────────────────────────────────────────
  Widget _buildSalesList() {
    final sales = _filteredSales;

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: StockTheme.primary));
    }

    if (sales.isEmpty) {
      return const StockEmptyState(
        icon: Icons.receipt_long_outlined,
        titleLa: 'ບໍ່ພົບລາຍການຂາຍ',
        titleEn: 'No sales found',
      );
    }

    return StockTableContainer(
      headers: const [
        'ເລກທີ', 'ວັນທີ', 'ລາຍການ', 'ຍອດຮວມ', 'ຊຳລະ', 'ສະຖານະ', 'ເບິ່ງ'
      ],
      flexValues: const [2, 2, 1, 2, 1, 1, 1],
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: sales.length,
        itemBuilder: (context, index) {
          final s = sales[index];
          return TweenAnimationBuilder<double>(
            duration:
                Duration(milliseconds: 300 + (index * 40).clamp(0, 800)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) => Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            ),
            child: _buildSaleRow(s),
          );
        },
      ),
    );
  }

  Widget _buildSaleRow(Map<String, dynamic> s) {
    final status = s['status'] ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          StockTheme.bgDark.withOpacity(0.3),
          StockTheme.bgDarker.withOpacity(0.2),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: StockTheme.primary.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          // Sale number
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['sale_number'] ?? 'SALE-${s['id']}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: StockTheme.primary)),
                if ((s['notes'] ?? '').toString().isNotEmpty)
                  Text(s['notes'],
                      style: TextStyle(
                          fontSize: 11,
                          color: StockTheme.textSecondary.withOpacity(0.6)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
                StockTheme.formatDate(s['sale_date'] ?? s['created_at']),
                style: const TextStyle(
                    fontSize: 13, color: StockTheme.textSecondary)),
          ),
          // Items count
          Expanded(
            flex: 1,
            child: Text('${s['item_count'] ?? 0}',
                style: const TextStyle(
                    fontSize: 13,
                    color: StockTheme.textSecondary,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ),
          // Total
          Expanded(
            flex: 2,
            child: Text(_formatCurrency(s['total_amount']),
                style: const TextStyle(
                    fontSize: 13,
                    color: StockTheme.success,
                    fontWeight: FontWeight.w700)),
          ),
          // Payment
          Expanded(flex: 1, child: _paymentBadge(s['payment_method'] ?? 'cash')),
          // Status
          Expanded(flex: 1, child: StockStatusBadge(status: status)),
          // View button only (read-only for own history)
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: StockActionButton(
                icon: Icons.visibility_rounded,
                color: StockTheme.info,
                onTap: () => _viewSaleDetails(s),
                tooltip: 'ເບິ່ງລາຍລະອຽດ',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBadge(String method) {
    final colors = {
      'cash':     const Color(0xFF10B981),
      'card':     const Color(0xFF3B82F6),
      'transfer': const Color(0xFF8B5CF6),
      'credit':   const Color(0xFFF59E0B),
    };
    final labels = {
      'cash': 'ເງິນສົດ', 'card': 'ບັດ',
      'transfer': 'ໂອນ',  'credit': 'ສິນເຊື່ອ',
    };
    final color = colors[method] ?? StockTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(labels[method] ?? method,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color),
          textAlign: TextAlign.center),
    );
  }

  // ── VIEW DETAIL ───────────────────────────────────────────────────────────
  void _viewSaleDetails(Map<String, dynamic> sale) async {
    final saleId  = sale['id'] ?? sale['sale_id'];
    final saleNum = sale['sale_number'] ?? 'SALE-$saleId';

    try {
      final response = await SaleApiService.getSaleById(saleId);
      final s     = response['data'];
      final items = (s['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 720,
            constraints: const BoxConstraints(maxHeight: 620),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                StockTheme.bgDark.withOpacity(0.98),
                StockTheme.bgCard.withOpacity(0.98),
              ]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: StockTheme.primary.withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                StockDialogHeader(
                  titleLa: saleNum,
                  titleEn: 'Sale Details',
                  icon: Icons.receipt_long_rounded,
                  onClose: () => Navigator.pop(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _detailField('ຜູ້ຂາຍ',
                              s['cashier'] ?? s['created_by'] ?? '-'),
                          const SizedBox(width: 16),
                          _detailField('ວັນທີ',
                              StockTheme.formatDate(
                                  s['sale_date'] ?? s['created_at'])),
                          const SizedBox(width: 16),
                          Expanded(
                              child: StockStatusBadge(
                                  status: s['status'] ?? 'pending')),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          _detailField(
                              'ຊຳລະດ້ວຍ', s['payment_method'] ?? 'cash'),
                          const SizedBox(width: 16),
                          _detailField('ສ່ວນຫຼຸດ',
                              _formatCurrency(s['discount_amount'])),
                          const SizedBox(width: 16),
                          _detailField(
                              'ຍອດຮວມ', _formatCurrency(s['total_amount'])),
                        ]),
                        const SizedBox(height: 24),
                        const Text('ລາຍການສິນຄ້າ',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: StockTheme.textPrimary)),
                        const SizedBox(height: 12),
                        if (items.isEmpty)
                          const Text('ບໍ່ມີລາຍການ',
                              style: TextStyle(color: StockTheme.textSecondary))
                        else
                          ...items.map((item) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: StockTheme.bgDarker.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: StockTheme.primary.withOpacity(0.1)),
                                ),
                                child: Row(children: [
                                  Expanded(
                                      flex: 3,
                                      child: Text(
                                          item['product_name'] ??
                                              'Product #${item['product_id']}',
                                          style: const TextStyle(
                                              color: StockTheme.textPrimary,
                                              fontWeight: FontWeight.w600))),
                                  Expanded(
                                      child: Text('x${item['quantity'] ?? 0}',
                                          style: const TextStyle(
                                              color: StockTheme.textSecondary,
                                              fontSize: 12))),
                                  Expanded(
                                      child: Text(
                                          '${StockTheme.formatPrice(item['unit_price'])} ₭',
                                          style: const TextStyle(
                                              color: StockTheme.textSecondary,
                                              fontSize: 12))),
                                  Expanded(
                                      child: Text(
                                          '${StockTheme.formatPrice(item['subtotal'])} ₭',
                                          style: const TextStyle(
                                              color: StockTheme.success,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12))),
                                ]),
                              )),
                        const SizedBox(height: 12),
                        // Total summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: StockTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: StockTheme.primary.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('ຍອດລວມທັງໝົດ',
                                  style: TextStyle(
                                      color: StockTheme.textSecondary
                                          .withOpacity(0.8),
                                      fontWeight: FontWeight.w600)),
                              Text(_formatCurrency(s['total_amount']),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: StockTheme.success)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ເກີດຂໍ້ຜິດພາດ'),
            backgroundColor: StockTheme.error),
      );
    }
  }

  Widget _detailField(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: StockTheme.textSecondary.withOpacity(0.6),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  color: StockTheme.textPrimary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}