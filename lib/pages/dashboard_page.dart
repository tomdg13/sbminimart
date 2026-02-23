// lib/pages/dashboard_page.dart
//
// COLOR SCHEME UPDATE: Dark Blue Theme
//   - Primary:   0xFF1E40AF (blue-700) / 0xFF2563EB (blue-600)
//   - Accent:    0xFF3B82F6 (blue-500) / 0xFF60A5FA (blue-400)
//   - Background: 0xFF020817 (deep navy) / 0xFF0A1628 / 0xFF0F1E35
//   - Sidebar:   0xFF071022 / 0xFF0C1A33
//   - Surface:   0xFF0D2045 / 0xFF0F2A4A
//   - Border:    0xFF1E3A6E / 0xFF1D4ED8 (with opacity)

import 'package:flutter/material.dart';
import 'user_management_page.dart';
import 'role_management_page.dart';
import 'product_management_page.dart';
import 'sales/sales_page.dart';
import 'sales/pos_scan_page.dart';
import 'sales/sale_history_page.dart';
import 'cash_drawer/daily_close_page.dart';
import 'stock/stock_page.dart';
import 'stock/suppliers_page.dart';
import 'stock/warehouses_page.dart';
import 'stock/purchase_orders_page.dart';
import 'stock/stock_in_out_page.dart';
import 'stock/stock_adjustments_page.dart';
import 'stock/stock_transfers_page.dart';
import 'stock/stock_movements_page.dart';
import 'reports/reports_page.dart';
import '../services/cash_drawer_api_service.dart';
import '../widgets/cash_drawer_guard.dart';

// ─── BLUE COLOR PALETTE ───────────────────────────────────────────────────────
// Background layers
const _bgDeep = Color(0xFF020817); // deepest bg
const _bgBase = Color(0xFF0A1628); // base bg
const _bgOverlay = Color(0xFF0F1E35); // slight overlay
// Sidebar / surface layers
const _sideTop = Color(0xFF071022); // sidebar top
const _sideBot = Color(0xFF0C1A33); // sidebar bottom
const _surface = Color(0xFF0D2045); // card surface
const _surfaceAlt = Color(0xFF0F2A4A); // alt surface
// Primary blue accent
const _blue1 = Color(0xFF1D4ED8); // blue-700
const _blue2 = Color(0xFF2563EB); // blue-600
const _blue3 = Color(0xFF3B82F6); // blue-500 (main accent)
const _blue4 = Color(0xFF60A5FA); // blue-400 (lighter)
const _blue5 = Color(0xFF93C5FD); // blue-300 (highlights)
// Text
const _textPrimary = Color(0xFFE2E8F0);
const _textSecondary = Color(0xFF94A3B8);
const _textMuted = Color(0xFF475569);
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> menus;

  const DashboardPage({super.key, required this.user, required this.menus});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  int _selectedMenuIndex = 0;
  bool _sidebarExpanded = true;
  Widget? _currentPage;
  String _activePageName = 'ໜ້າຫຼັກ';
  String _activePagePath = '/dashboard';
  late AnimationController _menuAnimationController;
  late AnimationController _contentAnimationController;

  List<Map<String, dynamic>> _parentMenus = [];
  Map<int, List<Map<String, dynamic>>> _childMenus = {};

  @override
  void initState() {
    super.initState();
    _organizeMenus();
    _currentPage = null;
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _contentAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _contentAnimationController.forward();
  }

  @override
  void dispose() {
    _menuAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  void _organizeMenus() {
    _parentMenus = widget.menus
        .where((menu) => menu['parent_menu_id'] == null)
        .toList();
    _parentMenus.sort(
      (a, b) => (a['menu_order'] ?? 0).compareTo(b['menu_order'] ?? 0),
    );

    for (var menu in widget.menus) {
      if (menu['parent_menu_id'] != null) {
        final parentId = menu['parent_menu_id'] as int;
        if (!_childMenus.containsKey(parentId)) {
          _childMenus[parentId] = [];
        }
        _childMenus[parentId]!.add(menu);
      }
    }
    _childMenus.forEach((key, children) {
      children.sort(
        (a, b) => (a['menu_order'] ?? 0).compareTo(b['menu_order'] ?? 0),
      );
    });
    for (var parent in _parentMenus) {
      final menuId = parent['menu_id'] as int;
      parent['children'] = _childMenus[menuId] ?? [];
    }
  }

  void _navigateToHistory() {
    _contentAnimationController.reset();
    setState(() {
      _selectedMenuIndex = -1;
      _activePageName = 'ປະຫວັດການຂາຍ';
      _activePagePath = '/sales/history';
      _currentPage = SaleHistoryPage(currentUser: widget.user);
    });
    _contentAnimationController.forward();
  }

  void _navigateToHome() {
    _contentAnimationController.reset();
    setState(() {
      _selectedMenuIndex = 0;
      _activePageName = 'ໜ້າຫຼັກ';
      _activePagePath = '/dashboard';
      _currentPage = null;
    });
    _contentAnimationController.forward();
  }

  Widget _buildDailyClosePage() {
    final cashierId = widget.user['user_id'] ?? widget.user['id'];

    return FutureBuilder<Map<String, dynamic>>(
      future: CashDrawerApiService.getActiveShift(cashierId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _blue3),
                const SizedBox(height: 16),
                Text(
                  'ກຳລັງໂຫລດຂໍ້ມູນກະ...',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        final res = snapshot.data;

        if (res == null || res['responseCode'] != '00' || res['data'] == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_clock_rounded,
                    size: 44,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ບໍ່ມີກະເປີດຢູ່',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ທ່ານຍັງບໍ່ໄດ້ເປີດກະ ຫຼື ກະຖືກປິດແລ້ວ\nNo active shift found.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary.withOpacity(0.6),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _navigateToHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.home_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'ກັບໜ້າຫຼັກ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final activeShift = res['data'] as Map<String, dynamic>;
        return DailyClosePage(
          currentUser: widget.user,
          activeShift: activeShift,
          onShiftClosed: _navigateToHome,
        );
      },
    );
  }

  IconData _getIcon(String? iconName) {
    final map = {
      'dashboard': Icons.grid_view_rounded,
      'point_of_sale': Icons.point_of_sale_rounded,
      'inventory_2': Icons.inventory_2_rounded,
      'warehouse': Icons.warehouse_rounded,
      'shopping_cart': Icons.shopping_cart_rounded,
      'local_shipping': Icons.local_shipping_rounded,
      'people': Icons.people_rounded,
      'discount': Icons.local_offer_rounded,
      'bar_chart': Icons.analytics_rounded,
      'receipt_long': Icons.receipt_long_rounded,
      'badge': Icons.badge_rounded,
      'settings': Icons.settings_rounded,
      'category': Icons.category_rounded,
      'branding_watermark': Icons.branding_watermark_rounded,
      'straighten': Icons.straighten_rounded,
      'swap_horiz': Icons.swap_horiz_rounded,
      'add_circle': Icons.add_circle_rounded,
      'remove_circle': Icons.remove_circle_rounded,
      'tune': Icons.tune_rounded,
      'history': Icons.history_rounded,
      'business': Icons.business_rounded,
      'assignment': Icons.assignment_rounded,
      'move_to_inbox': Icons.move_to_inbox_rounded,
      'outbox': Icons.outbox_rounded,
      'receipt': Icons.receipt_rounded,
      'sell': Icons.sell_rounded,
      'storefront': Icons.storefront_rounded,
      'inventory': Icons.inventory_rounded,
      'stock': Icons.inventory_2_rounded,
      'lock_clock': Icons.lock_clock_rounded,
    };
    return map[iconName] ?? Icons.circle_outlined;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'ສະບາຍດີຕອນເຊົ້າ';
    if (hour < 17) return 'ສະບາຍດີຕອນບ່າຍ';
    return 'ສະບາຍດີຕອນແລງ';
  }

  void _handleMenuTap(int index) {
    final menu = _parentMenus[index];
    final menuPath = menu['menu_path'] as String?;

    debugPrint('>>> PARENT MENU TAPPED: $menuPath');

    _contentAnimationController.reset();

    setState(() {
      _selectedMenuIndex = index;
      _activePageName = menu['menu_name'] ?? 'ໜ້າຫຼັກ';
      _activePagePath = menuPath ?? '/dashboard';

      if (menuPath == '/users' || menuPath == '/employees/list') {
        _currentPage = UserManagementPage(currentUser: widget.user);
      } else if (menuPath == '/roles' || menuPath == '/settings/roles') {
        _currentPage = RoleManagementPage(currentUser: widget.user);
      } else if (menuPath == '/products') {
        _currentPage = ProductManagementPage(
          currentUser: widget.user,
          initialTab: 0,
        );
      } else if (menuPath == '/categories') {
        _currentPage = ProductManagementPage(
          currentUser: widget.user,
          initialTab: 1,
        );
      } else if (menuPath == '/brands') {
        _currentPage = ProductManagementPage(
          currentUser: widget.user,
          initialTab: 2,
        );
      } else if (menuPath == '/units') {
        _currentPage = ProductManagementPage(
          currentUser: widget.user,
          initialTab: 3,
        );
      } else if (menuPath == '/sales') {
        debugPrint('>>> ROUTING TO SalesPage (guarded): $menuPath');
        _currentPage = CashDrawerGuard(
          currentUser: widget.user,
          child: SalesPage(
            currentUser: widget.user,
            onSaleCreated: _navigateToHistory,
          ),
        );
      } else if (menuPath == '/sales/history' ||
          menuPath == '/history' ||
          menuPath == '/pos/history') {
        debugPrint('>>> ROUTING TO SaleHistoryPage: $menuPath');
        _currentPage = SaleHistoryPage(currentUser: widget.user);
      } else if (menuPath == '/pos' ||
          menuPath == 'pos' ||
          menuPath == '/point-of-sale' ||
          menuPath == 'point_of_sale') {
        debugPrint('>>> ROUTING TO PosScanPage (guarded): $menuPath');
        _currentPage = CashDrawerGuard(
          currentUser: widget.user,
          child: PosScanPage(currentUser: widget.user, onBack: _navigateToHome),
        );
      } else if (menuPath == '/daily-close' ||
          menuPath == '/sales/daily-close' ||
          menuPath == '/pos/daily-close') {
        debugPrint('>>> ROUTING TO DailyClosePage: $menuPath');
        _currentPage = _buildDailyClosePage();
      } else if (menuPath == '/stock' ||
          menuPath == '/stock/list' ||
          menuPath == '/inventory/stock' ||
          menuPath == '/inventory/stock-list') {
        debugPrint('>>> ROUTING TO StockPage: $menuPath');
        _currentPage = StockPage(currentUser: widget.user);
      } else if (menuPath == '/inventory') {
        debugPrint('>>> ROUTING TO StockPage (inventory parent): $menuPath');
        _currentPage = StockPage(currentUser: widget.user);
      } else if (menuPath == '/reports' || menuPath == '/report') {
        debugPrint('>>> ROUTING TO ReportsPage: $menuPath');
        _currentPage = ReportsPage(currentUser: widget.user, initialTab: 0);
      } else {
        _currentPage = null;
      }
    });

    _contentAnimationController.forward();
  }

  void _handleChildMenuTap(Map<String, dynamic> child) {
    final menuPath = child['menu_path'] as String?;

    _contentAnimationController.reset();

    setState(() {
      _selectedMenuIndex = -1;
      _activePageName = child['menu_name'] ?? 'ໜ້າຫຼັກ';
      _activePagePath = menuPath ?? '/dashboard';

      if (menuPath == '/employees/list') {
        _currentPage = UserManagementPage(currentUser: widget.user);
      } else if (menuPath == '/settings/roles') {
        _currentPage = RoleManagementPage(currentUser: widget.user);
      } else if (menuPath == '/products/list' || menuPath == '/products') {
        _currentPage = ProductManagementPage(
          currentUser: widget.user,
          initialTab: 0,
        );
      } else if (menuPath == '/products/categories' ||
          menuPath == '/categories') {
        _currentPage = ProductManagementPage(
          currentUser: widget.user,
          initialTab: 1,
        );
      } else if (menuPath == '/products/brands' || menuPath == '/brands') {
        _currentPage = ProductManagementPage(
          currentUser: widget.user,
          initialTab: 2,
        );
      } else if (menuPath == '/products/units' || menuPath == '/units') {
        _currentPage = ProductManagementPage(
          currentUser: widget.user,
          initialTab: 3,
        );
      } else if (menuPath == '/products/pricing' ||
          menuPath == '/products/barcode') {
        _currentPage = ProductManagementPage(
          currentUser: widget.user,
          initialTab: 0,
        );
      } else if (menuPath == '/sales' ||
          menuPath == '/sales/list' ||
          menuPath == '/sales/overview') {
        debugPrint('>>> CHILD ROUTING TO SalesPage (guarded): $menuPath');
        _currentPage = CashDrawerGuard(
          currentUser: widget.user,
          child: SalesPage(
            currentUser: widget.user,
            onSaleCreated: _navigateToHistory,
          ),
        );
      } else if (menuPath == '/sales/history' ||
          menuPath == '/history' ||
          menuPath == '/pos/history') {
        debugPrint('>>> CHILD ROUTING TO SaleHistoryPage: $menuPath');
        _currentPage = SaleHistoryPage(currentUser: widget.user);
      } else if (menuPath == '/pos' ||
          menuPath == '/pos/list' ||
          menuPath == '/point-of-sale' ||
          menuPath == 'pos' ||
          menuPath == 'point_of_sale') {
        debugPrint('>>> CHILD ROUTING TO PosScanPage (guarded): $menuPath');
        _currentPage = CashDrawerGuard(
          currentUser: widget.user,
          child: PosScanPage(currentUser: widget.user, onBack: _navigateToHome),
        );
      } else if (menuPath == '/daily-close' ||
          menuPath == '/sales/daily-close' ||
          menuPath == '/pos/daily-close') {
        debugPrint('>>> CHILD ROUTING TO DailyClosePage: $menuPath');
        _currentPage = _buildDailyClosePage();
      } else if (menuPath == '/stock' ||
          menuPath == '/stock/list' ||
          menuPath == '/inventory/stock' ||
          menuPath == '/inventory/stock-list') {
        debugPrint('>>> CHILD ROUTING TO StockPage: $menuPath');
        _currentPage = StockPage(currentUser: widget.user);
      } else if (menuPath == '/inventory/overview' ||
          menuPath == '/inventory/stock-list' ||
          menuPath == '/inventory/stock') {
        debugPrint('>>> CHILD ROUTING TO StockPage: $menuPath');
        _currentPage = StockPage(currentUser: widget.user);
      } else if (menuPath == '/inventory/suppliers') {
        _currentPage = SuppliersPage(currentUser: widget.user);
      } else if (menuPath == '/inventory/warehouses') {
        _currentPage = WarehousesPage(currentUser: widget.user);
      } else if (menuPath == '/inventory/purchase-orders' ||
          menuPath == '/inventory/orders') {
        _currentPage = PurchaseOrdersPage(currentUser: widget.user);
      } else if (menuPath == '/inventory/in') {
        _currentPage = StockInOutPage(currentUser: widget.user, initialTab: 0);
      } else if (menuPath == '/inventory/out') {
        _currentPage = StockInOutPage(currentUser: widget.user, initialTab: 1);
      } else if (menuPath == '/inventory/count') {
        _currentPage = StockAdjustmentsPage(currentUser: widget.user);
      } else if (menuPath == '/inventory/transfers' ||
          menuPath == '/inventory/stock-transfers') {
        _currentPage = StockTransfersPage(currentUser: widget.user);
      } else if (menuPath == '/inventory/movements' ||
          menuPath == '/inventory/stock-movements') {
        _currentPage = StockMovementsPage(currentUser: widget.user);
      } else if (menuPath == '/reports/sales' || menuPath == '/report/sales') {
        _currentPage = ReportsPage(currentUser: widget.user, initialTab: 0);
      } else if (menuPath == '/reports/inventory' ||
          menuPath == '/report/inventory') {
        _currentPage = ReportsPage(currentUser: widget.user, initialTab: 1);
      } else if (menuPath == '/reports/customers' ||
          menuPath == '/report/customers') {
        _currentPage = ReportsPage(currentUser: widget.user, initialTab: 2);
      } else if (menuPath == '/reports/users' ||
          menuPath == '/report/users' ||
          menuPath == '/reports/staff') {
        _currentPage = ReportsPage(currentUser: widget.user, initialTab: 3);
      } else if (menuPath?.startsWith('/reports') == true ||
          menuPath?.startsWith('/report') == true) {
        _currentPage = ReportsPage(currentUser: widget.user, initialTab: 0);
      } else {
        _currentPage = null;
      }
    });

    _contentAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Scaffold(
      backgroundColor: _bgDeep,
      drawer: isMobile ? _buildSidebar(true) : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgDeep, _bgBase, _bgDeep.withOpacity(0.92)],
          ),
        ),
        child: Row(
          children: [
            if (!isMobile) _buildSidebar(false),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(isMobile),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isDrawer) {
    final sidebar = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _sidebarExpanded ? 280 : 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_sideTop.withOpacity(0.97), _sideBot.withOpacity(0.99)],
        ),
        border: Border(
          right: BorderSide(color: _blue1.withOpacity(0.2), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: _blue2.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: ClipRRect(
        child: Column(
          children: [
            // ── Logo ──────────────────────────────────────────────────────
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_blue2.withOpacity(0.12), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_blue2, _blue1],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: _blue2.withOpacity(0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.store_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  if (_sidebarExpanded) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [_blue4, _blue5],
                            ).createShader(bounds),
                            child: const Text(
                              'MiniMart',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          Text(
                            'POS System',
                            style: TextStyle(
                              color: _textSecondary.withOpacity(0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── User card ──────────────────────────────────────────────────
            if (_sidebarExpanded)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_blue2.withOpacity(0.1), _blue1.withOpacity(0.06)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _blue2.withOpacity(0.25), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_blue2, _blue1],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _blue2.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.user['full_name']
                                  ?.toString()
                                  .characters
                                  .first
                                  .toUpperCase() ??
                              'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user['full_name'] ?? '',
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _blue2.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.user['role']?.toString() ?? '',
                              style: TextStyle(
                                color: _blue4.withOpacity(0.95),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Menu list ─────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: _parentMenus.length,
                itemBuilder: (context, index) {
                  final menu = _parentMenus[index];
                  final isActive = _selectedMenuIndex == index;
                  final icon = _getIcon(menu['menu_icon']);
                  final children =
                      menu['children'] as List<Map<String, dynamic>>? ?? [];

                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 300 + (index * 50)),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: _buildMenuItem(
                      menu,
                      icon,
                      isActive,
                      index,
                      children,
                    ),
                  );
                },
              ),
            ),

            // ── Logout ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => _buildLogoutRedirect()),
                      (route) => false,
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _sidebarExpanded ? 14 : 0,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFEF4444).withOpacity(0.1),
                          const Color(0xFFDC2626).withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: _sidebarExpanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFFCA5A5),
                          size: 22,
                        ),
                        if (_sidebarExpanded) ...[
                          const SizedBox(width: 14),
                          const Text(
                            'ອອກຈາກລະບົບ',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isDrawer) return Drawer(child: sidebar);
    return sidebar;
  }

  Widget _buildLogoutRedirect() {
    return const Scaffold(body: Center(child: Text('ກຳລັງໄປໜ້າເຂົ້າລະບົບ...')));
  }

  Widget _buildTopBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_sideTop.withOpacity(0.6), _bgBase.withOpacity(0.4)],
        ),
        border: Border(
          bottom: BorderSide(color: _blue1.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (ctx) => IconButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                icon: Icon(Icons.menu_rounded, color: _textSecondary),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() {
                    _currentPage = null;
                    _selectedMenuIndex = 0;
                    _activePageName = 'ໜ້າຫຼັກ';
                    _activePagePath = '/dashboard';
                  }),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        size: 16,
                        color: _blue3.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ໜ້າຫຼັກ',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textSecondary.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_activePagePath != '/dashboard') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: _textSecondary.withOpacity(0.4),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _blue2.withOpacity(0.22),
                          _blue3.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _blue2.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: _blue3,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _activePageName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isMobile)
            IconButton(
              onPressed: () =>
                  setState(() => _sidebarExpanded = !_sidebarExpanded),
              icon: Icon(
                _sidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                color: _blue3,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    debugPrint(
      '>>> _buildContent: _currentPage=$_currentPage, _selectedMenuIndex=$_selectedMenuIndex',
    );
    return FadeTransition(
      opacity: _contentAnimationController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _contentAnimationController,
                curve: Curves.easeOut,
              ),
            ),
        child: _currentPage != null
            ? _currentPage!
            : (_selectedMenuIndex >= 0 &&
                  _selectedMenuIndex < _parentMenus.length)
            ? (_parentMenus[_selectedMenuIndex]['menu_path'] == '/dashboard')
                  ? _buildDashboardContent()
                  : _buildPlaceholderContent(_parentMenus[_selectedMenuIndex])
            : _buildDashboardContent(),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [_textPrimary, _textSecondary],
                      ).createShader(bounds),
                      child: Text(
                        '${_getGreeting()},',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [_blue4, _blue5],
                      ).createShader(bounds),
                      child: Text(
                        widget.user['full_name'] ?? '',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: crossCount,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.4,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard(
                    'ຍອດຂາຍມື້ນີ້',
                    '₭ 12.5M',
                    Icons.trending_up_rounded,
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                    '+12.5%',
                  ),
                  _buildStatCard(
                    'ລາຍການຂາຍ',
                    '47',
                    Icons.receipt_rounded,
                    _blue3,
                    _blue2,
                    '+8 ມື້ນີ້',
                  ),
                  _buildStatCard(
                    'ສິນຄ້າໃກ້ໝົດ',
                    '12',
                    Icons.warning_amber_rounded,
                    const Color(0xFFF59E0B),
                    const Color(0xFFD97706),
                    'ຕ້ອງສັ່ງ',
                  ),
                  _buildStatCard(
                    'ລູກຄ້າໃໝ່',
                    '5',
                    Icons.person_add_rounded,
                    const Color(0xFFEC4899),
                    const Color(0xFFDB2777),
                    'ອາທິດນີ້',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_blue3, _blue4]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'ເມນູດ່ວນ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ເຂົ້າໃຊ້ດ່ວນ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _parentMenus
                .where((m) => m['menu_path'] != '/dashboard')
                .take(6)
                .map((menu) => _buildQuickAccessCard(menu))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color1,
    Color color2,
    String badge,
  ) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, animValue, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * animValue),
          child: Opacity(opacity: animValue, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_surface.withOpacity(0.7), _surfaceAlt.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color1.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color1.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color1, color2]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color1.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color1.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: color1,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [color1, color2],
                  ).createShader(bounds),
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(Map<String, dynamic> menu) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: InkWell(
        onTap: () {
          final idx = _parentMenus.indexOf(menu);
          if (idx >= 0) _handleMenuTap(idx);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_surface.withOpacity(0.6), _surfaceAlt.withOpacity(0.4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _blue1.withOpacity(0.25), width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_blue2, _blue1]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _blue2.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _getIcon(menu['menu_icon']),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                menu['menu_name_la'] ?? menu['menu_name'] ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderContent(Map<String, dynamic>? menu) {
    final children =
        (menu?['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (children.isNotEmpty) ...[
            const Text(
              'ໂມດູນຍ່ອຍ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: children.map((child) {
                return InkWell(
                  onTap: () => _handleChildMenuTap(child),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 240,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _surface.withOpacity(0.6),
                          _surfaceAlt.withOpacity(0.4),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _blue1.withOpacity(0.22),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child['menu_name_la'] ?? child['menu_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          child['menu_path'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textSecondary.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (child['can_view'] == 1)
                              _permTag('View', const Color(0xFF10B981)),
                            if (child['can_create'] == 1)
                              _permTag('Create', _blue3),
                            if (child['can_edit'] == 1)
                              _permTag('Edit', const Color(0xFFF59E0B)),
                            if (child['can_delete'] == 1)
                              _permTag('Delete', const Color(0xFFEF4444)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 60),
          ],
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _blue2.withOpacity(0.12),
                        _blue1.withOpacity(0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    size: 72,
                    color: _blue3,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ກຳລັງພັດທະນາ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ໂມດູນນີ້ກຳລັງຢູ່ໃນຂັ້ນຕອນການພັດທະນາ',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _permTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  final Map<int, bool> _expandedMenus = {};

  Widget _buildMenuItem(
    Map<String, dynamic> menu,
    IconData icon,
    bool isActive,
    int index,
    List<Map<String, dynamic>> children,
  ) {
    final menuId = menu['menu_id'] as int;
    final isExpanded = _expandedMenus[menuId] ?? false;
    final hasChildren = children.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (hasChildren) {
                  setState(() => _expandedMenus[menuId] = !isExpanded);
                }
                _handleMenuTap(index);
              },
              borderRadius: BorderRadius.circular(14),
              splashColor: _blue2.withOpacity(0.12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: _sidebarExpanded ? 14 : 0,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? LinearGradient(
                          colors: [
                            _blue2.withOpacity(0.22),
                            _blue1.withOpacity(0.16),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  border: isActive
                      ? Border.all(color: _blue2.withOpacity(0.35), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: _sidebarExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: isActive ? _blue4 : _textMuted, size: 22),
                    if (_sidebarExpanded) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          menu['menu_name'] ?? '',
                          style: TextStyle(
                            color: isActive ? _textPrimary : _textSecondary,
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasChildren)
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded,
                          color: _textMuted,
                          size: 20,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasChildren && isExpanded && _sidebarExpanded)
          ...children.map((child) => _buildChildMenuItem(child, menuId)),
      ],
    );
  }

  Widget _buildChildMenuItem(Map<String, dynamic> child, int parentMenuId) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleChildMenuTap(child),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _blue1.withOpacity(0.15), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _textMuted.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    child['menu_name'] ?? '',
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
