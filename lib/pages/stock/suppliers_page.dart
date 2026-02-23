// lib/pages/stock/suppliers_page.dart
import 'package:flutter/material.dart';
import '../../services/stock_api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

class SuppliersPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const SuppliersPage({super.key, required this.currentUser});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  late AnimationController _animationController;
  final List<Map<String, dynamic>> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _fetchSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final data = await StockApiService.getSuppliers();
      setState(() {
        _suppliers.clear();
        _suppliers.addAll(data.cast<Map<String, dynamic>>());
      });
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredSuppliers {
    if (_searchQuery.isEmpty) return _suppliers;
    return _suppliers.where((s) {
      final q = _searchQuery.toLowerCase();
      return (s['supplier_name'] ?? '').toString().toLowerCase().contains(q) ||
          (s['supplier_code'] ?? '').toString().toLowerCase().contains(q) ||
          (s['contact_person'] ?? '').toString().toLowerCase().contains(q) ||
          (s['phone'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
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
              titleLa: 'ຈັດການຜູ້ສະໜອງ',
              titleEn: 'Supplier Management',
              actions: [
                StockRefreshButton(isLoading: _isLoading, onTap: _fetchSuppliers),
                const SizedBox(width: 12),
                StockPrimaryButton(icon: Icons.add_business_rounded, label: 'ເພີ່ມຜູ້ສະໜອງ', onTap: () => _showSupplierForm()),
              ],
            ),
            const SizedBox(height: 20),
            _buildStats(),
            const SizedBox(height: 20),
            _buildSearch(),
            const SizedBox(height: 20),
            Expanded(child: _buildSuppliersList()),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final total = _suppliers.length;
    final active = _suppliers.where((s) => s['is_active'] == true || s['is_active'] == 1).length;
    return Row(
      children: [
        Expanded(child: StockStatCard(label: 'ຜູ້ສະໜອງທັງໝົດ', value: '$total', icon: Icons.business_rounded, color: StockTheme.primary)),
        const SizedBox(width: 16),
        Expanded(child: StockStatCard(label: 'ເປີດໃຊ້ງານ', value: '$active', icon: Icons.check_circle_rounded, color: StockTheme.success)),
        const SizedBox(width: 16),
        Expanded(child: StockStatCard(label: 'ປິດໃຊ້ງານ', value: '${total - active}', icon: Icons.cancel_rounded, color: StockTheme.error)),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [StockTheme.bgDark.withOpacity(0.5), StockTheme.bgDarker.withOpacity(0.3)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StockTheme.primary.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: StockTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: StockTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ຄົ້ນຫາຜູ້ສະໜອງ...',
                hintStyle: TextStyle(color: StockTheme.textSecondary.withOpacity(0.5), fontSize: 14),
                border: InputBorder.none, isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuppliersList() {
    final suppliers = _filteredSuppliers;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: StockTheme.primary));
    }

    if (suppliers.isEmpty) {
      return const StockEmptyState(icon: Icons.business_outlined, titleLa: 'ບໍ່ພົບຜູ້ສະໜອງ', titleEn: 'No suppliers found');
    }

    return StockTableContainer(
      headers: const ['ລະຫັດ', 'ຊື່ຜູ້ສະໜອງ', 'ຜູ້ຕິດຕໍ່', 'ໂທລະສັບ', 'ເຄຣດິດ (ວັນ)', 'ສະຖານະ', 'ຈັດການ'],
      flexValues: const [1, 3, 2, 2, 1, 1, 1],
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: suppliers.length,
        itemBuilder: (context, index) {
          final s = suppliers[index];
          final isActive = s['is_active'] == true || s['is_active'] == 1;
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
                  Expanded(flex: 1, child: Text(s['supplier_code'] ?? '-', style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary, fontWeight: FontWeight.w600))),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['supplier_name'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: StockTheme.textPrimary)),
                        if ((s['supplier_name_la'] ?? '').toString().isNotEmpty)
                          Text(s['supplier_name_la'], style: TextStyle(fontSize: 12, color: StockTheme.textSecondary.withOpacity(0.7))),
                      ],
                    ),
                  ),
                  Expanded(flex: 2, child: Text(s['contact_person'] ?? '-', style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  Expanded(flex: 2, child: Text(s['phone'] ?? '-', style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary))),
                  Expanded(flex: 1, child: Text('${s['credit_days'] ?? 0}', style: const TextStyle(fontSize: 13, color: StockTheme.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: StockStatusBadge(status: isActive ? 'confirmed' : 'cancelled')),
                  Expanded(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        StockActionButton(icon: Icons.edit_rounded, color: StockTheme.primary, onTap: () => _showSupplierForm(supplier: s)),
                        const SizedBox(width: 8),
                        StockActionButton(icon: Icons.delete_rounded, color: StockTheme.error, onTap: () => _deleteSupplier(s)),
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

  void _showSupplierForm({Map<String, dynamic>? supplier}) {
    final isEdit = supplier != null;
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController(text: supplier?['supplier_code'] ?? '');
    final nameCtrl = TextEditingController(text: supplier?['supplier_name'] ?? '');
    final nameLaCtrl = TextEditingController(text: supplier?['supplier_name_la'] ?? '');
    final contactCtrl = TextEditingController(text: supplier?['contact_person'] ?? '');
    final phoneCtrl = TextEditingController(text: supplier?['phone'] ?? '');
    final phone2Ctrl = TextEditingController(text: supplier?['phone2'] ?? '');
    final emailCtrl = TextEditingController(text: supplier?['email'] ?? '');
    final addressCtrl = TextEditingController(text: supplier?['address'] ?? '');
    final provinceCtrl = TextEditingController(text: supplier?['province'] ?? '');
    final taxIdCtrl = TextEditingController(text: supplier?['tax_id'] ?? '');
    final bankNameCtrl = TextEditingController(text: supplier?['bank_name'] ?? '');
    final bankAccountCtrl = TextEditingController(text: supplier?['bank_account'] ?? '');
    final creditDaysCtrl = TextEditingController(text: supplier?['credit_days']?.toString() ?? '30');
    final creditLimitCtrl = TextEditingController(text: supplier?['credit_limit']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: supplier?['notes'] ?? '');
    bool isActive = supplier?['is_active'] ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 700,
            constraints: const BoxConstraints(maxHeight: 800),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [StockTheme.bgDark.withOpacity(0.98), StockTheme.bgCard.withOpacity(0.98)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: StockTheme.primary.withOpacity(0.3), width: 1),
              boxShadow: [BoxShadow(color: StockTheme.primary.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StockDialogHeader(
                  titleLa: isEdit ? 'ແກ້ໄຂຜູ້ສະໜອງ' : 'ເພີ່ມຜູ້ສະໜອງໃໝ່',
                  titleEn: isEdit ? 'Edit Supplier' : 'Add Supplier',
                  icon: Icons.business_rounded,
                  onClose: () => Navigator.pop(context),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(child: buildStockFormField(label: 'ລະຫັດຜູ້ສະໜອງ (Code)', controller: codeCtrl, icon: Icons.tag_rounded, validator: (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນລະຫັດ' : null)),
                            const SizedBox(width: 16),
                            Expanded(child: buildStockFormField(label: 'ເລກປະຈຳຕົວຜູ້ເສຍພາສີ (Tax ID)', controller: taxIdCtrl, icon: Icons.receipt_rounded)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: buildStockFormField(label: 'ຊື່ຜູ້ສະໜອງ (English)', controller: nameCtrl, icon: Icons.business_rounded, validator: (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນຊື່' : null)),
                            const SizedBox(width: 16),
                            Expanded(child: buildStockFormField(label: 'ຊື່ຜູ້ສະໜອງ (ລາວ)', controller: nameLaCtrl, icon: Icons.translate_rounded)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: buildStockFormField(label: 'ຜູ້ຕິດຕໍ່ (Contact Person)', controller: contactCtrl, icon: Icons.person_rounded)),
                            const SizedBox(width: 16),
                            Expanded(child: buildStockFormField(label: 'ອີເມວ (Email)', controller: emailCtrl, icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: buildStockFormField(label: 'ໂທລະສັບ (Phone)', controller: phoneCtrl, icon: Icons.phone_rounded, keyboardType: TextInputType.phone)),
                            const SizedBox(width: 16),
                            Expanded(child: buildStockFormField(label: 'ໂທລະສັບ 2 (Phone 2)', controller: phone2Ctrl, icon: Icons.phone_rounded, keyboardType: TextInputType.phone)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: buildStockFormField(label: 'ທີ່ຢູ່ (Address)', controller: addressCtrl, icon: Icons.location_on_rounded)),
                            const SizedBox(width: 16),
                            Expanded(child: buildStockFormField(label: 'ແຂວງ (Province)', controller: provinceCtrl, icon: Icons.map_rounded)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: buildStockFormField(label: 'ທະນາຄານ (Bank)', controller: bankNameCtrl, icon: Icons.account_balance_rounded)),
                            const SizedBox(width: 16),
                            Expanded(child: buildStockFormField(label: 'ເລກບັນຊີ (Account)', controller: bankAccountCtrl, icon: Icons.credit_card_rounded)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: buildStockFormField(label: 'ເຄຣດິດ (ວັນ)', controller: creditDaysCtrl, icon: Icons.schedule_rounded, keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(child: buildStockFormField(label: 'ວົງເງິນເຄຣດິດ', controller: creditLimitCtrl, icon: Icons.money_rounded, keyboardType: TextInputType.number)),
                          ]),
                          const SizedBox(height: 16),
                          buildStockFormField(label: 'ໝາຍເຫດ (Notes)', controller: notesCtrl, icon: Icons.notes_rounded, maxLines: 2),
                          const SizedBox(height: 16),
                          _buildStatusRow(isActive, (v) => setDialogState(() => isActive = v)),
                        ],
                      ),
                    ),
                  ),
                ),
                StockDialogFooter(
                  onCancel: () => Navigator.pop(context),
                  saveLabel: isEdit ? 'ບັນທຶກການປ່ຽນແປງ' : 'ບັນທຶກ',
                  onSave: () async {
                    if (!formKey.currentState!.validate()) return;
                    final body = {
                      'supplier_code': codeCtrl.text,
                      'supplier_name': nameCtrl.text,
                      'supplier_name_la': nameLaCtrl.text,
                      'contact_person': contactCtrl.text,
                      'phone': phoneCtrl.text,
                      'phone2': phone2Ctrl.text,
                      'email': emailCtrl.text,
                      'address': addressCtrl.text,
                      'province': provinceCtrl.text,
                      'tax_id': taxIdCtrl.text,
                      'bank_name': bankNameCtrl.text,
                      'bank_account': bankAccountCtrl.text,
                      'credit_days': int.tryParse(creditDaysCtrl.text) ?? 0,
                      'credit_limit': double.tryParse(creditLimitCtrl.text) ?? 0,
                      'notes': notesCtrl.text,
                      'is_active': isActive,
                      'created_by': widget.currentUser['username'],
                    };
                    try {
                      final response = isEdit
                          ? await StockApiService.updateSupplier(supplier!['id'] ?? supplier['supplier_id'], body)
                          : await StockApiService.createSupplier(body);
                      if (response['responseCode'] == '00') {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${isEdit ? "ອັບເດດ" : "ເພີ່ມ"}ຜູ້ສະໜອງສຳເລັດ'), backgroundColor: StockTheme.success));
                        _fetchSuppliers();
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

  Widget _buildStatusRow(bool isActive, ValueChanged<bool> onChanged) {
    return Container(
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
          Switch(value: isActive, onChanged: onChanged, activeColor: StockTheme.success),
          Text(isActive ? 'ເປີດໃຊ້' : 'ປິດໃຊ້', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? StockTheme.success : StockTheme.error)),
        ],
      ),
    );
  }

  Future<void> _deleteSupplier(Map<String, dynamic> supplier) async {
    final confirmed = await showStockConfirmDialog(context,
      title: 'ລຶບຜູ້ສະໜອງ',
      message: 'ທ່ານຕ້ອງການລຶບ ${supplier['supplier_name']} ແທ້ບໍ່?',
      confirmLabel: 'ລຶບ',
    );
    if (!confirmed) return;
    try {
      final response = await StockApiService.deleteSupplier(supplier['id'] ?? supplier['supplier_id']);
      if (response['responseCode'] == '00') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ລຶບ ${supplier['supplier_name']} ສຳເລັດ'), backgroundColor: StockTheme.success));
        _fetchSuppliers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: StockTheme.error));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການເຊື່ອມຕໍ່'), backgroundColor: StockTheme.error));
    }
  }
}
