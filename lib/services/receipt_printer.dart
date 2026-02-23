// lib/services/receipt_printer.dart
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class ReceiptPrinter {
  // ── Status callbacks ─────────────────────────────────────────────────
  static Function(bool paired, String label)? onStatusChanged;

  /// Call once in main.dart
  static void initCashDrawer() {
    if (!kIsWeb) return;
    js.context.callMethod('eval', [
      r'''
      window.__drawerReady  = false;
      window.__usbPrinter   = null;
      window.__drawerStatus = 'not_paired'; // not_paired | pairing | ready | error

      function __notifyFlutter(status, label) {
        window.__drawerStatus = status;
        if (window.__onDrawerStatus) window.__onDrawerStatus(status, label);
      }

      // ── Auto-try to reconnect previously paired device ─────────────
      window.__autoConnectDrawer = async function() {
        try {
          if (!navigator.usb) {
            __notifyFlutter('error', 'WebUSB not supported');
            return false;
          }
          const devices = await navigator.usb.getDevices();
          if (devices.length === 0) {
            __notifyFlutter('not_paired', 'ບໍ່ມີ Printer');
            return false;
          }
          window.__usbPrinter  = devices[0];
          window.__drawerReady = true;
          const name = devices[0].productName || ('ID:' + devices[0].vendorId);
          __notifyFlutter('ready', name);
          console.log('[CashDrawer] Auto-connected:', name);
          return true;
        } catch(e) {
          __notifyFlutter('error', e.message || 'Error');
          return false;
        }
      };

      // ── Manual pair (needs user gesture) ──────────────────────────
      window.__pairDrawer = async function() {
        try {
          if (!navigator.usb) {
            __notifyFlutter('error', 'WebUSB not supported');
            return false;
          }
          __notifyFlutter('pairing', 'Pairing...');
          let devices = await navigator.usb.getDevices();
          if (devices.length === 0) {
            const d = await navigator.usb.requestDevice({ filters: [] });
            devices = [d];
          }
          window.__usbPrinter  = devices[0];
          window.__drawerReady = true;
          const name = devices[0].productName || ('ID:' + devices[0].vendorId);
          __notifyFlutter('ready', name);
          console.log('[CashDrawer] Paired:', name);
          return true;
        } catch(e) {
          __notifyFlutter('error', e.message || 'Pair failed');
          console.error('[CashDrawer] Pair error:', e.message);
          return false;
        }
      };

      // ── Open cash drawer ──────────────────────────────────────────
      window.__openDrawer = async function() {
        if (!window.__drawerReady || !window.__usbPrinter) {
          console.warn('[CashDrawer] Not paired');
          return false;
        }
        try {
          const printer = window.__usbPrinter;
          if (printer.opened) { try { await printer.close(); } catch(_){} }
          await printer.open();
          if (printer.configuration === null) await printer.selectConfiguration(1);

          let claimedIface = null, endpoint = null;
          for (const iface of printer.configuration.interfaces) {
            try {
              await printer.claimInterface(iface.interfaceNumber);
              claimedIface = iface;
              endpoint = iface.alternate.endpoints.find(
                e => e.direction === 'out' && e.type === 'bulk'
              );
              if (endpoint) break;
              await printer.releaseInterface(iface.interfaceNumber);
              claimedIface = null;
            } catch(e) { console.warn('[CashDrawer] iface error:', e.message); }
          }

          if (!endpoint || !claimedIface) {
            console.error('[CashDrawer] No bulk OUT endpoint found');
            try { await printer.close(); } catch(_){}
            __notifyFlutter('error', 'No endpoint');
            return false;
          }

          // ESC p 0x00 0x32 0xFF — open drawer pin2
          const cmd = new Uint8Array([0x1B, 0x70, 0x00, 0x32, 0xFF]);
          const res = await printer.transferOut(endpoint.endpointNumber, cmd);
          await printer.releaseInterface(claimedIface.interfaceNumber);
          await printer.close();

          if (res.status === 'ok') {
            console.log('[CashDrawer] ✅ Drawer opened!');
            return true;
          } else {
            console.error('[CashDrawer] transferOut:', res.status);
            return false;
          }
        } catch(err) {
          console.error('[CashDrawer] Error:', err.message);
          window.__drawerReady = false;
          window.__usbPrinter  = null;
          __notifyFlutter('error', err.message || 'Error');
          return false;
        }
      };

      console.log('[CashDrawer] Init OK');
      // Auto-connect on startup
      window.__autoConnectDrawer();
    ''',
    ]);
  }

  /// Register a Dart callback to receive status updates from JS.
  /// Uses polling instead of JS→Dart callback (avoids allowInterop issues).
  static void setStatusCallback(Function(bool paired, String label) cb) {
    onStatusChanged = cb;
    if (!kIsWeb) return;
    // Poll JS status every 2 seconds
    _startPolling();
  }

  static bool _polling = false;
  static void _startPolling() {
    if (_polling) return;
    _polling = true;
    _poll();
  }

  static void _poll() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!_polling) return;
    try {
      final status = js.context['__drawerStatus']?.toString() ?? 'not_paired';
      final printer = js.context['__usbPrinter'];
      String label = 'ບໍ່ໄດ້ເຊື່ອມ';
      if (printer != null) {
        final name = printer['productName']?.toString() ?? '';
        final vid = printer['vendorId']?.toString() ?? '';
        label = name.isNotEmpty ? name : 'ID:$vid';
      }
      if (status == 'pairing') label = 'Pairing...';
      if (status == 'error') label = 'Error';
      final paired = status == 'ready';
      onStatusChanged?.call(paired, paired ? label : 'ບໍ່ໄດ້ເຊື່ອມ');
    } catch (_) {}
    _poll(); // recursive polling
  }

  static void stopPolling() {
    _polling = false;
  }

  /// Poll current status (call on page init)
  static void refreshStatus() {
    if (!kIsWeb) return;
    js.context.callMethod('eval', [
      'window.__autoConnectDrawer && window.__autoConnectDrawer()',
    ]);
  }

  /// Show HTML overlay button (real user gesture for WebUSB requestDevice)
  static void pairPrinter() {
    if (!kIsWeb) return;
    final script = """
(function() {
  var old = document.getElementById('__pair_overlay__');
  if (old) old.remove();

  // Overlay backdrop
  var overlay = document.createElement('div');
  overlay.id = '__pair_overlay__';
  overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.7);z-index:99998;display:flex;align-items:center;justify-content:center;';

  // Card
  var card = document.createElement('div');
  card.style.cssText = 'background:#0D2045;border:1px solid #2563EB;border-radius:16px;padding:32px 40px;text-align:center;min-width:320px;box-shadow:0 8px 40px rgba(37,99,235,0.4);';

  var title = document.createElement('div');
  title.innerText = '🖨️ Pair Printer';
  title.style.cssText = 'color:#E2E8F0;font-size:20px;font-weight:bold;margin-bottom:8px;';

  var sub = document.createElement('div');
  sub.innerText = 'ກົດ button ດ້ານລຸ່ມ ແລ້ວ ເລືອກ AN581 printer';
  sub.style.cssText = 'color:#94A3B8;font-size:13px;margin-bottom:24px;';

  var btn = document.createElement('button');
  btn.innerText = 'ເລືອກ Printer';
  btn.style.cssText = 'background:#2563EB;color:white;border:none;border-radius:10px;padding:14px 32px;font-size:16px;font-weight:bold;cursor:pointer;width:100%;';

  var status = document.createElement('div');
  status.style.cssText = 'color:#94A3B8;font-size:12px;margin-top:16px;min-height:20px;';

  var closeBtn = document.createElement('button');
  closeBtn.innerText = 'ປິດ';
  closeBtn.style.cssText = 'background:transparent;color:#60A5FA;border:1px solid #1D4ED8;border-radius:8px;padding:8px 24px;font-size:13px;cursor:pointer;margin-top:12px;width:100%;';
  closeBtn.onclick = function() { overlay.remove(); };

  btn.onclick = async function() {
    btn.innerText = 'Pairing...';
    btn.disabled = true;
    status.innerText = '';
    try {
      const ok = await window.__pairDrawer();
      if (ok) {
        btn.innerText = '✅ Paired!';
        btn.style.background = '#10B981';
        const name = window.__usbPrinter ? (window.__usbPrinter.productName || 'Printer') : 'Printer';
        status.style.color = '#10B981';
        status.innerText = 'Connected: ' + name;
        setTimeout(function() { overlay.remove(); }, 1500);
      } else {
        btn.innerText = 'ລອງໃໝ່';
        btn.disabled = false;
        status.style.color = '#EF4444';
        status.innerText = 'Failed — ກົດ ເລືອກ Printer ອີກຄັ້ງ';
      }
    } catch(e) {
      btn.innerText = 'ລອງໃໝ່';
      btn.disabled = false;
      status.style.color = '#EF4444';
      status.innerText = e.message || 'Error';
    }
  };

  card.appendChild(title);
  card.appendChild(sub);
  card.appendChild(btn);
  card.appendChild(status);
  card.appendChild(closeBtn);
  overlay.appendChild(card);
  document.body.appendChild(overlay);
})();
""";
    js.context.callMethod('eval', [script]);
  }

  /// Open cash drawer
  static void openCashDrawer() {
    if (!kIsWeb) return;
    final isPaired = js.context['__drawerReady'];
    if (isPaired != true) {
      pairPrinter();
      return;
    }
    js.context.callMethod('eval', [
      'window.__openDrawer && window.__openDrawer()',
    ]);
  }

  /// Print receipt via hidden iframe
  static void printReceipt({
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
    String shopName = 'iShop',
    String shopAddress = 'ວຽງຈັນ, ລາວ',
    String shopPhone = '',
    String shopTaxId = '',
  }) {
    if (!kIsWeb) return;
    final html = _buildReceiptHtml(
      sale: sale,
      items: items,
      shopName: shopName,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      shopTaxId: shopTaxId,
    );
    _printViaIframe(html);
  }

  static void _printViaIframe(String receiptHtml) {
    final escaped = _jsStringLiteral(receiptHtml);
    final script =
        """
(function() {
  var old = document.getElementById('__receipt_frame__');
  if (old) old.remove();
  var iframe = document.createElement('iframe');
  iframe.id = '__receipt_frame__';
  iframe.style.cssText = 'position:fixed;right:0;bottom:0;width:1px;height:1px;border:0;opacity:0;pointer-events:none;';
  document.body.appendChild(iframe);
  var doc = iframe.contentWindow.document;
  doc.open();
  doc.write($escaped);
  doc.close();
  iframe.onload = function() {
    setTimeout(function() {
      try {
        iframe.contentWindow.focus();
        iframe.contentWindow.print();
        console.log('[Receipt] Print dialog opened');
      } catch(e) {
        console.error('[Receipt] Print error:', e.message);
      }
      setTimeout(function() {
        var f = document.getElementById('__receipt_frame__');
        if (f) f.remove();
      }, 5000);
    }, 500);
  };
})();
""";
    js.context.callMethod('eval', [script]);
    debugPrint('[Receipt] printViaIframe called');
  }

  static String _jsStringLiteral(String s) =>
      '`${s.replaceAll('\\', '\\\\').replaceAll('`', '\\`').replaceAll('\${', '\\\${')}`';

  static String _formatCurrency(dynamic value) {
    if (value == null) return '0';
    final num v = num.tryParse(value.toString()) ?? 0;
    return v
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  static String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
    }
  }

  static String _paymentLabel(String? m) {
    switch (m) {
      case 'cash':
        return 'ເງິນສົດ';
      case 'card':
        return 'ບັດ';
      case 'transfer':
        return 'ໂອນ';
      case 'credit':
        return 'ສິນເຊື່ອ';
      default:
        return m ?? 'ເງິນສົດ';
    }
  }

  static String _buildReceiptHtml({
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required String shopTaxId,
  }) {
    final saleNumber = sale['sale_number'] ?? 'SALE-${sale['id']}';
    final cashier = sale['cashier'] ?? sale['created_by'] ?? '-';
    final saleDate = _formatDate(sale['sale_date'] ?? sale['created_at']);
    final paymentMethod = _paymentLabel(sale['payment_method']);
    final totalAmount = _formatCurrency(sale['total_amount']);
    final discountAmount =
        num.tryParse((sale['discount_amount'] ?? 0).toString()) ?? 0;
    final subtotal = items.fold<double>(
      0,
      (s, i) =>
          s +
          ((num.tryParse(i['unit_price'].toString()) ?? 0) *
              (i['quantity'] as int? ?? 1)),
    );

    final itemRows = items
        .map((item) {
          final name = (item['product_name_la'] as String?)?.isNotEmpty == true
              ? item['product_name_la'] as String
              : (item['display_name'] as String?)?.isNotEmpty == true
              ? item['display_name'] as String
              : (item['product_name'] as String?) ?? '-';
          final qty = item['quantity'] ?? 1;
          final price = num.tryParse(item['unit_price'].toString()) ?? 0;
          final sub = price * (qty as int);
          return '''
        <tr>
          <td class="item-name">$name</td>
          <td class="center">$qty</td>
          <td class="right">${_formatCurrency(price)}</td>
          <td class="right bold">${_formatCurrency(sub)}</td>
        </tr>''';
        })
        .join('\n');

    final discountRow = discountAmount > 0
        ? '''
      <tr class="discount-row">
        <td colspan="3" class="right">ສ່ວນຫຼຸດ</td>
        <td class="right">- ${_formatCurrency(discountAmount)}</td>
      </tr>'''
        : '';

    final taxIdRow = shopTaxId.isNotEmpty ? '<p>ທະບຽນພາສີ: $shopTaxId</p>' : '';
    final phoneRow = shopPhone.isNotEmpty ? '<p>ໂທ: $shopPhone</p>' : '';

    return '''<!DOCTYPE html>
<html><head>
  <meta charset="UTF-8">
  <title>Receipt - $saleNumber</title>
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { font-family:'Phetsarath OT','Noto Sans Lao','Courier New',monospace; font-size:20px; color:#000; background:#fff; width:80mm; margin:0 auto; padding:4mm 3mm; }
    .header { text-align:center; margin-bottom:8px; border-bottom:1px dashed #000; padding-bottom:8px; }
    .shop-name { font-size:32px; font-weight:bold; letter-spacing:2px; margin-bottom:4px; }
    .header p { font-size:20px; color:#333; line-height:1.6; }
    .sale-info { margin:8px 0; border-bottom:1px dashed #000; padding-bottom:8px; }
    .sale-info table { width:100%; border-collapse:collapse; }
    .sale-info td { padding:3px 0; font-size:20px; }
    .sale-info td:first-child { color:#555; width:45%; }
    .sale-info td:last-child { font-weight:bold; }
    .items-header { font-size:20px; font-weight:bold; border-bottom:1px solid #000; border-top:1px solid #000; padding:3px 0; margin:6px 0 2px; }
    .items-header table, .items-table { width:100%; border-collapse:collapse; }
    .items-header th { font-size:20px; padding:3px 1px; }
    .items-table td { font-size:20px; padding:4px 1px; vertical-align:top; }
    .items-table tr:not(:last-child) td { border-bottom:1px dotted #ccc; }
    .item-name { width:42%; word-break:break-word; line-height:1.5; }
    .totals { border-top:1px dashed #000; margin-top:4px; padding-top:4px; }
    .totals table { width:100%; border-collapse:collapse; }
    .totals td { padding:4px 1px; font-size:20px; }
    .discount-row td { color:#c00; }
    .total-final td { font-size:24px; font-weight:bold; border-top:1px solid #000; padding-top:5px; }
    .payment-row td { font-size:20px; color:#333; }
    .footer { text-align:center; margin-top:10px; border-top:1px dashed #000; padding-top:8px; font-size:20px; color:#555; line-height:1.8; }
    .thank-you { font-size:22px; font-weight:bold; color:#000; }
    .center { text-align:center; } .right { text-align:right; } .bold { font-weight:bold; }
    @media print { @page { size:80mm auto; margin:0; } body { width:80mm; padding:3mm 2mm; } }
    @media screen { body { margin:20px auto; border:1px dashed #ccc; padding:10px; } }
  </style>
</head>
<body>
  <div class="header">
    <div class="shop-name">$shopName</div>
    <p>$shopAddress</p>$phoneRow$taxIdRow
  </div>
  <div class="sale-info">
    <table>
      <tr><td>ເລກທີ:</td><td>$saleNumber</td></tr>
      <tr><td>ວັນທີ:</td><td>$saleDate</td></tr>
      <tr><td>ພະນັກງານ:</td><td>$cashier</td></tr>
      <tr><td>ຊຳລະ:</td><td>$paymentMethod</td></tr>
    </table>
  </div>
  <div class="items-header">
    <table><tr>
      <th style="text-align:left" class="item-name">ລາຍການ</th>
      <th class="center">ຈຳ</th>
      <th class="right">ລາຄາ</th>
      <th class="right">ລວມ</th>
    </tr></table>
  </div>
  <table class="items-table">$itemRows</table>
  <div class="totals">
    <table>
      <tr><td colspan="3" class="right">ລາຄາລວມ</td><td class="right">${_formatCurrency(subtotal)} ₭</td></tr>
      $discountRow
      <tr class="total-final"><td colspan="3" class="right">ຍອດລວມທັງໝົດ</td><td class="right">$totalAmount ₭</td></tr>
      <tr class="payment-row"><td colspan="3" class="right">ວິທີຊຳລະ</td><td class="right">$paymentMethod</td></tr>
    </table>
  </div>
  <div class="footer">
    <p class="thank-you">ຂອບໃຈທີ່ໃຊ້ບໍລິການ!</p>
    <p>Thank you for your purchase</p>
    <p style="margin-top:6px;font-size:10px;color:#aaa;">*** $shopName ***</p>
  </div>
</body></html>''';
  }
}
