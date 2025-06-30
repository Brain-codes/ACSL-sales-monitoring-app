import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class CustomTextField extends StatelessWidget {
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
  final bool obscureText;
  final String? hintText;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixIconTap;

  const CustomTextField({
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
    this.obscureText = false,
    this.hintText,
    this.suffixIcon,
    this.onSuffixIconTap,
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
        obscureText: obscureText,
        decoration: decoration ??
            InputDecoration(
              labelText: label,
              hintText: hintText,
              labelStyle: TextThemes(context).getTextStyle(
                fontSize: 14,
                color: AppColors.secondaryTextColor,
              ),
              hintStyle: TextThemes(context).getTextStyle(
                fontSize: 14,
                color: AppColors.hintTextColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.red, width: 2),
              ),
              suffixIcon: suffixIcon != null
                  ? GestureDetector(
                      onTap: onSuffixIconTap,
                      child: suffixIcon,
                    )
                  : null,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
        style: TextThemes(context).getTextStyle(
          fontSize: 16,
          color: AppColors.primaryTextColor,
        ),
      ),
    );
  }
}
