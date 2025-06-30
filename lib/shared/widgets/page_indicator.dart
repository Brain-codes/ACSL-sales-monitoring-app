import 'package:flutter/material.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';

class PageIndicator extends StatelessWidget {
  final int itemCount;
  final int currentIndex;

  const PageIndicator({
    Key? key,
    required this.itemCount,
    required this.currentIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 8,
          width: currentIndex == index ? 24 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: currentIndex == index
                ? AppColors.primaryColor
                : AppColors.disabledColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
