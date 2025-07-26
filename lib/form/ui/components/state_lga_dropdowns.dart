import 'package:flutter/material.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/constants.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

class StateAndLGADropdowns extends StatelessWidget {
  final String? selectedState;
  final String? selectedLGA;
  final Function(String?) onStateChanged;
  final Function(String?) onLGAChanged;
  final String? Function(String?)? stateValidator;
  final String? Function(String?)? lgaValidator;

  const StateAndLGADropdowns({
    Key? key,
    required this.selectedState,
    required this.selectedLGA,
    required this.onStateChanged,
    required this.onLGAChanged,
    this.stateValidator,
    this.lgaValidator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          style: TextThemes(context).getTextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.primaryColor,
          ),
          decoration: InputDecoration(
            labelText: 'State',
            labelStyle: TextThemes(context).getTextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primaryColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          items: lgaAndStates.keys.map((state) {
            return DropdownMenuItem<String>(
              value: state,
              child: Text(state),
            );
          }).toList(),
          value: selectedState?.isNotEmpty == true ? selectedState : null,
          onChanged: onStateChanged,
          validator: stateValidator,
        ),
        SizedBox(height: 20),
        DropdownButtonFormField<String>(
          style: TextThemes(context).getTextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.primaryColor,
          ),
          decoration: InputDecoration(
            labelText: 'LGA',
            labelStyle: TextThemes(context).getTextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primaryColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          items: selectedState?.isNotEmpty == true &&
                  lgaAndStates.containsKey(selectedState)
              ? lgaAndStates[selectedState]!.map((lga) {
                  return DropdownMenuItem<String>(
                    value: lga,
                    child: Text(lga),
                  );
                }).toList()
              : [],
          value: selectedLGA?.isNotEmpty == true ? selectedLGA : null,
          onChanged: onLGAChanged,
          validator: lgaValidator,
        ),
      ],
    );
  }
}
