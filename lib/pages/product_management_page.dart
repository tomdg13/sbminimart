// lib/pages/product_management_page.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProductManagementPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final int initialTab;

  const ProductManagementPage({
    super.key,
    required this.currentUser,
    this.initialTab = 0,
  });

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';
  int? _selectedCategoryFilter;
  late AnimationController _animationController;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  final Set<int> _selectedProducts = {};

  final List<Map<String, dynamic>> _products = [];
  final List<Map<String, dynamic>> _categories = [];
  final List<Map<String, dynamic>> _brands = [];
  final List<Map<String, dynamic>> _units = [];

  int _currentTab = 0;

  // ── theme constants ──────────────────────────────
  static const _bgDeep      = Color(0xFF050A14);
  static const _surface     = Color(0xFF0A1628);
  static const _card        = Color(0xFF0D1F3C);
  static const _cardAlt     = Color(0xFF0F2444);
  static const _border      = Color(0xFF1E3A5F);
  static const _primary     = Color(0xFF2563EB);
  static const _primaryHi   = Color(0xFF3B82F6);
  static const _primaryGlow = Color(0xFF1D4ED8);
  static const _success     = Color(0xFF10B981);
  static const _warning     = Color(0xFFF59E0B);
  static const _danger      = Color(0xFFEF4444);
  static const _textHi      = Color(0xFFE2E8F0);
  static const _textMid     = Color(0xFF94A3B8);
  static const _textLo      = Color(0xFF64748B);

  static const _gradBg      = LinearGradient(colors: [_surface, _bgDeep]);
  static const _gradPrimary = LinearGradient(colors: [_primaryHi, _primary]);
  // ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _animationController.forward();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchProducts(), _fetchCategories(), _fetchBrands(), _fetchUnits()]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchProducts() async {
    try {
      final products = await ApiService.getProducts();
      if (products.isNotEmpty) setState(() { _products.clear(); _products.addAll(products.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('fetchProducts: $e'); }
  }

  Future<void> _fetchCategories() async {
    try {
      final categories = await ApiService.getCategories();
      setState(() { _categories.clear(); _categories.addAll(categories.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('fetchCategories: $e'); }
  }

  Future<void> _fetchBrands() async {
    try {
      final brands = await ApiService.getBrands();
      setState(() { _brands.clear(); _brands.addAll(brands.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('fetchBrands: $e'); }
  }

  Future<void> _fetchUnits() async {
    try {
      final units = await ApiService.getUnits();
      setState(() { _units.clear(); _units.addAll(units.cast<Map<String, dynamic>>()); });
    } catch (e) { debugPrint('fetchUnits: $e'); }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num = double.tryParse(price.toString()) ?? 0;
    return num.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  String _formatJsonForLog(Map<String, dynamic> json) {
    final buffer = StringBuffer();
    buffer.writeln('{');
    json.forEach((key, value) { buffer.writeln('  "$key": ${value is String ? '"$value"' : value},'); });
    buffer.write('}');
    return buffer.toString();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          (product['product_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product['product_name_la'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product['product_code'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product['barcode'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _selectedFilter == 'all' ||
          (_selectedFilter == 'active' && product['is_active'] == true) ||
          (_selectedFilter == 'inactive' && product['is_active'] == false) ||
          (_selectedFilter == 'low_stock' && (int.tryParse((product['current_stock'] ?? product['stock'] ?? 0).toString()) ?? 0) <= (int.tryParse((product['min_stock'] ?? 0).toString()) ?? 0));
      final matchesCategory = _selectedCategoryFilter == null || product['category_id'] == _selectedCategoryFilter;
      return matchesSearch && matchesFilter && matchesCategory;
    }).toList();
  }

  void _clearSelection() => setState(() { _selectedProducts.clear(); _isSelectionMode = false; });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        decoration: const BoxDecoration(gradient: _gradBg),
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildTabBar(),
          const SizedBox(height: 20),
          if (_currentTab == 0) ...[
            _buildFiltersAndSearch(),
            const SizedBox(height: 20),
            _buildStatsCards(),
            const SizedBox(height: 20),
            if (_isSelectionMode) ...[_buildSelectionBar(), const SizedBox(height: 12)],
            Expanded(child: _buildProductsList()),
          ] else if (_currentTab == 1) ...[
            Expanded(child: _buildCategoriesTab()),
          ] else if (_currentTab == 2) ...[
            Expanded(child: _buildBrandsTab()),
          ] else ...[
            Expanded(child: _buildUnitsTab()),
          ],
        ]),
      ),
    );
  }

  // ── Header ──────────────────────────────────────
  Widget _buildHeader() {
    return Row(children: [
      Container(
        width: 4, height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_primaryHi, _primaryGlow]),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: _primaryHi.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)],
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [_textHi, _textMid]).createShader(b),
          child: const Text('ຈັດການສິນຄ້າ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
        ),
        Text('Product Management', style: TextStyle(fontSize: 14, color: _textLo.withOpacity(0.8), fontWeight: FontWeight.w500)),
      ])),
      _buildIconBtn(Icons.refresh_rounded, _fetchAllData),
      const SizedBox(width: 12),
      _buildAddButton(),
    ]);
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_card, Color(0xFF0A1A30)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border, width: 1),
          ),
          child: Icon(icon, color: _textMid, size: 20),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    final labels = ['ເພີ່ມສິນຄ້າ', 'ເພີ່ມໝວດໝູ່', 'ເພີ່ມຍີ່ຫໍ້', 'ເພີ່ມຫົວໜ່ວຍ'];
    final icons  = [Icons.add_shopping_cart_rounded, Icons.category_rounded, Icons.branding_watermark_rounded, Icons.straighten_rounded];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () { switch (_currentTab) { case 0: _showProductForm(); break; case 1: _showCategoryForm(); break; case 2: _showBrandForm(); break; case 3: _showUnitForm(); break; } },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: _gradPrimary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _primaryHi.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Icon(icons[_currentTab], color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(labels[_currentTab], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = [
      {'icon': Icons.inventory_2_rounded,       'label': 'ສິນຄ້າ',   'count': _products.length},
      {'icon': Icons.category_rounded,           'label': 'ໝວດໝູ່',   'count': _categories.length},
      {'icon': Icons.branding_watermark_rounded, 'label': 'ຍີ່ຫໍ້',   'count': _brands.length},
      {'icon': Icons.straighten_rounded,         'label': 'ຫົວໜ່ວຍ',  'count': _units.length},
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_card, Color(0xFF0A1A30)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
        boxShadow: [BoxShadow(color: _bgDeep.withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: List.generate(tabs.length, (index) {
        final isSelected = _currentTab == index;
        final tab = tabs[index];
        return Expanded(child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _currentTab = index),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: isSelected ? _gradPrimary : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected ? [BoxShadow(color: _primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))] : [],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(tab['icon'] as IconData, color: isSelected ? Colors.white : _textLo, size: 20),
                const SizedBox(width: 8),
                Text(tab['label'] as String, style: TextStyle(color: isSelected ? Colors.white : _textMid, fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.2) : _primaryHi.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? Colors.white.withOpacity(0.1) : _border, width: 1),
                  ),
                  child: Text('${tab['count']}', style: TextStyle(color: isSelected ? Colors.white : _primaryHi, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
        ));
      })),
    );
  }

  // ── Filters ─────────────────────────────────────
  Widget _buildFiltersAndSearch() {
    return Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_card, Color(0xFF0A1A30)]), borderRadius: BorderRadius.circular(14), border: Border.all(color: _border, width: 1)),
        child: Row(children: [
          const Icon(Icons.search_rounded, color: _primaryHi, size: 20),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: _textHi, fontSize: 14),
            decoration: InputDecoration(hintText: 'ຄົ້ນຫາສິນຄ້າ, ບາໂຄ້ດ...', hintStyle: TextStyle(color: _textLo.withOpacity(0.6), fontSize: 14), border: InputBorder.none, isDense: true),
          )),
        ]),
      )),
      const SizedBox(width: 12),
      _buildFilterChip('all',       'ທັງໝົດ'),
      const SizedBox(width: 8),
      _buildFilterChip('active',    'ເປີດໃຊ້'),
      const SizedBox(width: 8),
      _buildFilterChip('inactive',  'ປິດໃຊ້'),
      const SizedBox(width: 8),
      _buildFilterChip('low_stock', 'ສິນຄ້າໃກ້ໝົດ'),
    ]);
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? _gradPrimary : null,
            color: isSelected ? null : _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? _primaryHi.withOpacity(0.6) : _border, width: 1),
            boxShadow: isSelected ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : [],
          ),
          child: Text(label, style: TextStyle(color: isSelected ? Colors.white : _textMid, fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  // ── Stats cards ──────────────────────────────────
  Widget _buildStatsCards() {
    final total  = _products.length;
    final active = _products.where((p) => p['is_active'] == true).length;
    final low    = _products.where((p) =>
        (int.tryParse((p['current_stock'] ?? p['stock'] ?? 0).toString()) ?? 0) <=
        (int.tryParse((p['min_stock'] ?? 0).toString()) ?? 0)).length;
    final value  = _products.fold<double>(0, (s, p) =>
        s + ((double.tryParse((p['selling_price'] ?? p['sell_price'] ?? '0').toString()) ?? 0) *
             (int.tryParse((p['current_stock'] ?? p['stock'] ?? '0').toString()) ?? 0)));
    return Row(children: [
      Expanded(child: _buildStatCard('ສິນຄ້າທັງໝົດ', total.toString(),              Icons.inventory_2_rounded,     _primaryHi)),
      const SizedBox(width: 16),
      Expanded(child: _buildStatCard('ເປີດໃຊ້',       active.toString(),             Icons.check_circle_rounded,    _success)),
      const SizedBox(width: 16),
      Expanded(child: _buildStatCard('ສິນຄ້າໃກ້ໝົດ',  low.toString(),               Icons.warning_rounded,         _warning)),
      const SizedBox(width: 16),
      Expanded(child: _buildStatCard('ມູນຄ່າລວມ',     '${_formatPrice(value)} ₭',   Icons.monetization_on_rounded, _primary)),
    ]);
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_card, Color(0xFF0A1A30)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _textLo, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ShaderMask(
            shaderCallback: (b) => LinearGradient(colors: [color, color.withOpacity(0.7)]).createShader(b),
            child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1), overflow: TextOverflow.ellipsis),
          ),
        ])),
      ]),
    );
  }

  // ── Selection bar ────────────────────────────────
  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_primaryHi.withOpacity(0.12), _primary.withOpacity(0.08)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryHi.withOpacity(0.3), width: 1),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _primaryHi.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: _primaryHi.withOpacity(0.3), width: 1)),
          child: Text('ເລືອກແລ້ວ ${_selectedProducts.length} ລາຍການ', style: const TextStyle(color: _primaryHi, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        _buildSelectionAction(Icons.delete_sweep_rounded, 'ລຶບທັງໝົດ', _danger,   _batchDelete),
        const SizedBox(width: 12),
        _buildSelectionAction(Icons.close_rounded,        'ຍົກເລີກ',   _textMid,  _clearSelection),
      ]),
    );
  }

  Widget _buildSelectionAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3), width: 1)),
          child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))]),
        ),
      ),
    );
  }

  // ── Products list ────────────────────────────────
  Widget _buildProductsList() {
    final products = _filteredProducts;
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: _primaryHi));
    if (products.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_primaryHi.withOpacity(0.08), _primary.withOpacity(0.04)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: _border, width: 1)),
          child: const Icon(Icons.inventory_2_outlined, size: 64, color: _primaryHi),
        ),
        const SizedBox(height: 16),
        const Text('ບໍ່ພົບສິນຄ້າ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textHi)),
        const SizedBox(height: 8),
        Text('No products found', style: TextStyle(fontSize: 14, color: _textLo.withOpacity(0.7))),
      ]));
    }
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_card, Color(0xFF0A1A30)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 1),
        boxShadow: [BoxShadow(color: _bgDeep.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0x1A3B82F6), Color(0x0A1D4ED8)]),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
          ),
          child: Row(children: [
            if (_isSelectionMode) const SizedBox(width: 40),
            const Expanded(flex: 3, child: Text('ສິນຄ້າ',   style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMid, letterSpacing: 0.5))),
            const Expanded(flex: 2, child: Text('ໝວດໝູ່',   style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMid, letterSpacing: 0.5))),
            const Expanded(flex: 1, child: Text('ລາຄາຊື້',  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMid, letterSpacing: 0.5))),
            const Expanded(flex: 1, child: Text('ລາຄາຂາຍ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMid, letterSpacing: 0.5))),
            const Expanded(flex: 1, child: Text('ລາຄາສົ່ງ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMid, letterSpacing: 0.5))),
            const Expanded(flex: 1, child: Text('ສະຕ໋ອກ',  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMid, letterSpacing: 0.5))),
            const Expanded(flex: 1, child: Text('ສະຖານະ',  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMid, letterSpacing: 0.5))),
            const SizedBox(width: 100),
          ]),
        ),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: products.length,
          itemBuilder: (context, index) => _buildProductRow(products[index], index),
        )),
      ]),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> product, int index) {
    final isActive   = product['is_active'] == true;
    final stock      = int.tryParse((product['current_stock'] ?? product['stock'] ?? 0).toString()) ?? 0;
    final minStock   = int.tryParse((product['min_stock'] ?? 0).toString()) ?? 0;
    final isLowStock = stock <= minStock && minStock > 0;
    final productId  = product['id'] ?? product['product_id'];
    final isSelected = _selectedProducts.contains(productId);
    final category   = _categories.firstWhere((c) => c['category_id'] == product['category_id'] || c['id'] == product['category_id'], orElse: () => {});
    final categoryName = category['category_name_la'] ?? category['category_name'] ?? category['name'] ?? '-';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Transform.translate(offset: Offset(0, 20*(1-value)), child: Opacity(opacity: value, child: child)),
      child: GestureDetector(
        onLongPress: () => setState(() { _isSelectionMode = true; _selectedProducts.add(productId); }),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: isSelected
                ? [_primaryHi.withOpacity(0.12), _primary.withOpacity(0.08)]
                : [_cardAlt.withOpacity(0.8), _card.withOpacity(0.6)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? _primaryHi.withOpacity(0.45) : _border.withOpacity(0.6), width: 1),
          ),
          child: Row(children: [
            if (_isSelectionMode) Checkbox(
              value: isSelected,
              onChanged: (v) => setState(() { if (v == true) _selectedProducts.add(productId); else { _selectedProducts.remove(productId); if (_selectedProducts.isEmpty) _isSelectionMode = false; } }),
              activeColor: _primaryHi,
            ),
            Expanded(flex: 3, child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(gradient: _gradPrimary, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]),
                child: Center(child: Text((product['product_name'] ?? product['product_name_la'] ?? 'P').toString().characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product['product_name'] ?? 'N/A', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textHi), overflow: TextOverflow.ellipsis, maxLines: 1),
                if ((product['product_name_la'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(product['product_name_la'] ?? '', style: const TextStyle(fontSize: 12, color: _textMid), overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 2),
                Text('${product['product_code'] ?? '-'} · ${product['barcode'] ?? '-'}', style: TextStyle(fontSize: 11, color: _textLo.withOpacity(0.7)), overflow: TextOverflow.ellipsis),
              ])),
            ])),
            Expanded(flex: 2, child: Text(categoryName, style: const TextStyle(fontSize: 13, color: _textMid, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            Expanded(flex: 1, child: Text('${_formatPrice(product['cost_price'])} ₭',                             style: const TextStyle(fontSize: 13, color: _textMid, fontWeight: FontWeight.w500))),
            Expanded(flex: 1, child: Text('${_formatPrice(product['selling_price'] ?? product['sell_price'])} ₭', style: const TextStyle(fontSize: 13, color: _success,  fontWeight: FontWeight.w700))),
            Expanded(flex: 1, child: Text('${_formatPrice(product['wholesale_price'])} ₭',                        style: TextStyle(fontSize: 13, color: _textMid.withOpacity(0.7), fontWeight: FontWeight.w500))),
            Expanded(flex: 1, child: Row(children: [
              if (isLowStock) ...[const Icon(Icons.warning_rounded, color: _warning, size: 14), const SizedBox(width: 4)],
              Text('$stock', style: TextStyle(fontSize: 13, color: isLowStock ? _warning : _textMid, fontWeight: FontWeight.w600)),
            ])),
            Expanded(flex: 1, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isActive ? [_success.withOpacity(0.15), _success.withOpacity(0.08)] : [_danger.withOpacity(0.15), _danger.withOpacity(0.08)]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isActive ? _success.withOpacity(0.35) : _danger.withOpacity(0.35), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: isActive ? _success : _danger, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (isActive ? _success : _danger).withOpacity(0.5), blurRadius: 4, spreadRadius: 1)])),
                const SizedBox(width: 6),
                Text(isActive ? 'ເປີດ' : 'ປິດ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? _success : _danger)),
              ]),
            )),
            SizedBox(width: 100, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _buildActionButton(Icons.edit_rounded,   _primaryHi, () => _showProductForm(product: product)),
              const SizedBox(width: 8),
              _buildActionButton(Icons.delete_rounded, _danger,    () => _showDeleteProductConfirmation(product)),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.25), width: 1)),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // ==========================================
  // PRODUCT FORM DIALOG
  // ==========================================
  void _showProductForm({Map<String, dynamic>? product}) {
    final isEdit = product != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl      = TextEditingController(text: product?['product_name']     ?? '');
    final nameLaCtrl    = TextEditingController(text: product?['product_name_la']  ?? '');
    final codeCtrl      = TextEditingController(text: product?['product_code']     ?? '');
    final barcodeCtrl   = TextEditingController(text: product?['barcode']          ?? '');
    final descCtrl      = TextEditingController(text: product?['description']      ?? '');
    final costCtrl      = TextEditingController(text: (product?['cost_price']      ?? '').toString());
    final sellCtrl      = TextEditingController(text: (product?['selling_price']   ?? product?['sell_price'] ?? '').toString());
    final wholesaleCtrl = TextEditingController(text: (product?['wholesale_price'] ?? '').toString());
    final minPriceCtrl  = TextEditingController(text: (product?['min_price']       ?? '0').toString());
    final stockCtrl     = TextEditingController(text: (product?['current_stock']   ?? product?['stock'] ?? '0').toString());
    final minStockCtrl  = TextEditingController(text: (product?['min_stock']       ?? '0').toString());
    final maxStockCtrl  = TextEditingController(text: (product?['max_stock']       ?? '0').toString());
    int?  selCatId   = _toId(product?['category_id']);
    int?  selBrandId = _toId(product?['brand_id']);
    int?  selUnitId  = _toId(product?['unit_id']);
    bool  isActive   = product?['is_active'] ?? true;
    void disposeAll() { for (final c in [nameCtrl,nameLaCtrl,codeCtrl,barcodeCtrl,descCtrl,costCtrl,sellCtrl,wholesaleCtrl,minPriceCtrl,stockCtrl,minStockCtrl,maxStockCtrl]) c.dispose(); }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDS) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 820),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D1F3C), Color(0xFF050A14)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border, width: 1),
            boxShadow: [BoxShadow(color: _primary.withOpacity(0.25), blurRadius: 32, offset: const Offset(0, 12)), BoxShadow(color: _bgDeep.withOpacity(0.8), blurRadius: 8, spreadRadius: 2)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x1A3B82F6), Colors.transparent]), borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: _gradPrimary, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: _primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: Icon(isEdit ? Icons.edit_rounded : Icons.add_shopping_cart_rounded, color: Colors.white, size: 24)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEdit ? 'ແກ້ໄຂສິນຄ້າ' : 'ເພີ່ມສິນຄ້າໃໝ່', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textHi)),
                  Text(isEdit ? 'Edit Product' : 'Add New Product', style: const TextStyle(fontSize: 12, color: _textMid)),
                ])),
                IconButton(onPressed: () { disposeAll(); Navigator.pop(context); }, icon: const Icon(Icons.close_rounded, color: _textMid)),
              ]),
            ),
            // Body
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _pmSectionLabel('ຂໍ້ມູນສິນຄ້າ', 'Product Info'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(flex: 2, child: _buildFormField(label: 'ຊື່ສິນຄ້າ (English) *', controller: nameCtrl, icon: Icons.shopping_bag_rounded, validator: (v) => v==null||v.isEmpty?'ກະລຸນາປ້ອນຊື່':null)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildFormField(label: 'ຊື່ສິນຄ້າ (ລາວ)', controller: nameLaCtrl, icon: Icons.translate_rounded)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _buildFormField(label: 'ລະຫັດສິນຄ້າ *', controller: codeCtrl, icon: Icons.tag_rounded, validator: (v) => v==null||v.isEmpty?'ກະລຸນາປ້ອນລະຫັດ':null)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFormField(label: 'ບາໂຄ້ດ (Barcode)', controller: barcodeCtrl, icon: Icons.qr_code_rounded)),
                ]),
                const SizedBox(height: 14),
                _buildFormField(label: 'ລາຍລະອຽດ (Description)', controller: descCtrl, icon: Icons.notes_rounded),
                const SizedBox(height: 22),

                _pmSectionLabel('ຈັດປະເພດ', 'Classification'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _pmDropdown<int>(label: 'ໝວດໝູ່ (Category)', icon: Icons.category_rounded, value: selCatId, hint: 'ເລືອກໝວດ',
                    items: _categories.map((c) => DropdownMenuItem<int>(value: c['category_id']??c['id'], child: Text('${c['category_name_la']??c['category_name']??'-'}', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setDS(() => selCatId = v))),
                  const SizedBox(width: 14),
                  Expanded(child: _pmDropdown<int>(label: 'ຍີ່ຫໍ້ (Brand)', icon: Icons.branding_watermark_rounded, value: selBrandId, hint: 'ເລືອກຍີ່ຫໍ້',
                    items: _brands.map((b) => DropdownMenuItem<int>(value: b['brand_id']??b['id'], child: Text('${b['brand_name_la']??b['brand_name']??'-'}', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setDS(() => selBrandId = v))),
                  const SizedBox(width: 14),
                  Expanded(child: _pmDropdown<int>(label: 'ຫົວໜ່ວຍ (Unit)', icon: Icons.straighten_rounded, value: selUnitId, hint: 'ເລືອກຫົວໜ່ວຍ',
                    items: _units.map((u) => DropdownMenuItem<int>(value: u['unit_id']??u['id'], child: Text('${u['unit_name']??u['name']??'-'}${(u['unit_short']??u['abbreviation']??'').toString().isNotEmpty?" (${u['unit_short']??u['abbreviation']})":""}', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setDS(() => selUnitId = v))),
                ]),
                const SizedBox(height: 22),

                _pmSectionLabel('ລາຄາ', 'Pricing'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _buildFormField(label: 'ລາຄາຊື້ (Cost) *',         controller: costCtrl,      icon: Icons.money_rounded,         keyboardType: TextInputType.number, validator: (v) => v==null||v.isEmpty?'ກະລຸນາປ້ອນ':null)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildFormField(label: 'ລາຄາຂາຍ (Sell) *',         controller: sellCtrl,      icon: Icons.sell_rounded,           keyboardType: TextInputType.number, validator: (v) => v==null||v.isEmpty?'ກະລຸນາປ້ອນ':null)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildFormField(label: 'ລາຄາສົ່ງ (Wholesale)',      controller: wholesaleCtrl, icon: Icons.local_shipping_rounded,  keyboardType: TextInputType.number)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildFormField(label: 'ລາຄາຕໍ່າສຸດ (Min Price)',   controller: minPriceCtrl,  icon: Icons.price_change_rounded,    keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 22),

                _pmSectionLabel('ຈັດການສາງ', 'Stock Management'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _buildFormField(label: 'ສາງເລີ່ມຕົ້ນ (Stock)', controller: stockCtrl,    icon: Icons.inventory_rounded,      keyboardType: TextInputType.number)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildFormField(label: 'ສາງຕໍ່າສຸດ (Min)',     controller: minStockCtrl, icon: Icons.trending_down_rounded,   keyboardType: TextInputType.number)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildFormField(label: 'ສາງສູງສຸດ (Max)',      controller: maxStockCtrl, icon: Icons.trending_up_rounded,     keyboardType: TextInputType.number)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildStatusToggle(isActive, (v) => setDS(() => isActive = v))),
                ]),
              ])),
            )),
            // Footer
            _buildDialogFooter(
              onCancel: () { disposeAll(); Navigator.pop(context); },
              saveLabel: isEdit ? 'ບັນທຶກການປ່ຽນແປງ' : 'ເພີ່ມສິນຄ້າ',
              onSave: () async {
                if (formKey.currentState!.validate()) {
                  final body = {
                    'product_name': nameCtrl.text.trim(), 'product_name_la': nameLaCtrl.text.trim(),
                    'product_code': codeCtrl.text.trim(), 'barcode': barcodeCtrl.text.trim(),
                    'description': descCtrl.text.trim(), 'category_id': selCatId, 'brand_id': selBrandId, 'unit_id': selUnitId,
                    'cost_price': double.tryParse(costCtrl.text) ?? 0, 'selling_price': double.tryParse(sellCtrl.text) ?? 0,
                    'sell_price': double.tryParse(sellCtrl.text) ?? 0, 'wholesale_price': double.tryParse(wholesaleCtrl.text) ?? 0,
                    'min_price': double.tryParse(minPriceCtrl.text) ?? 0, 'stock': int.tryParse(stockCtrl.text) ?? 0,
                    'current_stock': int.tryParse(stockCtrl.text) ?? 0, 'min_stock': int.tryParse(minStockCtrl.text) ?? 0,
                    'max_stock': int.tryParse(maxStockCtrl.text) ?? 0, 'is_active': isActive,
                  };
                  try {
                    final response = isEdit
                        ? await ApiService.updateProduct(product!['id'] ?? product['product_id'], body)
                        : await ApiService.createProduct(body);
                    if (response['responseCode'] == '00') {
                      disposeAll(); Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${isEdit?"ອັບເດດ":"ເພີ່ມ"}ສິນຄ້າ ${nameCtrl.text} ສຳເລັດ'), backgroundColor: _success));
                      _fetchProducts();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger));
                    }
                  } catch (e) {
                    disposeAll(); Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການເຊື່ອມຕໍ່'), backgroundColor: _danger));
                  }
                }
              },
            ),
          ]),
        ),
      )),
    );
  }

  Widget _pmSectionLabel(String la, String en) {
    return Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_primaryHi, _primaryGlow]), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(la, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textHi)),
      const SizedBox(width: 8),
      Text(en, style: const TextStyle(fontSize: 11, color: _textMid)),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: _border, height: 1)),
    ]);
  }

  Widget _pmDropdown<T>({required String label, required IconData icon, required T? value, required String hint, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMid)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_card, Color(0xFF0A1A30)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: _border, width: 1)),
        child: DropdownButtonFormField<T>(
          value: value, dropdownColor: const Color(0xFF0D1F3C), isExpanded: true,
          decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), prefixIcon: Icon(icon, color: _primaryHi)),
          style: const TextStyle(color: _textHi, fontSize: 14),
          hint: Text(hint, style: TextStyle(color: _textLo.withOpacity(0.6))),
          items: items, onChanged: onChanged,
        ),
      ),
    ]);
  }

  int? _toId(dynamic v) { if (v == null) return null; if (v is int) return v; return int.tryParse(v.toString()); }

  void _showDeleteProductConfirmation(Map<String, dynamic> product) {
    final productId = product['id'] ?? product['product_id'];
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF0D1F3C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _danger.withOpacity(0.35), width: 1)),
      title: const Text('ລຶບສິນຄ້າ', style: TextStyle(color: _textHi, fontWeight: FontWeight.w800)),
      content: Text('ທ່ານຕ້ອງການລຶບ ${product['product_name']} ແທ້ບໍ່?\n\nການລຶບຈະບໍ່ສາມາດຍົກເລີກໄດ້.', style: const TextStyle(color: _textMid)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ຍົກເລີກ', style: TextStyle(color: _textMid))),
        ElevatedButton(
          onPressed: () async {
            try {
              final response = await ApiService.deleteProduct(productId);
              Navigator.pop(context);
              if (response['responseCode'] == '00') { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ລຶບ ${product['product_name']} ສຳເລັດ'), backgroundColor: _success)); _fetchProducts(); }
              else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger)); }
            } catch (e) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger)); }
          },
          style: ElevatedButton.styleFrom(backgroundColor: _danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('ລຶບ'),
        ),
      ],
    ));
  }

  Future<void> _batchDelete() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF0D1F3C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _danger.withOpacity(0.35), width: 1)),
      title: const Text('ລຶບສິນຄ້າທີ່ເລືອກ', style: TextStyle(color: _textHi, fontWeight: FontWeight.w800)),
      content: Text('ທ່ານຕ້ອງການລຶບ ${_selectedProducts.length} ລາຍການ ແທ້ບໍ່?', style: const TextStyle(color: _textMid)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ຍົກເລີກ', style: TextStyle(color: _textMid))),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: _danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('ລຶບ')),
      ],
    ));
    if (confirmed == true) {
      try {
        for (final id in _selectedProducts) await ApiService.deleteProduct(id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ລຶບ ${_selectedProducts.length} ລາຍການ ສຳເລັດ'), backgroundColor: _success));
        _clearSelection(); _fetchProducts();
      } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ: $e'), backgroundColor: _danger)); }
    }
  }

  // ── Categories / Brands / Units tabs ────────────
  Widget _buildCategoriesTab() {
    return Container(
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_card, Color(0xFF0A1A30)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: _border, width: 1)),
      child: Column(children: [
        _buildSimpleTableHeader(['#', 'ຊື່ (English)', 'ຊື່ (ລາວ)', 'ສະຖານະ', 'ຈັດການ']),
        Expanded(child: _categories.isEmpty ? _buildEmptyState(Icons.category_outlined, 'ບໍ່ມີໝວດໝູ່', 'No categories found')
            : ListView.builder(padding: const EdgeInsets.all(8), itemCount: _categories.length, itemBuilder: (ctx, i) {
                final c = _categories[i];
                return _buildSimpleRow(index: i, cells: ['${i+1}', c['category_name']??'', c['category_name_la']??'', c['is_active']==1?'Active':'Inactive'],
                    onEdit: () => _showCategoryForm(category: c), onDelete: () => _deleteItem('categories', c['category_id']??c['id'], c['category_name']??''));
              })),
      ]),
    );
  }

  Widget _buildBrandsTab() {
    return Container(
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_card, Color(0xFF0A1A30)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: _border, width: 1)),
      child: Column(children: [
        _buildSimpleTableHeader(['#', 'ຊື່ (English)', 'ຊື່ (ລາວ)', 'ລາຍລະອຽດ', 'ຈັດການ']),
        Expanded(child: _brands.isEmpty ? _buildEmptyState(Icons.branding_watermark_outlined, 'ບໍ່ມີຍີ່ຫໍ້', 'No brands found')
            : ListView.builder(padding: const EdgeInsets.all(8), itemCount: _brands.length, itemBuilder: (ctx, i) {
                final b = _brands[i];
                return _buildSimpleRow(index: i, cells: ['${i+1}', b['brand_name']??'', b['brand_name_la']??'', b['description']??'-'],
                    onEdit: () => _showBrandForm(brand: b), onDelete: () => _deleteItem('brands', b['brand_id']??b['id'], b['brand_name']??''));
              })),
      ]),
    );
  }

  Widget _buildUnitsTab() {
    return Container(
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_card, Color(0xFF0A1A30)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: _border, width: 1)),
      child: Column(children: [
        _buildSimpleTableHeader(['#', 'ຊື່ (English)', 'ຊື່ (ລາວ)', 'ຕົວຫຍໍ້', 'ຈັດການ']),
        Expanded(child: _units.isEmpty ? _buildEmptyState(Icons.straighten_outlined, 'ບໍ່ມີຫົວໜ່ວຍ', 'No units found')
            : ListView.builder(padding: const EdgeInsets.all(8), itemCount: _units.length, itemBuilder: (ctx, i) {
                final u = _units[i];
                return _buildSimpleRow(index: i, cells: ['${i+1}', u['unit_name']??'', u['unit_name_la']??'', u['abbreviation']??'-'],
                    onEdit: () => _showUnitForm(unit: u), onDelete: () => _deleteItem('units', u['unit_id']??u['id'], u['unit_name']??''));
              })),
      ]),
    );
  }

  Widget _buildSimpleTableHeader(List<String> headers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x1A3B82F6), Color(0x0A1D4ED8)]), borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18))),
      child: Row(children: headers.map((h) => Expanded(flex: h=='#'?1:(h=='ຈັດການ'?1:2), child: Text(h, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMid, letterSpacing: 0.5)))).toList()),
    );
  }

  Widget _buildSimpleRow({required int index, required List<String> cells, required VoidCallback onEdit, required VoidCallback onDelete}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Transform.translate(offset: Offset(0, 20*(1-value)), child: Opacity(opacity: value, child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardAlt, Color(0xFF0A1A30)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: _border.withOpacity(0.6), width: 1)),
        child: Row(children: [
          ...cells.asMap().entries.map((e) => Expanded(flex: e.key==0?1:2, child: Text(e.value, style: TextStyle(fontSize: 13, color: e.key==0?_textMid:_textHi, fontWeight: e.key==1?FontWeight.w700:FontWeight.w500), overflow: TextOverflow.ellipsis))),
          Expanded(flex: 1, child: Row(children: [_buildActionButton(Icons.edit_rounded, _primaryHi, onEdit), const SizedBox(width: 8), _buildActionButton(Icons.delete_rounded, _danger, onDelete)])),
        ]),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(gradient: LinearGradient(colors: [_primaryHi.withOpacity(0.08), _primary.withOpacity(0.04)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: _border, width: 1)), child: Icon(icon, size: 64, color: _primaryHi)),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textHi)),
      const SizedBox(height: 8),
      Text(subtitle, style: TextStyle(fontSize: 14, color: _textLo.withOpacity(0.7))),
    ]));
  }

  // ── Category / Brand / Unit forms ────────────────
  void _showCategoryForm({Map<String, dynamic>? category}) {
    final isEdit = category != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl   = TextEditingController(text: category?['category_name']    ?? '');
    final nameLaCtrl = TextEditingController(text: category?['category_name_la'] ?? '');
    final iconCtrl   = TextEditingController(text: category?['icon']             ?? '');
    showDialog(context: context, barrierDismissible: false, builder: (context) => Dialog(backgroundColor: Colors.transparent, child: Container(width: 500,
      decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D1F3C), Color(0xFF050A14)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: _border, width: 1), boxShadow: [BoxShadow(color: _primary.withOpacity(0.2), blurRadius: 28, offset: const Offset(0, 10))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildDialogHeader(isEdit?'ແກ້ໄຂໝວດໝູ່':'ເພີ່ມໝວດໝູ່ໃໝ່', isEdit?'Edit Category':'Add Category', Icons.category_rounded, () => Navigator.pop(context)),
        Padding(padding: const EdgeInsets.all(24), child: Form(key: formKey, child: Column(children: [
          _buildFormField(label: 'ຊື່ໝວດໝູ່ (English)', controller: nameCtrl, icon: Icons.category_rounded, validator: (v) => v==null||v.isEmpty?'ກະລຸນາປ້ອນຊື່':null),
          const SizedBox(height: 16),
          _buildFormField(label: 'ຊື່ໝວດໝູ່ (ລາວ)', controller: nameLaCtrl, icon: Icons.translate_rounded),
          const SizedBox(height: 16),
          _buildFormField(label: 'Icon Name', controller: iconCtrl, icon: Icons.emoji_symbols_rounded),
        ]))),
        _buildDialogFooter(onCancel: () => Navigator.pop(context), saveLabel: isEdit?'ບັນທຶກການປ່ຽນແປງ':'ບັນທຶກ', onSave: () async {
          if (formKey.currentState!.validate()) {
            try {
              final r = isEdit ? await ApiService.updateCategory(category!['id']??category['category_id'], {'category_name':nameCtrl.text,'category_name_la':nameLaCtrl.text,'icon':iconCtrl.text}) : await ApiService.createCategory({'category_name':nameCtrl.text,'category_name_la':nameLaCtrl.text,'icon':iconCtrl.text});
              Navigator.pop(context);
              if (r['responseCode']=='00') { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${isEdit?"ອັບເດດ":"ເພີ່ມ"}ໝວດໝູ່ສຳເລັດ'), backgroundColor: _success)); _fetchCategories(); }
              else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['message']??'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger)); }
            } catch (e) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger)); }
          }
        }),
      ]),
    )));
  }

  void _showBrandForm({Map<String, dynamic>? brand}) {
    final isEdit = brand != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: brand?['brand_name']    ?? '');
    final nameLaCtrl = TextEditingController(text: brand?['brand_name_la'] ?? '');
    final descCtrl = TextEditingController(text: brand?['description']   ?? '');
    showDialog(context: context, barrierDismissible: false, builder: (context) => Dialog(backgroundColor: Colors.transparent, child: Container(width: 500,
      decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D1F3C), Color(0xFF050A14)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: _border, width: 1), boxShadow: [BoxShadow(color: _primary.withOpacity(0.2), blurRadius: 28, offset: const Offset(0, 10))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildDialogHeader(isEdit?'ແກ້ໄຂຍີ່ຫໍ້':'ເພີ່ມຍີ່ຫໍ້ໃໝ່', isEdit?'Edit Brand':'Add Brand', Icons.branding_watermark_rounded, () => Navigator.pop(context)),
        Padding(padding: const EdgeInsets.all(24), child: Form(key: formKey, child: Column(children: [
          _buildFormField(label: 'ຊື່ຍີ່ຫໍ້ (English)', controller: nameCtrl, icon: Icons.branding_watermark_rounded, validator: (v) => v==null||v.isEmpty?'ກະລຸນາປ້ອນຊື່':null),
          const SizedBox(height: 16),
          _buildFormField(label: 'ຊື່ຍີ່ຫໍ້ (ລາວ)', controller: nameLaCtrl, icon: Icons.translate_rounded),
          const SizedBox(height: 16),
          _buildFormField(label: 'ລາຍລະອຽດ (Description)', controller: descCtrl, icon: Icons.description_rounded),
        ]))),
        _buildDialogFooter(onCancel: () => Navigator.pop(context), saveLabel: isEdit?'ບັນທຶກການປ່ຽນແປງ':'ບັນທຶກ', onSave: () async {
          if (formKey.currentState!.validate()) {
            try {
              final r = isEdit ? await ApiService.updateBrand(brand!['id']??brand['brand_id'], {'brand_name':nameCtrl.text,'brand_name_la':nameLaCtrl.text,'description':descCtrl.text}) : await ApiService.createBrand({'brand_name':nameCtrl.text,'brand_name_la':nameLaCtrl.text,'description':descCtrl.text});
              Navigator.pop(context);
              if (r['responseCode']=='00') { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${isEdit?"ອັບເດດ":"ເພີ່ມ"}ຍີ່ຫໍ້ສຳເລັດ'), backgroundColor: _success)); _fetchBrands(); }
              else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['message']??'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger)); }
            } catch (e) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger)); }
          }
        }),
      ]),
    )));
  }

  void _showUnitForm({Map<String, dynamic>? unit}) {
    final isEdit = unit != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl   = TextEditingController(text: unit?['unit_name']    ?? '');
    final nameLaCtrl = TextEditingController(text: unit?['unit_name_la'] ?? '');
    final abbrCtrl   = TextEditingController(text: unit?['abbreviation'] ?? '');
    showDialog(context: context, barrierDismissible: false, builder: (context) => Dialog(backgroundColor: Colors.transparent, child: Container(width: 500,
      decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D1F3C), Color(0xFF050A14)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: _border, width: 1), boxShadow: [BoxShadow(color: _primary.withOpacity(0.2), blurRadius: 28, offset: const Offset(0, 10))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildDialogHeader(isEdit?'ແກ້ໄຂຫົວໜ່ວຍ':'ເພີ່ມຫົວໜ່ວຍໃໝ່', isEdit?'Edit Unit':'Add Unit', Icons.straighten_rounded, () => Navigator.pop(context)),
        Padding(padding: const EdgeInsets.all(24), child: Form(key: formKey, child: Column(children: [
          _buildFormField(label: 'ຊື່ຫົວໜ່ວຍ (English)', controller: nameCtrl, icon: Icons.straighten_rounded, validator: (v) => v==null||v.isEmpty?'ກະລຸນາປ້ອນຊື່':null),
          const SizedBox(height: 16),
          _buildFormField(label: 'ຊື່ຫົວໜ່ວຍ (ລາວ)', controller: nameLaCtrl, icon: Icons.translate_rounded),
          const SizedBox(height: 16),
          _buildFormField(label: 'ຕົວຫຍໍ້ (Abbreviation)', controller: abbrCtrl, icon: Icons.short_text_rounded),
        ]))),
        _buildDialogFooter(onCancel: () => Navigator.pop(context), saveLabel: isEdit?'ບັນທຶກການປ່ຽນແປງ':'ບັນທຶກ', onSave: () async {
          if (formKey.currentState!.validate()) {
            try {
              final r = isEdit ? await ApiService.updateUnit(unit!['id']??unit['unit_id'], {'unit_name':nameCtrl.text,'unit_name_la':nameLaCtrl.text,'abbreviation':abbrCtrl.text}) : await ApiService.createUnit({'unit_name':nameCtrl.text,'unit_name_la':nameLaCtrl.text,'abbreviation':abbrCtrl.text});
              Navigator.pop(context);
              if (r['responseCode']=='00') { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${isEdit?"ອັບເດດ":"ເພີ່ມ"}ຫົວໜ່ວຍສຳເລັດ'), backgroundColor: _success)); _fetchUnits(); }
              else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['message']??'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger)); }
            } catch (e) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger)); }
          }
        }),
      ]),
    )));
  }

  Future<void> _deleteItem(String type, dynamic id, String name) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF0D1F3C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _danger.withOpacity(0.35), width: 1)),
      title: Text('ລຶບ $name', style: const TextStyle(color: _textHi, fontWeight: FontWeight.w800)),
      content: Text('ທ່ານຕ້ອງການລຶບ $name ແທ້ບໍ່?', style: const TextStyle(color: _textMid)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ຍົກເລີກ', style: TextStyle(color: _textMid))),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: _danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('ລຶບ')),
      ],
    ));
    if (confirmed == true) {
      try {
        Map<String, dynamic> r;
        switch (type) { case 'categories': r = await ApiService.deleteCategory(id); break; case 'brands': r = await ApiService.deleteBrand(id); break; case 'units': r = await ApiService.deleteUnit(id); break; default: return; }
        if (r['responseCode']=='00') { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ລຶບ $name ສຳເລັດ'), backgroundColor: _success)); _fetchAllData(); }
        else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['message']??'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger)); }
      } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'), backgroundColor: _danger)); }
    }
  }

  // ── Shared dialog widgets ────────────────────────
  Widget _buildDialogHeader(String title, String subtitle, IconData icon, VoidCallback onClose) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x1A3B82F6), Colors.transparent]), borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: _gradPrimary, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: _primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]), child: Icon(icon, color: Colors.white, size: 24)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textHi)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: _textMid)),
        ])),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: _textMid)),
      ]),
    );
  }

  Widget _buildFormField({required String label, required TextEditingController controller, required IconData icon, String? Function(String?)? validator, TextInputType? keyboardType, bool enabled = true}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMid)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: enabled ? [_card, const Color(0xFF0A1A30)] : [const Color(0xFF081420), const Color(0xFF060E1A)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: enabled ? _border : _border.withOpacity(0.4), width: 1),
        ),
        child: TextFormField(
          controller: controller, keyboardType: keyboardType, enabled: enabled,
          style: TextStyle(color: enabled ? _textHi : _textLo),
          decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), prefixIcon: Icon(icon, color: enabled ? _primaryHi : _textLo)),
          validator: validator,
        ),
      ),
    ]);
  }

  Widget _buildStatusToggle(bool isActive, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_card, Color(0xFF0A1A30)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: _border, width: 1)),
      child: Row(children: [
        const Icon(Icons.toggle_on_rounded, color: _primaryHi),
        const SizedBox(width: 12),
        const Expanded(child: Text('ສະຖານະ (Status)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textMid))),
        Switch(value: isActive, onChanged: onChanged, activeColor: _success),
        Text(isActive ? 'ເປີດໃຊ້' : 'ປິດໃຊ້', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? _success : _danger)),
      ]),
    );
  }

  Widget _buildDialogFooter({required VoidCallback onCancel, required VoidCallback onSave, required String saveLabel}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _border, width: 1))),
      child: Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: _border, width: 1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('ຍົກເລີກ', style: TextStyle(color: _textMid, fontSize: 14, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: Container(
          height: 48,
          decoration: BoxDecoration(gradient: _gradPrimary, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: _primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(saveLabel, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        )),
      ]),
    );
  }
}