// lib/services/sale_api_service.dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

class SaleApiService {
  static String get baseUrl => ApiService.baseUrl;
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (ApiService.token != null) 'Authorization': 'Bearer ${ApiService.token}',
      };

  // ── Internal logger ───────────────────────────────────────────────────────
  static void _log(String method, String url, {String? body, int? status, String? response, String? error}) {
    debugPrint('');
    debugPrint('╔══ API: $method $url');
    if (body != null)     debugPrint('╠── BODY: $body');
    if (status != null)   debugPrint('╠── STATUS: $status');
    if (response != null) debugPrint('╠── RESPONSE: $response');
    if (error != null)    debugPrint('╠── ERROR: $error');
    debugPrint('╚══════════════════════════════');
  }

  // ── Internal response handler ─────────────────────────────────────────────
  static Map<String, dynamic> _handle(http.Response res) {
    try {
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      }
      final body = jsonDecode(res.body);
      return {
        'responseCode': body['responseCode'] ?? '99',
        'message': body['message'] ?? 'Server error: ${res.statusCode}',
      };
    } catch (_) {
      return {'responseCode': '99', 'message': 'Server error: ${res.statusCode}'};
    }
  }

  // ──────────────────────────────────────────────
  // GET /sales
  // ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getSales() async {
    final url = '$baseUrl/sales';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      final data = _handle(res);
      return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      _log('GET', url, error: e.toString());
      return [];
    }
  }

  // ──────────────────────────────────────────────
  // GET /sales/summary
  // ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSalesSummary() async {
    final url = '$baseUrl/sales/summary';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('GET', url, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ──────────────────────────────────────────────
  // GET /sales/search?keyword=
  // ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> searchSales(String keyword) async {
    final url = '$baseUrl/sales/search?keyword=${Uri.encodeComponent(keyword)}';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      final data = _handle(res);
      return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      _log('GET', url, error: e.toString());
      return [];
    }
  }

  // ──────────────────────────────────────────────
  // GET /sales/date-range?startDate=&endDate=
  // ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getSalesByDateRange(
      String startDate, String endDate) async {
    final url = '$baseUrl/sales/date-range?startDate=$startDate&endDate=$endDate';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      final data = _handle(res);
      return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      _log('GET', url, error: e.toString());
      return [];
    }
  }

  // ──────────────────────────────────────────────
  // GET /sales/:id
  // ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSaleById(dynamic id) async {
    final url = '$baseUrl/sales/$id';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('GET', url, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ──────────────────────────────────────────────
  // GET /products/barcode/:code
  // ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> getProductByBarcode(String code) async {
    final url = '$baseUrl/products/barcode/${Uri.encodeComponent(code)}';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('GET', url, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ──────────────────────────────────────────────
  // POST /sales
  // ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> createSale(Map<String, dynamic> body) async {
    final url = '$baseUrl/sales';
    final bodyJson = jsonEncode(body);
    try {
      _log('POST', url, body: bodyJson);
      final res = await http.post(Uri.parse(url), headers: _headers, body: bodyJson);
      _log('POST', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('POST', url, body: bodyJson, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ──────────────────────────────────────────────
  // PUT /sales/:id
  // ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateSale(
      dynamic id, Map<String, dynamic> body) async {
    final url = '$baseUrl/sales/$id';
    final bodyJson = jsonEncode(body);
    try {
      _log('PUT', url, body: bodyJson);
      final res = await http.put(Uri.parse(url), headers: _headers, body: bodyJson);
      _log('PUT', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('PUT', url, body: bodyJson, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ──────────────────────────────────────────────
  // POST /sales/:id/cancel
  // ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> cancelSale(dynamic id, {String? reason, String? cancelledBy}) async {
    final url = '$baseUrl/sales/$id/cancel';
    final bodyJson = jsonEncode({
      'reason': reason ?? 'Cancelled',
      'cancelled_by': cancelledBy ?? 'admin',
    });
    try {
      _log('POST', url, body: bodyJson);
      final res = await http.post(Uri.parse(url), headers: _headers, body: bodyJson);
      _log('POST', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('POST', url, body: bodyJson, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ──────────────────────────────────────────────
  // DELETE /sales/:id
  // ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> deleteSale(dynamic id) async {
    final url = '$baseUrl/sales/$id';
    try {
      _log('DELETE', url);
      final res = await http.delete(Uri.parse(url), headers: _headers);
      _log('DELETE', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('DELETE', url, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ──────────────────────────────────────────────
  // DAILY CLOSE
  // ──────────────────────────────────────────────

  // GET /daily-close/preview
  static Future<Map<String, dynamic>> getDailyClosePreview() async {
    final url = '$baseUrl/daily-close/preview';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('GET', url, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // GET /daily-close
  static Future<Map<String, dynamic>> getDailyCloseHistory() async {
    final url = '$baseUrl/daily-close';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('GET', url, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // POST /daily-close
  static Future<Map<String, dynamic>> closeDay(Map<String, dynamic> body) async {
    final url = '$baseUrl/daily-close';
    final bodyJson = jsonEncode(body);
    try {
      _log('POST', url, body: bodyJson);
      final res = await http.post(Uri.parse(url), headers: _headers, body: bodyJson);
      _log('POST', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('POST', url, body: bodyJson, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }
}