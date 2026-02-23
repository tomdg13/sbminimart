// lib/pages/stock/stock_page.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

// ─── LOCAL BLUE PALETTE ───────────────────────────────────────────────────────
const _blue1 = Color(0xFF1D4ED8);
const _blue2 = Color(0xFF2563EB);
const _blue3 = Color(0xFF3B82F6);
const _blue4 = Color(0xFF60A5FA);
const _bgDeep    = Color(0xFF020817);
const _bgCard    = Color(0xFF0D2045);
const _bgDarker  = Color(0xFF071022);
const _surface   = Color(0xFF0F2A4A);
const _textPrimary   = Color(0xFFE2E8F0);
const _textSecondary = Color(0xFF94A3B8);
// ─────────────────────────────────────────────────────────────────────────────

// Sort options
enum _SortOrder { none, asc, desc }

class StockPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const StockPage({super.key, required this.currentUser});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading       = false;
  String _stockFilter   = 'all';
  String _searchKeyword = '';
  _SortOrder _sortOrder = _SortOrder.none; // ← sort state

  late AnimationController _animationController;

  final List<Map<String, dynamic>> _products   = [];
  final List<Map<String, dynamic>> _categories = [];

  final TextEditingController _searchCtrl = TextEditingController();
  int? _selectedCategoryId;

  String get _me => widget.currentUser['username']?.toString() ?? 'unknown';

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

  // ── FETCH ─────────────────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.wait([_fetchProducts(), _fetchCategories()]);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _fetchProducts() async {
    try {
      final data = await ApiService.getProducts();
      if (!mounted) return;
      setState(() {
        _products.clear();
        _products.addAll(data.cast<Map<String, dynamic>>());
      });
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await ApiService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories.clear();
        _categories.addAll(data.cast<Map<String, dynamic>>());
      });
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  // ── FILTER + SORT ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredProducts {
    var list = List<Map<String, dynamic>>.from(_products);

    if (_selectedCategoryId != null) {
      list = list
          .where((p) =>
              (p['category_id'] ?? p['categoryId']) == _selectedCategoryId)
          .toList();
    }

    if (_stockFilter != 'all') {
      list = list.where((p) {
        final stock   = _getStock(p);
        final reorder = _getReorder(p);
        switch (_stockFilter) {
          case 'out':      return stock == 0;
          case 'low':      return stock > 0 && stock <= reorder;
          case 'in_stock': return stock > reorder;
          default:         return true;
        }
      }).toList();
    }

    if (_searchKeyword.isNotEmpty) {
      final kw = _searchKeyword.toLowerCase();
      list = list.where((p) =>
          (p['product_name'] ?? '').toString().toLowerCase().contains(kw) ||
          (p['product_code'] ?? '').toString().toLowerCase().contains(kw) ||
          (p['barcode']      ?? '').toString().toLowerCase().contains(kw),
      ).toList();
    }

    // ── Sort by stock amount ──
    if (_sortOrder == _SortOrder.asc) {
      list.sort((a, b) => _getStock(a).compareTo(_getStock(b)));
    } else if (_sortOrder == _SortOrder.desc) {
      list.sort((a, b) => _getStock(b).compareTo(_getStock(a)));
    }

    return list;
  }

  // ── cycle sort: none → asc → desc → none ──────────────────────────────────
  void _cycleSort() {
    setState(() {
      switch (_sortOrder) {
        case _SortOrder.none: _sortOrder = _SortOrder.asc;  break;
        case _SortOrder.asc:  _sortOrder = _SortOrder.desc; break;
        case _SortOrder.desc: _sortOrder = _SortOrder.none; break;
      }
    });
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  int _getStock(Map<String, dynamic> p) =>
      double.tryParse((p['current_stock'] ?? p['stock'] ?? '0').toString())
          ?.round() ?? 0;

  int _getReorder(Map<String, dynamic> p) =>
      int.tryParse((p['reorder_point'] ?? p['reorder'] ?? '10').toString()) ?? 10;

  String _stockStatus(Map<String, dynamic> p) {
    final stock   = _getStock(p);
    final reorder = _getReorder(p);
    if (stock == 0)       return 'out';
    if (stock <= reorder) return 'low';
    return 'ok';
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '₭ 0';
    final num v = num.tryParse(value.toString()) ?? 0;
    return '₭ ${v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  int get _totalCount   => _products.length;
  int get _inStockCount => _products.where((p) => _stockStatus(p) == 'ok').length;
  int get _lowCount     => _products.where((p) => _stockStatus(p) == 'low').length;
  int get _outCount     => _products.where((p) => _stockStatus(p) == 'out').length;

  // ── BUILD ─────────────────────────────────────────────────────────────────
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
              titleLa: 'ສາງສິນຄ້າ',
              titleEn: 'Stock',
              actions: [
                StockRefreshButton(isLoading: _isLoading, onTap: _fetchAll),
                const SizedBox(width: 12),
                StockPrimaryButton(
                  icon: Icons.add_box_rounded,
                  label: 'ເພີ່ມສາງ',
                  onTap: () => _showAdjustStockDialog(null, initialType: 'in'),
                ),
                const SizedBox(width: 12),
                StockPrimaryButton(
                  icon: Icons.add_rounded,
                  label: 'ເພີ່ມສິນຄ້າ',
                  onTap: () => _showProductForm(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStats(),
            const SizedBox(height: 20),
            _buildFiltersRow(),
            const SizedBox(height: 20),
            Expanded(child: _buildProductGrid()),
          ],
        ),
      ),
    );
  }

  // ── STATS ─────────────────────────────────────────────────────────────────
  Widget _buildStats() {
    return Row(children: [
      Expanded(child: _BlueStat(label: 'ສິນຄ້າທັງໝົດ', value: '$_totalCount',  icon: Icons.inventory_2_rounded,    color: _blue3)),
      const SizedBox(width: 16),
      Expanded(child: _BlueStat(label: 'ສາງປົກກະຕິ',   value: '$_inStockCount', icon: Icons.check_circle_rounded,   color: StockTheme.success)),
      const SizedBox(width: 16),
      Expanded(child: _BlueStat(label: 'ໃກ້ໝົດ',        value: '$_lowCount',     icon: Icons.warning_amber_rounded,  color: StockTheme.warning)),
      const SizedBox(width: 16),
      Expanded(child: _BlueStat(label: 'ໝົດສາງ',        value: '$_outCount',     icon: Icons.remove_circle_rounded,  color: StockTheme.error)),
    ]);
  }

  // ── FILTERS ROW ───────────────────────────────────────────────────────────
  Widget _buildFiltersRow() {
    final stockFilters = [
      {'value': 'all',      'label': 'ທັງໝົດ'},
      {'value': 'in_stock', 'label': 'ປົກກະຕິ'},
      {'value': 'low',      'label': 'ໃກ້ໝົດ'},
      {'value': 'out',      'label': 'ໝົດສາງ'},
    ];

    // sort button label & icon
    final sortIcon = _sortOrder == _SortOrder.asc
        ? Icons.arrow_upward_rounded
        : _sortOrder == _SortOrder.desc
            ? Icons.arrow_downward_rounded
            : Icons.sort_rounded;
    final sortLabel = _sortOrder == _SortOrder.asc
        ? 'ສາງ ↑'
        : _sortOrder == _SortOrder.desc
            ? 'ສາງ ↓'
            : 'ຮຽງສາງ';
    final sortActive = _sortOrder != _SortOrder.none;

    return Row(children: [
      // Status filter chips
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            ...stockFilters.map((f) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _BlueFilterChip(
                label: f['label']!,
                selected: _stockFilter == f['value'],
                onTap: () => setState(() => _stockFilter = f['value']!),
              ),
            )),
          ]),
        ),
      ),
      const SizedBox(width: 12),

      // ── Sort button ──
      GestureDetector(
        onTap: _cycleSort,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: sortActive ? _blue2.withOpacity(0.15) : _surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sortActive ? _blue3.withOpacity(0.6) : _blue1.withOpacity(0.2),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(sortIcon, size: 15,
                color: sortActive ? _blue4 : _textSecondary),
            const SizedBox(width: 6),
            Text(sortLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: sortActive ? _blue4 : _textSecondary)),
          ]),
        ),
      ),
      const SizedBox(width: 12),

      // Search box
      SizedBox(
        width: 240,
        height: 40,
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: _textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'ຄົ້ນຫາ ຊື່ / ລະຫັດ / Barcode...',
            hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 18),
            filled: true,
            fillColor: _surface.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _blue1.withOpacity(0.2))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _blue1.withOpacity(0.18))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _blue3.withOpacity(0.5))),
          ),
          onChanged: (v) => setState(() => _searchKeyword = v),
        ),
      ),
    ]);
  }

  // ── PRODUCT GRID ──────────────────────────────────────────────────────────
  Widget _buildProductGrid() {
    final products = _filteredProducts;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _blue3));
    }
    if (products.isEmpty) {
      return const StockEmptyState(
        icon: Icons.inventory_2_outlined,
        titleLa: 'ບໍ່ພົບສິນຄ້າ',
        titleEn: 'No products found',
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 280,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 40).clamp(0, 1000)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Opacity(opacity: value, child: child),
          ),
          child: _buildProductCard(p),
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final status  = _stockStatus(p);
    final stock   = _getStock(p);
    final reorder = _getReorder(p);
    final maxStock = (reorder * 5).clamp(reorder + 1, 9999);
    final barPct  = (stock / maxStock).clamp(0.0, 1.0);

    final statusColor = status == 'out'
        ? StockTheme.error
        : status == 'low' ? StockTheme.warning : StockTheme.success;

    final statusLabel = status == 'out' ? 'ໝົດສາງ'
        : status == 'low' ? 'ໃກ້ໝົດ' : 'ປົກກະຕິ';

    final borderColor = status == 'out'
        ? StockTheme.error.withOpacity(0.3)
        : status == 'low'
            ? StockTheme.warning.withOpacity(0.3)
            : _blue1.withOpacity(0.12);

    final categoryName = p['category_name'] ?? p['category'] ?? '-';
    final brandName    = p['brand_name']    ?? p['brand']    ?? '-';
    final unitName     = p['unit_name']     ?? p['unit']     ?? '-';
    final costPrice    = p['cost_price']    ?? p['cost']     ?? 0;
    final sellPrice    = p['selling_price'] ?? p['sale_price'] ?? p['sell_price'] ?? p['price'] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _viewProductDetails(p),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _bgCard.withOpacity(0.8),
                _surface.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── IMAGE AREA ──
              Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _bgDarker.withOpacity(0.6),
                      _blue1.withOpacity(0.04),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Stack(children: [
                  Center(
                    child: Icon(Icons.inventory_2_rounded,
                        size: 38, color: _blue2.withOpacity(0.18)),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: statusColor)),
                    ),
                  ),
                  // sort badge: show rank number when sorted
                  if (_sortOrder != _SortOrder.none)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _blue2.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _blue3.withOpacity(0.35)),
                        ),
                        child: Text(
                          '# ${_filteredProducts.indexOf(p) + 1}',
                          style: const TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w800, color: _blue4),
                        ),
                      ),
                    ),
                ]),
              ),
              // ── BODY ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['product_code'] ?? '-'}  ·  ${p['barcode'] ?? ''}',
                        style: TextStyle(
                            fontSize: 10,
                            color: _textSecondary.withOpacity(0.5),
                            fontFamily: 'monospace'),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(p['product_name'] ?? '-',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4, runSpacing: 4,
                        children: [
                          _metaChip(Icons.category_rounded,   categoryName),
                          _metaChip(Icons.star_rounded,        brandName),
                          _metaChip(Icons.straighten_rounded,  unitName),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ສາງ',
                              style: TextStyle(
                                  fontSize: 10, color: _textSecondary.withOpacity(0.6))),
                          // highlight stock number when sorted
                          Container(
                            padding: _sortOrder != _SortOrder.none
                                ? const EdgeInsets.symmetric(horizontal: 7, vertical: 2)
                                : EdgeInsets.zero,
                            decoration: _sortOrder != _SortOrder.none
                                ? BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statusColor.withOpacity(0.3)),
                                  )
                                : null,
                            child: Text('$stock $unitName',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: barPct,
                          minHeight: 4,
                          backgroundColor: _bgDarker.withOpacity(0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const Spacer(),
                      Divider(color: _blue1.withOpacity(0.12), height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ທຶນ',
                                  style: TextStyle(
                                      fontSize: 9, color: _textSecondary.withOpacity(0.5))),
                              Text(_formatCurrency(costPrice),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _textSecondary.withOpacity(0.8),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Text(_formatCurrency(sellPrice),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: StockTheme.success)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _bgDarker.withOpacity(0.5),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _blue1.withOpacity(0.12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 9, color: _textSecondary.withOpacity(0.5)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: _textSecondary.withOpacity(0.7),
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── VIEW DETAIL ───────────────────────────────────────────────────────────
  void _viewProductDetails(Map<String, dynamic> p) {
    final name   = p['product_name'] ?? '-';
    final status = _stockStatus(p);
    final stock  = _getStock(p);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 540),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              _bgCard.withOpacity(0.98),
              _surface.withOpacity(0.98),
            ]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _blue2.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(color: _blue2.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 12)),
            ],
          ),
          child: Column(children: [
            StockDialogHeader(
              titleLa: name,
              titleEn: 'Product Detail',
              icon: Icons.inventory_2_rounded,
              onClose: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _detailField('ລະຫັດ', p['product_code'] ?? '-'),
                      const SizedBox(width: 16),
                      _detailField('Barcode', p['barcode'] ?? '-'),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StockStatusBadge(
                          status: status == 'out' ? 'cancelled'
                              : status == 'low' ? 'pending' : 'completed',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _detailField('ໝວດ', p['category_name'] ?? p['category'] ?? '-'),
                      const SizedBox(width: 16),
                      _detailField('ຍີ່ຫໍ້', p['brand_name'] ?? p['brand'] ?? '-'),
                      const SizedBox(width: 16),
                      _detailField('ໜ່ວຍ', p['unit_name'] ?? p['unit'] ?? '-'),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _detailField('ລາຄາທຶນ', _formatCurrency(p['cost_price'] ?? p['cost'])),
                      const SizedBox(width: 16),
                      _detailField('ລາຄາຂາຍ', _formatCurrency(p['selling_price'] ?? p['sale_price'] ?? p['price'])),
                      const SizedBox(width: 16),
                      _detailField('Reorder', '${_getReorder(p)}'),
                    ]),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          _blue2.withOpacity(0.08),
                          _blue1.withOpacity(0.04),
                        ]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _blue2.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ສາງທີ່ມີ',
                              style: TextStyle(
                                  color: _textSecondary.withOpacity(0.8),
                                  fontWeight: FontWeight.w600)),
                          Text('$stock ${p['unit_name'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: StockTheme.success)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _blue1.withOpacity(0.12))),
              ),
              child: Row(children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ປິດ',
                      style: TextStyle(color: _textSecondary.withOpacity(0.6))),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAdjustStockDialog(p);
                  },
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('ປັບສາງ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StockTheme.warning,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showProductForm(product: p);
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('ແກ້ໄຂ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue2,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _detailField(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: _textSecondary.withOpacity(0.6),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, color: _textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── SELECT PRODUCT FOR STOCK ───────────────────────────────────────────────
  void _showSelectProductForStockDialog() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(_products);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 520),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _bgCard.withOpacity(0.97),
                  _bgDarker.withOpacity(0.98),
                ]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _blue2.withOpacity(0.2)),
              ),
              child: Column(children: [
                StockDialogHeader(
                  icon: Icons.add_box_rounded,
                  titleLa: 'ເພີ່ມສາງ',
                  titleEn: 'Select Product',
                  onClose: () => Navigator.pop(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: searchCtrl,
                    style: const TextStyle(color: _textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'ຄົ້ນຫາສິນຄ້າ...',
                      hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 18),
                      filled: true,
                      fillColor: _surface.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _blue1.withOpacity(0.2))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _blue1.withOpacity(0.18))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _blue3.withOpacity(0.5))),
                    ),
                    onChanged: (v) {
                      setDialogState(() {
                        final kw = v.toLowerCase();
                        filtered = _products.where((p) {
                          final name = (p['product_name'] ?? '').toLowerCase();
                          final code = (p['product_code'] ?? '').toLowerCase();
                          return name.contains(kw) || code.contains(kw);
                        }).toList();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text('ບໍ່ພົບສິນຄ້າ',
                          style: TextStyle(color: _textSecondary.withOpacity(0.5), fontSize: 13)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final p     = filtered[i];
                            final name  = p['product_name'] ?? '-';
                            final code  = p['product_code'] ?? '-';
                            final stock = _getStock(p);
                            final status = _stockStatus(p);
                            final sc = status == 'out' ? StockTheme.error
                                : status == 'low' ? StockTheme.warning : StockTheme.success;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _showAdjustStockDialog(p, initialType: 'in');
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _bgCard.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _blue1.withOpacity(0.1)),
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: StockTheme.success.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.inventory_2_rounded,
                                          size: 18, color: StockTheme.success),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: const TextStyle(
                                                  fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                          Text(code,
                                              style: TextStyle(fontSize: 11, color: _textSecondary.withOpacity(0.6)),
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: sc.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: sc.withOpacity(0.3)),
                                      ),
                                      child: Text('$stock',
                                          style: TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.w700, color: sc)),
                                    ),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── ADJUST STOCK DIALOG ───────────────────────────────────────────────────
  void _showAdjustStockDialog(Map<String, dynamic>? p, {String initialType = 'in'}) {
    if (p == null) { _showSelectProductForStockDialog(); return; }

    final qtyCtrl    = TextEditingController();
    final reasonCtrl = TextEditingController();
    String adjustType = initialType;
    final name    = p['product_name'] ?? '-';
    final current = _getStock(p);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 460,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _bgCard.withOpacity(0.98),
                  _surface.withOpacity(0.98),
                ]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _blue2.withOpacity(0.3), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StockDialogHeader(
                    titleLa: 'ປັບຈຳນວນສາງ',
                    titleEn: 'Stock Adjustment',
                    icon: Icons.tune_rounded,
                    onClose: () => Navigator.pop(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _surface.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _blue1.withOpacity(0.15)),
                          ),
                          child: Row(children: [
                            Icon(Icons.inventory_2_rounded, size: 20, color: _blue3),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary)),
                                  Text('ສາງປັດຈຸບັນ: $current',
                                      style: TextStyle(
                                          fontSize: 11, color: _textSecondary.withOpacity(0.6))),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => adjustType = 'in'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: adjustType == 'in'
                                      ? StockTheme.success.withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: adjustType == 'in'
                                        ? StockTheme.success.withOpacity(0.5)
                                        : _blue1.withOpacity(0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_circle_rounded, size: 16,
                                        color: adjustType == 'in' ? StockTheme.success : _textSecondary),
                                    const SizedBox(width: 6),
                                    Text('ເພີ່ມສາງ',
                                        style: TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w700,
                                            color: adjustType == 'in' ? StockTheme.success : _textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => adjustType = 'out'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: adjustType == 'out'
                                      ? StockTheme.error.withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: adjustType == 'out'
                                        ? StockTheme.error.withOpacity(0.5)
                                        : _blue1.withOpacity(0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.remove_circle_rounded, size: 16,
                                        color: adjustType == 'out' ? StockTheme.error : _textSecondary),
                                    const SizedBox(width: 6),
                                    Text('ຕັດສາງ',
                                        style: TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w700,
                                            color: adjustType == 'out' ? StockTheme.error : _textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        buildStockFormField(
                          label: 'ຈຳນວນ', controller: qtyCtrl,
                          icon: Icons.numbers_rounded, keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        buildStockFormField(
                          label: 'ເຫດຜົນ', controller: reasonCtrl, icon: Icons.notes_rounded,
                        ),
                      ],
                    ),
                  ),
                  StockDialogFooter(
                    onCancel: () => Navigator.pop(context),
                    saveLabel: 'ຢືນຢັນ',
                    onSave: () async {
                      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                      if (qty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('ກະລຸນາລະບຸຈຳນວນທີ່ຖືກຕ້ອງ'),
                              backgroundColor: StockTheme.warning));
                        return;
                      }
                      final productId = p['id'] ?? p['product_id'];
                      try {
                        final body = {
                          'type': adjustType, 'quantity': qty,
                          'reason': reasonCtrl.text, 'created_by': _me,
                        };
                        final res = await ApiService.adjustStock(productId, body);
                        Navigator.pop(context);
                        if (!mounted) return;
                        if (res['responseCode'] == '00') {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ປັບສາງສຳເລັດ'),
                                  backgroundColor: StockTheme.success));
                          _fetchProducts();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(res['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'),
                              backgroundColor: StockTheme.error));
                        }
                      } catch (_) {
                        Navigator.pop(context);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດ'),
                                backgroundColor: StockTheme.error));
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

  // ── PRODUCT FORM ──────────────────────────────────────────────────────────
  void _showProductForm({Map<String, dynamic>? product}) {
    final isEdit  = product != null;
    final formKey = GlobalKey<FormState>();

    // Controllers — mapped to full API field set
    final nameCtrl        = TextEditingController(text: product?['product_name']     ?? '');
    final nameLaCtrl      = TextEditingController(text: product?['product_name_la']  ?? '');
    final codeCtrl        = TextEditingController(text: product?['product_code']     ?? '');
    final barcodeCtrl     = TextEditingController(text: product?['barcode']          ?? '');
    final descCtrl        = TextEditingController(text: product?['description']      ?? '');
    final costCtrl        = TextEditingController(
        text: (product?['cost_price']      ?? '').toString());
    final priceCtrl       = TextEditingController(
        text: (product?['selling_price']   ?? product?['sale_price'] ?? product?['price'] ?? '').toString());
    final wholesaleCtrl   = TextEditingController(
        text: (product?['wholesale_price'] ?? '').toString());
    final minPriceCtrl    = TextEditingController(
        text: (product?['min_price']       ?? '0').toString());
    final stockCtrl       = TextEditingController(
        text: (product?['current_stock']   ?? '0').toString());
    final minStockCtrl    = TextEditingController(
        text: (product?['min_stock']       ?? product?['reorder_point'] ?? '0').toString());
    final maxStockCtrl    = TextEditingController(
        text: (product?['max_stock']       ?? '0').toString());
    final reorderCtrl     = TextEditingController(
        text: (product?['reorder_point']   ?? product?['min_stock'] ?? '10').toString());

    int? selectedCatId   = product?['category_id']   is int ? product!['category_id']   : int.tryParse(product?['category_id']?.toString() ?? '');
    int? selectedBrandId = product?['brand_id']      is int ? product!['brand_id']      : int.tryParse(product?['brand_id']?.toString()    ?? '');
    int? selectedUnitId  = product?['unit_id']       is int ? product!['unit_id']       : int.tryParse(product?['unit_id']?.toString()     ?? '');

    // Brands & Units — fetched from product list (unique values available)
    final brands = <Map<String, dynamic>>[];
    final units  = <Map<String, dynamic>>[];
    for (final p in _products) {
      final bid = p['brand_id']; final bn = p['brand_name'] ?? p['brand_name_la'] ?? '';
      if (bid != null && bn.isNotEmpty && !brands.any((b) => b['id'] == bid)) {
        brands.add({'id': bid, 'name': bn, 'name_la': p['brand_name_la'] ?? bn});
      }
      final uid = p['unit_id']; final un = p['unit_name'] ?? p['unit_short'] ?? '';
      if (uid != null && un.isNotEmpty && !units.any((u) => u['id'] == uid)) {
        units.add({'id': uid, 'name': un, 'short': p['unit_short'] ?? ''});
      }
    }
    // include current product's brand/unit if editing and not already in list
    if (isEdit) {
      final bid = product!['brand_id']; final bn = product['brand_name'] ?? '';
      if (bid != null && bn.isNotEmpty && !brands.any((b) => b['id'] == bid)) {
        brands.add({'id': bid, 'name': bn, 'name_la': product['brand_name_la'] ?? bn});
      }
      final uid = product['unit_id']; final un = product['unit_name'] ?? '';
      if (uid != null && un.isNotEmpty && !units.any((u) => u['id'] == uid)) {
        units.add({'id': uid, 'name': un, 'short': product['unit_short'] ?? ''});
      }
    }

    void disposeAll() {
      nameCtrl.dispose();   nameLaCtrl.dispose();  codeCtrl.dispose();
      barcodeCtrl.dispose(); descCtrl.dispose();
      costCtrl.dispose();   priceCtrl.dispose();   wholesaleCtrl.dispose();
      minPriceCtrl.dispose(); stockCtrl.dispose();
      minStockCtrl.dispose(); maxStockCtrl.dispose(); reorderCtrl.dispose();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 720,
              constraints: const BoxConstraints(maxHeight: 780),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _bgCard.withOpacity(0.98),
                  _surface.withOpacity(0.98),
                ]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _blue2.withOpacity(0.3), width: 1),
                boxShadow: [BoxShadow(color: _blue2.withOpacity(0.12), blurRadius: 32, offset: const Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StockDialogHeader(
                    titleLa: isEdit ? 'ແກ້ໄຂສິນຄ້າ' : 'ເພີ່ມສິນຄ້າໃໝ່',
                    titleEn: isEdit ? 'Edit Product' : 'New Product',
                    icon: Icons.inventory_2_rounded,
                    onClose: () { disposeAll(); Navigator.pop(context); },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ── Section: ຂໍ້ມູນພື້ນຖານ ──────────────────
                            _sectionLabel('ຂໍ້ມູນສິນຄ້າ', 'Product Info'),
                            const SizedBox(height: 10),

                            // Name EN + Name LA
                            Row(children: [
                              Expanded(flex: 2, child: buildStockFormField(
                                  label: 'ຊື່ສິນຄ້າ (EN) *', controller: nameCtrl,
                                  icon: Icons.label_rounded,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'ກະລຸນາລະບຸຊື່' : null)),
                              const SizedBox(width: 14),
                              Expanded(flex: 2, child: buildStockFormField(
                                  label: 'ຊື່ສິນຄ້າ (ລາວ)', controller: nameLaCtrl,
                                  icon: Icons.label_outlined)),
                            ]),
                            const SizedBox(height: 14),

                            // Code + Barcode
                            Row(children: [
                              Expanded(child: buildStockFormField(
                                  label: 'ລະຫັດ *', controller: codeCtrl,
                                  icon: Icons.tag_rounded,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'ກະລຸນາລະບຸລະຫັດ' : null)),
                              const SizedBox(width: 14),
                              Expanded(child: buildStockFormField(
                                  label: 'Barcode', controller: barcodeCtrl,
                                  icon: Icons.qr_code_rounded)),
                            ]),
                            const SizedBox(height: 14),

                            // Description
                            buildStockFormField(
                                label: 'ລາຍລະອຽດ (Description)',
                                controller: descCtrl,
                                icon: Icons.notes_rounded,
                                maxLines: 2),
                            const SizedBox(height: 20),

                            // ── Section: ຈັດປະເພດ ─────────────────────────
                            _sectionLabel('ຈັດປະເພດ', 'Classification'),
                            const SizedBox(height: 10),

                            Row(children: [
                              // Category
                              Expanded(child: buildStockDropdown<int>(
                                label: 'ໝວດ', icon: Icons.category_rounded,
                                value: selectedCatId, hint: 'ເລືອກໝວດ',
                                items: _categories.map((c) => DropdownMenuItem<int>(
                                    value: c['id'] ?? c['category_id'],
                                    child: Text(
                                      '${c['category_name_la'] ?? c['category_name'] ?? '-'}',
                                      overflow: TextOverflow.ellipsis,
                                    ))).toList(),
                                onChanged: (v) => setDialogState(() => selectedCatId = v),
                              )),
                              const SizedBox(width: 14),
                              // Brand
                              Expanded(child: buildStockDropdown<int>(
                                label: 'ຍີ່ຫໍ້ (Brand)', icon: Icons.star_rounded,
                                value: selectedBrandId, hint: 'ເລືອກຍີ່ຫໍ້',
                                items: brands.map((b) => DropdownMenuItem<int>(
                                    value: b['id'],
                                    child: Text(
                                      '${b['name_la'] ?? b['name'] ?? '-'}',
                                      overflow: TextOverflow.ellipsis,
                                    ))).toList(),
                                onChanged: (v) => setDialogState(() => selectedBrandId = v),
                              )),
                              const SizedBox(width: 14),
                              // Unit
                              Expanded(child: buildStockDropdown<int>(
                                label: 'ໜ່ວຍ (Unit)', icon: Icons.straighten_rounded,
                                value: selectedUnitId, hint: 'ເລືອກໜ່ວຍ',
                                items: units.map((u) => DropdownMenuItem<int>(
                                    value: u['id'],
                                    child: Text(
                                      '${u['name']}${u['short'].isNotEmpty ? " (${u['short']})" : ""}',
                                      overflow: TextOverflow.ellipsis,
                                    ))).toList(),
                                onChanged: (v) => setDialogState(() => selectedUnitId = v),
                              )),
                            ]),
                            const SizedBox(height: 20),

                            // ── Section: ລາຄາ ────────────────────────────
                            _sectionLabel('ລາຄາ', 'Pricing'),
                            const SizedBox(height: 10),

                            Row(children: [
                              Expanded(child: buildStockFormField(
                                  label: 'ລາຄາທຶນ *', controller: costCtrl,
                                  icon: Icons.attach_money_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'ກະລຸນາລະບຸ' : null)),
                              const SizedBox(width: 14),
                              Expanded(child: buildStockFormField(
                                  label: 'ລາຄາຂາຍ *', controller: priceCtrl,
                                  icon: Icons.sell_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'ກະລຸນາລະບຸ' : null)),
                              const SizedBox(width: 14),
                              Expanded(child: buildStockFormField(
                                  label: 'ລາຄາຂາຍສົ່ງ', controller: wholesaleCtrl,
                                  icon: Icons.local_shipping_rounded,
                                  keyboardType: TextInputType.number)),
                              const SizedBox(width: 14),
                              Expanded(child: buildStockFormField(
                                  label: 'ລາຄາຕໍ່າສຸດ', controller: minPriceCtrl,
                                  icon: Icons.price_change_rounded,
                                  keyboardType: TextInputType.number)),
                            ]),
                            const SizedBox(height: 20),

                            // ── Section: ສາງ ─────────────────────────────
                            _sectionLabel('ການຈັດການສາງ', 'Stock Management'),
                            const SizedBox(height: 10),

                            Row(children: [
                              Expanded(child: buildStockFormField(
                                  label: 'ສາງເລີ່ມຕົ້ນ', controller: stockCtrl,
                                  icon: Icons.inventory_rounded,
                                  keyboardType: TextInputType.number)),
                              const SizedBox(width: 14),
                              Expanded(child: buildStockFormField(
                                  label: 'ສາງຕໍ່າສຸດ (Min)', controller: minStockCtrl,
                                  icon: Icons.warning_amber_rounded,
                                  keyboardType: TextInputType.number)),
                              const SizedBox(width: 14),
                              Expanded(child: buildStockFormField(
                                  label: 'ສາງສູງສຸດ (Max)', controller: maxStockCtrl,
                                  icon: Icons.inventory_2_rounded,
                                  keyboardType: TextInputType.number)),
                              const SizedBox(width: 14),
                              Expanded(child: buildStockFormField(
                                  label: 'Reorder Point', controller: reorderCtrl,
                                  icon: Icons.autorenew_rounded,
                                  keyboardType: TextInputType.number)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  StockDialogFooter(
                    onCancel: () { disposeAll(); Navigator.pop(context); },
                    saveLabel: isEdit ? 'ບັນທຶກ' : 'ເພີ່ມສິນຄ້າ',
                    onSave: () async {
                      if (!formKey.currentState!.validate()) return;
                      final body = {
                        'product_name':    nameCtrl.text.trim(),
                        'product_name_la': nameLaCtrl.text.trim(),
                        'product_code':    codeCtrl.text.trim(),
                        'barcode':         barcodeCtrl.text.trim(),
                        'description':     descCtrl.text.trim(),
                        'category_id':     selectedCatId,
                        'brand_id':        selectedBrandId,
                        'unit_id':         selectedUnitId,
                        'cost_price':      num.tryParse(costCtrl.text) ?? 0,
                        'selling_price':   num.tryParse(priceCtrl.text) ?? 0,
                        'sale_price':      num.tryParse(priceCtrl.text) ?? 0,
                        'price':           num.tryParse(priceCtrl.text) ?? 0,
                        'wholesale_price': num.tryParse(wholesaleCtrl.text) ?? 0,
                        'min_price':       num.tryParse(minPriceCtrl.text) ?? 0,
                        'current_stock':   int.tryParse(stockCtrl.text) ?? 0,
                        'min_stock':       int.tryParse(minStockCtrl.text) ?? 0,
                        'max_stock':       int.tryParse(maxStockCtrl.text) ?? 0,
                        'reorder_point':   int.tryParse(reorderCtrl.text) ?? 10,
                        'created_by':      _me,
                      };
                      try {
                        final res = isEdit
                            ? await ApiService.updateProduct(
                                product!['id'] ?? product['product_id'], body)
                            : await ApiService.createProduct(body);
                        if (res['responseCode'] == '00') {
                          disposeAll();
                          Navigator.pop(context);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('${isEdit ? 'ອັບເດດ' : 'ເພີ່ມ'}ສິນຄ້າສຳເລັດ'),
                              backgroundColor: StockTheme.success));
                          _fetchAll();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(res['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'),
                              backgroundColor: StockTheme.error));
                        }
                      } catch (_) {
                        disposeAll();
                        Navigator.pop(context);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການເຊື່ອມຕໍ່'),
                                backgroundColor: StockTheme.error));
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

  // ── Section label helper ──────────────────────────────────────────────────
  Widget _sectionLabel(String laLabel, String enLabel) {
    return Row(children: [
      Container(
        width: 3, height: 18,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(laLabel,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE2E8F0))),
      const SizedBox(width: 8),
      Text(enLabel,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: const Color(0xFF1D4ED8).withOpacity(0.2), height: 1)),
    ]);
  }
}

// ── Private widgets ────────────────────────────────────────────────────────────

class _BlueStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _BlueStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        const Color(0xFF0D2045).withOpacity(0.7),
        const Color(0xFF0F2A4A).withOpacity(0.5),
      ]),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ]),
    ]),
  );
}

class _BlueFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BlueFilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF2563EB).withOpacity(0.15)
            : const Color(0xFF0F2A4A).withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? const Color(0xFF3B82F6).withOpacity(0.6)
              : const Color(0xFF1D4ED8).withOpacity(0.18),
        ),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8))),
      ),
    ),
  );
}