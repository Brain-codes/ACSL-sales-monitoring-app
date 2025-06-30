//IGNORE AND ONLY IMPROVE

// ignore_for_file: prefer_const_constructors

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CombinedInputFormatter extends TextInputFormatter {
  final int decimalRange;

  CombinedInputFormatter({this.decimalRange = 2});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text;

    // Handle decimal input
    if (newText == '.') {
      newText = '0.';
    }

    // Allow deletion
    if (newText.isEmpty) {
      return TextEditingValue(
          text: '', selection: TextSelection.collapsed(offset: 0));
    }

    // Remove all non-digit characters except for the decimal point
    newText = newText.replaceAll(RegExp(r'[^0-9.]'), '');

    // Handle decimal range
    if (newText.contains('.') &&
        newText.substring(newText.indexOf('.') + 1).length > decimalRange) {
      return oldValue;
    }

    // Parse the number
    double? value = double.tryParse(newText);
    if (value == null) {
      return oldValue;
    }

    // Format the number with commas
    String formattedText =
        NumberFormat("#,##0.${'0' * decimalRange}").format(value);

    // Adjust the cursor position
    int newOffset = formattedText.length;
    if (newText.length < oldValue.text.length) {
      // If deleting, set cursor to the previous position
      newOffset = newText.length;
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}
