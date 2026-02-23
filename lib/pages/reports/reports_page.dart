// lib/pages/reports/reports_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DARK + BLUE THEME CONSTANTS
// Add/replace these in your StockTheme class in stock_ui_helpers.dart:
//
//   static const Color primary        = Color(0xFF2563EB); // electric blue
//   static const Color primaryLight   = Color(0xFF60A5FA); // sky blue
//   static const Color success        = Color(0xFF10B981); // emerald
//   static const Color warning        = Color(0xFFF59E0B); // amber
//   static const Color error          = Color(0xFFEF4444); // red
//   static const Color bgCard         = Color(0xFF1E2A3B); // dark navy card
//   static const Color bgPage         = Color(0xFF0F172A); // deep navy page bg
//   static const Color textPrimary    = Color(0xFFE2E8F0); // slate-200
//   static const Color textSecondary  = Color(0xFF94A3B8); // slate-400
// ─────────────────────────────────────────────────────────────────────────────

class ReportsPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final int initialTab;

  const ReportsPage({
    super.key,
    required this.currentUser,
    this.initialTab = 0,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 4, vsync: this, initialIndex: widget.initialTab);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

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
              titleLa: 'ລາຍງານ',
              titleEn: 'Reports',
              actions: const [],
            ),
            const SizedBox(height: 20),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabAlignment: TabAlignment.start,
              isScrollable: true,
              dividerColor: const Color(0xFF2563EB).withOpacity(0.15),
              dividerHeight: 1,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF94A3B8),
              padding: EdgeInsets.zero,
              tabs: const [
                Tab(child: _TabLabel(Icons.point_of_sale_rounded,  'ລາຍງານຍອດຂາຍ')),
                Tab(child: _TabLabel(Icons.inventory_2_rounded,    'ລາຍງານສາງ')),
                Tab(child: _TabLabel(Icons.people_rounded,         'ລາຍງານລູກຄ້າ')),
                Tab(child: _TabLabel(Icons.badge_rounded,          'ລາຍງານພະນັກງານ')),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SalesReportTab(currentUser: widget.currentUser),
                  _InventoryReportTab(currentUser: widget.currentUser),
                  _CustomerReportTab(currentUser: widget.currentUser),
                  _UserReportTab(currentUser: widget.currentUser),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TabLabel(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(label),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
final _numFmt  = NumberFormat('#,##0', 'en');
final _dateFmt = DateFormat('dd/MM/yyyy');
final _mthFmt  = DateFormat('MMM yyyy');

// Dark + blue palette shortcuts
const _kPrimary       = Color(0xFF2563EB);
const _kPrimaryLight  = Color(0xFF60A5FA);
const _kSuccess       = Color(0xFF10B981);
const _kWarning       = Color(0xFFF59E0B);
const _kError         = Color(0xFFEF4444);
const _kBgCard        = Color(0xFF1E2A3B);
const _kTextPrimary   = Color(0xFFE2E8F0);
const _kTextSecondary = Color(0xFF94A3B8);

String _fNum(dynamic v)  => _numFmt.format(num.tryParse(v.toString()) ?? 0);
String _fDate(dynamic v) {
  if (v == null) return '-';
  try { return _dateFmt.format(DateTime.parse(v.toString())); } catch (_) { return v.toString(); }
}

Color _rColor(int idx) {
  const colors = [
    _kPrimary, _kSuccess, _kWarning,
    _kError, Color(0xFF8B5CF6), Color(0xFFEC4899),
    Color(0xFF06B6D4), Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFF6366F1),
  ];
  return colors[idx % colors.length];
}

Widget _loadingWidget() => const Center(
    child: CircularProgressIndicator(color: _kPrimary));

Widget _emptyWidget(String msg) => Center(
  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.inbox_rounded, size: 56, color: _kTextSecondary.withOpacity(0.2)),
    const SizedBox(height: 12),
    Text(msg, style: TextStyle(fontSize: 14, color: _kTextSecondary.withOpacity(0.4))),
  ]),
);

Widget _sectionTitle(String title, {IconData? icon}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(children: [
    if (icon != null) ...[
      Icon(icon, size: 16, color: _kPrimary),
      const SizedBox(width: 8),
    ],
    Text(title, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w800, color: _kTextPrimary)),
  ]),
);

Widget _statCard(String label, String value, IconData icon, Color color) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kBgCard,
            color.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const Spacer(),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            fontSize: 12, color: _kTextSecondary.withOpacity(0.7))),
      ]),
    );

// ─────────────────────────────────────────────────────────────────────────────
// 1. SALES REPORT TAB
// ─────────────────────────────────────────────────────────────────────────────
class _SalesReportTab extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const _SalesReportTab({required this.currentUser});

  @override
  State<_SalesReportTab> createState() => _SalesReportTabState();
}

class _SalesReportTabState extends State<_SalesReportTab> {
  String _period = 'day';
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;

  Map<String, dynamic> _summary = {};
  List _topProducts = [];
  List _byCategory  = [];
  List _salesList   = [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _startStr {
    if (_period == 'month') {
      return DateFormat('yyyy-MM-01').format(_selectedDate);
    } else if (_period == 'year') {
      return DateFormat('yyyy-01-01').format(_selectedDate);
    }
    return _dateStr;
  }
  String get _endStr {
    if (_period == 'month') {
      final last = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      return DateFormat('yyyy-MM-dd').format(last);
    } else if (_period == 'year') {
      return DateFormat('yyyy-12-31').format(_selectedDate);
    }
    return _dateStr;
  }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getSalesSummary(period: _period, date: _dateStr),
      ApiService.getTopProducts(startDate: _startStr, endDate: _endStr),
      ApiService.getSalesByCategory(startDate: _startStr, endDate: _endStr),
      ApiService.getSalesList(startDate: _startStr, endDate: _endStr, limit: 100),
    ]);
    if (!mounted) return;
    setState(() {
      _summary     = results[0] as Map<String, dynamic>;
      _topProducts = results[1] as List;
      _byCategory  = results[2] as List;
      final sl     = results[3] as Map<String, dynamic>;
      _salesList   = sl['data'] as List? ?? sl['items'] as List? ?? [];
      _loading     = false;
    });
    debugPrint('=== Sales summary: $_summary ===');
    debugPrint('=== Top products: ${_topProducts.length} ===');
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle both response formats:
    // New:  { data: { total_orders, total_revenue, total_sales, avg_order } }
    // Old:  { today: { total_transactions, total_revenue }, monthly: {...} }
    final data    = _summary['data'] as Map<String, dynamic>? ?? _summary;
    final today   = _summary['today']   as Map<String, dynamic>? ?? {};

    final totalOrders  = data['total_orders']  ?? data['totalOrders']
                      ?? today['total_transactions']
                      ?? 0;
    final totalRevenue = data['total_revenue'] ?? data['totalRevenue']
                      ?? today['total_revenue']
                      ?? 0;
    final totalSales   = data['total_sales']   ?? data['totalSales']
                      ?? today['total_transactions']
                      ?? 0;
    final _avgNum      = (num.tryParse(totalOrders.toString()) ?? 0);
    final avgOrder     = data['avg_order'] ?? data['avgOrder']
                      ?? (_avgNum > 0
                          ? (num.tryParse(totalRevenue.toString()) ?? 0) / _avgNum
                          : 0);

    return _loading
        ? _loadingWidget()
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Period selector ──
                Row(children: [
                  _PeriodBtn('ລາຍວັນ', 'day',   _period, (v) { setState(() => _period = v); _fetchAll(); }),
                  const SizedBox(width: 8),
                  _PeriodBtn('ລາຍເດືອນ', 'month', _period, (v) { setState(() => _period = v); _fetchAll(); }),
                  const SizedBox(width: 8),
                  _PeriodBtn('ລາຍປີ',  'year',  _period, (v) { setState(() => _period = v); _fetchAll(); }),
                  const SizedBox(width: 16),
                  // Date picker
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kBgCard.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kPrimary.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 14, color: _kPrimaryLight),
                        const SizedBox(width: 8),
                        Text(
                          _period == 'day'   ? _dateFmt.format(_selectedDate)
                              : _period == 'month' ? _mthFmt.format(_selectedDate)
                              : DateFormat('yyyy').format(_selectedDate),
                          style: const TextStyle(
                              fontSize: 13, color: _kTextPrimary,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_drop_down_rounded,
                            color: _kTextSecondary.withOpacity(0.6)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  // Refresh
                  StockRefreshButton(isLoading: _loading, onTap: _fetchAll),
                ]),
                const SizedBox(height: 20),

                // ── Summary cards ──
                Row(children: [
                  Expanded(child: _statCard('ຍອດຂາຍ (ໃບ)', '$totalOrders',
                      Icons.receipt_long_rounded, _kPrimary)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('ລາຍຮັບທັງໝົດ',
                      '₭ ${_fNum(totalRevenue)}',
                      Icons.payments_rounded, _kSuccess)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('ສິນຄ້າທີ່ຂາຍ', '$totalSales',
                      Icons.shopping_bag_rounded, _kWarning)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('ສະເລ່ຍ/ໃບ',
                      '₭ ${_fNum(avgOrder)}',
                      Icons.bar_chart_rounded, _kError)),
                ]),
                const SizedBox(height: 24),

                // ── Top 10 products + Category side by side ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top products
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _kBgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _kPrimary.withOpacity(0.15)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('ສິນຄ້າຂາຍດີ Top 10',
                                icon: Icons.emoji_events_rounded),
                            if (_topProducts.isEmpty)
                              _emptyWidget('ບໍ່ມີຂໍ້ມູນ')
                            else
                              ..._topProducts.asMap().entries.map((e) {
                                final i = e.key;
                                final p = e.value;
                                final name = p['product_name'] ?? p['name'] ?? '-';
                                final qty  = p['total_qty']  ?? p['qty']  ?? 0;
                                final rev  = p['total_revenue'] ?? p['revenue'] ?? 0;
                                final maxQty = (_topProducts.first['total_qty']
                                    ?? _topProducts.first['qty'] ?? 1) as num;
                                final pct = maxQty > 0
                                    ? (qty as num) / maxQty : 0.0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(children: [
                                    // Rank
                                    SizedBox(
                                      width: 28,
                                      child: Text('${i + 1}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: i < 3
                                                  ? _rColor(i)
                                                  : _kTextSecondary.withOpacity(0.5))),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                              child: Text(name,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: _kTextPrimary),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis),
                                            ),
                                            Text('$qty ຊ່ວຍ',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: _kTextSecondary.withOpacity(0.6))),
                                          ]),
                                          const SizedBox(height: 4),
                                          Stack(children: [
                                            Container(
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(4),
                                                )),
                                            FractionallySizedBox(
                                              widthFactor: pct.toDouble(),
                                              child: Container(
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [_rColor(i), _rColor(i).withOpacity(0.5)],
                                                    ),
                                                    borderRadius: BorderRadius.circular(4),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: _rColor(i).withOpacity(0.4),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  )),
                                            ),
                                          ]),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('₭ ${_fNum(rev)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _kSuccess)),
                                  ]),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // By category
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _kBgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _kPrimary.withOpacity(0.15)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('ຍອດຂາຍຕາມໝວດ',
                                icon: Icons.pie_chart_rounded),
                            if (_byCategory.isEmpty)
                              _emptyWidget('ບໍ່ມີຂໍ້ມູນ')
                            else
                              ..._byCategory.asMap().entries.map((e) {
                                final i   = e.key;
                                final cat = e.value;
                                final name = cat['category_name'] ?? cat['name'] ?? '-';
                                final rev  = cat['total_revenue'] ?? cat['revenue'] ?? 0;
                                final qty  = cat['total_qty']     ?? cat['qty']     ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(children: [
                                    Container(
                                      width: 10, height: 10,
                                      decoration: BoxDecoration(
                                        color: _rColor(i),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _rColor(i).withOpacity(0.5),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(name,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: _kTextPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₭ ${_fNum(rev)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: _kTextPrimary)),
                                        Text('$qty ຊ່ວຍ',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: _kTextSecondary.withOpacity(0.5))),
                                      ],
                                    ),
                                  ]),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Sales list ──
                _sectionTitle('ລາຍການຂາຍ (ໃບບິນ)',
                    icon: Icons.receipt_long_rounded),
                if (_salesList.isEmpty)
                  _emptyWidget('ບໍ່ມີລາຍການຂາຍ')
                else
                  Container(
                    decoration: BoxDecoration(
                      color: _kBgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kPrimary.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _kPrimary.withOpacity(0.15),
                              _kPrimary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14)),
                        ),
                        child: Row(children: [
                          Expanded(flex: 2, child: Text('ເລກໃບບິນ',
                              style: _hStyle)),
                          Expanded(flex: 2, child: Text('ວັນທີ', style: _hStyle)),
                          Expanded(flex: 2, child: Text('ລູກຄ້າ', style: _hStyle)),
                          Expanded(flex: 1, child: Text('ລາຍການ',
                              style: _hStyle, textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('ລວມ',
                              style: _hStyle, textAlign: TextAlign.right)),
                        ]),
                      ),
                      ..._salesList.take(50).toList().asMap().entries.map((e) {
                        final i = e.key;
                        final s = e.value;
                        final ref      = s['sale_ref']   ?? s['order_no'] ?? s['id'] ?? '-';
                        final date     = s['created_at'] ?? s['sale_date'] ?? '-';
                        final customer = s['customer_name'] ?? s['customer'] ?? 'Walk-in';
                        final items    = s['total_items']   ?? s['items']   ?? 0;
                        final total    = s['total_amount']  ?? s['total']   ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.02),
                          ),
                          child: Row(children: [
                            Expanded(flex: 2, child: Text('#$ref',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _kPrimaryLight))),
                            Expanded(flex: 2, child: Text(_fDate(date),
                                style: _rStyle)),
                            Expanded(flex: 2, child: Text(customer.toString(),
                                style: _rStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                            Expanded(flex: 1, child: Text('$items',
                                style: _rStyle,
                                textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text(
                                '₭ ${_fNum(total)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _kSuccess),
                                textAlign: TextAlign.right)),
                          ]),
                        );
                      }),
                    ]),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
  }
}

const _hStyle = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700,
    color: _kTextSecondary, letterSpacing: 0.5);
const _rStyle = TextStyle(fontSize: 12, color: _kTextPrimary);

class _PeriodBtn extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _PeriodBtn(this.label, this.value, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [_kPrimary, _kPrimaryLight])
              : null,
          color: selected ? null : _kBgCard.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? _kPrimary.withOpacity(0.7)
                  : _kPrimary.withOpacity(0.2)),
          boxShadow: selected ? [
            BoxShadow(
              color: _kPrimary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _kTextSecondary)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. INVENTORY REPORT TAB
// ─────────────────────────────────────────────────────────────────────────────
class _InventoryReportTab extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const _InventoryReportTab({required this.currentUser});

  @override
  State<_InventoryReportTab> createState() => _InventoryReportTabState();
}

class _InventoryReportTabState extends State<_InventoryReportTab> {
  bool _loading = false;
  Map<String, dynamic> _report = {};
  List _movements = [];
  String _movType = 'all';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate   = DateTime.now();

  @override
  void initState() { super.initState(); _fetchAll(); }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final sd = DateFormat('yyyy-MM-dd').format(_startDate);
    final ed = DateFormat('yyyy-MM-dd').format(_endDate);
    final results = await Future.wait([
      ApiService.getInventoryReport(),
      ApiService.getStockMovements(startDate: sd, endDate: ed, type: _movType),
    ]);
    if (!mounted) return;
    setState(() {
      _report    = results[0] as Map<String, dynamic>;
      _movements = results[1] as List;
      _loading   = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingWidget();

    final data         = _report['data'] ?? _report;
    final totalProducts  = data['total_products']  ?? 0;
    final lowStock       = data['low_stock_count'] ?? 0;
    final outStock       = data['out_of_stock']    ?? 0;
    final inventoryValue = data['total_value']     ?? data['inventory_value'] ?? 0;
    final products       = (data['products'] as List? ?? []);
    final lowStockList   = products
        .where((p) => (p['stock_status'] ?? '') == 'low' ||
            (p['current_stock'] ?? 0) > 0 &&
            (p['current_stock'] ?? 0) <= (p['reorder_point'] ?? 10))
        .toList();
    final outStockList = products
        .where((p) => (p['current_stock'] ?? 0) == 0)
        .toList();

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          _sectionTitle('ສາງສິນຄ້າ', icon: Icons.inventory_2_rounded),
          const Spacer(),
          StockRefreshButton(isLoading: _loading, onTap: _fetchAll),
        ]),
        const SizedBox(height: 12),

        // Stats
        Row(children: [
          Expanded(child: _statCard('ສິນຄ້າທັງໝົດ', '$totalProducts',
              Icons.inventory_2_rounded, _kPrimary)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('ມູນຄ່າສາງ', '₭ ${_fNum(inventoryValue)}',
              Icons.account_balance_wallet_rounded, _kSuccess)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('ໃກ້ໝົດ', '$lowStock',
              Icons.warning_amber_rounded, _kWarning)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('ໝົດສາງ', '$outStock',
              Icons.remove_shopping_cart_rounded, _kError)),
        ]),
        const SizedBox(height: 24),

        // Low stock + Out of stock side by side
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _StockAlertTable(
            title: 'ສິນຄ້າໃກ້ໝົດ', color: _kWarning,
            icon: Icons.warning_amber_rounded, items: lowStockList)),
          const SizedBox(width: 16),
          Expanded(child: _StockAlertTable(
            title: 'ສິນຄ້າໝົດສາງ', color: _kError,
            icon: Icons.error_rounded, items: outStockList)),
        ]),
        const SizedBox(height: 24),

        // Stock movements
        _sectionTitle('ປະຫວັດ Stock In/Out', icon: Icons.swap_vert_rounded),
        // Filter row
        Row(children: [
          _PeriodBtn('ທັງໝົດ', 'all', _movType, (v) { setState(() => _movType = v); _fetchAll(); }),
          const SizedBox(width: 8),
          _PeriodBtn('ຮັບເຂົ້າ', 'in', _movType, (v) { setState(() => _movType = v); _fetchAll(); }),
          const SizedBox(width: 8),
          _PeriodBtn('ຈ່າຍອອກ', 'out', _movType, (v) { setState(() => _movType = v); _fetchAll(); }),
          const SizedBox(width: 16),
          _DateRangePicker(
            start: _startDate, end: _endDate,
            onChanged: (s, e) { setState(() { _startDate = s; _endDate = e; }); _fetchAll(); },
          ),
        ]),
        const SizedBox(height: 12),

        if (_movements.isEmpty)
          _emptyWidget('ບໍ່ມີລາຍການ')
        else
          Container(
            decoration: BoxDecoration(
              color: _kBgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kPrimary.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _kPrimary.withOpacity(0.15),
                      _kPrimary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(children: [
                  Expanded(flex: 2, child: Text('ວັນທີ', style: _hStyle)),
                  Expanded(flex: 3, child: Text('ສິນຄ້າ', style: _hStyle)),
                  Expanded(flex: 1, child: Text('ປະເພດ', style: _hStyle, textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('ຈຳນວນ', style: _hStyle, textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('ໝາຍເຫດ', style: _hStyle)),
                ]),
              ),
              ..._movements.take(100).toList().asMap().entries.map((e) {
                final i   = e.key;
                final mv  = e.value;
                final type = mv['type'] ?? mv['movement_type'] ?? '-';
                final isIn = type == 'in';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: i.isEven ? Colors.transparent : Colors.white.withOpacity(0.02),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text(
                        _fDate(mv['created_at'] ?? mv['date']), style: _rStyle)),
                    Expanded(flex: 3, child: Text(
                        mv['product_name'] ?? mv['product'] ?? '-',
                        style: _rStyle, maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 1, child: Center(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isIn ? _kSuccess : _kError).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isIn ? _kSuccess : _kError).withOpacity(0.3),
                        ),
                      ),
                      child: Text(isIn ? 'IN' : 'OUT',
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isIn ? _kSuccess : _kError)),
                    ))),
                    Expanded(flex: 1, child: Text(
                        '${isIn ? '+' : '-'}${mv['quantity'] ?? 0}',
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isIn ? _kSuccess : _kError),
                        textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(mv['reason'] ?? '-',
                          style: TextStyle(fontSize: 11,
                              color: _kTextSecondary.withOpacity(0.6)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    )),
                  ]),
                );
              }),
            ]),
          ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _StockAlertTable extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List items;
  const _StockAlertTable(
      {required this.title, required this.color,
       required this.icon,  required this.items});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kBgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.25)),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Text('${items.length}',
              style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w800, color: color)),
        ),
      ]),
      const SizedBox(height: 12),
      if (items.isEmpty)
        Text('ບໍ່ມີ', style: TextStyle(fontSize: 13,
            color: _kTextSecondary.withOpacity(0.4)))
      else
        ...items.take(10).map((p) {
          final name  = p['product_name'] ?? p['name'] ?? '-';
          final stock = p['current_stock'] ?? p['stock'] ?? 0;
          final reorder = p['reorder_point'] ?? 10;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Text(name,
                  style: const TextStyle(fontSize: 12,
                      color: _kTextPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text('$stock / $reorder',
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          );
        }),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. CUSTOMER REPORT TAB
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerReportTab extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const _CustomerReportTab({required this.currentUser});

  @override
  State<_CustomerReportTab> createState() => _CustomerReportTabState();
}

class _CustomerReportTabState extends State<_CustomerReportTab> {
  bool _loading = false;
  List _customers = [];
  Map<String, dynamic>? _selectedCustomer;
  List _purchases = [];
  bool _loadingPurchases = false;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() { super.initState(); _fetchCustomers(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _fetchCustomers() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final res = await ApiService.getCustomers(search: _search.isEmpty ? null : _search);
    if (!mounted) return;
    setState(() {
      final data = res['data'];
      _customers = data is List ? data : (res['items'] as List? ?? []);
      _loading   = false;
    });
    debugPrint('=== Customers: ${_customers.length} ===');
  }

  Future<void> _fetchPurchases(int id) async {
    if (!mounted) return;
    setState(() => _loadingPurchases = true);
    final data = await ApiService.getCustomerPurchases(id);
    if (!mounted) return;
    setState(() { _purchases = data; _loadingPurchases = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Customer list
      SizedBox(
        width: 320,
        child: Column(children: [
          // Search
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: _kTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ຄົ້ນຫາລູກຄ້າ...',
                hintStyle: TextStyle(color: _kTextSecondary.withOpacity(0.5), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: _kTextSecondary, size: 18),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: _kTextSecondary, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          _fetchCustomers();
                        })
                    : null,
                filled: true,
                fillColor: _kBgCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kPrimary.withOpacity(0.25))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _kPrimary.withOpacity(0.2))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
              ),
              onChanged: (v) => setState(() => _search = v),
              onSubmitted: (_) => _fetchCustomers(),
            ),
          ),
          const SizedBox(height: 12),

          if (_loading)
            const Expanded(child: Center(
                child: CircularProgressIndicator(color: _kPrimary)))
          else if (_customers.isEmpty)
            Expanded(child: _emptyWidget('ບໍ່ພົບລູກຄ້າ'))
          else
            Expanded(child: ListView.builder(
              itemCount: _customers.length,
              itemBuilder: (ctx, i) {
                final c = _customers[i] as Map<String, dynamic>;
                final name    = c['customer_name'] ?? c['name'] ?? '-';
                final phone   = c['phone'] ?? c['tel'] ?? '';
                final points  = c['points'] ?? c['loyalty_points'] ?? 0;
                final isSelected = _selectedCustomer?['id'] == c['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _kPrimary.withOpacity(0.15)
                        : _kBgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _kPrimary.withOpacity(0.6)
                          : _kPrimary.withOpacity(0.12),
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: _kPrimary.withOpacity(0.15),
                        blurRadius: 8,
                      ),
                    ] : null,
                  ),
                  child: InkWell(
                    onTap: () {
                      final id = c['id'] ?? c['customer_id'];
                      setState(() { _selectedCustomer = c; _purchases = []; });
                      if (id != null) _fetchPurchases(id as int);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _kPrimary.withOpacity(0.15),
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800,
                                  color: _kPrimaryLight)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: _kTextPrimary),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (phone.isNotEmpty)
                              Text(phone.toString(), style: TextStyle(
                                  fontSize: 11,
                                  color: _kTextSecondary.withOpacity(0.6))),
                          ],
                        )),
                        if (points > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _kWarning.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _kWarning.withOpacity(0.3)),
                            ),
                            child: Text('$points pts',
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: _kWarning)),
                          ),
                      ]),
                    ),
                  ),
                );
              },
            )),
        ]),
      ),
      const SizedBox(width: 20),

      // Purchase history
      Expanded(child: _selectedCustomer == null
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search_rounded, size: 56,
                    color: _kTextSecondary.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text('ເລືອກລູກຄ້າເພື່ອເບິ່ງລາຍການ',
                    style: TextStyle(fontSize: 14,
                        color: _kTextSecondary.withOpacity(0.4))),
              ],
            ))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Customer info header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _kBgCard,
                      _kPrimary.withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kPrimary.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withOpacity(0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _kPrimary.withOpacity(0.2),
                    child: Text(
                      (_selectedCustomer!['customer_name'] ??
                          _selectedCustomer!['name'] ?? '?')
                          .toString().isNotEmpty
                          ? (_selectedCustomer!['customer_name'] ??
                              _selectedCustomer!['name'])[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _kPrimaryLight),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedCustomer!['customer_name'] ??
                          _selectedCustomer!['name'] ?? '-',
                          style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _kTextPrimary)),
                      Text(_selectedCustomer!['phone'] ??
                          _selectedCustomer!['tel'] ?? '-',
                          style: TextStyle(fontSize: 12,
                              color: _kTextSecondary.withOpacity(0.6))),
                    ],
                  )),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('ລາຍການຊື້',
                        style: TextStyle(fontSize: 11,
                            color: _kTextSecondary.withOpacity(0.5))),
                    Text('${_purchases.length}',
                        style: const TextStyle(fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _kPrimaryLight)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              _sectionTitle('ປະຫວັດການຊື້', icon: Icons.history_rounded),

              if (_loadingPurchases)
                const Expanded(child: Center(
                    child: CircularProgressIndicator(color: _kPrimary)))
              else if (_purchases.isEmpty)
                Expanded(child: _emptyWidget('ບໍ່ມີລາຍການຊື້'))
              else
                Expanded(child: ListView.builder(
                  itemCount: _purchases.length,
                  itemBuilder: (ctx, i) {
                    final p = _purchases[i] as Map<String, dynamic>;
                    final ref   = p['sale_ref'] ?? p['order_no'] ?? p['id'] ?? '-';
                    final date  = p['created_at'] ?? p['sale_date'] ?? '-';
                    final total = p['total_amount'] ?? p['total'] ?? 0;
                    final items = p['total_items'] ?? p['items'] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _kBgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kPrimary.withOpacity(0.12)),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#$ref', style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: _kPrimaryLight)),
                            Text(_fDate(date), style: TextStyle(
                                fontSize: 11,
                                color: _kTextSecondary.withOpacity(0.6))),
                          ],
                        )),
                        Text('$items ລາຍການ',
                            style: TextStyle(fontSize: 12,
                                color: _kTextSecondary.withOpacity(0.6))),
                        const SizedBox(width: 16),
                        Text('₭ ${_fNum(total)}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800,
                                color: _kSuccess)),
                      ]),
                    );
                  },
                )),
            ])),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. USER / STAFF REPORT TAB
// ─────────────────────────────────────────────────────────────────────────────
class _UserReportTab extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const _UserReportTab({required this.currentUser});

  @override
  State<_UserReportTab> createState() => _UserReportTabState();
}

class _UserReportTabState extends State<_UserReportTab> {
  bool _loading = false;
  List _users = [];
  List _activity = [];
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate   = DateTime.now();

  @override
  void initState() { super.initState(); _fetchAll(); }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final sd = DateFormat('yyyy-MM-dd').format(_startDate);
    final ed = DateFormat('yyyy-MM-dd').format(_endDate);
    final results = await Future.wait([
      ApiService.getUsers(),
      ApiService.getUserActivityReport(startDate: sd, endDate: ed),
    ]);
    if (!mounted) return;
    setState(() {
      _users    = results[0] as List;
      _activity = results[1] as List;
      _loading  = false;
    });
    debugPrint('=== Users: ${_users.length} Activity: ${_activity.length} ===');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingWidget();

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _sectionTitle('ສະຫຼຸບພະນັກງານ', icon: Icons.badge_rounded),
          const Spacer(),
          _DateRangePicker(
            start: _startDate, end: _endDate,
            onChanged: (s, e) {
              setState(() { _startDate = s; _endDate = e; });
              _fetchAll();
            },
          ),
          const SizedBox(width: 12),
          StockRefreshButton(isLoading: _loading, onTap: _fetchAll),
        ]),
        const SizedBox(height: 16),

        // User cards grid
        if (_users.isEmpty)
          _emptyWidget('ບໍ່ມີຂໍ້ມູນ')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _users.length,
            itemBuilder: (ctx, i) {
              final u    = _users[i] as Map<String, dynamic>;
              final name = u['full_name'] ?? u['username'] ?? '-';
              final role = u['role_name'] ?? u['role'] ?? '-';
              final sales = u['total_sales'] ?? 0;
              final status = u['status'] ?? u['is_active'] ?? 1;
              final isActive = status == 1 || status == true || status == 'active';

              final act = _activity.firstWhere(
                  (a) => a['user_id'] == u['id'] || a['username'] == u['username'],
                  orElse: () => {});

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kBgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _rColor(i).withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _rColor(i).withOpacity(0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w800, color: _rColor(i)),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? _kSuccess : _kError,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isActive ? _kSuccess : _kError).withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(name, style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: _kTextPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(role, style: TextStyle(
                        fontSize: 11,
                        color: _kTextSecondary.withOpacity(0.6))),
                    const Spacer(),
                    Row(children: [
                      Icon(Icons.receipt_rounded, size: 12,
                          color: _kPrimary.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text('${act['total_sales'] ?? sales} ໃບ',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: _kPrimaryLight)),
                    ]),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 24),

        // Activity log
        _sectionTitle('ກິດຈະກຳ', icon: Icons.history_rounded),
        if (_activity.isEmpty)
          _emptyWidget('ບໍ່ມີກິດຈະກຳ')
        else
          Container(
            decoration: BoxDecoration(
              color: _kBgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kPrimary.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _kPrimary.withOpacity(0.15),
                      _kPrimary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(children: [
                  Expanded(flex: 2, child: Text('ພະນັກງານ', style: _hStyle)),
                  Expanded(flex: 2, child: Text('ກິດຈະກຳ', style: _hStyle)),
                  Expanded(flex: 1, child: Text('ຍອດຂາຍ', style: _hStyle, textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('ລາຍຮັບ', style: _hStyle, textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('ວັນທີ', style: _hStyle, textAlign: TextAlign.right)),
                ]),
              ),
              ..._activity.take(50).toList().asMap().entries.map((e) {
                final i   = e.key;
                final act = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: i.isEven ? Colors.transparent : Colors.white.withOpacity(0.02),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text(
                        act['username'] ?? act['user'] ?? '-',
                        style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kTextPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text(
                        act['action'] ?? act['activity'] ?? '-',
                        style: _rStyle, maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 1, child: Text(
                        '${act['total_sales'] ?? 0}',
                        style: _rStyle, textAlign: TextAlign.center)),
                    Expanded(flex: 1, child: Text(
                        '₭ ${_fNum(act['total_revenue'] ?? 0)}',
                        style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kSuccess),
                        textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text(
                        _fDate(act['date'] ?? act['created_at']),
                        style: TextStyle(fontSize: 11,
                            color: _kTextSecondary.withOpacity(0.6)),
                        textAlign: TextAlign.right)),
                  ]),
                );
              }),
            ]),
          ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE RANGE PICKER WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _DateRangePicker extends StatelessWidget {
  final DateTime start, end;
  final void Function(DateTime, DateTime) onChanged;

  const _DateRangePicker(
      {required this.start, required this.end, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: start, end: end),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (range != null) onChanged(range.start, range.end);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _pick(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _kBgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kPrimary.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.date_range_rounded, size: 14, color: _kPrimaryLight),
            const SizedBox(width: 8),
            Text(
              '${_dateFmt.format(start)} – ${_dateFmt.format(end)}',
              style: const TextStyle(
                  fontSize: 12, color: _kTextPrimary,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_drop_down_rounded,
                color: _kTextSecondary.withOpacity(0.6)),
          ]),
        ),
      );
}