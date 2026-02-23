// lib/services/stock_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class StockApiService {
  static String get baseUrl => ApiService.baseUrl;
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${ApiService.token}',
      };

  // ============================================
  // PRODUCTS
  // ============================================
  static Future<List<dynamic>> getProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/products'), headers: headers);
    final data = json.decode(response.body);
    if (data is List) return data;
    if (data is Map) {
      if (data['responseCode'] == '00') return data['data'] ?? [];
      if (data['products'] != null) return data['products'];
    }
    return [];
  }

  // ============================================
  // SUPPLIERS
  // ============================================
  static Future<List<dynamic>> getSuppliers() async {
    final response = await http.get(Uri.parse('$baseUrl/suppliers'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> searchSuppliers(String keyword) async {
    final response = await http.get(Uri.parse('$baseUrl/suppliers/search?keyword=$keyword'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<Map<String, dynamic>> getSupplierById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/suppliers/$id'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/suppliers'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updateSupplier(int id, Map<String, dynamic> body) async {
    final response = await http.put(Uri.parse('$baseUrl/suppliers/$id'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteSupplier(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/suppliers/$id'), headers: headers);
    return json.decode(response.body);
  }

  // ============================================
  // WAREHOUSES
  // ============================================
  static Future<List<dynamic>> getWarehouses() async {
    final response = await http.get(Uri.parse('$baseUrl/warehouses'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<Map<String, dynamic>> getDefaultWarehouse() async {
    final response = await http.get(Uri.parse('$baseUrl/warehouses/default'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> createWarehouse(Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/warehouses'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updateWarehouse(int id, Map<String, dynamic> body) async {
    final response = await http.put(Uri.parse('$baseUrl/warehouses/$id'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteWarehouse(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/warehouses/$id'), headers: headers);
    return json.decode(response.body);
  }

  // ============================================
  // PURCHASE ORDERS
  // ============================================
  static Future<List<dynamic>> getPurchaseOrders() async {
    final response = await http.get(Uri.parse('$baseUrl/purchase-orders'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getPurchaseOrdersByStatus(String status) async {
    final response = await http.get(Uri.parse('$baseUrl/purchase-orders/status/$status'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<Map<String, dynamic>> getPurchaseOrderById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/purchase-orders/$id'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> createPurchaseOrder(Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/purchase-orders'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updatePurchaseOrder(int id, Map<String, dynamic> body) async {
    final response = await http.put(Uri.parse('$baseUrl/purchase-orders/$id'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updatePurchaseOrderStatus(int id, Map<String, dynamic> body) async {
    final response = await http.put(Uri.parse('$baseUrl/purchase-orders/$id/status'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> addPurchaseOrderItem(int poId, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/purchase-orders/$poId/items'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updatePurchaseOrderItem(int poItemId, Map<String, dynamic> body) async {
    final response = await http.put(Uri.parse('$baseUrl/purchase-orders/items/$poItemId'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deletePurchaseOrderItem(int poItemId) async {
    final response = await http.delete(Uri.parse('$baseUrl/purchase-orders/items/$poItemId'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deletePurchaseOrder(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/purchase-orders/$id'), headers: headers);
    return json.decode(response.body);
  }

  // ============================================
  // STOCK IN
  // ============================================
  static Future<List<dynamic>> getStockIn() async {
    final response = await http.get(Uri.parse('$baseUrl/stock-in'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getStockInByStatus(String status) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-in/status/$status'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<Map<String, dynamic>> getStockInById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-in/$id'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> createStockIn(Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/stock-in'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> confirmStockIn(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-in/$id/confirm'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> cancelStockIn(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-in/$id/cancel'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> addStockInItem(int stockInId, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/stock-in/$stockInId/items'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updateStockInItem(int itemId, Map<String, dynamic> body) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-in/items/$itemId'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteStockInItem(int itemId) async {
    final response = await http.delete(Uri.parse('$baseUrl/stock-in/items/$itemId'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteStockIn(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/stock-in/$id'), headers: headers);
    return json.decode(response.body);
  }

  // ============================================
  // STOCK OUT
  // ============================================
  static Future<List<dynamic>> getStockOut() async {
    final response = await http.get(Uri.parse('$baseUrl/stock-out'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getStockOutByStatus(String status) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-out/status/$status'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<Map<String, dynamic>> getStockOutById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-out/$id'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> createStockOut(Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/stock-out'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> confirmStockOut(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-out/$id/confirm'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> cancelStockOut(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-out/$id/cancel'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> addStockOutItem(int stockOutId, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/stock-out/$stockOutId/items'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updateStockOutItem(int itemId, Map<String, dynamic> body) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-out/items/$itemId'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteStockOutItem(int itemId) async {
    final response = await http.delete(Uri.parse('$baseUrl/stock-out/items/$itemId'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteStockOut(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/stock-out/$id'), headers: headers);
    return json.decode(response.body);
  }

  // ============================================
  // STOCK ADJUSTMENTS
  // ============================================
  static Future<List<dynamic>> getStockAdjustments() async {
    final response = await http.get(Uri.parse('$baseUrl/stock-adjustments'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<Map<String, dynamic>> getStockAdjustmentById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-adjustments/$id'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> createStockAdjustment(Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/stock-adjustments'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> confirmStockAdjustment(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-adjustments/$id/confirm'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> cancelStockAdjustment(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-adjustments/$id/cancel'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> addStockAdjustmentItem(int adjustmentId, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/stock-adjustments/$adjustmentId/items'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteStockAdjustmentItem(int itemId) async {
    final response = await http.delete(Uri.parse('$baseUrl/stock-adjustments/items/$itemId'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteStockAdjustment(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/stock-adjustments/$id'), headers: headers);
    return json.decode(response.body);
  }

  // ============================================
  // STOCK TRANSFERS
  // ============================================
  static Future<List<dynamic>> getStockTransfers() async {
    final response = await http.get(Uri.parse('$baseUrl/stock-transfers'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getStockTransfersByStatus(String status) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-transfers/status/$status'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<Map<String, dynamic>> getStockTransferById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-transfers/$id'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> createStockTransfer(Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/stock-transfers'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> dispatchStockTransfer(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-transfers/$id/dispatch'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> receiveStockTransfer(int id, {Map<String, dynamic>? body}) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-transfers/$id/receive'), headers: headers, body: body != null ? json.encode(body) : null);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> cancelStockTransfer(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/stock-transfers/$id/cancel'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> addStockTransferItem(int transferId, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl/stock-transfers/$transferId/items'), headers: headers, body: json.encode(body));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteStockTransferItem(int itemId) async {
    final response = await http.delete(Uri.parse('$baseUrl/stock-transfers/items/$itemId'), headers: headers);
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> deleteStockTransfer(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/stock-transfers/$id'), headers: headers);
    return json.decode(response.body);
  }

  // ============================================
  // STOCK MOVEMENTS (Read-only)
  // ============================================
  static Future<List<dynamic>> getStockMovements({int limit = 100, int offset = 0}) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-movements?limit=$limit&offset=$offset'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getStockMovementsByProduct(int productId) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-movements/product/$productId'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getStockMovementsByWarehouse(int warehouseId) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-movements/warehouse/$warehouseId'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getStockMovementsByType(String movementType) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-movements/type/$movementType'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getStockMovementsByDateRange(String startDate, String endDate) async {
    final response = await http.get(Uri.parse('$baseUrl/stock-movements/date-range?startDate=$startDate&endDate=$endDate'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getStockSummary() async {
    final response = await http.get(Uri.parse('$baseUrl/stock-movements/summary/stock'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getStockValue() async {
    final response = await http.get(Uri.parse('$baseUrl/stock-movements/summary/value'), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }

  static Future<List<dynamic>> getStockMovementSummaryByType({String? startDate, String? endDate}) async {
    String url = '$baseUrl/stock-movements/summary/by-type';
    if (startDate != null && endDate != null) {
      url += '?startDate=$startDate&endDate=$endDate';
    }
    final response = await http.get(Uri.parse(url), headers: headers);
    final data = json.decode(response.body);
    if (data['responseCode'] == '00') return data['data'] ?? [];
    return [];
  }
}