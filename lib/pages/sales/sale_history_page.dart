// lib/pages/sales/sale_history_page.dart
import 'package:flutter/material.dart';
import '../../services/sale_api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

class SaleHistoryPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const SaleHistoryPage({super.key, required this.currentUser});

  @override
  State<SaleHistoryPage> createState() => _SaleHistoryPageState();
}

class _SaleHistoryPageState extends State<SaleHistoryPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  final List<Map<String, dynamic>> _sales = [];

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate   = DateTime.now();

  String _searchKeyword  = '';
  String _paymentFilter  = 'all';
  String _statusFilter   = 'all';

  final TextEditingController _searchCtrl = TextEditingController();
  late AnimationController _animCtrl;

  // ── INIT ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350))
      ..forward();
    _fetchSales();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── FETCH ─────────────────────────────────────────────────────────────────
  Future<void> _fetchSales() async {
    setState(() => _isLoading = true);
    try {
      final start = _fmt(_startDate);
      final end   = _fmt(_endDate);
      final data  = await SaleApiService.getSalesByDateRange(start, end);
      setState(() { _sales.clear(); _sales.addAll(data); });
    } catch (e) {
      debugPrint('Error fetching sales: $e');
    }
    setState(() => _isLoading = false);
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  String _fmtDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  String _fmtCurrency(dynamic v) {
    final n = num.tryParse(v.toString()) ?? 0;
    return '₭ ${n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String _fmtDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return raw; }
  }

  Color _statusColor(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'VOIDED':
      case 'CANCELLED': return const Color(0xFFEF4444);
      case 'RETURNED':  return const Color(0xFFF59E0B);
      default:          return const Color(0xFF64748B);
    }
  }

  Color _paymentColor(String? p) {
    switch ((p ?? '').toUpperCase()) {
      case 'CASH':     return const Color(0xFF10B981);
      case 'CARD':     return const Color(0xFF3B82F6);
      case 'TRANSFER': return const Color(0xFF8B5CF6);
      case 'QR':       return const Color(0xFFF59E0B);
      default:         return const Color(0xFF64748B);
    }
  }

  // ── FILTERED LIST ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    var list = List<Map<String, dynamic>>.from(_sales);
    if (_paymentFilter != 'all') {
      list = list.where((s) =>
          (s['payment_method'] ?? '').toString().toUpperCase() == _paymentFilter).toList();
    }
    if (_statusFilter != 'all') {
      list = list.where((s) =>
          (s['status'] ?? '').toString().toUpperCase() == _statusFilter).toList();
    }
    if (_searchKeyword.isNotEmpty) {
      final kw = _searchKeyword.toLowerCase();
      list = list.where((s) =>
          (s['sale_number']    ?? '').toString().toLowerCase().contains(kw) ||
          (s['cashier_name']   ?? '').toString().toLowerCase().contains(kw) ||
          (s['payment_method'] ?? '').toString().toLowerCase().contains(kw)).toList();
    }
    return list;
  }

  // ── SUMMARY TOTALS ────────────────────────────────────────────────────────
  Map<String, dynamic> get _totals {
    final list = _filtered;
    final completed = list.where((s) =>
        (s['status'] ?? '').toString().toUpperCase() == 'COMPLETED').toList();
    final revenue = completed.fold<double>(
        0, (sum, s) => sum + (num.tryParse(s['total_amount'].toString()) ?? 0));
    return {
      'total':     list.length,
      'completed': completed.length,
      'revenue':   revenue,
    };
  }

  // ── DATE PICKER ───────────────────────────────────────────────────────────
  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: StockTheme.primary,
            surface: StockTheme.bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_startDate.isAfter(_endDate)) _endDate = picked;
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) _startDate = picked;
      }
    });
    _fetchSales();
  }

  // ── QUICK DATE SHORTCUTS ──────────────────────────────────────────────────
  void _setQuickDate(String range) {
    final now = DateTime.now();
    setState(() {
      switch (range) {
        case 'today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate   = now;
          break;
        case 'week':
          _startDate = now.subtract(const Duration(days: 7));
          _endDate   = now;
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate   = now;
          break;
        case 'last_month':
          final first = DateTime(now.year, now.month - 1, 1);
          final last  = DateTime(now.year, now.month, 0);
          _startDate  = first;
          _endDate    = last;
          break;
      }
    });
    _fetchSales();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animCtrl,
      child: Container(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            StockPageHeader(
              titleLa: 'ປະຫວັດການຂາຍ',
              titleEn: 'Sale History',
              actions: [
                StockRefreshButton(isLoading: _isLoading, onTap: _fetchSales),
              ],
            ),
            const SizedBox(height: 20),
            // Date filter bar
            _buildDateBar(),
            const SizedBox(height: 16),
            // Summary cards
            _buildSummaryRow(),
            const SizedBox(height: 16),
            // Search + payment + status filters
            _buildFilterRow(),
            const SizedBox(height: 16),
            // List
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  // ── DATE BAR ──────────────────────────────────────────────────────────────
  Widget _buildDateBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StockTheme.bgCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StockTheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick shortcuts
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 15, color: StockTheme.primary),
              const SizedBox(width: 8),
              Text('ໄລຍະເວລາ / Date Range',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: StockTheme.textPrimary)),
              const Spacer(),
              ...[
                ('ມື້ນີ້', 'today'),
                ('7 ວັນ', 'week'),
                ('ເດືອນນີ້', 'month'),
                ('ເດືອນແລ້ວ', 'last_month'),
              ].map((e) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _quickBtn(e.$1, e.$2),
              )),
            ],
          ),
          const SizedBox(height: 12),
          // Date pickers
          Row(
            children: [
              Expanded(child: _datePicker('ຈາກ / From', _startDate, isStart: true)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 16, color: StockTheme.textSecondary),
              ),
              Expanded(child: _datePicker('ຫາ / To', _endDate, isStart: false)),
              const SizedBox(width: 12),
              // Apply button
              Material(
                color: StockTheme.primary,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _fetchSales,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    child: Row(
                      children: const [
                        Icon(Icons.search_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text('ຄົ້ນຫາ', style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                      ],
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

  Widget _quickBtn(String label, String key) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setQuickDate(key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: StockTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: StockTheme.primary.withOpacity(0.2)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: StockTheme.primary)),
        ),
      ),
    );
  }

  Widget _datePicker(String label, DateTime date, {required bool isStart}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickDate(isStart: isStart),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: StockTheme.bgDark.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: StockTheme.primary.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.event_rounded, size: 15, color: StockTheme.primary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: StockTheme.textSecondary)),
                  Text(_fmtDisplay(date),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: StockTheme.textPrimary)),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_drop_down_rounded,
                  size: 18, color: StockTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ── SUMMARY ROW ───────────────────────────────────────────────────────────
  Widget _buildSummaryRow() {
    final t = _totals;
    return Row(
      children: [
        Expanded(child: _summaryCard(
          icon: Icons.receipt_long_rounded,
          label: 'ທັງໝົດ / Total',
          value: '${t['total']} ລາຍການ',
          color: const Color(0xFF3B82F6),
        )),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard(
          icon: Icons.check_circle_rounded,
          label: 'ສຳເລັດ / Completed',
          value: '${t['completed']} ລາຍການ',
          color: const Color(0xFF10B981),
        )),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard(
          icon: Icons.payments_rounded,
          label: 'ລາຍຮັບ / Revenue',
          value: _fmtCurrency(t['revenue']),
          color: const Color(0xFFF59E0B),
        )),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: StockTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FILTER ROW ────────────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    return Row(
      children: [
        // Search
        Expanded(
          flex: 3,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: StockTheme.bgCard.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: StockTheme.primary.withOpacity(0.15)),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13, color: StockTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'ຄົ້ນຫາ ເລກໃບບິນ, ພະນັກງານ... / Search...',
                hintStyle: TextStyle(
                    fontSize: 12, color: StockTheme.textSecondary.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18, color: StockTheme.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchKeyword = v),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Payment filter
        _dropdownFilter(
          value: _paymentFilter,
          hint: 'ການຊຳລະ',
          items: const {
            'all': 'ທັງໝົດ',
            'CASH': 'ເງິນສົດ',
            'CARD': 'ບັດ',
            'TRANSFER': 'ໂອນ',
            'QR': 'QR',
          },
          onChanged: (v) => setState(() => _paymentFilter = v ?? 'all'),
        ),
        const SizedBox(width: 12),
        // Status filter
        _dropdownFilter(
          value: _statusFilter,
          hint: 'ສະຖານະ',
          items: const {
            'all':       'ທັງໝົດ',
            'COMPLETED': 'ສຳເລັດ',
            'VOIDED':    'ຍົກເລີກ',
            'RETURNED':  'ຄືນສິນຄ້າ',
          },
          onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
        ),
      ],
    );
  }

  Widget _dropdownFilter({
    required String value,
    required String hint,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: StockTheme.bgCard.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: StockTheme.primary.withOpacity(0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: StockTheme.bgCard,
          style: const TextStyle(fontSize: 13, color: StockTheme.textPrimary),
          icon: Icon(Icons.arrow_drop_down_rounded,
              color: StockTheme.textSecondary),
          items: items.entries.map((e) => DropdownMenuItem(
            value: e.key,
            child: Text(e.value),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── LIST ──────────────────────────────────────────────────────────────────
  Widget _buildList() {
    final list = _filtered;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 56, color: StockTheme.textSecondary.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text('ບໍ່ພົບລາຍການຂາຍ',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: StockTheme.textSecondary.withOpacity(0.4))),
            const SizedBox(height: 4),
            Text('ລອງປ່ຽນໄລຍະເວລາ ຫຼື ຄຳຄົ້ນຫາ',
                style: TextStyle(
                    fontSize: 12,
                    color: StockTheme.textSecondary.withOpacity(0.3))),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildSaleCard(list[i]),
    );
  }

  // ── SALE CARD ─────────────────────────────────────────────────────────────
  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final status  = (sale['status'] ?? '').toString().toUpperCase();
    final payment = (sale['payment_method'] ?? '').toString().toUpperCase();
    final sColor  = _statusColor(status);
    final pColor  = _paymentColor(payment);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: StockTheme.bgCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StockTheme.primary.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _showDetail(sale),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_rounded, size: 22, color: sColor),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            sale['sale_number'] ?? '-',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: StockTheme.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          _badge(status, sColor),
                          const SizedBox(width: 6),
                          _badge(payment, pColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 12, color: StockTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            sale['cashier_name'] ?? sale['created_by'] ?? '-',
                            style: TextStyle(
                                fontSize: 12, color: StockTheme.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time_rounded,
                              size: 12, color: StockTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _fmtDateTime(sale['sale_date']?.toString()),
                            style: TextStyle(
                                fontSize: 12, color: StockTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmtCurrency(sale['total_amount']),
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: sColor),
                    ),
                    const SizedBox(height: 2),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: StockTheme.textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ── DETAIL DIALOG ─────────────────────────────────────────────────────────
  void _showDetail(Map<String, dynamic> sale) async {
    final saleId = sale['sale_id'];
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _SaleDetailDialog(
        saleId: saleId,
        sale: sale,
        fmtCurrency: _fmtCurrency,
        fmtDateTime: _fmtDateTime,
        statusColor: _statusColor,
        paymentColor: _paymentColor,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SALE DETAIL DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _SaleDetailDialog extends StatefulWidget {
  final dynamic saleId;
  final Map<String, dynamic> sale;
  final String Function(dynamic) fmtCurrency;
  final String Function(String?) fmtDateTime;
  final Color Function(String?) statusColor;
  final Color Function(String?) paymentColor;

  const _SaleDetailDialog({
    required this.saleId,
    required this.sale,
    required this.fmtCurrency,
    required this.fmtDateTime,
    required this.statusColor,
    required this.paymentColor,
  });

  @override
  State<_SaleDetailDialog> createState() => _SaleDetailDialogState();
}

class _SaleDetailDialogState extends State<_SaleDetailDialog> {
  bool _loading = true;
  Map<String, dynamic> _detail = {};
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final res = await SaleApiService.getSaleById(widget.saleId);
      if (res['responseCode'] == '00') {
        setState(() {
          _detail = res['data'] ?? widget.sale;
          _items  = (res['items'] as List? ?? []).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error fetching detail: $e');
      setState(() => _detail = widget.sale);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final status  = (_detail['status'] ?? '').toString().toUpperCase();
    final payment = (_detail['payment_method'] ?? '').toString().toUpperCase();
    final sColor  = widget.statusColor(status);
    final pColor  = widget.paymentColor(payment);

    return Dialog(
      backgroundColor: StockTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: StockTheme.primary.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long_rounded, size: 22, color: sColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _detail['sale_number'] ?? widget.sale['sale_number'] ?? '-',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: StockTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _chip(status, sColor),
                            const SizedBox(width: 6),
                            _chip(payment, pColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: StockTheme.textSecondary),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Sale Info Grid ──
                          _buildInfoGrid(),
                          const SizedBox(height: 20),
                          // ── Items ──
                          Row(
                            children: [
                              Icon(Icons.shopping_cart_rounded,
                                  size: 16, color: StockTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'ລາຍການສິນຄ້າ / Items (${_items.length})',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: StockTheme.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildItemsTable(),
                          const SizedBox(height: 20),
                          // ── Totals ──
                          _buildTotals(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildInfoGrid() {
    final d = _detail;
    final rows = [
      ('ເລກໃບບິນ', d['sale_number'] ?? '-'),
      ('ວັນທີ', widget.fmtDateTime(d['sale_date']?.toString())),
      ('ພະນັກງານຂາຍ', d['cashier_name'] ?? d['created_by'] ?? '-'),
      ('ວິທີຊຳລະ', (d['payment_method'] ?? '-').toString().toUpperCase()),
      ('ສ້າງໂດຍ', d['created_by'] ?? '-'),
      ('ໝາຍເຫດ', d['notes'] ?? '-'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StockTheme.bgDark.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StockTheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(r.$1,
                    style: TextStyle(
                        fontSize: 12, color: StockTheme.textSecondary)),
              ),
              const Text(' : ',
                  style: TextStyle(color: StockTheme.textSecondary)),
              Expanded(
                child: Text(r.$2,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: StockTheme.textPrimary)),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildItemsTable() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: StockTheme.bgDark.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('ບໍ່ມີລາຍການ',
              style: TextStyle(color: StockTheme.textSecondary)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: StockTheme.bgDark.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StockTheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: StockTheme.primary.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: const [
                Expanded(flex: 4, child: Text('#  ສິນຄ້າ / Product',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: StockTheme.textSecondary))),
                SizedBox(width: 80, child: Text('ຈຳນວນ\nQty',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: StockTheme.textSecondary))),
                SizedBox(width: 100, child: Text('ລາຄາ\nPrice',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: StockTheme.textSecondary))),
                SizedBox(width: 110, child: Text('ລວມ\nSubtotal',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: StockTheme.textSecondary))),
              ],
            ),
          ),
          // Rows
          ..._items.asMap().entries.map((e) {
            final i    = e.key;
            final item = e.value;
            final qty  = num.tryParse(item['quantity'].toString()) ?? 0;
            final price = num.tryParse(item['unit_price'].toString()) ?? 0;
            final sub   = num.tryParse(item['subtotal'].toString()) ?? (qty * price);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: i.isEven
                    ? Colors.transparent
                    : StockTheme.bgDark.withOpacity(0.2),
                border: Border(
                  bottom: BorderSide(
                    color: StockTheme.primary.withOpacity(0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: StockTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: StockTheme.primary)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['product_name'] ?? '-',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: StockTheme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item['product_code'] ?? '',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: StockTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      qty % 1 == 0
                          ? qty.toInt().toString()
                          : qty.toStringAsFixed(2),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: StockTheme.textPrimary),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      widget.fmtCurrency(price),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 12, color: StockTheme.textSecondary),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      widget.fmtCurrency(sub),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: StockTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    final d = _detail;
    final rows = [
      ('ລວມກ່ອນຫັກ / Subtotal', d['subtotal'],         false),
      ('ສ່ວນຫຼຸດ / Discount',    d['discount_amount'],  false),
      ('ພາສີ / Tax',             d['tax_amount'],       false),
      ('ຍອດລວມ / Total',        d['total_amount'],     true),
      ('ຮັບເງິນ / Paid',         d['paid_amount'],      false),
      ('ທອນ / Change',           d['change_amount'],    false),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StockTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StockTheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        children: rows.map((r) {
          if (r.$2 == null) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.symmetric(vertical: r.$3 ? 8 : 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.$1,
                    style: TextStyle(
                        fontSize: r.$3 ? 14 : 12,
                        fontWeight: r.$3 ? FontWeight.w700 : FontWeight.w500,
                        color: r.$3
                            ? StockTheme.textPrimary
                            : StockTheme.textSecondary)),
                Text(
                  widget.fmtCurrency(r.$2),
                  style: TextStyle(
                      fontSize: r.$3 ? 18 : 13,
                      fontWeight: r.$3 ? FontWeight.w800 : FontWeight.w600,
                      color: r.$3 ? StockTheme.primary : StockTheme.textPrimary),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}