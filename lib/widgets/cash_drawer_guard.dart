// lib/widgets/cash_drawer_guard.dart
//
// Wrap any widget that requires an open shift.
// If no active shift → shows a "locked" screen prompting to open shift.
// Usage:
//   CashDrawerGuard(
//     currentUser: widget.currentUser,
//     onShiftOpened: () => setState(() {}),
//     child: PosScanPage(...),
//   )

import 'package:flutter/material.dart';
import '../services/cash_drawer_api_service.dart';
import 'stock_ui_helpers.dart';

class CashDrawerGuard extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Widget child;

  /// Optional: called after a shift is opened (to refresh parent state)
  final VoidCallback? onShiftOpened;

  const CashDrawerGuard({
    super.key,
    required this.currentUser,
    required this.child,
    this.onShiftOpened,
  });

  @override
  State<CashDrawerGuard> createState() => _CashDrawerGuardState();
}

class _CashDrawerGuardState extends State<CashDrawerGuard>
    with SingleTickerProviderStateMixin {
  bool _isChecking = true;
  bool _hasActiveShift = false;
  Map<String, dynamic>? _activeShift;
  late AnimationController _animCtrl;

  dynamic get _cashierId =>
      widget.currentUser['user_id'] ?? widget.currentUser['id'];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _checkShift();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkShift() async {
    setState(() => _isChecking = true);
    try {
      final res = await CashDrawerApiService.getActiveShift(_cashierId);
      debugPrint('=== GUARD CHECK SHIFT: ${res['responseCode']} ===');
      if (!mounted) return;
      if (res['responseCode'] == '00' && res['data'] != null) {
        setState(() {
          _hasActiveShift = true;
          _activeShift = res['data'] as Map<String, dynamic>;
        });
      } else {
        setState(() {
          _hasActiveShift = false;
          _activeShift = null;
        });
      }
    } catch (e) {
      debugPrint('Guard check error: $e');
      if (!mounted) return;
      setState(() => _hasActiveShift = false);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: StockTheme.primary),
            SizedBox(height: 16),
            Text('ກຳລັງກວດສອບກະ...',
                style: TextStyle(color: StockTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    if (_hasActiveShift) {
      return widget.child;
    }

    // ── BLOCKED: No active shift ─────────────────────────────────────────
    return FadeTransition(
      opacity: _animCtrl,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lock icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: StockTheme.error.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: StockTheme.error.withOpacity(0.2), width: 2),
              ),
              child: Icon(Icons.lock_rounded,
                  size: 50, color: StockTheme.error.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            const Text(
              'ຍັງບໍ່ໄດ້ເປີດກະ',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: StockTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'ຕ້ອງເປີດກະກ່ອນຈຶ່ງສາມາດໃຊ້ລະບົບຂາຍໄດ້\nYou must open a shift before selling.',
              style: TextStyle(
                  fontSize: 13,
                  color: StockTheme.textSecondary.withOpacity(0.6),
                  height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Open Shift inline mini-form
            _OpenShiftMiniForm(
              currentUser: widget.currentUser,
              onShiftOpened: () {
                _checkShift();
                widget.onShiftOpened?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inline Open Shift Mini Form ──────────────────────────────────────────────
class _OpenShiftMiniForm extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final VoidCallback onShiftOpened;

  const _OpenShiftMiniForm({
    required this.currentUser,
    required this.onShiftOpened,
  });

  @override
  State<_OpenShiftMiniForm> createState() => _OpenShiftMiniFormState();
}

class _OpenShiftMiniFormState extends State<_OpenShiftMiniForm> {
  final TextEditingController _amountCtrl =
      TextEditingController(text: '0');
  bool _isLoading = false;
  String? _errorMsg;

  static const List<int> _quickAmounts = [0, 50000, 100000, 200000, 500000];

  String _fmt(dynamic v) {
    final num val = num.tryParse(v.toString()) ?? 0;
    return '₭ ${val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        )}';
  }

  Future<void> _submit() async {
    final amount =
        num.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final res = await CashDrawerApiService.openShift({
        'cashier_id':
            widget.currentUser['user_id'] ?? widget.currentUser['id'],
        'cashier_name': widget.currentUser['full_name'] ??
            widget.currentUser['username'] ??
            'Cashier',
        'opening_amount': amount,
        'opened_by':
            widget.currentUser['username'] ?? 'unknown',
      });

      if (!mounted) return;
      if (res['responseCode'] == '00') {
        widget.onShiftOpened();
      } else {
        setState(() => _errorMsg = res['message'] ?? 'ເກີດຂໍ້ຜິດພາດ');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          StockTheme.bgDark.withOpacity(0.95),
          StockTheme.bgCard.withOpacity(0.95),
        ]),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: StockTheme.primary.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: -5),
        ],
      ),
      child: Column(
        children: [
          const Text('ປ້ອນເງິນເປີດໜ້ານ',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: StockTheme.textPrimary)),
          const SizedBox(height: 16),

          // Amount field
          TextField(
            controller: _amountCtrl,
            style: const TextStyle(
                color: StockTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: '₭  ',
              prefixStyle: TextStyle(
                  color: StockTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
              filled: true,
              fillColor: StockTheme.bgDarker.withOpacity(0.5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: StockTheme.primary.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: StockTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Quick amounts
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: _quickAmounts.map((amt) {
              return InkWell(
                onTap: () => setState(() => _amountCtrl.text = '$amt'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_amountCtrl.text == '$amt')
                        ? StockTheme.primary.withOpacity(0.2)
                        : StockTheme.bgDarker.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (_amountCtrl.text == '$amt')
                          ? StockTheme.primary.withOpacity(0.5)
                          : StockTheme.primary.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    amt == 0 ? '₭ 0' : _fmt(amt),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (_amountCtrl.text == '$amt')
                            ? StockTheme.primary
                            : StockTheme.textSecondary.withOpacity(0.6)),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_errorMsg != null) ...[
            const SizedBox(height: 10),
            Text(_errorMsg!,
                style:
                    const TextStyle(fontSize: 12, color: StockTheme.error)),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: StockTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('ເປີດກະ / Start Shift',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}