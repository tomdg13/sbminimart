// lib/pages/stock/purchase_orders_page.dart
import 'package:flutter/material.dart';
import '../../services/stock_api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

class PurchaseOrdersPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const PurchaseOrdersPage({super.key, required this.currentUser});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _statusFilter = 'all';
  late AnimationController _animationController;
  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _suppliers = [];
  final List<Map<String, dynamic>> _warehouses = [];
  final List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _fetchAll();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchOrders(), _fetchSuppliers(), _fetchWarehouses(), _fetchProducts()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchOrders() async {
    try {
      final data = await StockApiService.getPurchaseOrders();
      setState(() { _orders.clear(); _orders.addAll(data.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _fetchSuppliers() async {
    try {
      final data = await StockApiService.getSuppliers();
      setState(() { _suppliers.clear(); _suppliers.addAll(data.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _fetchWarehouses() async {
    try {
      final data = await StockApiService.getWarehouses();
      setState(() { _warehouses.clear(); _warehouses.addAll(data.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _fetchProducts() async {
    try {
      // Use main ApiService for products
      final response = await StockApiService.getStockSummary(); // fallback
      // You may want to call ApiService.getProducts() here instead
    } catch (e) { debugPrint('Error: $e'); }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_statusFilter == 'all') return _orders;
    return _orders.where((o) => o['status'] == _statusFilter).toList();
  }

  String _getSupplierName(dynamic supplierId) {
    final s = _suppliers.firstWhere((s) => s['id'] == supplierId || s['supplier_id'] == supplierId, orElse: () => {});
    return s['supplier_name'] ?? '-';
  }

  String _getWarehouseName(dynamic warehouseId) {
    final w = _warehouses.firstWhere((w) => w['id'] == warehouseId || w['warehouse_id'] == warehouseId, orElse: () => {});
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
              titleLa: 'ໃບສັ່ງຊື້',
              titleEn: 'Purchase Orders',
              actions: [
                StockRefreshButton(isLoading: _isLoading, onTap: _fetchAll),
                const SizedBox(width: 12),
                StockPrimaryButton(icon: Icons.add_rounded, label: 'ສ້າງໃບສັ່ງຊື້', onTap: () => _showPOForm()),
              ],
            ),
            const SizedBox(height: 20),
            _buildStats(),
            const SizedBox(height: 20),
            _buildStatusFilters(),
            const SizedBox(height: 20),
            Expanded(child: _buildOrdersList()),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final total = _orders.length;
    final draft = _orders.where((o) => o['status'] == 'draft').length;
    final pending = _orders.where((o) => o['status'] == 'pending' || o['status'] == 'approved' || o['status'] == 'ordered').length;
    final received = _orders.where((o) => o['status'] == 'received' || o['status'] == 'partial_received').length;
    return Row(
      children: [
        Expanded(child: StockStatCard(label: 'ໃບສັ່ງຊື້ທັງໝົດ', value: '$total', icon: Icons.shopping_cart_rounded, color: StockTheme.primary)),
        const SizedBox(width: 16),
        Expanded(child: StockStatCard(label: 'ຮ່າງ', value: '$draft', icon: Icons.edit_note_rounded, color: StockTheme.textSecondary)),
        const SizedBox(width: 16),
        Expanded(child: StockStatCard(label: 'ກຳລັງດຳເນີນ', value: '$pending', icon: Icons.pending_rounded, color: StockTheme.warning)),
        const SizedBox(width: 16),
        Expanded(child: StockStatCard(label: 'ຮັບແລ້ວ', value: '$received', icon: Icons.check_circle_rounded, color: StockTheme.success)),
      ],
    );
  }

  Widget _buildStatusFilters() {
    final filters = [
      {'value': 'all', 'label': 'ທັງໝົດ'},
      {'value': 'draft', 'label': 'ຮ່າງ'},
      {'value': 'pending', 'label': 'ລໍຖ້າ'},
      {'value': 'approved', 'label': 'ອະນຸມັດ'},
      {'value': 'ordered', 'label': 'ສັ່ງແລ້ວ'},
      {'value': 'partial_received', 'label': 'ຮັບບາງສ່ວນ'},
      {'value': 'received', 'label': 'ຮັບແລ້ວ'},
      {'value': 'cancelled', 'label': 'ຍົກເລີກ'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: StockFilterChip(
            value: f['value']!,
            label: f['label']!,
            isSelected: _statusFilter == f['value'],
            onTap: () => setState(() => _statusFilter = f['value']!),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildOrdersList() {
    final orders = _filteredOrders;
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: StockTheme.primary));
    if (orders.isEmpty) return const StockEmptyState(icon: Icons.shopping_cart_outlined, titleLa: 'ບໍ່ພົບໃບສັ່ງຊື້', titleEn: 'No purchase orders found');

    return StockTableContainer(
      headers: const ['ເລກທີ PO', 'ຜູ້ສະໜອງ', 'ສາງ', 'ວັນທີ', 'ຈຳນວນລາຍການ', 'ສະຖານະ', 'ຈັດການ'],
      flexValues: const [2, 2, 2, 2, 1, 1, 2],
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final o = orders[index];
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
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o['po_number'] ?? 'PO-${o['id']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: StockTheme.primary)),
                        if ((o['notes'] ?? '').toString().isNotEmpty)
                          Text(o['notes'], style: TextStyle(fontSize: 11, color: StockTheme.textSecondary.withOpacity(0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Expanded(flex: 2, child: Text(_getSupplierName(o['supplier_id']), style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  Expanded(flex: 2, child: Text(_getWarehouseName(o['warehouse_id']), style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  Expanded(flex: 2, child: Text(StockTheme.formatDate(o['order_date'] ?? o['created_at']), style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  Expanded(flex: 1, child: Text('${o['item_count'] ?? 0}', style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: StockStatusBadge(status: o['status'] ?? 'draft')),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        StockActionButton(icon: Icons.visibility_rounded, color: StockTheme.info, onTap: () => _viewPODetails(o), tooltip: 'ເບິ່ງ'),
                        const SizedBox(width: 6),
                        if (o['status'] == 'draft') ...[
                          StockActionButton(icon: Icons.edit_rounded, color: StockTheme.primary, onTap: () => _showPOForm(order: o), tooltip: 'ແກ້ໄຂ'),
                          const SizedBox(width: 6),
                          StockActionButton(icon: Icons.send_rounded, color: StockTheme.success, onTap: () => _updateStatus(o, 'pending'), tooltip: 'ສົ່ງ'),
                          const SizedBox(width: 6),
                        ],
                        if (o['status'] == 'pending')
                          StockActionButton(icon: Icons.check_rounded, color: StockTheme.success, onTap: () => _updateStatus(o, 'approved'), tooltip: 'ອະນຸມັດ'),
                        if (o['status'] == 'approved')
                          StockActionButton(icon: Icons.local_shipping_rounded, color: StockTheme.info, onTap: () => _updateStatus(o, 'ordered'), tooltip: 'ສັ່ງ'),
                        if (o['status'] != 'received' && o['status'] != 'cancelled')
                          StockActionButton(icon: Icons.cancel_rounded, color: StockTheme.error, onTap: () => _updateStatus(o, 'cancelled'), tooltip: 'ຍົກເລີກ'),
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

  Future<void> _updateStatus(Map<String, dynamic> order, String newStatus) async {
    final poId = order['id'] ?? order['po_id'];
    final confirmed = await showStockConfirmDialog(context,
      title: 'ປ່ຽນສະຖານະ',
      message: 'ປ່ຽນສະຖານະເປັນ ${StockTheme.statusLabel(newStatus)}?',
      confirmLabel: 'ຢືນຢັນ',
      confirmColor: StockTheme.primary,
    );
    if (!confirmed) return;
    try {
      final response = await StockApiService.updatePurchaseOrderStatus(poId, {'status': newStatus});
      if (response['responseCode'] == '00') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ອັບເດດສະຖານະເປັນ ${StockTheme.statusLabel(newStatus)} ສຳເລັດ'), backgroundColor: StockTheme.success));
        _fetchOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການເຊື່ອມຕໍ່'), backgroundColor: StockTheme.error));
    }
  }

  void _viewPODetails(Map<String, dynamic> order) async {
    final poId = order['id'] ?? order['po_id'];
    try {
      final response = await StockApiService.getPurchaseOrderById(poId);
      if (response['responseCode'] != '00') return;
      final po = response['data'];
      final items = (po['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 700,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.98), StockTheme.bgCard.withOpacity(0.98)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: StockTheme.primary.withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                StockDialogHeader(titleLa: po['po_number'] ?? 'PO-$poId', titleEn: 'Purchase Order Details', icon: Icons.receipt_long_rounded, onClose: () => Navigator.pop(context)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _detailField('ຜູ້ສະໜອງ', _getSupplierName(po['supplier_id'])),
                            const SizedBox(width: 16),
                            _detailField('ສາງ', _getWarehouseName(po['warehouse_id'])),
                            const SizedBox(width: 16),
                            Expanded(child: StockStatusBadge(status: po['status'] ?? 'draft')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _detailField('ວັນທີສັ່ງ', StockTheme.formatDate(po['order_date'])),
                            const SizedBox(width: 16),
                            _detailField('ວັນທີຄາດຮັບ', StockTheme.formatDate(po['expected_date'])),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text('ລາຍການສິນຄ້າ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StockTheme.textPrimary)),
                        const SizedBox(height: 12),
                        if (items.isEmpty)
                          const Text('ບໍ່ມີລາຍການ', style: TextStyle(color: StockTheme.textSecondary))
                        else
                          ...items.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: StockTheme.bgDarker.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: StockTheme.primary.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: Text(item['product_name'] ?? 'Product #${item['product_id']}', style: const TextStyle(color: StockTheme.textPrimary, fontWeight: FontWeight.w600))),
                                Expanded(child: Text('ສັ່ງ: ${item['quantity_ordered'] ?? 0}', style: const TextStyle(color: StockTheme.textSecondary, fontSize: 12))),
                                Expanded(child: Text('ຮັບ: ${item['quantity_received'] ?? 0}', style: const TextStyle(color: StockTheme.success, fontSize: 12))),
                                Expanded(child: Text('${StockTheme.formatPrice(item['unit_cost'])} ₭', style: const TextStyle(color: StockTheme.textSecondary, fontSize: 12))),
                                Expanded(child: Text('${StockTheme.formatPrice(item['total_cost'])} ₭', style: const TextStyle(color: StockTheme.primary, fontWeight: FontWeight.w700, fontSize: 12))),
                              ],
                            ),
                          )),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
    }
  }

  Widget _detailField(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: StockTheme.textSecondary.withOpacity(0.6), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, color: StockTheme.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showPOForm({Map<String, dynamic>? order}) {
    final isEdit = order != null;
    final formKey = GlobalKey<FormState>();
    final poNumberCtrl = TextEditingController(text: order?['po_number'] ?? '');
    final notesCtrl = TextEditingController(text: order?['notes'] ?? '');
    int? selectedSupplierId = order?['supplier_id'];
    int? selectedWarehouseId = order?['warehouse_id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 600,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.98), StockTheme.bgCard.withOpacity(0.98)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: StockTheme.primary.withOpacity(0.3), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StockDialogHeader(titleLa: isEdit ? 'ແກ້ໄຂໃບສັ່ງຊື້' : 'ສ້າງໃບສັ່ງຊື້ໃໝ່', titleEn: isEdit ? 'Edit PO' : 'New Purchase Order', icon: Icons.shopping_cart_rounded, onClose: () => Navigator.pop(context)),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        buildStockFormField(label: 'ເລກທີ PO (PO Number)', controller: poNumberCtrl, icon: Icons.tag_rounded),
                        const SizedBox(height: 16),
                        buildStockDropdown<int>(
                          label: 'ຜູ້ສະໜອງ (Supplier)',
                          icon: Icons.business_rounded,
                          value: selectedSupplierId,
                          hint: 'ເລືອກຜູ້ສະໜອງ',
                          items: _suppliers.map((s) => DropdownMenuItem<int>(value: s['id'] ?? s['supplier_id'], child: Text(s['supplier_name'] ?? ''))).toList(),
                          onChanged: (v) => setDialogState(() => selectedSupplierId = v),
                        ),
                        const SizedBox(height: 16),
                        buildStockDropdown<int>(
                          label: 'ສາງ (Warehouse)',
                          icon: Icons.warehouse_rounded,
                          value: selectedWarehouseId,
                          hint: 'ເລືອກສາງ',
                          items: _warehouses.map((w) => DropdownMenuItem<int>(value: w['id'] ?? w['warehouse_id'], child: Text(w['warehouse_name'] ?? ''))).toList(),
                          onChanged: (v) => setDialogState(() => selectedWarehouseId = v),
                        ),
                        const SizedBox(height: 16),
                        buildStockFormField(label: 'ໝາຍເຫດ (Notes)', controller: notesCtrl, icon: Icons.notes_rounded, maxLines: 2),
                      ],
                    ),
                  ),
                ),
                StockDialogFooter(
                  onCancel: () => Navigator.pop(context),
                  saveLabel: isEdit ? 'ບັນທຶກ' : 'ສ້າງໃບສັ່ງຊື້',
                  onSave: () async {
                    if (!formKey.currentState!.validate()) return;
                    final body = {
                      'po_number': poNumberCtrl.text,
                      'supplier_id': selectedSupplierId,
                      'warehouse_id': selectedWarehouseId,
                      'notes': notesCtrl.text,
                      'created_by': widget.currentUser['username'],
                    };
                    try {
                      final response = isEdit
                          ? await StockApiService.updatePurchaseOrder(order!['id'] ?? order['po_id'], body)
                          : await StockApiService.createPurchaseOrder(body);
                      if (response['responseCode'] == '00') {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${isEdit ? "ອັບເດດ" : "ສ້າງ"}ໃບສັ່ງຊື້ສຳເລັດ'), backgroundColor: StockTheme.success));
                        _fetchOrders();
                      } else {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
                      }
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການເຊື່ອມຕໍ່'), backgroundColor: StockTheme.error));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
