import 'package:flutter/material.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class StoveSerialAutocomplete extends StatefulWidget {
  final List<String> stoveIds;
  final Function(String) onSelected;
  final String? Function(String?)? validator;
  final TextEditingController? controller;

  const StoveSerialAutocomplete({
    Key? key,
    required this.stoveIds,
    required this.onSelected,
    this.validator,
    this.controller,
  }) : super(key: key);

  @override
  State<StoveSerialAutocomplete> createState() =>
      _StoveSerialAutocompleteState();
}

class _StoveSerialAutocompleteState extends State<StoveSerialAutocomplete> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return widget.stoveIds.where((String option) {
          return option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              );
        });
      },
      onSelected: widget.onSelected,
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // Sync the internal controller with the provided controller
        if (widget.controller != null) {
          textEditingController.text = widget.controller!.text;
          textEditingController.addListener(() {
            if (widget.controller!.text != textEditingController.text) {
              widget.controller!.text = textEditingController.text;
            }
          });
          widget.controller!.addListener(() {
            if (textEditingController.text != widget.controller!.text) {
              textEditingController.text = widget.controller!.text;
            }
          });
        }

        return TextFormField(
          style: TextThemes(context).getTextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.primaryColor,
          ),
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Stove Serial No.',
            labelStyle: TextThemes(context).getTextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primaryColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            errorText: textEditingController.text.isNotEmpty &&
                    !widget.stoveIds
                        .any((id) => id == textEditingController.text)
                ? 'Invalid Stove Serial No.'
                : null,
          ),
          validator: widget.validator,
          onChanged: (value) {
            // Trigger rebuild for error state
          },
        );
      },
    );
  }
}
