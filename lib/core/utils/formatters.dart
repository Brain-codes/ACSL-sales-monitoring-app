import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _nairaFmt = NumberFormat.currency(
  locale: 'en_NG',
  symbol: '₦',
  decimalDigits: 0,
);

/// Formats a double as Nigerian Naira, e.g. ₦50,000,000. Returns '—' for null.
String formatNaira(double? v) => v != null ? _nairaFmt.format(v) : '—';

/// Formats a raw numeric string with thousand separators, e.g. "50000000" → "50,000,000".
String formatAmountInput(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  // int.parse THROWS on anything past the 64-bit range (~19 digits), so a long
  // pasted/typed number would blow up mid-format. Fall back to the raw digits
  // rather than crashing.
  final n = int.tryParse(digits);
  if (n == null) return digits;
  return NumberFormat('#,##0', 'en_NG').format(n);
}

/// TextInputFormatter that keeps the field value as comma-separated digits.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }
    // A formatter that throws takes down text input entirely, so never let a
    // number too large for a 64-bit int (>19 digits, easily pasted) crash here —
    // just keep the previous value instead.
    final n = int.tryParse(digits);
    if (n == null) return oldValue;
    final formatted = NumberFormat('#,##0', 'en_NG').format(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
