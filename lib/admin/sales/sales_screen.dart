import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar( title: "Admin Sales"),
      body: const Center(child: Text('Admin Sales Page Content')),
    );
  }
}
