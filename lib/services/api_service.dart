import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ==========================================
  // CONFIGURATION
  // ==========================================
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'prod',
  );

  static String get baseUrl {
    switch (environment) {
      case 'dev':
        return 'http://localhost:2026/api';
      case 'staging':
        return 'https://staging.ishop.sabaiapp.com/api';
      case 'prod':
      default:
        return 'https://ishop.sabaiapp.com/api';
    }
  }

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // ==========================================
  // TOKEN MANAGEMENT
  // ==========================================
  static String? _token;
  static String? get token => _token;

  static void setToken(String token) {
    _token = token;
    _logBox('TOKEN', '🔐 Token stored (${token.length} chars)');
  }

  static void clearToken() {
    _token = null;
    _logBox('TOKEN', '🔓 Token cleared');
  }

  static Map<String, String> get _authHeaders {
    final headers = Map<String, String>.from(_headers);
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    return headers;
  }

  // ==========================================
  // LOG STORAGE
  // ==========================================
  static final List<ApiLog> _logs = [];
  static List<ApiLog> get logs => List.unmodifiable(_logs);
  static void clearLogs() => _logs.clear();

  static String exportLogsAsJson() => const JsonEncoder.withIndent(
    '  ',
  ).convert(_logs.map((l) => l.toJson()).toList());

  // ==========================================
  // AUTH
  // ==========================================
  static Future<Map<String, dynamic>> login(
    String userId,
    String password,
  ) async {
    final ep = '$baseUrl/auth/login';
    final body = {'userId': userId, 'password': password};
    _logRequest('POST', ep, body: body);
    try {
      final res = await http.post(
        Uri.parse(ep),
        headers: _headers,
        body: jsonEncode(body),
      );
      final result = _handleWithLog('POST', ep, res, requestBody: body);
      if (result['responseCode'] == '00' && result['access_token'] != null) {
        setToken(result['access_token']);
      }
      return result;
    } catch (e) {
      return _errorWithLog(
        'POST',
        ep,
        'ເຊື່ອມຕໍ່ບໍ່ໄດ້ | Cannot connect to server',
        e,
        requestBody: body,
      );
    }
  }

  // ==========================================
  // USERS
  // ==========================================
  static Future<List> getUsers() async {
    final ep = '$baseUrl/users';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get users', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> createUser(
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/users';
    _logRequest('POST', ep, body: body);
    try {
      final res = await http.post(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('POST', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'POST',
        ep,
        'Failed to create user',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> updateUser(
    int id,
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/users/$id';
    _logRequest('PUT', ep, body: body);
    try {
      final res = await http.put(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('PUT', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'PUT',
        ep,
        'Failed to update user',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> deleteUser(int id) async {
    final ep = '$baseUrl/users/$id';
    _logRequest('DELETE', ep);
    try {
      final res = await http.delete(Uri.parse(ep), headers: _authHeaders);
      return _handleWithLog('DELETE', ep, res);
    } catch (e) {
      return _errorWithLog('DELETE', ep, 'Failed to delete user', e);
    }
  }

  static Future<Map<String, dynamic>> unlockUser(int id) async {
    final ep = '$baseUrl/users/$id/unlock';
    _logRequest('PUT', ep);
    try {
      final res = await http.put(Uri.parse(ep), headers: _authHeaders);
      return _handleWithLog('PUT', ep, res);
    } catch (e) {
      return _errorWithLog('PUT', ep, 'Failed to unlock user', e);
    }
  }

  // ==========================================
  // ROLES
  // ==========================================
  static Future<List> getRoles() async {
    final ep = '$baseUrl/roles';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get roles', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> createRole(
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/roles';
    _logRequest('POST', ep, body: body);
    try {
      final res = await http.post(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('POST', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'POST',
        ep,
        'Failed to create role',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> updateRole(
    int id,
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/roles/$id';
    _logRequest('PUT', ep, body: body);
    try {
      final res = await http.put(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('PUT', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'PUT',
        ep,
        'Failed to update role',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> deleteRole(int id) async {
    final ep = '$baseUrl/roles/$id';
    _logRequest('DELETE', ep);
    try {
      final res = await http.delete(Uri.parse(ep), headers: _authHeaders);
      return _handleWithLog('DELETE', ep, res);
    } catch (e) {
      return _errorWithLog('DELETE', ep, 'Failed to delete role', e);
    }
  }

  // ==========================================
  // MENUS & ROLE-MENU MAPPING
  // ==========================================
  static Future<List> getMenus() async {
    final ep = '$baseUrl/roles/menus/all';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get menus', e);
      return [];
    }
  }

  static Future<List> getRoleMenuMapping(int roleId) async {
    final ep = '$baseUrl/roles/$roleId/menus';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get role menu mapping', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> saveRoleMenuMapping(
    int roleId,
    List<Map<String, dynamic>> mappings,
  ) async {
    final ep = '$baseUrl/roles/$roleId/menus';
    final body = {'mappings': mappings};
    _logRequest('POST', ep, body: body);
    try {
      final res = await http.post(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('POST', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'POST',
        ep,
        'Failed to save mappings',
        e,
        requestBody: body,
      );
    }
  }

  // ==========================================
  // PRODUCTS
  // ==========================================
  static Future<List> getProducts() async {
    final ep = '$baseUrl/products';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get products', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> getProductById(int id) async {
    final ep = '$baseUrl/products/$id';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      return _handleWithLog('GET', ep, res);
    } catch (e) {
      return _errorWithLog('GET', ep, 'Failed to fetch product', e);
    }
  }

  static Future<List> searchProducts(String keyword) async {
    final ep = '$baseUrl/products/search?keyword=$keyword';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to search products', e);
      return [];
    }
  }

  static Future<List> getProductsByCategory(int categoryId) async {
    final ep = '$baseUrl/products/category/$categoryId';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get products by category', e);
      return [];
    }
  }

  static Future<List> getLowStockProducts() async {
    final ep = '$baseUrl/products/low-stock';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get low stock products', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/products';
    _logRequest('POST', ep, body: body);
    try {
      final res = await http.post(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('POST', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'POST',
        ep,
        'Failed to create product',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> updateProduct(
    int id,
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/products/$id';
    _logRequest('PUT', ep, body: body);
    try {
      final res = await http.put(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('PUT', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'PUT',
        ep,
        'Failed to update product',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> deleteProduct(int id) async {
    final ep = '$baseUrl/products/$id';
    _logRequest('DELETE', ep);
    try {
      final res = await http.delete(Uri.parse(ep), headers: _authHeaders);
      return _handleWithLog('DELETE', ep, res);
    } catch (e) {
      return _errorWithLog('DELETE', ep, 'Failed to delete product', e);
    }
  }

  static Future<Map<String, dynamic>> updateStock(
    int id,
    int quantity,
    String type,
  ) async {
    final ep = '$baseUrl/products/stock/$id';
    final body = {'quantity': quantity, 'type': type};
    _logRequest('PUT', ep, body: body);
    try {
      final res = await http.put(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('PUT', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'PUT',
        ep,
        'Failed to update stock',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> adjustStock(
    int id,
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/products/stock/$id';
    _logRequest('PUT', ep, body: body);
    try {
      final res = await http.put(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('PUT', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'PUT',
        ep,
        'Failed to adjust stock',
        e,
        requestBody: body,
      );
    }
  }

  static Future<List> getPriceHistory(int productId) async {
    final ep = '$baseUrl/products/price-history/$productId';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get price history', e);
      return [];
    }
  }

  // ==========================================
  // STOCK HISTORY
  // ==========================================
  static Future<List> getStockHistory() async {
    final ep = '$baseUrl/stock/history';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get stock history', e);
      return [];
    }
  }

  // ==========================================
  // CATEGORIES
  // ==========================================
  static Future<List> getCategories() async {
    final ep = '$baseUrl/categories';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get categories', e);
      return [];
    }
  }

  static Future<List> getParentCategories() async {
    final ep = '$baseUrl/categories/parents';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get parent categories', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> createCategory(
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/categories';
    _logRequest('POST', ep, body: body);
    try {
      final res = await http.post(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('POST', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'POST',
        ep,
        'Failed to create category',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> updateCategory(
    int id,
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/categories/$id';
    _logRequest('PUT', ep, body: body);
    try {
      final res = await http.put(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('PUT', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'PUT',
        ep,
        'Failed to update category',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> deleteCategory(int id) async {
    final ep = '$baseUrl/categories/$id';
    _logRequest('DELETE', ep);
    try {
      final res = await http.delete(Uri.parse(ep), headers: _authHeaders);
      return _handleWithLog('DELETE', ep, res);
    } catch (e) {
      return _errorWithLog('DELETE', ep, 'Failed to delete category', e);
    }
  }

  // ==========================================
  // BRANDS
  // ==========================================
  static Future<List> getBrands() async {
    final ep = '$baseUrl/brands';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get brands', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> createBrand(
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/brands';
    _logRequest('POST', ep, body: body);
    try {
      final res = await http.post(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('POST', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'POST',
        ep,
        'Failed to create brand',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> updateBrand(
    int id,
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/brands/$id';
    _logRequest('PUT', ep, body: body);
    try {
      final res = await http.put(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('PUT', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'PUT',
        ep,
        'Failed to update brand',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> deleteBrand(int id) async {
    final ep = '$baseUrl/brands/$id';
    _logRequest('DELETE', ep);
    try {
      final res = await http.delete(Uri.parse(ep), headers: _authHeaders);
      return _handleWithLog('DELETE', ep, res);
    } catch (e) {
      return _errorWithLog('DELETE', ep, 'Failed to delete brand', e);
    }
  }

  // ==========================================
  // UNITS
  // ==========================================
  static Future<List> getUnits() async {
    final ep = '$baseUrl/units';
    _logRequest('GET', ep);
    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      final data = _handleWithLog('GET', ep, res);
      return data['data'] ?? [];
    } catch (e) {
      _errorWithLog('GET', ep, 'Failed to get units', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>> createUnit(
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/units';
    _logRequest('POST', ep, body: body);
    try {
      final res = await http.post(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('POST', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'POST',
        ep,
        'Failed to create unit',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> updateUnit(
    int id,
    Map<String, dynamic> body,
  ) async {
    final ep = '$baseUrl/units/$id';
    _logRequest('PUT', ep, body: body);
    try {
      final res = await http.put(
        Uri.parse(ep),
        headers: _authHeaders,
        body: jsonEncode(body),
      );
      return _handleWithLog('PUT', ep, res, requestBody: body);
    } catch (e) {
      return _errorWithLog(
        'PUT',
        ep,
        'Failed to update unit',
        e,
        requestBody: body,
      );
    }
  }

  static Future<Map<String, dynamic>> deleteUnit(int id) async {
    final ep = '$baseUrl/units/$id';
    _logRequest('DELETE', ep);
    try {
      final res = await http.delete(Uri.parse(ep), headers: _authHeaders);
      return _handleWithLog('DELETE', ep, res);
    } catch (e) {
      return _errorWithLog('DELETE', ep, 'Failed to delete unit', e);
    }
  }

  // ==========================================
  // ██████╗ ███████╗██████╗  ██████╗ ██████╗ ████████╗███████╗
  // ██╔══██╗██╔════╝██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔════╝
  // ██████╔╝█████╗  ██████╔╝██║   ██║██████╔╝   ██║   ███████╗
  // ██╔══██╗██╔══╝  ██╔═══╝ ██║   ██║██╔══██╗   ██║   ╚════██║
  // ██║  ██║███████╗██║     ╚██████╔╝██║  ██║   ██║   ███████║
  // ╚═╝  ╚═╝╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝
  // ==========================================

  // ─────────────────────────────────────────────────────────────
  // SALES REPORTS
  // ─────────────────────────────────────────────────────────────

  /// GET /sales/summary?period=day|month|year&date=YYYY-MM-DD
  /// Returns: { responseCode, data: { total_orders, total_sales, total_revenue, avg_order } }
  static Future<Map<String, dynamic>> getSalesSummary({
    String period = 'day',
    String? date,
  }) async {
    final params = <String, String>{'period': period};
    if (date != null) params['date'] = date;

    final uri = Uri.parse(
      '$baseUrl/sales/summary',
    ).replace(queryParameters: params);
    final ep = uri.toString();
    _logRequest('GET', ep);

    try {
      final res = await http.get(uri, headers: _authHeaders);
      debugPrint('=== getSalesSummary [$period] ${res.statusCode} ===');
      final body = _safeJson(res.body);
      return body is Map<String, dynamic> ? body : {'data': body};
    } catch (e) {
      debugPrint('getSalesSummary error: $e');
      return _error('getSalesSummary: $e');
    }
  }

  /// GET /sales?startDate=&endDate=&page=&limit=
  /// Returns: { responseCode, data: List<Sale>, total, page, limit }
  static Future<Map<String, dynamic>> getSalesList({
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
    final uri = Uri.parse('$baseUrl/sales').replace(queryParameters: params);
    final ep = uri.toString();
    _logRequest('GET', ep);

    try {
      final res = await http.get(uri, headers: _authHeaders);
      debugPrint('=== getSalesList ${res.statusCode} ===');
      final body = _safeJson(res.body);
      return body is Map<String, dynamic> ? body : {'data': body};
    } catch (e) {
      debugPrint('getSalesList error: $e');
      return _error('getSalesList: $e');
    }
  }

  /// GET /sales/top-products?limit=10&startDate=&endDate=
  /// Returns: { responseCode, data: List<{ product_name, total_qty, total_revenue }> }
  static Future<List> getTopProducts({
    int limit = 10,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
    final uri = Uri.parse(
      '$baseUrl/sales/top-products',
    ).replace(queryParameters: params);
    final ep = uri.toString();
    _logRequest('GET', ep);

    try {
      final res = await http.get(uri, headers: _authHeaders);
      debugPrint('=== getTopProducts ${res.statusCode} ===');
      final body = _safeJson(res.body);
      if (body is List) return body;
      return (body['data'] as List?) ?? [];
    } catch (e) {
      debugPrint('getTopProducts error: $e');
      return [];
    }
  }

  /// GET /sales/by-category?startDate=&endDate=
  /// Returns: List<{ category_name, total_qty, total_revenue }>
  static Future<List> getSalesByCategory({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
    final uri = Uri.parse(
      '$baseUrl/sales/by-category',
    ).replace(queryParameters: params);
    final ep = uri.toString();
    _logRequest('GET', ep);

    try {
      final res = await http.get(uri, headers: _authHeaders);
      debugPrint('=== getSalesByCategory ${res.statusCode} ===');
      final body = _safeJson(res.body);
      if (body is List) return body;
      return (body['data'] as List?) ?? [];
    } catch (e) {
      debugPrint('getSalesByCategory error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // INVENTORY REPORTS
  // ─────────────────────────────────────────────────────────────

  /// GET /products/inventory-report
  /// Returns: { responseCode, data: { total_products, low_stock_count, out_of_stock, total_value, products[] } }
  static Future<Map<String, dynamic>> getInventoryReport() async {
    final ep = '$baseUrl/products/inventory-report';
    _logRequest('GET', ep);

    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      debugPrint('=== getInventoryReport ${res.statusCode} ===');
      final body = _safeJson(res.body);
      return body is Map<String, dynamic> ? body : {'data': body};
    } catch (e) {
      debugPrint('getInventoryReport error: $e');
      return _error('getInventoryReport: $e');
    }
  }

  /// GET /products/stock-movements?type=all|in|out&startDate=&endDate=
  /// Returns: { responseCode, data: List<{ product_name, type, quantity, reason, created_at }> }
  static Future<List> getStockMovements({
    String? startDate,
    String? endDate,
    String type = 'all',
  }) async {
    final params = <String, String>{
      'type': type,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
    final uri = Uri.parse(
      '$baseUrl/products/stock-movements',
    ).replace(queryParameters: params);
    final ep = uri.toString();
    _logRequest('GET', ep);

    try {
      final res = await http.get(uri, headers: _authHeaders);
      debugPrint('=== getStockMovements [$type] ${res.statusCode} ===');
      final body = _safeJson(res.body);
      if (body is List) return body;
      return (body['data'] as List?) ?? [];
    } catch (e) {
      debugPrint('getStockMovements error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CUSTOMER REPORTS
  // ─────────────────────────────────────────────────────────────

  /// GET /customers?search=&page=&limit=
  /// Returns: { responseCode, data: List<Customer>, total, page, limit }
  static Future<Map<String, dynamic>> getCustomers({
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final uri = Uri.parse(
      '$baseUrl/customers',
    ).replace(queryParameters: params);
    final ep = uri.toString();
    _logRequest('GET', ep);

    try {
      final res = await http.get(uri, headers: _authHeaders);
      debugPrint('=== getCustomers ${res.statusCode} ===');
      final body = _safeJson(res.body);
      return body is Map<String, dynamic> ? body : {'data': body};
    } catch (e) {
      debugPrint('getCustomers error: $e');
      return _error('getCustomers: $e');
    }
  }

  /// GET /customers/:id/purchases
  /// Returns: List<Sale>
  static Future<List> getCustomerPurchases(int customerId) async {
    final ep = '$baseUrl/customers/$customerId/purchases';
    _logRequest('GET', ep);

    try {
      final res = await http.get(Uri.parse(ep), headers: _authHeaders);
      debugPrint('=== getCustomerPurchases $customerId ${res.statusCode} ===');
      final body = _safeJson(res.body);
      if (body is List) return body;
      return (body['data'] as List?) ?? [];
    } catch (e) {
      debugPrint('getCustomerPurchases error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // USER ACTIVITY REPORT
  // ─────────────────────────────────────────────────────────────

  /// GET /users/activity-report?startDate=&endDate=
  /// Returns: List<{ user_id, username, full_name, total_sales, total_revenue, date }>
  static Future<List> getUserActivityReport({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
    final uri = Uri.parse(
      '$baseUrl/users/activity-report',
    ).replace(queryParameters: params);
    final ep = uri.toString();
    _logRequest('GET', ep);

    try {
      final res = await http.get(uri, headers: _authHeaders);
      debugPrint('=== getUserActivityReport ${res.statusCode} ===');
      final body = _safeJson(res.body);
      if (body is List) return body;
      return (body['data'] as List?) ?? [];
    } catch (e) {
      debugPrint('getUserActivityReport error: $e');
      return [];
    }
  }

  // ==========================================
  // INTERNAL HELPERS
  // ==========================================

  /// Safe JSON decode — never throws, returns {} on failure
  static dynamic _safeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static void _logBox(String tag, String message) {
    developer.log(message, name: tag);
  }

  static void _logRequest(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) {
    final ts = DateTime.now();
    developer.log(
      '╔═══════════════════════════════════════════════════════════════',
      name: 'API_REQUEST',
    );
    developer.log('║ 🚀 $method  $url', name: 'API_REQUEST');
    developer.log('║ ⏰ ${ts.toIso8601String()}', name: 'API_REQUEST');
    developer.log(
      '║ 🔑 Token: ${_token != null ? "Present" : "None"}',
      name: 'API_REQUEST',
    );
    if (body != null && body.isNotEmpty) {
      final safe = Map<String, dynamic>.from(body);
      if (safe.containsKey('password')) safe['password'] = '********';
      final str = const JsonEncoder.withIndent('  ').convert(safe);
      for (final line in str.split('\n')) {
        developer.log('║   $line', name: 'API_REQUEST');
      }
    }
    developer.log(
      '╚═══════════════════════════════════════════════════════════════',
      name: 'API_REQUEST',
    );

    _logs.add(
      ApiLog(
        method: method,
        url: url,
        timestamp: ts,
        headers: Map<String, String>.from(_authHeaders),
        requestBody: body,
      ),
    );
    if (_logs.length > 100) _logs.removeAt(0);
  }

  static Map<String, dynamic> _handleWithLog(
    String method,
    String url,
    http.Response response, {
    Map<String, dynamic>? requestBody,
  }) {
    final ts = DateTime.now();
    final statusCode = response.statusCode;
    final isSuccess = statusCode == 200 || statusCode == 201;

    Map<String, dynamic>? responseBody;
    try {
      responseBody = jsonDecode(response.body);
    } catch (_) {
      responseBody = {'raw': response.body};
    }

    developer.log(
      '║ ${isSuccess ? '✅' : '❌'} $method $statusCode  $url',
      name: 'API_RESPONSE',
    );

    if (_logs.isNotEmpty) {
      final last = _logs.last;
      if (last.method == method && last.url == url) {
        last.responseTimestamp = ts;
        last.statusCode = statusCode;
        last.responseBody = responseBody;
        last.duration = ts.difference(last.timestamp);
      }
    }
    return _handle(response);
  }

  static Map<String, dynamic> _errorWithLog(
    String method,
    String url,
    String message,
    dynamic error, {
    Map<String, dynamic>? requestBody,
  }) {
    final ts = DateTime.now();
    developer.log('║ ❌ $method ERROR  $url  →  $error', name: 'API_ERROR');
    if (_logs.isNotEmpty) {
      final last = _logs.last;
      if (last.method == method && last.url == url) {
        last.responseTimestamp = ts;
        last.error = error.toString();
        last.duration = ts.difference(last.timestamp);
      }
    }
    return _error(message);
  }

  static Map<String, dynamic> _handle(http.Response response) {
    try {
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      final body = jsonDecode(response.body);
      return {
        'responseCode': body['responseCode'] ?? '99',
        'message': body['message'] ?? 'Server error: ${response.statusCode}',
      };
    } catch (_) {
      return {
        'responseCode': '99',
        'message': 'Server error: ${response.statusCode}',
      };
    }
  }

  static Map<String, dynamic> _error(String message) => {
    'responseCode': '99',
    'message': message,
  };
}

// ==========================================
// API LOG MODEL
// ==========================================
class ApiLog {
  final String method;
  final String url;
  final DateTime timestamp;
  final Map<String, String>? headers;
  final Map<String, dynamic>? requestBody;

  DateTime? responseTimestamp;
  int? statusCode;
  Map<String, dynamic>? responseBody;
  String? error;
  Duration? duration;

  ApiLog({
    required this.method,
    required this.url,
    required this.timestamp,
    this.headers,
    this.requestBody,
    this.responseTimestamp,
    this.statusCode,
    this.responseBody,
    this.error,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'method': method,
    'url': url,
    'timestamp': timestamp.toIso8601String(),
    'headers': headers,
    'requestBody': requestBody,
    'responseTimestamp': responseTimestamp?.toIso8601String(),
    'statusCode': statusCode,
    'responseBody': responseBody,
    'error': error,
    'durationMs': duration?.inMilliseconds,
  };
}
