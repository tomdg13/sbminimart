// lib/pages/sales/sales_page.dart
import 'package:flutter/material.dart';
import '../../services/sale_api_service.dart';
import '../../services/api_service.dart';
import '../../services/receipt_printer.dart';
import '../../widgets/stock_ui_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY LOG MODEL
// ─────────────────────────────────────────────────────────────────────────────
enum SaleLogAction {
  viewed,
  created,
  edited,
  cancelled,
  completed,
  searched,
  filtered,
  printed,
}

class SaleActivityLog {
  final SaleLogAction action;
  final String description;
  final String user;
  final DateTime timestamp;
  final Map<String, dynamic>? meta;

  SaleActivityLog({
    required this.action,
    required this.description,
    required this.user,
    this.meta,
  }) : timestamp = DateTime.now();

  IconData get icon {
    switch (action) {
      case SaleLogAction.viewed:    return Icons.visibility_rounded;
      case SaleLogAction.created:   return Icons.add_circle_rounded;
      case SaleLogAction.edited:    return Icons.edit_rounded;
      case SaleLogAction.cancelled: return Icons.cancel_rounded;
      case SaleLogAction.completed: return Icons.check_circle_rounded;
      case SaleLogAction.searched:  return Icons.search_rounded;
      case SaleLogAction.filtered:  return Icons.filter_list_rounded;
      case SaleLogAction.printed:   return Icons.print_rounded;
    }
  }

  Color get color {
    switch (action) {
      case SaleLogAction.viewed:    return const Color(0xFF3B82F6);
      case SaleLogAction.created:   return const Color(0xFF10B981);
      case SaleLogAction.edited:    return const Color(0xFFF59E0B);
      case SaleLogAction.cancelled: return const Color(0xFFEF4444);
      case SaleLogAction.completed: return const Color(0xFF10B981);
      case SaleLogAction.searched:  return const Color(0xFF64748B);
      case SaleLogAction.filtered:  return const Color(0xFF8B5CF6);
      case SaleLogAction.printed:   return const Color(0xFF06B6D4);
    }
  }

  String get formattedTime =>
      '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';

  String get dateLabel {
    final now  = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SALES PAGE
// ─────────────────────────────────────────────────────────────────────────────
class SalesPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final VoidCallback? onSaleCreated;

  const SalesPage({
    super.key,
    required this.currentUser,
    this.onSaleCreated,
  });

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage>
    with SingleTickerProviderStateMixin {
  bool   _isLoading      = false;
  bool   _showLog        = false;
  String _statusFilter   = 'all';
  String _searchKeyword  = '';
  late AnimationController _animationController;

  final List<Map<String, dynamic>> _sales    = [];
  final List<Map<String, dynamic>> _products = [];
  final List<SaleActivityLog>      _logs     = [];
  Map<String, dynamic> _summary = {};

  final TextEditingController _searchCtrl = TextEditingController();

  String get _me =>
      widget.currentUser['username']?.toString() ?? 'unknown';

  // ── LOG ───────────────────────────────────────────────────────────────
  void _addLog(
    SaleLogAction action,
    String description, {
    Map<String, dynamic>? meta,
  }) {
    setState(() {
      _logs.insert(
        0,
        SaleActivityLog(
            action: action, description: description, user: _me, meta: meta),
      );
      if (_logs.length > 200) _logs.removeLast();
    });
  }

  // ── LIFECYCLE ─────────────────────────────────────────────────────────
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

  // ── FETCH ─────────────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchSales(), _fetchSummary(), _fetchProducts()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchSales() async {
    try {
      final data = await SaleApiService.getSales();
      setState(() {
        _sales.clear();
        _sales.addAll(data);
      });
    } catch (e) {
      debugPrint('Error fetching sales: $e');
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

  Future<void> _fetchProducts() async {
    try {
      final data = await ApiService.getProducts();
      setState(() {
        _products.clear();
        _products.addAll(data.cast<Map<String, dynamic>>());
      });
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }
  }

  // ── FILTER ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredSales {
    var list = _sales;
    if (_statusFilter != 'all') {
      list = list.where((s) => s['status'] == _statusFilter).toList();
    }
    if (_searchKeyword.isNotEmpty) {
      final kw = _searchKeyword.toLowerCase();
      list = list
          .where((s) =>
              (s['sale_number'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(kw) ||
              (s['cashier'] ?? s['created_by'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(kw))
          .toList();
    }
    return list;
  }

  // ── FORMAT ────────────────────────────────────────────────────────────
  String _formatCurrency(dynamic value) {
    if (value == null) return '₭ 0';
    final num v = num.tryParse(value.toString()) ?? 0;
    return '₭ ${v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    )}';
  }

  // ── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StockPageHeader(
              titleLa: 'ລາຍການຂາຍ',
              titleEn: 'Sales',
              actions: [
                _buildLogToggle(),
                const SizedBox(width: 12),
                StockRefreshButton(
                    isLoading: _isLoading, onTap: _fetchAll),
                const SizedBox(width: 12),
                StockPrimaryButton(
                  icon: Icons.add_rounded,
                  label: 'ສ້າງລາຍການຂາຍ',
                  onTap: () => _showSaleForm(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStats(),
            const SizedBox(height: 20),
            _buildFiltersRow(),
            const SizedBox(height: 20),
            Expanded(
              child: _showLog
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildSalesList()),
                        const SizedBox(width: 16),
                        SizedBox(
                            width: 300, child: _buildLogPanel()),
                      ],
                    )
                  : _buildSalesList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── LOG TOGGLE ────────────────────────────────────────────────────────
  Widget _buildLogToggle() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _showLog = !_showLog),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _showLog
                    ? StockTheme.primary.withOpacity(0.15)
                    : StockTheme.bgCard.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _showLog
                      ? StockTheme.primary.withOpacity(0.5)
                      : StockTheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 18,
                      color: _showLog
                          ? StockTheme.primary
                          : StockTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text('Activity Log',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _showLog
                              ? StockTheme.primary
                              : StockTheme.textSecondary)),
                ],
              ),
            ),
          ),
        ),
        if (_logs.isNotEmpty)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: StockTheme.primary,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                _logs.length > 99 ? '99+' : '${_logs.length}',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  // ── LOG PANEL ─────────────────────────────────────────────────────────
  Widget _buildLogPanel() {
    return Container(
      decoration: BoxDecoration(
        color: StockTheme.bgDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: StockTheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: StockTheme.primary.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: StockTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.history_rounded,
                      size: 15, color: StockTheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Activity Log',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: StockTheme.textPrimary)),
                      Text('${_logs.length} events',
                          style: TextStyle(
                              fontSize: 10,
                              color: StockTheme.textSecondary
                                  .withOpacity(0.5))),
                    ],
                  ),
                ),
                if (_logs.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _logs.clear()),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: StockTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: StockTheme.error.withOpacity(0.2)),
                      ),
                      child: Text('Clear',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color:
                                  StockTheme.error.withOpacity(0.8))),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 36,
                            color: StockTheme.textSecondary
                                .withOpacity(0.25)),
                        const SizedBox(height: 10),
                        Text('No activity yet',
                            style: TextStyle(
                                fontSize: 12,
                                color: StockTheme.textSecondary
                                    .withOpacity(0.4))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount:   _logs.length,
                    itemBuilder: (context, i) =>
                        _buildLogEntry(_logs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(SaleActivityLog log) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: log.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: log.color.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: log.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(log.icon, size: 13, color: log.color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.description,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: StockTheme.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 9,
                        color: StockTheme.textSecondary
                            .withOpacity(0.4)),
                    const SizedBox(width: 3),
                    Text(log.user,
                        style: TextStyle(
                            fontSize: 10,
                            color: StockTheme.textSecondary
                                .withOpacity(0.5))),
                    const SizedBox(width: 8),
                    Icon(Icons.access_time_rounded,
                        size: 9,
                        color: StockTheme.textSecondary
                            .withOpacity(0.4)),
                    const SizedBox(width: 3),
                    Text(log.formattedTime,
                        style: TextStyle(
                            fontSize: 10,
                            color: StockTheme.textSecondary
                                .withOpacity(0.5))),
                  ],
                ),
                if (log.meta != null && log.meta!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: log.meta!.entries
                        .where((e) =>
                            e.value != null &&
                            e.value.toString().isNotEmpty)
                        .map((e) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: log.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('${e.key}: ${e.value}',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: log.color)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── STATS ─────────────────────────────────────────────────────────────
  Widget _buildStats() {
    final total      = _sales.length;
    final todayTotal = _summary['today_total'] ?? 0;
    final monthTotal = _summary['month_total'] ?? 0;
    final cancelled =
        _sales.where((s) => s['status'] == 'cancelled').length;

    return Row(
      children: [
        Expanded(
            child: StockStatCard(
                label: 'ລາຍການທັງໝົດ',
                value: '$total',
                icon: Icons.receipt_rounded,
                color: StockTheme.primary)),
        const SizedBox(width: 16),
        Expanded(
            child: StockStatCard(
                label: 'ຍອດຂາຍມື້ນີ້',
                value: _formatCurrency(todayTotal),
                icon: Icons.today_rounded,
                color: StockTheme.success)),
        const SizedBox(width: 16),
        Expanded(
            child: StockStatCard(
                label: 'ຍອດຂາຍເດືອນນີ້',
                value: _formatCurrency(monthTotal),
                icon: Icons.calendar_month_rounded,
                color: const Color(0xFF8B5CF6))),
        const SizedBox(width: 16),
        Expanded(
            child: StockStatCard(
                label: 'ຍົກເລີກ',
                value: '$cancelled',
                icon: Icons.cancel_rounded,
                color: StockTheme.error)),
      ],
    );
  }

  // ── FILTERS ROW ───────────────────────────────────────────────────────
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
              children: statusFilters
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: StockFilterChip(
                          value: f['value']!,
                          label: f['label']!,
                          isSelected: _statusFilter == f['value'],
                          onTap: () {
                            setState(() =>
                                _statusFilter = f['value']!);
                            if (f['value'] != 'all') {
                              _addLog(
                                SaleLogAction.filtered,
                                'Filtered by: ${f['label']}',
                                meta: {'status': f['value']},
                              );
                            }
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 240,
          height: 40,
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(
                color: StockTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ຄົ້ນຫາ...',
              hintStyle: TextStyle(
                  color: StockTheme.textSecondary.withOpacity(0.5),
                  fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: StockTheme.textSecondary, size: 18),
              filled: true,
              fillColor: StockTheme.bgCard.withOpacity(0.5),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: StockTheme.primary.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: StockTheme.primary.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: StockTheme.primary.withOpacity(0.5)),
              ),
            ),
            onChanged: (v) {
              setState(() => _searchKeyword = v);
              if (v.length >= 2) {
                _addLog(SaleLogAction.searched, 'Searched: "$v"',
                    meta: {'keyword': v});
              }
            },
          ),
        ),
      ],
    );
  }

  // ── SALES LIST ────────────────────────────────────────────────────────
  Widget _buildSalesList() {
    final sales = _filteredSales;

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: StockTheme.primary));
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
        'ເລກທີ', 'ຜູ້ຂາຍ', 'ວັນທີ', 'ລາຍການ',
        'ຍອດຮວມ', 'ຊຳລະ', 'ສະຖານະ', 'ຈັດການ'
      ],
      flexValues: const [2, 2, 2, 1, 2, 1, 1, 2],
      child: ListView.builder(
        padding:     const EdgeInsets.all(8),
        itemCount:   sales.length,
        itemBuilder: (context, index) {
          final s = sales[index];
          return TweenAnimationBuilder<double>(
            duration: Duration(
                milliseconds:
                    300 + (index * 40).clamp(0, 1000)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) =>
                Transform.translate(
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
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 14),
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
          // Sale number + notes
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
                          color: StockTheme.textSecondary
                              .withOpacity(0.6)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Cashier
          Expanded(
            flex: 2,
            child: Text(
                s['cashier'] ?? s['created_by'] ?? '-',
                style: const TextStyle(
                    fontSize: 13,
                    color: StockTheme.textSecondary)),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
                StockTheme.formatDate(
                    s['sale_date'] ?? s['created_at']),
                style: const TextStyle(
                    fontSize: 13,
                    color: StockTheme.textSecondary)),
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
          // Payment badge
          Expanded(
              flex: 1,
              child: _paymentBadge(
                  s['payment_method'] ?? 'cash')),
          // Status badge
          Expanded(
              flex: 1,
              child: StockStatusBadge(status: status)),
          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                StockActionButton(
                  icon: Icons.visibility_rounded,
                  color: StockTheme.info,
                  onTap: () => _viewSaleDetails(s),
                  tooltip: 'ເບິ່ງ',
                ),
                const SizedBox(width: 6),
                // Print button — always visible
                StockActionButton(
                  icon: Icons.print_rounded,
                  color: const Color(0xFF06B6D4),
                  onTap: () => _quickPrint(s),
                  tooltip: 'ພິມ',
                ),
                const SizedBox(width: 6),
                if (status == 'pending') ...[
                  StockActionButton(
                    icon: Icons.check_circle_rounded,
                    color: StockTheme.success,
                    onTap: () =>
                        _updateStatus(s, 'completed'),
                    tooltip: 'ສຳເລັດ',
                  ),
                  const SizedBox(width: 6),
                ],
                if (status != 'cancelled' &&
                    status != 'completed')
                  StockActionButton(
                    icon: Icons.cancel_rounded,
                    color: StockTheme.error,
                    onTap: () => _cancelSale(s),
                    tooltip: 'ຍົກເລີກ',
                  ),
                if (status == 'pending') ...[
                  const SizedBox(width: 6),
                  StockActionButton(
                    icon: Icons.edit_rounded,
                    color: StockTheme.primary,
                    onTap: () => _showSaleFormWithFetch(s),
                    tooltip: 'ແກ້ໄຂ',
                  ),
                ],
              ],
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
    final color =
        colors[method] ?? StockTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(labels[method] ?? method,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color),
          textAlign: TextAlign.center),
    );
  }

  // ── QUICK PRINT from list (fetches full sale first) ───────────────────
  Future<void> _quickPrint(Map<String, dynamic> sale) async {
    final saleId  = sale['id'] ?? sale['sale_id'];
    final saleNum = sale['sale_number'] ?? 'SALE-$saleId';
    try {
      final response = await SaleApiService.getSaleById(saleId);
      if (!mounted) return;
      final s     = response['data'] as Map<String, dynamic>? ?? sale;
      final items =
          (s['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      ReceiptPrinter.printReceipt(
        sale:        s,
        items:       items,
        shopName:    'iShop',
        shopAddress: 'ວຽງຈັນ, ລາວ',
      );
      _addLog(SaleLogAction.printed, 'Printed: $saleNum',
          meta: {
            'sale':   saleNum,
            'amount': _formatCurrency(s['total_amount']),
          });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ເກີດຂໍ້ຜິດພາດໃນການພິມ'),
          backgroundColor: StockTheme.error));
    }
  }

  // ── ACTIONS ───────────────────────────────────────────────────────────
  Future<void> _updateStatus(
      Map<String, dynamic> sale, String newStatus) async {
    final saleId  = sale['id'] ?? sale['sale_id'];
    final saleNum = sale['sale_number'] ?? 'SALE-$saleId';

    final confirmed = await showStockConfirmDialog(
      context,
      title: 'ປ່ຽນສະຖານະ',
      message:
          'ຢືນຢັນປ່ຽນສະຖານະເປັນ ${StockTheme.statusLabel(newStatus)}?',
      confirmLabel: 'ຢືນຢັນ',
      confirmColor: StockTheme.success,
    );
    if (!confirmed) return;

    try {
      final res = await SaleApiService.updateSale(
          saleId, {'status': newStatus});
      if (!mounted) return;
      if (res['responseCode'] == '00') {
        _addLog(SaleLogAction.completed,
            'Status → completed: $saleNum',
            meta: {
              'sale': saleNum,
              'from': sale['status'] ?? '-',
              'to':   newStatus,
            });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
          content: Text('ອັບເດດສະຖານະສຳເລັດ'),
          backgroundColor: StockTheme.success,
        ));
        _fetchSales();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'),
          backgroundColor: StockTheme.error,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ເກີດຂໍ້ຜິດພາດ'),
          backgroundColor: StockTheme.error));
    }
  }

  Future<void> _cancelSale(Map<String, dynamic> sale) async {
    final saleId  = sale['id'] ?? sale['sale_id'];
    final saleNum = sale['sale_number'] ?? 'SALE-$saleId';

    final confirmed = await showStockConfirmDialog(
      context,
      title: 'ຍົກເລີກລາຍການຂາຍ',
      message:
          'ຢືນຢັນຍົກເລີກ $saleNum?\nສິນຄ້າຈະຖືກຄືນເຂົ້າສາງ.',
      confirmLabel: 'ຍົກເລີກ',
      confirmColor: StockTheme.error,
    );
    if (!confirmed) return;

    try {
      final res = await SaleApiService.cancelSale(saleId);
      if (!mounted) return;
      if (res['responseCode'] == '00') {
        _addLog(SaleLogAction.cancelled,
            'Sale cancelled: $saleNum',
            meta: {
              'sale':   saleNum,
              'amount': _formatCurrency(sale['total_amount']),
              'by':     _me,
            });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
          content: Text('ຍົກເລີກລາຍການຂາຍສຳເລັດ'),
          backgroundColor: StockTheme.success,
        ));
        _fetchSales();
        _fetchSummary();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'),
          backgroundColor: StockTheme.error,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ເກີດຂໍ້ຜິດພາດ'),
          backgroundColor: StockTheme.error));
    }
  }

  Future<void> _showSaleFormWithFetch(
      Map<String, dynamic> sale) async {
    final saleId = sale['id'] ?? sale['sale_id'];
    try {
      final response = await SaleApiService.getSaleById(saleId);
      if (!mounted) return;
      final fullSale =
          response['data'] as Map<String, dynamic>? ?? sale;
      _showSaleForm(sale: fullSale);
    } catch (_) {
      if (!mounted) return;
      _showSaleForm(sale: sale);
    }
  }

  // ── VIEW DETAIL ───────────────────────────────────────────────────────
  void _viewSaleDetails(Map<String, dynamic> sale) async {
    final saleId  = sale['id'] ?? sale['sale_id'];
    final saleNum = sale['sale_number'] ?? 'SALE-$saleId';

    _addLog(SaleLogAction.viewed, 'Viewed sale: $saleNum', meta: {
      'sale':   saleNum,
      'amount': _formatCurrency(sale['total_amount']),
      'status': sale['status'] ?? '-',
    });

    try {
      final response = await SaleApiService.getSaleById(saleId);
      final s     = response['data'] as Map<String, dynamic>? ?? sale;
      final items =
          (s['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 720,
            constraints: const BoxConstraints(maxHeight: 680),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                StockTheme.bgDark.withOpacity(0.98),
                StockTheme.bgCard.withOpacity(0.98),
              ]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: StockTheme.primary.withOpacity(0.3),
                  width: 1),
            ),
            child: Column(
              children: [
                StockDialogHeader(
                  titleLa: s['sale_number'] ?? 'SALE-$saleId',
                  titleEn: 'Sale Details',
                  icon: Icons.receipt_long_rounded,
                  onClose: () => Navigator.pop(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _detailField('ຜູ້ຂາຍ',
                              s['cashier'] ??
                                  s['created_by'] ??
                                  '-'),
                          const SizedBox(width: 16),
                          _detailField(
                              'ວັນທີ',
                              StockTheme.formatDate(
                                  s['sale_date'] ??
                                      s['created_at'])),
                          const SizedBox(width: 16),
                          Expanded(
                              child: StockStatusBadge(
                                  status: s['status'] ??
                                      'pending')),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          _detailField('ຊຳລະດ້ວຍ',
                              s['payment_method'] ?? 'cash'),
                          const SizedBox(width: 16),
                          _detailField('ສ່ວນຫຼຸດ',
                              _formatCurrency(
                                  s['discount_amount'])),
                          const SizedBox(width: 16),
                          _detailField('ຍອດຮວມ',
                              _formatCurrency(
                                  s['total_amount'])),
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
                              style: TextStyle(
                                  color:
                                      StockTheme.textSecondary))
                        else
                          ...items.map((item) => Container(
                                margin: const EdgeInsets.only(
                                    bottom: 8),
                                padding:
                                    const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: StockTheme.bgDarker
                                      .withOpacity(0.3),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                      color: StockTheme.primary
                                          .withOpacity(0.1)),
                                ),
                                child: Row(children: [
                                  Expanded(
                                      flex: 3,
                                      child: Text(
                                          item['product_name'] ??
                                              'Product #${item['product_id']}',
                                          style: const TextStyle(
                                              color: StockTheme
                                                  .textPrimary,
                                              fontWeight:
                                                  FontWeight
                                                      .w600))),
                                  Expanded(
                                      child: Text(
                                          'x${item['quantity'] ?? 0}',
                                          style: const TextStyle(
                                              color: StockTheme
                                                  .textSecondary,
                                              fontSize: 12))),
                                  Expanded(
                                      child: Text(
                                          '${StockTheme.formatPrice(item['unit_price'])} ₭',
                                          style: const TextStyle(
                                              color: StockTheme
                                                  .textSecondary,
                                              fontSize: 12))),
                                  Expanded(
                                      child: Text(
                                          '${StockTheme.formatPrice(item['subtotal'])} ₭',
                                          style: const TextStyle(
                                              color: StockTheme
                                                  .success,
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 12))),
                                ]),
                              )),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: StockTheme.primary
                                .withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: StockTheme.primary
                                    .withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('ຍອດລວມທັງໝົດ',
                                  style: TextStyle(
                                      color: StockTheme
                                          .textSecondary
                                          .withOpacity(0.8),
                                      fontWeight:
                                          FontWeight.w600)),
                              Text(
                                  _formatCurrency(
                                      s['total_amount']),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color:
                                          StockTheme.success)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Print footer ──
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      24, 12, 24, 20),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: StockTheme.primary
                                .withOpacity(0.1))),
                  ),
                  child: Row(children: [
                    // Print button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ReceiptPrinter.printReceipt(
                            sale:        s,
                            items:       items,
                            shopName:    'iShop',
                            shopAddress: 'ວຽງຈັນ, ລາວ',
                          );
                          _addLog(
                            SaleLogAction.printed,
                            'Printed: ${s['sale_number'] ?? saleNum}',
                            meta: {
                              'sale': s['sale_number'] ?? saleNum,
                              'amount': _formatCurrency(
                                  s['total_amount']),
                            },
                          );
                        },
                        icon: const Icon(Icons.print_rounded,
                            color: Colors.white, size: 18),
                        label: const Text('ພິມໃບຮັບເງິນ',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF06B6D4),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Close button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: StockTheme.primary
                                  .withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                        child: const Text('ປິດ',
                            style: TextStyle(
                                color: StockTheme.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ເກີດຂໍ້ຜິດພາດ'),
          backgroundColor: StockTheme.error));
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

  // ── CREATE / EDIT FORM ────────────────────────────────────────────────
  void _showSaleForm({Map<String, dynamic>? sale}) {
    final isEdit         = sale != null;
    final formKey        = GlobalKey<FormState>();
    final saleNumberCtrl =
        TextEditingController(text: sale?['sale_number'] ?? '');
    final notesCtrl =
        TextEditingController(text: sale?['notes'] ?? '');
    final discountCtrl = TextEditingController(
        text: (sale?['discount_amount'] ?? '0').toString());

    String selectedPayment = sale?['payment_method'] ?? 'cash';
    final List<Map<String, dynamic>> cartItems = [];
    if (isEdit && sale?['items'] != null) {
      cartItems.addAll(
          (sale!['items'] as List).cast<Map<String, dynamic>>());
    }

    int? selectedProductId;
    final qtyCtrl   = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    VoidCallback? _discountListener;

    void disposeDialogControllers() {
      if (_discountListener != null) {
        discountCtrl.removeListener(_discountListener!);
      }
      saleNumberCtrl.dispose();
      notesCtrl.dispose();
      discountCtrl.dispose();
      qtyCtrl.dispose();
      priceCtrl.dispose();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (_discountListener != null) {
            discountCtrl.removeListener(_discountListener!);
          }
          _discountListener = () => setDialogState(() {});
          discountCtrl.addListener(_discountListener!);

          final double subtotal = cartItems.fold<double>(
              0.0,
              (sum, item) =>
                  sum +
                  ((num.tryParse(item['unit_price'].toString()) ??
                          0) *
                      (item['quantity'] as int? ?? 1)));
          final double discount =
              (num.tryParse(discountCtrl.text) ?? 0).toDouble();
          final double total =
              (subtotal - discount).clamp(0, double.infinity);

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 700,
              constraints: const BoxConstraints(maxHeight: 700),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  StockTheme.bgDark.withOpacity(0.98),
                  StockTheme.bgCard.withOpacity(0.98),
                ]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: StockTheme.primary.withOpacity(0.3),
                    width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StockDialogHeader(
                    titleLa: isEdit
                        ? 'ແກ້ໄຂລາຍການຂາຍ'
                        : 'ສ້າງລາຍການຂາຍໃໝ່',
                    titleEn: isEdit ? 'Edit Sale' : 'New Sale',
                    icon: Icons.receipt_rounded,
                    onClose: () {
                      disposeDialogControllers();
                      Navigator.pop(context);
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: buildStockFormField(
                                      label:
                                          'ເລກທີ (Sale Number)',
                                      controller: saleNumberCtrl,
                                      icon: Icons.tag_rounded)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: buildStockDropdown<String>(
                                label: 'ຮູບແບບການຊຳລະ',
                                icon: Icons.payment_rounded,
                                value: selectedPayment,
                                hint: 'ເລືອກ',
                                items: const [
                                  DropdownMenuItem(
                                      value: 'cash',
                                      child: Text('ເງິນສົດ')),
                                  DropdownMenuItem(
                                      value: 'card',
                                      child: Text('ບັດ')),
                                  DropdownMenuItem(
                                      value: 'transfer',
                                      child: Text('ໂອນ')),
                                  DropdownMenuItem(
                                      value: 'credit',
                                      child: Text('ສິນເຊື່ອ')),
                                ],
                                onChanged: (v) => setDialogState(
                                    () => selectedPayment =
                                        v ?? 'cash'),
                              )),
                            ]),
                            const SizedBox(height: 16),
                            const Text('ເພີ່ມສິນຄ້າ',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: StockTheme.textPrimary)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                flex: 3,
                                child: buildStockDropdown<int>(
                                  label: 'ສິນຄ້າ',
                                  icon: Icons.inventory_2_rounded,
                                  value: selectedProductId,
                                  hint: 'ເລືອກສິນຄ້າ',
                                  items: _products
                                      .map((p) =>
                                          DropdownMenuItem<int>(
                                            value: p['id'] ??
                                                p['product_id'],
                                            child: Text(
                                                p['product_name'] ??
                                                    ''),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    setDialogState(() {
                                      selectedProductId = v;
                                      final prod =
                                          _products.firstWhere(
                                              (p) =>
                                                  (p['id'] ??
                                                      p['product_id']) ==
                                                  v,
                                              orElse: () => {});
                                      priceCtrl.text =
                                          (prod['sale_price'] ??
                                                  prod['price'] ??
                                                  '0')
                                              .toString();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: buildStockFormField(
                                      label: 'ຈຳນວນ',
                                      controller: qtyCtrl,
                                      icon: Icons.numbers_rounded,
                                      keyboardType:
                                          TextInputType.number)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: buildStockFormField(
                                      label: 'ລາຄາ',
                                      controller: priceCtrl,
                                      icon: Icons
                                          .monetization_on_rounded,
                                      keyboardType:
                                          TextInputType.number)),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  if (selectedProductId == null)
                                    return;
                                  final prod =
                                      _products.firstWhere(
                                          (p) =>
                                              (p['id'] ??
                                                  p['product_id']) ==
                                              selectedProductId,
                                          orElse: () => {});
                                  setDialogState(() {
                                    cartItems.add({
                                      'product_id':
                                          selectedProductId,
                                      'product_name':
                                          prod['product_name'] ??
                                              '-',
                                      'product_code':
                                          prod['product_code'] ??
                                              prod['barcode'] ??
                                              prod['sku'] ??
                                              '',
                                      'quantity': int.tryParse(
                                              qtyCtrl.text) ??
                                          1,
                                      'unit_price':
                                          num.tryParse(
                                                  priceCtrl.text) ??
                                              0,
                                    });
                                    selectedProductId = null;
                                    qtyCtrl.text  = '1';
                                    priceCtrl.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      StockTheme.primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14),
                                ),
                                child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white),
                              ),
                            ]),
                            if (cartItems.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ...cartItems.asMap().entries.map(
                                (entry) {
                                  final i    = entry.key;
                                  final item = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 6),
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10),
                                    decoration: BoxDecoration(
                                      color: StockTheme.bgDarker
                                          .withOpacity(0.3),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color: StockTheme.primary
                                              .withOpacity(0.1)),
                                    ),
                                    child: Row(children: [
                                      Expanded(
                                          flex: 3,
                                          child: Text(
                                              item['product_name'] ??
                                                  '-',
                                              style: const TextStyle(
                                                  color: StockTheme
                                                      .textPrimary,
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight
                                                          .w600))),
                                      Text(
                                          'x${item['quantity']}',
                                          style: const TextStyle(
                                              color: StockTheme
                                                  .textSecondary,
                                              fontSize: 12)),
                                      const SizedBox(width: 12),
                                      Text(
                                          '${StockTheme.formatPrice(item['unit_price'])} ₭',
                                          style: const TextStyle(
                                              color: StockTheme
                                                  .textSecondary,
                                              fontSize: 12)),
                                      const SizedBox(width: 12),
                                      Text(
                                          '${StockTheme.formatPrice((num.tryParse(item['unit_price'].toString()) ?? 0) * (item['quantity'] as int? ?? 1))} ₭',
                                          style: const TextStyle(
                                              color:
                                                  StockTheme.success,
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 12)),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () =>
                                            setDialogState(() =>
                                                cartItems
                                                    .removeAt(i)),
                                        child: const Icon(
                                            Icons.close_rounded,
                                            color: StockTheme.error,
                                            size: 18),
                                      ),
                                    ]),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(
                                  child: buildStockFormField(
                                      label: 'ສ່ວນຫຼຸດ (₭)',
                                      controller: discountCtrl,
                                      icon: Icons.discount_rounded,
                                      keyboardType:
                                          TextInputType.number)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: buildStockFormField(
                                      label: 'ໝາຍເຫດ',
                                      controller: notesCtrl,
                                      icon: Icons.notes_rounded)),
                            ]),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: StockTheme.primary
                                    .withOpacity(0.08),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color: StockTheme.primary
                                        .withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('ຍອດລວມທັງໝົດ',
                                      style: TextStyle(
                                          color: StockTheme
                                              .textSecondary
                                              .withOpacity(0.8),
                                          fontWeight:
                                              FontWeight.w600)),
                                  Text(_formatCurrency(total),
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color:
                                              StockTheme.success)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  StockDialogFooter(
                    onCancel: () {
                      disposeDialogControllers();
                      Navigator.pop(context);
                    },
                    saveLabel:
                        isEdit ? 'ບັນທຶກ' : 'ສ້າງລາຍການຂາຍ',
                    onSave: () async {
                      if (!formKey.currentState!.validate())
                        return;
                      if (cartItems.isEmpty) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content:
                              Text('ກະລຸນາເພີ່ມລາຍການສິນຄ້າ'),
                          backgroundColor: StockTheme.warning,
                        ));
                        return;
                      }

                      final double subTot = cartItems.fold<double>(
                          0.0,
                          (sum, item) =>
                              sum +
                              ((num.tryParse(item['unit_price']
                                          .toString()) ??
                                      0) *
                                  (item['quantity'] as int? ?? 1)));
                      final double disc =
                          (num.tryParse(discountCtrl.text) ?? 0)
                              .toDouble();

                      final body = {
                        'sale_number':    saleNumberCtrl.text,
                        'payment_method': selectedPayment,
                        'discount_amount': disc,
                        'total_amount':
                            (subTot - disc).clamp(0, double.infinity),
                        'notes':      notesCtrl.text,
                        'created_by': widget.currentUser['username'],
                        'cashier_id': widget.currentUser['user_id'] ??
                            widget.currentUser['id'],
                        'cashier':
                            widget.currentUser['full_name'] ??
                                widget.currentUser['username'],
                        'items': cartItems
                            .map((item) => {
                                  'product_id': item['product_id'],
                                  'product_code':
                                      item['product_code'] ?? '',
                                  'product_name':
                                      item['product_name'] ?? '',
                                  'quantity':   item['quantity'],
                                  'unit_price': item['unit_price'],
                                  'subtotal':
                                      (num.tryParse(item['unit_price']
                                                  .toString()) ??
                                              0) *
                                          (item['quantity'] as int? ??
                                              1),
                                })
                            .toList(),
                      };

                      try {
                        final res = isEdit
                            ? await SaleApiService.updateSale(
                                sale!['id'] ?? sale['sale_id'],
                                body)
                            : await SaleApiService.createSale(body);

                        if (res['responseCode'] == '00') {
                          final saleNum =
                              saleNumberCtrl.text.isNotEmpty
                                  ? saleNumberCtrl.text
                                  : (res['data']?['sale_number'] ??
                                      '-');

                          disposeDialogControllers();
                          if (!mounted) return;
                          Navigator.pop(context);

                          _addLog(
                            isEdit
                                ? SaleLogAction.edited
                                : SaleLogAction.created,
                            isEdit
                                ? 'Sale edited: $saleNum'
                                : 'New sale created: $saleNum',
                            meta: {
                              'sale':    saleNum,
                              'items':   '${cartItems.length}',
                              'total':   _formatCurrency(
                                  body['total_amount']),
                              'payment': selectedPayment,
                            },
                          );

                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(
                                '${isEdit ? "ອັບເດດ" : "ສ້າງ"}ລາຍການຂາຍສຳເລັດ'),
                            backgroundColor: StockTheme.success,
                          ));

                          _fetchAll();

                          if (!isEdit) {
                            Future.delayed(
                              const Duration(milliseconds: 600),
                              () {
                                if (mounted) {
                                  widget.onSaleCreated?.call();
                                }
                              },
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(
                                res['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'),
                            backgroundColor: StockTheme.error,
                          ));
                        }
                      } catch (_) {
                        disposeDialogControllers();
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content:
                              Text('ເກີດຂໍ້ຜິດພາດໃນການເຊື່ອມຕໍ່'),
                          backgroundColor: StockTheme.error,
                        ));
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}