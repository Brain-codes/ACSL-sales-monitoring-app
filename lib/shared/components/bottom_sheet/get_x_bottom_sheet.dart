// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:stove_transaction/shared/components/bottom_sheet/response_bottom_sheet.dart';

void successBottomSheet({
  required String title,
  required String message,
  required VoidCallback onTaps,
  String buttonTitle = 'Done',
  bool isBoolBtn = false,
}) {
  Get.bottomSheet(
    BottomSheet(
      backgroundColor: Colors.transparent,
      onClosing: () {},
      builder: (BuildContext context) {
        return Text('data');
        // ResponseBottomSheet(
        //   message: message,
        //   title: title,
        //   type: 'success',
        //   onTaps: onTaps,
        //   buttonTitle: buttonTitle,
        //   isBoolBtn: isBoolBtn,
        // );
      },
    ),
  );
}

void errorBottomSheet({
  required String title,
  required String message,
  required VoidCallback onTaps,
  String buttonTitle = 'Done',
}) {
  Get.bottomSheet(
    isScrollControlled: true,
    BottomSheet(
      backgroundColor: Colors.transparent,
      onClosing: () {},
      builder: (BuildContext context) {
        return Text('data');

        //  ResponseBottomSheet(
        //   message: message,
        //   title: title,
        //   type: 'error',
        //   onTaps: onTaps,
        //   buttonTitle: buttonTitle,
        // );
      },
    ),
  );
}

void infoBottomSheet({
  required String title,
  required String message,
  VoidCallback? onTaps,
  String buttonTitle = 'Done',
  bool isDismissible = true,
}) {
  Get.bottomSheet(
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    BottomSheet(
      backgroundColor: Colors.transparent,
      onClosing: () {},
      enableDrag: isDismissible,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => isDismissible,
          child: ResponseBottomSheet(
            message: message,
            title: title,
            onTaps: onTaps,
            buttonTitle: buttonTitle,
          ),
        );
      },
    ),
  );
}

void showBaseBottomSheet({
  required String title,
  required String message,
  required VoidCallback onTaps,
  VoidCallback? secondaryOnTaps,
  String highlightedText = '',
  String secondaryButtonTitle = '',
  String buttonTitle = 'Done',
  bool isDismissible = true,
}) {
  Get.bottomSheet(
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    BottomSheet(
      backgroundColor: Colors.transparent,
      onClosing: () {},
      enableDrag: isDismissible,
      builder: (BuildContext context) {
        return ResponseBottomSheet(
          message: message,
          title: title,
          onTaps: onTaps,
          // highlightedText: highlightedText,
          // secondaryButtonTitle: secondaryButtonTitle,
          // secondaryOnTaps: secondaryOnTaps,
        );
      },
    ),
  );
}
