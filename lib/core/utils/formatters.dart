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
  final n = int.parse(digits);
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
    final formatted = NumberFormat('#,##0', 'en_NG').format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
