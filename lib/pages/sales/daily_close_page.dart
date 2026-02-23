// lib/pages/sales/daily_close_page.dart
//
// End-of-shift settlement page.
// Cashier counts actual cash in drawer, system calculates:
//   Expected = Opening + Cash Sales + Cash In - Cash Out
//   Difference = Actual - Expected  (positive = over, negative = short)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/cash_drawer_api_service.dart';
import '../../widgets/stock_ui_helpers.dart';

class DailyClosePage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  /// The currently active shift — fetched by the dashboard before navigating here
  final Map<String, dynamic> activeShift;

  /// Called after shift is successfully closed → dashboard navigates home
  final VoidCallback onShiftClosed;

  const DailyClosePage({
    super.key,
    required this.currentUser,
    required this.activeShift,
    required this.onShiftClosed,
  });

  @override
  State<DailyClosePage> createState() => _DailyClosePageState();
}

class _DailyClosePageState extends State<DailyClosePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _actualCashCtrl =
      TextEditingController(text: '0');
  final TextEditingController _noteCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isFetchingSummary = true;
  String? _errorMsg;
  Map<String, dynamic> _summary = {};
  late AnimationController _animCtrl;

  dynamic get _shiftId =>
      widget.activeShift['id'] ?? widget.activeShift['shift_id'];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fetchSummary();
  }

  @override
  void dispose() {
    _actualCashCtrl.dispose();
    _noteCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSummary() async {
    setState(() => _isFetchingSummary = true);
    try {
      final res = await CashDrawerApiService.getShiftSummary(_shiftId);
      debugPrint('=== SHIFT SUMMARY: $res ===');
      if (!mounted) return;
      if (res['responseCode'] == '00') {
        setState(() => _summary = res['data'] ?? {});
      }
    } catch (e) {
      debugPrint('Shift summary error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingSummary = false);
    }
  }

  String _formatCurrency(dynamic v) {
    final num val = num.tryParse(v.toString()) ?? 0;
    return '₭ ${val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        )}';
  }

  // ── Computed values ───────────────────────────────────────────────────────
  double get _openingAmount => (num.tryParse(
              (widget.activeShift['opening_amount'] ??
                      _summary['opening_amount'] ??
                      '0')
                  .toString()) ??
          0)
      .toDouble();

  double get _cashSalesTotal =>
      (num.tryParse((_summary['cash_sales_total'] ?? '0').toString()) ?? 0)
          .toDouble();

  double get _cashInTotal =>
      (num.tryParse((_summary['cash_in_total'] ?? '0').toString()) ?? 0)
          .toDouble();

  double get _cashOutTotal =>
      (num.tryParse((_summary['cash_out_total'] ?? '0').toString()) ?? 0)
          .toDouble();

  double get _expectedCash =>
      _openingAmount + _cashSalesTotal + _cashInTotal - _cashOutTotal;

  double get _actualCash =>
      (num.tryParse(_actualCashCtrl.text.replaceAll(',', '')) ?? 0).toDouble();

  double get _difference => _actualCash - _expectedCash;

  bool get _isOver => _difference > 0;
  bool get _isShort => _difference < 0;

  // ── Close shift ───────────────────────────────────────────────────────────
  Future<void> _closeShift() async {
    final confirmed = await showStockConfirmDialog(
      context,
      title: 'ປິດກະ / Close Shift',
      message:
          'ຢືນຢັນປິດກະ?\nຍອດຈຳໜ່າຍ: ${_formatCurrency(_cashSalesTotal)}\nເງິນຕົວຈິງ: ${_formatCurrency(_actualCash)}',
      confirmLabel: 'ປິດກະ',
      confirmColor: _isShort ? StockTheme.error : StockTheme.success,
    );
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final body = {
        'closing_amount':  _actualCash,
        'expected_amount': _expectedCash,
        'difference':      _difference,
        'note':            _noteCtrl.text.trim(),
        'closed_by':       widget.currentUser['username'] ?? 'unknown',
        'summary': {
          'opening_amount':     _openingAmount,
          'cash_sales_total':   _cashSalesTotal,
          'cash_in_total':      _cashInTotal,
          'cash_out_total':     _cashOutTotal,
          'total_sales':        _summary['total_sales'] ?? 0,
          'total_transactions': _summary['total_transactions'] ?? 0,
        },
      };

      debugPrint('=== CLOSE SHIFT: $body ===');
      final res = await CashDrawerApiService.closeShift(_shiftId, body);
      debugPrint('=== CLOSE SHIFT RESPONSE: $res ===');

      if (!mounted) return;

      if (res['responseCode'] == '00') {
        _showCloseSuccessDialog(res['data']);
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

  void _showCloseSuccessDialog(Map<String, dynamic>? data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              StockTheme.bgDark.withOpacity(0.98),
              StockTheme.bgCard.withOpacity(0.98),
            ]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: StockTheme.success.withOpacity(0.4)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: StockTheme.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: StockTheme.success, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('ປິດກະສຳເລັດ!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: StockTheme.textPrimary)),
            const SizedBox(height: 16),
            _closeSummaryRow('ເງິນເປີດໜ້ານ',
                _formatCurrency(_openingAmount), StockTheme.textSecondary),
            _closeSummaryRow('ຍອດຂາຍເງິນສົດ',
                _formatCurrency(_cashSalesTotal), StockTheme.success),
            if (_cashInTotal > 0)
              _closeSummaryRow(
                  'Cash In', _formatCurrency(_cashInTotal), StockTheme.info),
            if (_cashOutTotal > 0)
              _closeSummaryRow('Cash Out',
                  _formatCurrency(_cashOutTotal), StockTheme.error),
            const Divider(color: Colors.white12, height: 24),
            _closeSummaryRow('ຄາດໄວ້',
                _formatCurrency(_expectedCash), StockTheme.textPrimary),
            _closeSummaryRow('ຕົວຈິງ',
                _formatCurrency(_actualCash), StockTheme.primary),
            _closeSummaryRow(
              _isOver ? 'ເກີນ (+)' : _isShort ? 'ຂາດ (-)' : 'ຜົນຕ່າງ',
              _formatCurrency(_difference.abs()),
              _isShort
                  ? StockTheme.error
                  : _isOver
                      ? StockTheme.warning
                      : StockTheme.success,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onShiftClosed();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: StockTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ກັບໜ້າຫຼັກ',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _closeSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: StockTheme.textSecondary.withOpacity(0.7))),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animCtrl,
      child: Container(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            StockPageHeader(
              titleLa: 'ປິດກະ / ສະຫຼຸບເງິນ',
              titleEn: 'Daily Close — Cash Settlement',
              actions: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: StockTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: StockTheme.success.withOpacity(0.3)),
                  ),
                  child:
                      Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: StockTheme.success,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ກະເປີດຢູ່  •  ${widget.activeShift['cashier_name'] ?? widget.activeShift['cashier'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: StockTheme.success),
                    ),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: _isFetchingSummary
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: StockTheme.primary))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── LEFT: Shift Summary ────────────────────────
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildSummaryStats(),
                                const SizedBox(height: 16),
                                _buildCashBreakdown(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // ── RIGHT: Settlement Panel ────────────────────
                        SizedBox(
                            width: 320,
                            child: _buildSettlementPanel()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats() {
    final totalSales = _summary['total_sales'] ?? 0;
    final totalTx = _summary['total_transactions'] ?? 0;
    final cardSales = _summary['card_sales_total'] ?? 0;
    final transferSales = _summary['transfer_sales_total'] ?? 0;

    return Column(
      children: [
        Row(children: [
          Expanded(
              child: StockStatCard(
                  label: 'ຍອດຂາຍລວມ',
                  value: _formatCurrency(totalSales),
                  icon: Icons.receipt_rounded,
                  color: StockTheme.success)),
          const SizedBox(width: 12),
          Expanded(
              child: StockStatCard(
                  label: 'ຈຳນວນລາຍການ',
                  value: '$totalTx',
                  icon: Icons.shopping_cart_rounded,
                  color: StockTheme.primary)),
          const SizedBox(width: 12),
          Expanded(
              child: StockStatCard(
                  label: 'ຍອດຂາຍເງິນສົດ',
                  value: _formatCurrency(_cashSalesTotal),
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF10B981))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: StockStatCard(
                  label: 'ຍອດຂາຍຜ່ານບັດ',
                  value: _formatCurrency(cardSales),
                  icon: Icons.credit_card_rounded,
                  color: const Color(0xFF3B82F6))),
          const SizedBox(width: 12),
          Expanded(
              child: StockStatCard(
                  label: 'ຍອດໂອນ',
                  value: _formatCurrency(transferSales),
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFF8B5CF6))),
          const SizedBox(width: 12),
          Expanded(
              child: StockStatCard(
                  label: 'ເປີດໜ້ານ',
                  value: _formatCurrency(_openingAmount),
                  icon: Icons.account_balance_wallet_rounded,
                  color: StockTheme.warning)),
        ]),
      ],
    );
  }

  Widget _buildCashBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: StockTheme.bgDark.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StockTheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.calculate_rounded,
                size: 18, color: StockTheme.primary),
            const SizedBox(width: 8),
            const Text('ການຄຳນວນເງິນໃນລິ້ນຊັກ',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: StockTheme.textPrimary)),
          ]),
          const SizedBox(height: 20),
          _breakdownRow(
              '+ ເງິນເປີດໜ້ານ', _openingAmount, StockTheme.textSecondary),
          _breakdownRow(
              '+ ຍອດຂາຍເງິນສົດ', _cashSalesTotal, StockTheme.success),
          if (_cashInTotal > 0)
            _breakdownRow('+ Cash In', _cashInTotal, StockTheme.info),
          if (_cashOutTotal > 0)
            _breakdownRow('- Cash Out', _cashOutTotal, StockTheme.error,
                negative: true),
          const SizedBox(height: 12),
          Container(height: 1, color: StockTheme.primary.withOpacity(0.1)),
          const SizedBox(height: 12),
          Row(children: [
            const Text('= ຄາດໄວ້ໃນລິ້ນຊັກ',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: StockTheme.textPrimary)),
            const Spacer(),
            Text(_formatCurrency(_expectedCash),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: StockTheme.primary)),
          ]),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double amount, Color color,
      {bool negative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: StockTheme.textSecondary.withOpacity(0.7))),
        const Spacer(),
        Text(
          '${negative ? '-' : ''}${_formatCurrency(amount)}',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
      ]),
    );
  }

  Widget _buildSettlementPanel() {
    final differenceColor = _isShort
        ? StockTheme.error
        : _isOver
            ? StockTheme.warning
            : StockTheme.success;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            StockTheme.bgDark.withOpacity(0.7),
            StockTheme.bgDarker.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StockTheme.primary.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.account_balance_rounded,
                  size: 18, color: StockTheme.primary),
              const SizedBox(width: 8),
              const Text('ນັບເງິນຈິງ',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: StockTheme.textPrimary)),
            ]),
            const SizedBox(height: 6),
            Text('ນັບເງິນໃນລິ້ນຊັກ ແລ້ວປ້ອນຈຳນວນ',
                style: TextStyle(
                    fontSize: 11,
                    color: StockTheme.textSecondary.withOpacity(0.5))),
            const SizedBox(height: 16),

            // ── Actual cash input ─────────────────────────────────────
            TextField(
              controller: _actualCashCtrl,
              style: const TextStyle(
                  color: StockTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                prefixText: '₭  ',
                prefixStyle: TextStyle(
                    color: StockTheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
                labelText: 'ຈຳນວນເງິນຈິງ',
                labelStyle: TextStyle(
                    color: StockTheme.textSecondary.withOpacity(0.6),
                    fontSize: 12),
                filled: true,
                fillColor: StockTheme.bgDarker.withOpacity(0.5),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: StockTheme.primary.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: StockTheme.primary, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))
              ],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // ── Difference display ─────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: differenceColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: differenceColor.withOpacity(0.3)),
              ),
              child: Column(children: [
                Row(children: [
                  Text('ຄາດໄວ້:',
                      style: TextStyle(
                          fontSize: 12,
                          color: StockTheme.textSecondary
                              .withOpacity(0.6))),
                  const Spacer(),
                  Text(_formatCurrency(_expectedCash),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: StockTheme.textPrimary)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Text(
                    _difference == 0
                        ? 'ຜົນຕ່າງ:'
                        : _isShort
                            ? '⚠ ຂາດ:'
                            : '✓ ເກີນ:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: differenceColor),
                  ),
                  const Spacer(),
                  Text(
                    '${_isShort ? '-' : _isOver ? '+' : ''}${_formatCurrency(_difference.abs())}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: differenceColor),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Note ──────────────────────────────────────────────────
            TextField(
              controller: _noteCtrl,
              style: const TextStyle(
                  color: StockTheme.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                labelText: 'ໝາຍເຫດ / Note',
                labelStyle: TextStyle(
                    color: StockTheme.textSecondary.withOpacity(0.6),
                    fontSize: 12),
                prefixIcon: Icon(Icons.notes_rounded,
                    size: 16,
                    color: StockTheme.textSecondary.withOpacity(0.4)),
                filled: true,
                fillColor: StockTheme.bgDarker.withOpacity(0.3),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: StockTheme.primary.withOpacity(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: StockTheme.primary.withOpacity(0.5)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
              ),
              maxLines: 3,
            ),

            // ── Error ─────────────────────────────────────────────────
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: StockTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: StockTheme.error.withOpacity(0.3)),
                ),
                child: Text(_errorMsg!,
                    style: const TextStyle(
                        fontSize: 12, color: StockTheme.error)),
              ),
            ],

            const Spacer(),

            // ── Close Shift Button ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _closeShift,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isShort ? StockTheme.error : StockTheme.success,
                  disabledBackgroundColor:
                      StockTheme.success.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 18),
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
                    : Column(children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isShort
                                  ? Icons.warning_rounded
                                  : Icons.lock_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Text('ປິດກະ / Close Shift',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        if (_isShort)
                          Text(
                            'ຄ/ຂ: ${_formatCurrency(_difference.abs())}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11),
                          ),
                      ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}