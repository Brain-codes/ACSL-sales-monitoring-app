//IGNORE AND ONLY IMPROVE

import 'package:flutter/material.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:flutter/services.dart';

class CustomInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType inputType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final InputDecoration? decoration;
  final List<TextInputFormatter>? inputFormatters;

  const CustomInputField({
    Key? key,
    required this.label,
    required this.controller,
    this.inputType = TextInputType.text,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    this.onChanged,
    this.decoration,
    this.inputFormatters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        validator: validator,
        readOnly: readOnly,
        focusNode: focusNode,
        onTap: onTap,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        style: TextThemes(context).getTextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.primaryColor,
        ),
        decoration: decoration ??
            InputDecoration(
              labelText: label,
              labelStyle: TextThemes(context).getTextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primaryColor,
              ),
              filled: true,
              fillColor: AppColors.lightGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide.none,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Colors.red, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Colors.red, width: 1.0),
              ),
            ),
      ),
    );
  }
}
