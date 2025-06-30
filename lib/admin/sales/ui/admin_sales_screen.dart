import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';

import 'package:stove_transaction/admin/sales/ui/manage_sales_screen.dart';

class AdminSalesScreen extends StatelessWidget {
  AdminSalesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ManageSalesScreen();
  }
}
