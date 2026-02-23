// lib/pages/stock/stock_adjustments_page.dart
import 'package:flutter/material.dart';
import '../../services/stock_api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

class StockAdjustmentsPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const StockAdjustmentsPage({super.key, required this.currentUser});

  @override
  State<StockAdjustmentsPage> createState() => _StockAdjustmentsPageState();
}

class _StockAdjustmentsPageState extends State<StockAdjustmentsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _statusFilter = 'all';
  late AnimationController _animationController;
  final List<Map<String, dynamic>> _adjustments = [];
  final List<Map<String, dynamic>> _warehouses = [];

  final List<String> _adjustmentTypes = ['count', 'damage', 'loss', 'correction', 'other'];

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
    await Future.wait([_fetchAdjustments(), _fetchWarehouses()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchAdjustments() async {
    try {
      final data = await StockApiService.getStockAdjustments();
      setState(() { _adjustments.clear(); _adjustments.addAll(data.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _fetchWarehouses() async {
    try {
      final data = await StockApiService.getWarehouses();
      setState(() { _warehouses.clear(); _warehouses.addAll(data.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  List<Map<String, dynamic>> get _filteredAdjustments {
    if (_statusFilter == 'all') return _adjustments;
    return _adjustments.where((a) => a['status'] == _statusFilter).toList();
  }

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
              titleLa: 'ປັບປຸງສະຕ໋ອກ',
              titleEn: 'Stock Adjustments',
              actions: [
                StockRefreshButton(isLoading: _isLoading, onTap: _fetchAll),
                const SizedBox(width: 12),
                StockPrimaryButton(icon: Icons.tune_rounded, label: 'ສ້າງການປັບປຸງ', onTap: () => _showForm()),
              ],
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: StockStatCard(label: 'ການປັບປຸງທັງໝົດ', value: '${_adjustments.length}', icon: Icons.tune_rounded, color: StockTheme.primary)),
              const SizedBox(width: 16),
              Expanded(child: StockStatCard(label: 'ຮ່າງ', value: '${_adjustments.where((a) => a['status'] == 'draft').length}', icon: Icons.edit_note_rounded, color: StockTheme.textSecondary)),
              const SizedBox(width: 16),
              Expanded(child: StockStatCard(label: 'ຢືນຢັນແລ້ວ', value: '${_adjustments.where((a) => a['status'] == 'confirmed').length}', icon: Icons.check_circle_rounded, color: StockTheme.success)),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              StockFilterChip(value: 'all', label: 'ທັງໝົດ', isSelected: _statusFilter == 'all', onTap: () => setState(() => _statusFilter = 'all')),
              const SizedBox(width: 8),
              StockFilterChip(value: 'draft', label: 'ຮ່າງ', isSelected: _statusFilter == 'draft', onTap: () => setState(() => _statusFilter = 'draft')),
              const SizedBox(width: 8),
              StockFilterChip(value: 'confirmed', label: 'ຢືນຢັນແລ້ວ', isSelected: _statusFilter == 'confirmed', onTap: () => setState(() => _statusFilter = 'confirmed')),
              const SizedBox(width: 8),
              StockFilterChip(value: 'cancelled', label: 'ຍົກເລີກ', isSelected: _statusFilter == 'cancelled', onTap: () => setState(() => _statusFilter = 'cancelled')),
            ]),
            const SizedBox(height: 20),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _filteredAdjustments;
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: StockTheme.primary));
    if (items.isEmpty) return const StockEmptyState(icon: Icons.tune_rounded, titleLa: 'ບໍ່ມີການປັບປຸງ', titleEn: 'No adjustments found');

    return StockTableContainer(
      headers: const ['ເລກທີ', 'ປະເພດ', 'ສາງ', 'ວັນທີ', 'ສະຖານະ', 'ຈັດການ'],
      flexValues: const [2, 2, 2, 2, 1, 2],
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final a = items[index];
          final status = a['status'] ?? 'draft';
          final wh = _warehouses.firstWhere((w) => w['id'] == a['warehouse_id'] || w['warehouse_id'] == a['warehouse_id'], orElse: () => {});
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (index * 50)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) => Transform.translate(offset: Offset(0, 20 * (1 - value)), child: Opacity(opacity: value, child: child)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.3), StockTheme.bgDarker.withOpacity(0.2)]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StockTheme.primary.withOpacity(0.1), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(a['adjustment_number'] ?? '#${a['id']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: StockTheme.primary))),
                  Expanded(flex: 2, child: Text(_formatType(a['adjustment_type'] ?? '-'), style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  Expanded(flex: 2, child: Text(wh['warehouse_name'] ?? '-', style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  Expanded(flex: 2, child: Text(StockTheme.formatDate(a['created_at']), style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  Expanded(flex: 1, child: StockStatusBadge(status: status)),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        StockActionButton(icon: Icons.visibility_rounded, color: StockTheme.info, onTap: () => _viewDetails(a)),
                        if (status == 'draft') ...[
                          const SizedBox(width: 6),
                          StockActionButton(icon: Icons.check_circle_rounded, color: StockTheme.success, onTap: () => _confirm(a)),
                          const SizedBox(width: 6),
                          StockActionButton(icon: Icons.cancel_rounded, color: StockTheme.error, onTap: () => _cancel(a)),
                        ],
                      ],
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

  String _formatType(String type) => type.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

  Future<void> _confirm(Map<String, dynamic> adj) async {
    final confirmed = await showStockConfirmDialog(context, title: 'ຢືນຢັນການປັບປຸງ', message: 'ສະຕ໋ອກຈະຖືກປັບປຸງຕາມຜົນຕ່າງ. ດຳເນີນການ?', confirmLabel: 'ຢືນຢັນ', confirmColor: StockTheme.success);
    if (!confirmed) return;
    try {
      final response = await StockApiService.confirmStockAdjustment(adj['id']);
      if (response['responseCode'] == '00') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ຢືນຢັນສຳເລັດ'), backgroundColor: StockTheme.success));
        _fetchAll();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
    }
  }

  Future<void> _cancel(Map<String, dynamic> adj) async {
    final confirmed = await showStockConfirmDialog(context, title: 'ຍົກເລີກ', message: 'ທ່ານຕ້ອງການຍົກເລີກແທ້ບໍ່?');
    if (!confirmed) return;
    try {
      final response = await StockApiService.cancelStockAdjustment(adj['id']);
      if (response['responseCode'] == '00') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ຍົກເລີກສຳເລັດ'), backgroundColor: StockTheme.success));
        _fetchAll();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
    }
  }

  void _viewDetails(Map<String, dynamic> adj) async {
    try {
      final response = await StockApiService.getStockAdjustmentById(adj['id']);
      if (response['responseCode'] != '00') return;
      final data = response['data'];
      final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 650, constraints: const BoxConstraints(maxHeight: 550),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.98), StockTheme.bgCard.withOpacity(0.98)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: StockTheme.primary.withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                StockDialogHeader(titleLa: data['adjustment_number'] ?? '#${adj['id']}', titleEn: 'Adjustment Details', icon: Icons.tune_rounded, onClose: () => Navigator.pop(context)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [StockStatusBadge(status: data['status'] ?? 'draft'), const SizedBox(width: 12), Text(_formatType(data['adjustment_type'] ?? '-'), style: const TextStyle(color: StockTheme.textSecondary))]),
                        const SizedBox(height: 20),
                        const Text('ລາຍການ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StockTheme.textPrimary)),
                        const SizedBox(height: 12),
                        // Header
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: StockTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(children: [
                            Expanded(flex: 3, child: Text('ສິນຄ້າ', style: TextStyle(fontSize: 11, color: StockTheme.textSecondary, fontWeight: FontWeight.w700))),
                            Expanded(child: Text('ລະບົບ', style: TextStyle(fontSize: 11, color: StockTheme.textSecondary, fontWeight: FontWeight.w700))),
                            Expanded(child: Text('ຕົວຈິງ', style: TextStyle(fontSize: 11, color: StockTheme.textSecondary, fontWeight: FontWeight.w700))),
                            Expanded(child: Text('ຜົນຕ່າງ', style: TextStyle(fontSize: 11, color: StockTheme.textSecondary, fontWeight: FontWeight.w700))),
                          ]),
                        ),
                        ...items.map((item) {
                          final diff = (item['actual_qty'] ?? 0) - (item['system_qty'] ?? 0);
                          return Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: StockTheme.bgDarker.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              Expanded(flex: 3, child: Text(item['product_name'] ?? 'Product #${item['product_id']}', style: const TextStyle(color: StockTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
                              Expanded(child: Text('${item['system_qty'] ?? 0}', style: const TextStyle(color: StockTheme.textSecondary, fontSize: 13))),
                              Expanded(child: Text('${item['actual_qty'] ?? 0}', style: const TextStyle(color: StockTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
                              Expanded(child: Text('${diff > 0 ? '+' : ''}$diff', style: TextStyle(color: diff > 0 ? StockTheme.success : (diff < 0 ? StockTheme.error : StockTheme.textSecondary), fontSize: 13, fontWeight: FontWeight.w700))),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) { debugPrint('Error: $e'); }
  }

  void _showForm() {
    int? selectedWarehouseId;
    String? selectedType;
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.98), StockTheme.bgCard.withOpacity(0.98)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: StockTheme.primary.withOpacity(0.3), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StockDialogHeader(titleLa: 'ສ້າງການປັບປຸງໃໝ່', titleEn: 'New Adjustment', icon: Icons.tune_rounded, onClose: () => Navigator.pop(context)),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      buildStockDropdown<String>(label: 'ປະເພດ (Type)', icon: Icons.category_rounded, value: selectedType, hint: 'ເລືອກປະເພດ',
                        items: _adjustmentTypes.map((t) => DropdownMenuItem(value: t, child: Text(_formatType(t)))).toList(),
                        onChanged: (v) => setDialogState(() => selectedType = v)),
                      const SizedBox(height: 16),
                      buildStockDropdown<int>(label: 'ສາງ (Warehouse)', icon: Icons.warehouse_rounded, value: selectedWarehouseId, hint: 'ເລືອກສາງ',
                        items: _warehouses.map((w) => DropdownMenuItem<int>(value: w['id'] ?? w['warehouse_id'], child: Text(w['warehouse_name'] ?? ''))).toList(),
                        onChanged: (v) => setDialogState(() => selectedWarehouseId = v)),
                      const SizedBox(height: 16),
                      buildStockFormField(label: 'ໝາຍເຫດ (Notes)', controller: notesCtrl, icon: Icons.notes_rounded, maxLines: 2),
                    ],
                  ),
                ),
                StockDialogFooter(onCancel: () => Navigator.pop(context), saveLabel: 'ສ້າງ', onSave: () async {
                  try {
                    final response = await StockApiService.createStockAdjustment({
                      'adjustment_type': selectedType, 'warehouse_id': selectedWarehouseId, 'notes': notesCtrl.text, 'created_by': widget.currentUser['username'],
                    });
                    if (response['responseCode'] == '00') {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ສ້າງສຳເລັດ'), backgroundColor: StockTheme.success));
                      _fetchAll();
                    } else {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
                    }
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
                  }
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
