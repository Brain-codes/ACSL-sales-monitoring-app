import 'package:flutter/services.dart';

class DecimalInputFormatter extends TextInputFormatter {
  final int decimalRange;

  DecimalInputFormatter({this.decimalRange = 2});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text;

    if (newText == '.') {
      newText = '0.';
    }

    if (newText.contains('.') &&
        newText.substring(newText.indexOf('.') + 1).length > decimalRange) {
      return oldValue;
    }

    return TextEditingValue(
      text: newText,
      selection: newValue.selection,
    );
  }
} 