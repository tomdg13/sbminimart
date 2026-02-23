// lib/services/cash_drawer_api_service.dart
//
// Cash Drawer / Shift Management API Service
// Handles: open shift, get active shift, close shift, cash in/out transactions
//
// Backend endpoints needed:
//   POST   /cash-drawer/open         - Open a new shift
//   GET    /cash-drawer/active        - Get currently active shift for user
//   GET    /cash-drawer/:id           - Get shift by ID
//   GET    /cash-drawer               - Get all shifts (history)
//   POST   /cash-drawer/:id/close     - Close shift with settlement
//   POST   /cash-drawer/:id/cash-in   - Add cash in during shift
//   POST   /cash-drawer/:id/cash-out  - Remove cash out during shift
//   GET    /cash-drawer/:id/summary   - Get shift summary (sales, cash movements)

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

class CashDrawerApiService {
  static String get baseUrl => ApiService.baseUrl;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (ApiService.token != null)
          'Authorization': 'Bearer ${ApiService.token}',
      };

  static void _log(String method, String url,
      {String? body, int? status, String? response, String? error}) {
    debugPrint('');
    debugPrint('╔══ CASH DRAWER: $method $url');
    if (body != null) debugPrint('╠── BODY: $body');
    if (status != null) debugPrint('╠── STATUS: $status');
    if (response != null) debugPrint('╠── RESPONSE: $response');
    if (error != null) debugPrint('╠── ERROR: $error');
    debugPrint('╚══════════════════════════════');
  }

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
      return {
        'responseCode': '99',
        'message': 'Server error: ${res.statusCode}'
      };
    }
  }

  // ── GET active shift for a user ──────────────────────────────────────────
  /// Returns the currently open shift for the given cashier.
  /// Response: { responseCode: '00', data: { id, cashier_id, opening_amount, ... } }
  /// If no active shift: { responseCode: '01', message: 'No active shift' }
  static Future<Map<String, dynamic>> getActiveShift(dynamic cashierId) async {
    final url = '$baseUrl/cash-drawer/active?cashier_id=$cashierId';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('GET', url, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ── OPEN a new shift ─────────────────────────────────────────────────────
  /// Opens a new cash drawer shift.
  /// body: {
  ///   cashier_id, cashier_name, opening_amount (float),
  ///   note (optional), opened_by
  /// }
  static Future<Map<String, dynamic>> openShift(
      Map<String, dynamic> body) async {
    final url = '$baseUrl/cash-drawer/open';
    final bodyJson = jsonEncode(body);
    try {
      _log('POST', url, body: bodyJson);
      final res = await http.post(Uri.parse(url),
          headers: _headers, body: bodyJson);
      _log('POST', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('POST', url, body: bodyJson, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ── CLOSE a shift (Daily Close / Settlement) ─────────────────────────────
  /// Closes a shift with settlement.
  /// body: {
  ///   closing_amount (float) - actual cash counted by cashier,
  ///   note (optional),
  ///   closed_by
  /// }
  static Future<Map<String, dynamic>> closeShift(
      dynamic shiftId, Map<String, dynamic> body) async {
    final url = '$baseUrl/cash-drawer/$shiftId/close';
    final bodyJson = jsonEncode(body);
    try {
      _log('POST', url, body: bodyJson);
      final res = await http.post(Uri.parse(url),
          headers: _headers, body: bodyJson);
      _log('POST', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('POST', url, body: bodyJson, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ── GET shift by ID ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getShiftById(dynamic shiftId) async {
    final url = '$baseUrl/cash-drawer/$shiftId';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('GET', url, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ── GET shift history (all shifts) ──────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getShiftHistory(
      {dynamic cashierId, String? startDate, String? endDate}) async {
    final params = <String, String>{
      if (cashierId != null) 'cashier_id': '$cashierId',
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
    final uri = Uri.parse('$baseUrl/cash-drawer')
        .replace(queryParameters: params.isEmpty ? null : params);
    try {
      final res = await http.get(uri, headers: _headers);
      _log('GET', uri.toString(), status: res.statusCode, response: res.body);
      final data = _handle(res);
      return (data['data'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      _log('GET', uri.toString(), error: e.toString());
      return [];
    }
  }

  // ── GET shift summary (expected cash, sales total, etc.) ─────────────────
  static Future<Map<String, dynamic>> getShiftSummary(dynamic shiftId) async {
    final url = '$baseUrl/cash-drawer/$shiftId/summary';
    try {
      final res = await http.get(Uri.parse(url), headers: _headers);
      _log('GET', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('GET', url, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ── Cash IN (add cash during shift) ─────────────────────────────────────
  /// body: { amount, reason, created_by }
  static Future<Map<String, dynamic>> cashIn(
      dynamic shiftId, Map<String, dynamic> body) async {
    final url = '$baseUrl/cash-drawer/$shiftId/cash-in';
    final bodyJson = jsonEncode(body);
    try {
      _log('POST', url, body: bodyJson);
      final res = await http.post(Uri.parse(url),
          headers: _headers, body: bodyJson);
      _log('POST', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('POST', url, body: bodyJson, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }

  // ── Cash OUT (remove cash during shift) ──────────────────────────────────
  /// body: { amount, reason, created_by }
  static Future<Map<String, dynamic>> cashOut(
      dynamic shiftId, Map<String, dynamic> body) async {
    final url = '$baseUrl/cash-drawer/$shiftId/cash-out';
    final bodyJson = jsonEncode(body);
    try {
      _log('POST', url, body: bodyJson);
      final res = await http.post(Uri.parse(url),
          headers: _headers, body: bodyJson);
      _log('POST', url, status: res.statusCode, response: res.body);
      return _handle(res);
    } catch (e) {
      _log('POST', url, body: bodyJson, error: e.toString());
      return {'responseCode': '99', 'message': e.toString()};
    }
  }
}