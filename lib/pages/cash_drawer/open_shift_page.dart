// lib/pages/cash_drawer/open_shift_page.dart
//
// Shown BEFORE the cashier can use POS or create sales.
// Cashier enters opening cash amount → system opens a shift.
// If shift already open → redirects to main app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/cash_drawer_api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

class OpenShiftPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  /// Called after shift is successfully opened → navigate to main app
  final VoidCallback onShiftOpened;

  const OpenShiftPage({
    super.key,
    required this.currentUser,
    required this.onShiftOpened,
  });

  @override
  State<OpenShiftPage> createState() => _OpenShiftPageState();
}

class _OpenShiftPageState extends State<OpenShiftPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _amountCtrl =
      TextEditingController(text: '0');
  final TextEditingController _noteCtrl = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMsg;
  late AnimationController _animCtrl;

  String get _cashierName =>
      widget.currentUser['full_name'] ??
      widget.currentUser['username'] ??
      'Cashier';
  dynamic get _cashierId =>
      widget.currentUser['user_id'] ?? widget.currentUser['id'];

  String _formatCurrency(dynamic v) {
    final num val = num.tryParse(v.toString()) ?? 0;
    return '₭ ${val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        )}';
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _amountFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Quick amount buttons ───────────────────────────────────────────────────
  static const List<int> _quickAmounts = [
    0, 50000, 100000, 200000, 500000, 1000000
  ];

  Future<void> _openShift() async {
    final amount = num.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final body = {
        'cashier_id':     _cashierId,
        'cashier_name':   _cashierName,
        'opening_amount': amount,
        'note':           _noteCtrl.text.trim(),
        'opened_by':      widget.currentUser['username'] ?? 'unknown',
      };

      debugPrint('=== OPEN SHIFT: $body ===');
      final res = await CashDrawerApiService.openShift(body);
      debugPrint('=== OPEN SHIFT RESPONSE: $res ===');

      if (!mounted) return;

      if (res['responseCode'] == '00') {
        widget.onShiftOpened();
      } else {
        setState(() => _errorMsg = res['message'] ?? 'ເກີດຂໍ້ຜິດພາດ');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'ເຊື່ອມຕໍ່ບໍ່ໄດ້: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StockTheme.bgDarker,
      body: FadeTransition(
        opacity: _animCtrl,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo / Header ──────────────────────────────────────────
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      StockTheme.primary,
                      StockTheme.primary.withOpacity(0.7),
                    ]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: StockTheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.point_of_sale_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ເປີດກະ / Open Shift',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: StockTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'ສະບາຍດີ, $_cashierName',
                  style: TextStyle(
                      fontSize: 15,
                      color: StockTheme.textSecondary.withOpacity(0.7)),
                ),
                const SizedBox(height: 4),
                Text(
                  'ກະລຸນາປ້ອນເງິນເປີດໜ້ານ (Float Cash)',
                  style: TextStyle(
                      fontSize: 13,
                      color: StockTheme.textSecondary.withOpacity(0.5)),
                ),
                const SizedBox(height: 32),

                // ── Main Card ──────────────────────────────────────────────
                Container(
                  width: 480,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        StockTheme.bgDark.withOpacity(0.95),
                        StockTheme.bgCard.withOpacity(0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: StockTheme.primary.withOpacity(0.25),
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 40,
                          spreadRadius: -5),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info row
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: StockTheme.info.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: StockTheme.info.withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline_rounded,
                              size: 18, color: StockTheme.info),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'ຕ້ອງເປີດກະກ່ອນຈຶ່ງສາມາດຂາຍສິນຄ້າໄດ້\nYou must open a shift before making sales.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: StockTheme.info.withOpacity(0.9),
                                  height: 1.5),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // ── Opening Amount ────────────────────────────────
                      const Text('ເງິນເປີດໜ້ານ (Opening Cash)',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: StockTheme.textPrimary)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amountCtrl,
                        focusNode: _amountFocus,
                        style: const TextStyle(
                            color: StockTheme.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          prefixText: '₭  ',
                          prefixStyle: TextStyle(
                              color: StockTheme.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700),
                          filled: true,
                          fillColor: StockTheme.bgDarker.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: StockTheme.primary.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: StockTheme.primary.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: StockTheme.primary, width: 2),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 18),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9]')),
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // ── Quick Amount Buttons ──────────────────────────
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickAmounts.map((amt) {
                          final isSelected =
                              (_amountCtrl.text == '$amt');
                          return InkWell(
                            onTap: () => setState(
                                () => _amountCtrl.text = '$amt'),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? StockTheme.primary.withOpacity(0.2)
                                    : StockTheme.bgDarker.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? StockTheme.primary.withOpacity(0.6)
                                      : StockTheme.primary.withOpacity(0.12),
                                ),
                              ),
                              child: Text(
                                amt == 0
                                    ? '₭ 0'
                                    : '₭ ${amt.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? StockTheme.primary
                                        : StockTheme.textSecondary
                                            .withOpacity(0.6)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // ── Note ─────────────────────────────────────────
                      TextField(
                        controller: _noteCtrl,
                        style: const TextStyle(
                            color: StockTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'ໝາຍເຫດ (ທາງເລືອກ)',
                          labelStyle: TextStyle(
                              color: StockTheme.textSecondary.withOpacity(0.6),
                              fontSize: 13),
                          prefixIcon: Icon(Icons.notes_rounded,
                              color: StockTheme.textSecondary.withOpacity(0.4),
                              size: 18),
                          filled: true,
                          fillColor: StockTheme.bgDarker.withOpacity(0.3),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: StockTheme.primary.withOpacity(0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: StockTheme.primary.withOpacity(0.5)),
                          ),
                        ),
                        maxLines: 2,
                      ),

                      // ── Error ─────────────────────────────────────────
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: StockTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: StockTheme.error.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                color: StockTheme.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMsg!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: StockTheme.error)),
                            ),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Open Button ───────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _openShift,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StockTheme.primary,
                            disabledBackgroundColor:
                                StockTheme.primary.withOpacity(0.3),
                            padding:
                                const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 6,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.lock_open_rounded,
                                        color: Colors.white, size: 22),
                                    const SizedBox(width: 10),
                                    Column(
                                      children: [
                                        const Text('ເປີດກະ / Open Shift',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800)),
                                        Text(
                                          'ເງິນເປີດ: ${_formatCurrency(_amountCtrl.text.isEmpty ? '0' : _amountCtrl.text)}',
                                          style: TextStyle(
                                              color: Colors.white.withOpacity(0.7),
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}  •  ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      fontSize: 12,
                      color: StockTheme.textSecondary.withOpacity(0.3)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}