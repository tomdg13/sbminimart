// lib/widgets/stock_ui_helpers.dart
import 'package:flutter/material.dart';

/// Shared colors, formatters, and widgets used across all stock management pages
class StockTheme {
  // ── Dark + Blue palette ──────────────────────────────────────────────────
  static const Color primary      = Color(0xFF2563EB); // electric blue
  static const Color primaryLight = Color(0xFF60A5FA); // sky blue
  static const Color success      = Color(0xFF10B981); // emerald
  static const Color successDark  = Color(0xFF059669);
  static const Color warning      = Color(0xFFF59E0B); // amber
  static const Color warningDark  = Color(0xFFD97706);
  static const Color error        = Color(0xFFEF4444); // red
  static const Color errorDark    = Color(0xFFDC2626);
  static const Color info         = Color(0xFF38BDF8); // sky
  static const Color infoDark     = Color(0xFF0EA5E9);
  static const Color textPrimary  = Color(0xFFE2E8F0); // slate-200
  static const Color textSecondary= Color(0xFF94A3B8); // slate-400
  static const Color bgDark       = Color(0xFF0F172A); // deep navy
  static const Color bgDarker     = Color(0xFF080E1A); // deeper navy
  static const Color bgCard       = Color(0xFF1E2A3B); // dark navy card

  static String formatPrice(dynamic price) {
    if (price == null) return '0';
    final num = double.tryParse(price.toString()) ?? 0;
    return num.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  static String formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return date.toString();
    }
  }

  static String formatDateTime(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }

  static Color statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft': return textSecondary;
      case 'pending': return warning;
      case 'approved': return info;
      case 'ordered': return primaryLight;
      case 'partial_received': return warningDark;
      case 'received': case 'confirmed': return success;
      case 'cancelled': return error;
      case 'in_transit': return info;
      default: return textSecondary;
    }
  }

  static String statusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft': return 'ຮ່າງ';
      case 'pending': return 'ລໍຖ້າ';
      case 'approved': return 'ອະນຸມັດ';
      case 'ordered': return 'ສັ່ງແລ້ວ';
      case 'partial_received': return 'ຮັບບາງສ່ວນ';
      case 'received': return 'ຮັບແລ້ວ';
      case 'confirmed': return 'ຢືນຢັນແລ້ວ';
      case 'cancelled': return 'ຍົກເລີກ';
      case 'in_transit': return 'ກຳລັງຂົນສົ່ງ';
      default: return status ?? '-';
    }
  }
}

// ============================================
// REUSABLE WIDGETS
// ============================================

class StockPageHeader extends StatelessWidget {
  final String titleLa;
  final String titleEn;
  final List<Widget> actions;

  const StockPageHeader({
    super.key,
    required this.titleLa,
    required this.titleEn,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4, height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [StockTheme.primary, StockTheme.primaryLight]),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: StockTheme.primary.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                        colors: [StockTheme.textPrimary, StockTheme.primaryLight])
                    .createShader(bounds),
                child: Text(titleLa,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1)),
              ),
              Text(titleEn,
                  style: TextStyle(
                      fontSize: 14,
                      color: StockTheme.textSecondary.withOpacity(0.7),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

class StockStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StockStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [StockTheme.bgCard, color.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: StockTheme.textSecondary.withOpacity(0.8),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      LinearGradient(colors: [color, color.withOpacity(0.7)])
                          .createShader(bounds),
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StockStatusBadge extends StatelessWidget {
  final String status;

  const StockStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = StockTheme.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withOpacity(0.18), color.withOpacity(0.08)]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.6), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(StockTheme.statusLabel(status),
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class StockFilterChip extends StatelessWidget {
  final String value;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const StockFilterChip({
    super.key,
    required this.value,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [StockTheme.primary, StockTheme.primaryLight])
                : null,
            color: isSelected ? null : StockTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isSelected
                    ? StockTheme.primary.withOpacity(0.7)
                    : StockTheme.primary.withOpacity(0.2),
                width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: StockTheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(label,
              style: TextStyle(
                  color:
                      isSelected ? Colors.white : StockTheme.textSecondary,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }
}

class StockActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  const StockActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25), width: 1),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

class StockPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const StockPrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [StockTheme.primary, StockTheme.primaryLight]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: StockTheme.primary.withOpacity(0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class StockRefreshButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const StockRefreshButton(
      {super.key, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: StockTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: StockTheme.primary.withOpacity(0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isLoading
                ? Icons.hourglass_empty_rounded
                : Icons.refresh_rounded,
            color: StockTheme.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class StockEmptyState extends StatelessWidget {
  final IconData icon;
  final String titleLa;
  final String titleEn;

  const StockEmptyState({
    super.key,
    required this.icon,
    required this.titleLa,
    required this.titleEn,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                StockTheme.primary.withOpacity(0.12),
                StockTheme.primaryLight.withOpacity(0.05)
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: StockTheme.primary.withOpacity(0.15)),
            ),
            child: Icon(icon, size: 64, color: StockTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(titleLa,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: StockTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(titleEn,
              style: TextStyle(
                  fontSize: 14,
                  color: StockTheme.textSecondary.withOpacity(0.6))),
        ],
      ),
    );
  }
}

class StockTableContainer extends StatelessWidget {
  final List<String> headers;
  final List<int>? flexValues;
  final Widget child;

  const StockTableContainer({
    super.key,
    required this.headers,
    this.flexValues,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: StockTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: StockTheme.primary.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                StockTheme.primary.withOpacity(0.15),
                StockTheme.primary.withOpacity(0.05),
              ]),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: List.generate(headers.length, (i) {
                return Expanded(
                  flex: flexValues != null && i < flexValues!.length
                      ? flexValues![i]
                      : 1,
                  child: Text(headers[i],
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: StockTheme.textSecondary,
                          letterSpacing: 0.5)),
                );
              }),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ============================================
// DIALOG HELPERS
// ============================================

class StockDialogHeader extends StatelessWidget {
  final String titleLa;
  final String titleEn;
  final IconData icon;
  final VoidCallback onClose;

  const StockDialogHeader({
    super.key,
    required this.titleLa,
    required this.titleEn,
    required this.icon,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          StockTheme.primary.withOpacity(0.12),
          Colors.transparent,
        ]),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [StockTheme.primary, StockTheme.primaryLight]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: StockTheme.primary.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleLa,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: StockTheme.textPrimary)),
                Text(titleEn,
                    style: const TextStyle(
                        fontSize: 12,
                        color: StockTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded,
                color: StockTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class StockDialogFooter extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;
  final bool isLoading;

  const StockDialogFooter({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.saveLabel = 'ບັນທຶກ',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: StockTheme.primary.withOpacity(0.12), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                    color: StockTheme.primary.withOpacity(0.3), width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ຍົກເລີກ',
                  style: TextStyle(
                      color: StockTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [StockTheme.primary, StockTheme.primaryLight]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: StockTheme.primary.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : onSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(saveLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildStockFormField({
  required String label,
  required TextEditingController controller,
  required IconData icon,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  bool enabled = true,
  int maxLines = 1,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: StockTheme.textSecondary)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: enabled
              ? StockTheme.bgCard
              : StockTheme.bgCard.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: StockTheme.primary
                  .withOpacity(enabled ? 0.25 : 0.1),
              width: 1),
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          maxLines: maxLines,
          style: TextStyle(
              color: enabled
                  ? StockTheme.textPrimary
                  : const Color(0xFF64748B)),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            prefixIcon: Icon(icon,
                color: enabled
                    ? StockTheme.primary
                    : const Color(0xFF475569)),
          ),
          validator: validator,
        ),
      ),
    ],
  );
}

Widget buildStockDropdown<T>({
  required String label,
  required IconData icon,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
  String? hint,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: StockTheme.textSecondary)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: StockTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: StockTheme.primary.withOpacity(0.25), width: 1),
        ),
        child: DropdownButtonFormField<T>(
          value: value,
          dropdownColor: StockTheme.bgCard,
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            prefixIcon:
                Icon(icon, color: StockTheme.primary),
          ),
          style: const TextStyle(
              color: StockTheme.textPrimary, fontSize: 14),
          hint: hint != null
              ? Text(hint,
                  style: TextStyle(
                      color: StockTheme.textSecondary.withOpacity(0.5)))
              : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

/// Show confirmation dialog, returns true if confirmed
Future<bool> showStockConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'ຢືນຢັນ',
  Color confirmColor = StockTheme.error,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: StockTheme.bgCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: confirmColor.withOpacity(0.35), width: 1)),
      title: Text(title,
          style: const TextStyle(
              color: StockTheme.textPrimary,
              fontWeight: FontWeight.w800)),
      content: Text(message,
          style: const TextStyle(color: StockTheme.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ຍົກເລີກ',
              style: TextStyle(color: StockTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}