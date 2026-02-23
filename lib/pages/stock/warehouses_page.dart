// lib/pages/stock/warehouses_page.dart
import 'package:flutter/material.dart';
import '../../services/stock_api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

class WarehousesPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const WarehousesPage({super.key, required this.currentUser});

  @override
  State<WarehousesPage> createState() => _WarehousesPageState();
}

class _WarehousesPageState extends State<WarehousesPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  final List<Map<String, dynamic>> _warehouses = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _fetchWarehouses();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchWarehouses() async {
    setState(() => _isLoading = true);
    try {
      final data = await StockApiService.getWarehouses();
      setState(() {
        _warehouses.clear();
        _warehouses.addAll(data.cast<Map<String, dynamic>>());
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => _isLoading = false);
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
              titleLa: 'ຈັດການສາງ',
              titleEn: 'Warehouse Management',
              actions: [
                StockRefreshButton(isLoading: _isLoading, onTap: _fetchWarehouses),
                const SizedBox(width: 12),
                StockPrimaryButton(icon: Icons.add_rounded, label: 'ເພີ່ມສາງ', onTap: () => _showWarehouseForm()),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: StockStatCard(label: 'ສາງທັງໝົດ', value: '${_warehouses.length}', icon: Icons.warehouse_rounded, color: StockTheme.primary)),
                const SizedBox(width: 16),
                Expanded(child: StockStatCard(
                  label: 'ສາງເລີ່ມຕົ້ນ',
                  value: _warehouses.where((w) => w['is_default'] == true || w['is_default'] == 1).map((w) => w['warehouse_name'] ?? '-').firstOrNull ?? '-',
                  icon: Icons.star_rounded,
                  color: StockTheme.warning,
                )),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildWarehouseGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseGrid() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: StockTheme.primary));
    if (_warehouses.isEmpty) return const StockEmptyState(icon: Icons.warehouse_outlined, titleLa: 'ບໍ່ມີສາງ', titleEn: 'No warehouses found');

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossCount, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.6),
          itemCount: _warehouses.length,
          itemBuilder: (context, index) {
            final w = _warehouses[index];
            final isDefault = w['is_default'] == true || w['is_default'] == 1;
            final isActive = w['is_active'] == true || w['is_active'] == 1;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) => Transform.scale(scale: 0.9 + (0.1 * value), child: Opacity(opacity: value, child: child)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    isDefault ? StockTheme.primary.withOpacity(0.15) : StockTheme.bgDark.withOpacity(0.5),
                    isDefault ? StockTheme.primaryLight.withOpacity(0.1) : StockTheme.bgDarker.withOpacity(0.3),
                  ]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDefault ? StockTheme.primary.withOpacity(0.4) : StockTheme.primary.withOpacity(0.2), width: isDefault ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: isDefault ? [StockTheme.warning, StockTheme.warningDark] : [StockTheme.primary, StockTheme.primaryLight]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(isDefault ? Icons.star_rounded : Icons.warehouse_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w['warehouse_name'] ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StockTheme.textPrimary), overflow: TextOverflow.ellipsis),
                              if ((w['warehouse_name_la'] ?? '').toString().isNotEmpty)
                                Text(w['warehouse_name_la'], style: TextStyle(fontSize: 12, color: StockTheme.textSecondary.withOpacity(0.7))),
                            ],
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: StockTheme.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Default', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: StockTheme.warning)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if ((w['address'] ?? '').toString().isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14, color: StockTheme.textSecondary.withOpacity(0.5)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(w['address'] ?? '', style: TextStyle(fontSize: 12, color: StockTheme.textSecondary.withOpacity(0.7)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    if ((w['phone'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_rounded, size: 14, color: StockTheme.textSecondary.withOpacity(0.5)),
                          const SizedBox(width: 6),
                          Text(w['phone'] ?? '', style: TextStyle(fontSize: 12, color: StockTheme.textSecondary.withOpacity(0.7))),
                        ],
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        StockStatusBadge(status: isActive ? 'confirmed' : 'cancelled'),
                        const Spacer(),
                        StockActionButton(icon: Icons.edit_rounded, color: StockTheme.primary, onTap: () => _showWarehouseForm(warehouse: w)),
                        const SizedBox(width: 8),
                        StockActionButton(icon: Icons.delete_rounded, color: StockTheme.error, onTap: () => _deleteWarehouse(w)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showWarehouseForm({Map<String, dynamic>? warehouse}) {
    final isEdit = warehouse != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: warehouse?['warehouse_name'] ?? '');
    final nameLaCtrl = TextEditingController(text: warehouse?['warehouse_name_la'] ?? '');
    final addressCtrl = TextEditingController(text: warehouse?['address'] ?? '');
    final phoneCtrl = TextEditingController(text: warehouse?['phone'] ?? '');
    final notesCtrl = TextEditingController(text: warehouse?['notes'] ?? '');
    bool isDefault = warehouse?['is_default'] == true || warehouse?['is_default'] == 1;
    bool isActive = warehouse?['is_active'] ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 550,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [StockTheme.bgDark.withOpacity(0.98), StockTheme.bgCard.withOpacity(0.98)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: StockTheme.primary.withOpacity(0.3), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StockDialogHeader(titleLa: isEdit ? 'ແກ້ໄຂສາງ' : 'ເພີ່ມສາງໃໝ່', titleEn: isEdit ? 'Edit Warehouse' : 'Add Warehouse', icon: Icons.warehouse_rounded, onClose: () => Navigator.pop(context)),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        buildStockFormField(label: 'ຊື່ສາງ (English)', controller: nameCtrl, icon: Icons.warehouse_rounded, validator: (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນຊື່' : null),
                        const SizedBox(height: 16),
                        buildStockFormField(label: 'ຊື່ສາງ (ລາວ)', controller: nameLaCtrl, icon: Icons.translate_rounded),
                        const SizedBox(height: 16),
                        buildStockFormField(label: 'ທີ່ຢູ່ (Address)', controller: addressCtrl, icon: Icons.location_on_rounded),
                        const SizedBox(height: 16),
                        buildStockFormField(label: 'ໂທລະສັບ (Phone)', controller: phoneCtrl, icon: Icons.phone_rounded),
                        const SizedBox(height: 16),
                        buildStockFormField(label: 'ໝາຍເຫດ (Notes)', controller: notesCtrl, icon: Icons.notes_rounded, maxLines: 2),
                        const SizedBox(height: 16),
                        // Default toggle
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.5), StockTheme.bgDarker.withOpacity(0.3)]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: StockTheme.warning.withOpacity(0.2), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: StockTheme.warning),
                              const SizedBox(width: 12),
                              const Expanded(child: Text('ສາງເລີ່ມຕົ້ນ (Default)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: StockTheme.textSecondary))),
                              Switch(value: isDefault, onChanged: (v) => setDialogState(() => isDefault = v), activeColor: StockTheme.warning),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.5), StockTheme.bgDarker.withOpacity(0.3)]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: StockTheme.primary.withOpacity(0.2), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.toggle_on_rounded, color: StockTheme.primary),
                              const SizedBox(width: 12),
                              const Expanded(child: Text('ສະຖານະ (Status)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: StockTheme.textSecondary))),
                              Switch(value: isActive, onChanged: (v) => setDialogState(() => isActive = v), activeColor: StockTheme.success),
                              Text(isActive ? 'ເປີດໃຊ້' : 'ປິດໃຊ້', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? StockTheme.success : StockTheme.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                StockDialogFooter(
                  onCancel: () => Navigator.pop(context),
                  saveLabel: isEdit ? 'ບັນທຶກການປ່ຽນແປງ' : 'ບັນທຶກ',
                  onSave: () async {
                    if (!formKey.currentState!.validate()) return;
                    final body = {
                      'warehouse_name': nameCtrl.text,
                      'warehouse_name_la': nameLaCtrl.text,
                      'address': addressCtrl.text,
                      'phone': phoneCtrl.text,
                      'notes': notesCtrl.text,
                      'is_default': isDefault,
                      'is_active': isActive,
                    };
                    try {
                      final response = isEdit
                          ? await StockApiService.updateWarehouse(warehouse!['id'] ?? warehouse['warehouse_id'], body)
                          : await StockApiService.createWarehouse(body);
                      if (response['responseCode'] == '00') {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${isEdit ? "ອັບເດດ" : "ເພີ່ມ"}ສາງສຳເລັດ'), backgroundColor: StockTheme.success));
                        _fetchWarehouses();
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

  Future<void> _deleteWarehouse(Map<String, dynamic> warehouse) async {
    final confirmed = await showStockConfirmDialog(context,
      title: 'ລຶບສາງ',
      message: 'ທ່ານຕ້ອງການລຶບ ${warehouse['warehouse_name']} ແທ້ບໍ່?',
      confirmLabel: 'ລຶບ',
    );
    if (!confirmed) return;
    try {
      final response = await StockApiService.deleteWarehouse(warehouse['id'] ?? warehouse['warehouse_id']);
      if (response['responseCode'] == '00') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ລຶບ ${warehouse['warehouse_name']} ສຳເລັດ'), backgroundColor: StockTheme.success));
        _fetchWarehouses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການເຊື່ອມຕໍ່'), backgroundColor: StockTheme.error));
    }
  }
}
