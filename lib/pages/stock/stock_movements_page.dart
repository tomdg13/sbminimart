// lib/pages/stock/stock_movements_page.dart
import 'package:flutter/material.dart';
import '../../services/stock_api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

class StockMovementsPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const StockMovementsPage({super.key, required this.currentUser});

  @override
  State<StockMovementsPage> createState() => _StockMovementsPageState();
}

class _StockMovementsPageState extends State<StockMovementsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _typeFilter = 'all';
  int _currentView = 0; // 0=Movements, 1=Stock Summary, 2=Stock Value
  late AnimationController _animationController;
  final List<Map<String, dynamic>> _movements = [];
  final List<Map<String, dynamic>> _stockSummary = [];
  final List<Map<String, dynamic>> _stockValue = [];

  final List<String> _movementTypes = ['stock_in', 'stock_out', 'adjustment', 'transfer_in', 'transfer_out', 'sale', 'return', 'opening'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _fetchAll();
  }

  @override
  void dispose() { _animationController.dispose(); super.dispose(); }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchMovements(), _fetchSummary(), _fetchValue()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchMovements() async {
    try {
      final data = await StockApiService.getStockMovements(limit: 200);
      setState(() { _movements.clear(); _movements.addAll(data.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _fetchSummary() async {
    try {
      final data = await StockApiService.getStockSummary();
      setState(() { _stockSummary.clear(); _stockSummary.addAll(data.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _fetchValue() async {
    try {
      final data = await StockApiService.getStockValue();
      setState(() { _stockValue.clear(); _stockValue.addAll(data.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  List<Map<String, dynamic>> get _filteredMovements {
    if (_typeFilter == 'all') return _movements;
    return _movements.where((m) => m['movement_type'] == _typeFilter).toList();
  }

  Color _movementTypeColor(String? type) {
    switch (type) {
      case 'stock_in': case 'transfer_in': case 'return': case 'opening': return StockTheme.success;
      case 'stock_out': case 'transfer_out': case 'sale': return StockTheme.error;
      case 'adjustment': return StockTheme.warning;
      default: return StockTheme.textSecondary;
    }
  }

  String _formatType(String type) => type.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

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
              titleLa: 'ປະຫວັດເຄື່ອນໄຫວສະຕ໋ອກ',
              titleEn: 'Stock Movements',
              actions: [StockRefreshButton(isLoading: _isLoading, onTap: _fetchAll)],
            ),
            const SizedBox(height: 20),
            _buildViewTabs(),
            const SizedBox(height: 20),
            if (_currentView == 0) ...[
              _buildTypeFilters(),
              const SizedBox(height: 20),
              Expanded(child: _buildMovementsList()),
            ] else if (_currentView == 1) ...[
              Expanded(child: _buildSummaryView()),
            ] else ...[
              Expanded(child: _buildValueView()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.5), StockTheme.bgDarker.withOpacity(0.3)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StockTheme.primary.withOpacity(0.2), width: 1),
      ),
      child: Row(children: [
        _viewTab(0, Icons.history_rounded, 'ປະຫວັດ', 'Movements'),
        _viewTab(1, Icons.summarize_rounded, 'ສະຫຼຸບສະຕ໋ອກ', 'Stock Summary'),
        _viewTab(2, Icons.monetization_on_rounded, 'ມູນຄ່າສະຕ໋ອກ', 'Stock Value'),
      ]),
    );
  }

  Widget _viewTab(int index, IconData icon, String label, String sublabel) {
    final isSelected = _currentView == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentView = index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected ? const LinearGradient(colors: [StockTheme.primary, StockTheme.primaryLight]) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isSelected ? Colors.white : StockTheme.textSecondary, size: 20),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: isSelected ? Colors.white : StockTheme.textSecondary, fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        StockFilterChip(value: 'all', label: 'ທັງໝົດ (${_movements.length})', isSelected: _typeFilter == 'all', onTap: () => setState(() => _typeFilter = 'all')),
        ..._movementTypes.map((t) {
          final count = _movements.where((m) => m['movement_type'] == t).length;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: StockFilterChip(value: t, label: '${_formatType(t)} ($count)', isSelected: _typeFilter == t, onTap: () => setState(() => _typeFilter = t)),
          );
        }),
      ]),
    );
  }

  Widget _buildMovementsList() {
    final movements = _filteredMovements;
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: StockTheme.primary));
    if (movements.isEmpty) return const StockEmptyState(icon: Icons.history_rounded, titleLa: 'ບໍ່ມີປະຫວັດ', titleEn: 'No movements found');

    return StockTableContainer(
      headers: const ['ວັນທີ', 'ສິນຄ້າ', 'ປະເພດ', 'ຈຳນວນ', 'ສາງ', 'ອ້າງອີງ'],
      flexValues: const [2, 3, 2, 1, 2, 2],
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: movements.length,
        itemBuilder: (context, index) {
          final m = movements[index];
          final type = m['movement_type'] ?? '';
          final typeColor = _movementTypeColor(type);
          final qty = m['quantity'] ?? 0;
          final isPositive = ['stock_in', 'transfer_in', 'return', 'opening'].contains(type);

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.3), StockTheme.bgDarker.withOpacity(0.2)]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: typeColor.withOpacity(0.1), width: 1),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text(StockTheme.formatDateTime(m['created_at']), style: TextStyle(fontSize: 12, color: StockTheme.textSecondary.withOpacity(0.8)))),
                Expanded(flex: 3, child: Text(m['product_name'] ?? 'Product #${m['product_id']}', style: const TextStyle(fontSize: 13, color: StockTheme.textPrimary, fontWeight: FontWeight.w600))),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(_formatType(type), style: TextStyle(fontSize: 11, color: typeColor, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text('${isPositive ? '+' : '-'}$qty', style: TextStyle(fontSize: 14, color: isPositive ? StockTheme.success : StockTheme.error, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                ),
                Expanded(flex: 2, child: Text(m['warehouse_name'] ?? '-', style: const TextStyle(fontSize: 12, color: StockTheme.textSecondary))),
                Expanded(flex: 2, child: Text(m['reference_number'] ?? m['reference_id']?.toString() ?? '-', style: TextStyle(fontSize: 12, color: StockTheme.textSecondary.withOpacity(0.7)))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: StockTheme.primary));
    if (_stockSummary.isEmpty) return const StockEmptyState(icon: Icons.summarize_rounded, titleLa: 'ບໍ່ມີຂໍ້ມູນ', titleEn: 'No summary data');

    return StockTableContainer(
      headers: const ['ສິນຄ້າ', 'ສະຕ໋ອກປັດຈຸບັນ', 'ສະຕ໋ອກຕ່ຳສຸດ', 'ສະຖານະ'],
      flexValues: const [3, 1, 1, 1],
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _stockSummary.length,
        itemBuilder: (context, index) {
          final s = _stockSummary[index];
          final current = int.tryParse(s['current_stock']?.toString() ?? '0') ?? 0;
          final min = int.tryParse(s['min_stock']?.toString() ?? '0') ?? 0;
          final isLow = current <= min;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.3), StockTheme.bgDarker.withOpacity(0.2)]),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isLow ? StockTheme.warning.withOpacity(0.2) : StockTheme.primary.withOpacity(0.1), width: 1),
            ),
            child: Row(children: [
              Expanded(flex: 3, child: Text(s['product_name'] ?? '-', style: const TextStyle(fontSize: 13, color: StockTheme.textPrimary, fontWeight: FontWeight.w600))),
              Expanded(child: Text('$current', style: TextStyle(fontSize: 14, color: isLow ? StockTheme.warning : StockTheme.textPrimary, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
              Expanded(child: Text('$min', style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary), textAlign: TextAlign.center)),
              Expanded(child: isLow
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.warning_rounded, color: StockTheme.warning, size: 16), const SizedBox(width: 4), const Text('ໃກ້ໝົດ', style: TextStyle(fontSize: 11, color: StockTheme.warning, fontWeight: FontWeight.w700))])
                  : const Text('ປົກກະຕິ', style: TextStyle(fontSize: 11, color: StockTheme.success, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildValueView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: StockTheme.primary));
    if (_stockValue.isEmpty) return const StockEmptyState(icon: Icons.monetization_on_rounded, titleLa: 'ບໍ່ມີຂໍ້ມູນ', titleEn: 'No value data');

    final totalValue = _stockValue.fold<double>(0, (sum, v) => sum + (double.tryParse(v['total_value']?.toString() ?? '0') ?? 0));

    return Column(
      children: [
        StockStatCard(label: 'ມູນຄ່າສະຕ໋ອກລວມ', value: '${StockTheme.formatPrice(totalValue)} ₭', icon: Icons.monetization_on_rounded, color: StockTheme.primaryLight),
        const SizedBox(height: 20),
        Expanded(
          child: StockTableContainer(
            headers: const ['ສິນຄ້າ', 'ຈຳນວນ', 'ລາຄາຕໍ່ໜ່ວຍ', 'ມູນຄ່າລວມ'],
            flexValues: const [3, 1, 1, 2],
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _stockValue.length,
              itemBuilder: (context, index) {
                final v = _stockValue[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.3), StockTheme.bgDarker.withOpacity(0.2)]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: StockTheme.primary.withOpacity(0.1), width: 1),
                  ),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(v['product_name'] ?? '-', style: const TextStyle(fontSize: 13, color: StockTheme.textPrimary, fontWeight: FontWeight.w600))),
                    Expanded(child: Text('${v['current_stock'] ?? 0}', style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary), textAlign: TextAlign.center)),
                    Expanded(child: Text('${StockTheme.formatPrice(v['unit_cost'])} ₭', style: const TextStyle(fontSize: 12, color: StockTheme.textSecondary), textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text('${StockTheme.formatPrice(v['total_value'])} ₭', style: const TextStyle(fontSize: 14, color: StockTheme.primary, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                  ]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
