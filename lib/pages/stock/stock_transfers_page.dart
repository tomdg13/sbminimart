// lib/pages/stock/stock_transfers_page.dart
import 'package:flutter/material.dart';
import '../../services/stock_api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

class StockTransfersPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const StockTransfersPage({super.key, required this.currentUser});

  @override
  State<StockTransfersPage> createState() => _StockTransfersPageState();
}

class _StockTransfersPageState extends State<StockTransfersPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _statusFilter = 'all';
  late AnimationController _animationController;
  final List<Map<String, dynamic>> _transfers = [];
  final List<Map<String, dynamic>> _warehouses = [];

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
    await Future.wait([_fetchTransfers(), _fetchWarehouses()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchTransfers() async {
    try {
      final data = await StockApiService.getStockTransfers();
      setState(() { _transfers.clear(); _transfers.addAll(data.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _fetchWarehouses() async {
    try {
      final data = await StockApiService.getWarehouses();
      setState(() { _warehouses.clear(); _warehouses.addAll(data.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  List<Map<String, dynamic>> get _filteredTransfers {
    if (_statusFilter == 'all') return _transfers;
    return _transfers.where((t) => t['status'] == _statusFilter).toList();
  }

  String _whName(dynamic id) {
    final w = _warehouses.firstWhere((w) => w['id'] == id || w['warehouse_id'] == id, orElse: () => {});
    return w['warehouse_name'] ?? '-';
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
              titleLa: 'ໂອນສິນຄ້າ',
              titleEn: 'Stock Transfers',
              actions: [
                StockRefreshButton(isLoading: _isLoading, onTap: _fetchAll),
                const SizedBox(width: 12),
                StockPrimaryButton(icon: Icons.swap_horiz_rounded, label: 'ສ້າງການໂອນ', onTap: () => _showForm()),
              ],
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: StockStatCard(label: 'ທັງໝົດ', value: '${_transfers.length}', icon: Icons.swap_horiz_rounded, color: StockTheme.primary)),
              const SizedBox(width: 16),
              Expanded(child: StockStatCard(label: 'ຮ່າງ', value: '${_transfers.where((t) => t['status'] == 'draft').length}', icon: Icons.edit_note_rounded, color: StockTheme.textSecondary)),
              const SizedBox(width: 16),
              Expanded(child: StockStatCard(label: 'ກຳລັງຂົນສົ່ງ', value: '${_transfers.where((t) => t['status'] == 'in_transit').length}', icon: Icons.local_shipping_rounded, color: StockTheme.info)),
              const SizedBox(width: 16),
              Expanded(child: StockStatCard(label: 'ຮັບແລ້ວ', value: '${_transfers.where((t) => t['status'] == 'received').length}', icon: Icons.check_circle_rounded, color: StockTheme.success)),
            ]),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                StockFilterChip(value: 'all', label: 'ທັງໝົດ', isSelected: _statusFilter == 'all', onTap: () => setState(() => _statusFilter = 'all')),
                const SizedBox(width: 8),
                StockFilterChip(value: 'draft', label: 'ຮ່າງ', isSelected: _statusFilter == 'draft', onTap: () => setState(() => _statusFilter = 'draft')),
                const SizedBox(width: 8),
                StockFilterChip(value: 'in_transit', label: 'ກຳລັງຂົນສົ່ງ', isSelected: _statusFilter == 'in_transit', onTap: () => setState(() => _statusFilter = 'in_transit')),
                const SizedBox(width: 8),
                StockFilterChip(value: 'received', label: 'ຮັບແລ້ວ', isSelected: _statusFilter == 'received', onTap: () => setState(() => _statusFilter = 'received')),
                const SizedBox(width: 8),
                StockFilterChip(value: 'cancelled', label: 'ຍົກເລີກ', isSelected: _statusFilter == 'cancelled', onTap: () => setState(() => _statusFilter = 'cancelled')),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _filteredTransfers;
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: StockTheme.primary));
    if (items.isEmpty) return const StockEmptyState(icon: Icons.swap_horiz_rounded, titleLa: 'ບໍ່ມີການໂອນ', titleEn: 'No transfers found');

    return StockTableContainer(
      headers: const ['ເລກທີ', 'ຈາກສາງ', '→', 'ໄປສາງ', 'ວັນທີ', 'ສະຖານະ', 'ຈັດການ'],
      flexValues: const [2, 2, 0, 2, 2, 1, 2],
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final t = items[index];
          final status = t['status'] ?? 'draft';
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
                  Expanded(flex: 2, child: Text(t['transfer_number'] ?? '#${t['id']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: StockTheme.primary))),
                  Expanded(flex: 2, child: Text(_whName(t['source_warehouse_id']), style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  const SizedBox(width: 8, child: Icon(Icons.arrow_forward_rounded, size: 16, color: StockTheme.textSecondary)),
                  Expanded(flex: 2, child: Text(_whName(t['destination_warehouse_id']), style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  Expanded(flex: 2, child: Text(StockTheme.formatDate(t['created_at']), style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  Expanded(flex: 1, child: StockStatusBadge(status: status)),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        StockActionButton(icon: Icons.visibility_rounded, color: StockTheme.info, onTap: () => _viewDetails(t)),
                        if (status == 'draft') ...[
                          const SizedBox(width: 6),
                          StockActionButton(icon: Icons.local_shipping_rounded, color: StockTheme.info, onTap: () => _dispatch(t), tooltip: 'ສົ່ງອອກ'),
                          const SizedBox(width: 6),
                          StockActionButton(icon: Icons.cancel_rounded, color: StockTheme.error, onTap: () => _cancel(t)),
                        ],
                        if (status == 'in_transit') ...[
                          const SizedBox(width: 6),
                          StockActionButton(icon: Icons.check_circle_rounded, color: StockTheme.success, onTap: () => _receive(t), tooltip: 'ຮັບເຂົ້າ'),
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

  Future<void> _dispatch(Map<String, dynamic> transfer) async {
    final confirmed = await showStockConfirmDialog(context, title: 'ສົ່ງອອກ', message: 'ຢືນຢັນການສົ່ງອອກ? ສະຕ໋ອກຈາກສາງຕົ້ນທາງຈະຖືກຫັກ.', confirmLabel: 'ສົ່ງອອກ', confirmColor: StockTheme.info);
    if (!confirmed) return;
    try {
      final response = await StockApiService.dispatchStockTransfer(transfer['id']);
      if (response['responseCode'] == '00') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ສົ່ງອອກສຳເລັດ'), backgroundColor: StockTheme.success));
        _fetchAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error)); }
  }

  Future<void> _receive(Map<String, dynamic> transfer) async {
    final confirmed = await showStockConfirmDialog(context, title: 'ຮັບເຂົ້າ', message: 'ຢືນຢັນການຮັບເຂົ້າ? ສະຕ໋ອກຈະຖືກເພີ່ມໃສ່ສາງປາຍທາງ.', confirmLabel: 'ຮັບເຂົ້າ', confirmColor: StockTheme.success);
    if (!confirmed) return;
    try {
      final response = await StockApiService.receiveStockTransfer(transfer['id'], body: {'received_by': widget.currentUser['username']});
      if (response['responseCode'] == '00') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ຮັບເຂົ້າສຳເລັດ'), backgroundColor: StockTheme.success));
        _fetchAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error)); }
  }

  Future<void> _cancel(Map<String, dynamic> transfer) async {
    final confirmed = await showStockConfirmDialog(context, title: 'ຍົກເລີກ', message: 'ທ່ານຕ້ອງການຍົກເລີກແທ້ບໍ່?');
    if (!confirmed) return;
    try {
      final response = await StockApiService.cancelStockTransfer(transfer['id']);
      if (response['responseCode'] == '00') { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ຍົກເລີກສຳເລັດ'), backgroundColor: StockTheme.success)); _fetchAll(); }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error)); }
  }

  void _viewDetails(Map<String, dynamic> transfer) async {
    try {
      final response = await StockApiService.getStockTransferById(transfer['id']);
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
              borderRadius: BorderRadius.circular(24), border: Border.all(color: StockTheme.primary.withOpacity(0.3), width: 1),
            ),
            child: Column(children: [
              StockDialogHeader(titleLa: data['transfer_number'] ?? '#${transfer['id']}', titleEn: 'Transfer Details', icon: Icons.swap_horiz_rounded, onClose: () => Navigator.pop(context)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      StockStatusBadge(status: data['status'] ?? 'draft'),
                      const SizedBox(width: 16),
                      Text('${_whName(data['source_warehouse_id'])}  →  ${_whName(data['destination_warehouse_id'])}', style: const TextStyle(color: StockTheme.textPrimary, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 20),
                    const Text('ລາຍການ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StockTheme.textPrimary)),
                    const SizedBox(height: 12),
                    ...items.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: StockTheme.bgDarker.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(item['product_name'] ?? 'Product #${item['product_id']}', style: const TextStyle(color: StockTheme.textPrimary, fontWeight: FontWeight.w600))),
                        Expanded(child: Text('ສົ່ງ: ${item['quantity'] ?? 0}', style: const TextStyle(color: StockTheme.textSecondary, fontSize: 12))),
                        Expanded(child: Text('ຮັບ: ${item['quantity_received'] ?? '-'}', style: const TextStyle(color: StockTheme.success, fontSize: 12))),
                      ]),
                    )),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
    } catch (e) { debugPrint('Error: $e'); }
  }

  void _showForm() {
    int? sourceWarehouseId;
    int? destWarehouseId;
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 550,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.98), StockTheme.bgCard.withOpacity(0.98)]),
              borderRadius: BorderRadius.circular(24), border: Border.all(color: StockTheme.primary.withOpacity(0.3), width: 1),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              StockDialogHeader(titleLa: 'ສ້າງການໂອນໃໝ່', titleEn: 'New Transfer', icon: Icons.swap_horiz_rounded, onClose: () => Navigator.pop(context)),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  buildStockDropdown<int>(label: 'ສາງຕົ້ນທາງ (Source)', icon: Icons.warehouse_rounded, value: sourceWarehouseId, hint: 'ເລືອກສາງຕົ້ນທາງ',
                    items: _warehouses.map((w) => DropdownMenuItem<int>(value: w['id'] ?? w['warehouse_id'], child: Text(w['warehouse_name'] ?? ''))).toList(),
                    onChanged: (v) => setDialogState(() => sourceWarehouseId = v)),
                  const SizedBox(height: 8),
                  const Icon(Icons.arrow_downward_rounded, color: StockTheme.primary, size: 24),
                  const SizedBox(height: 8),
                  buildStockDropdown<int>(label: 'ສາງປາຍທາງ (Destination)', icon: Icons.warehouse_rounded, value: destWarehouseId, hint: 'ເລືອກສາງປາຍທາງ',
                    items: _warehouses.where((w) => (w['id'] ?? w['warehouse_id']) != sourceWarehouseId).map((w) => DropdownMenuItem<int>(value: w['id'] ?? w['warehouse_id'], child: Text(w['warehouse_name'] ?? ''))).toList(),
                    onChanged: (v) => setDialogState(() => destWarehouseId = v)),
                  const SizedBox(height: 16),
                  buildStockFormField(label: 'ໝາຍເຫດ (Notes)', controller: notesCtrl, icon: Icons.notes_rounded, maxLines: 2),
                ]),
              ),
              StockDialogFooter(onCancel: () => Navigator.pop(context), saveLabel: 'ສ້າງການໂອນ', onSave: () async {
                if (sourceWarehouseId == null || destWarehouseId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ກະລຸນາເລືອກສາງ'), backgroundColor: StockTheme.warning));
                  return;
                }
                try {
                  final response = await StockApiService.createStockTransfer({
                    'source_warehouse_id': sourceWarehouseId, 'destination_warehouse_id': destWarehouseId,
                    'notes': notesCtrl.text, 'created_by': widget.currentUser['username'],
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
            ]),
          ),
        ),
      ),
    );
  }
}
