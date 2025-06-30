// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BaseAppBar(title: "Admin Monitoring"),
      body: const Center(child: Text('Admin Monitoring Page Content')),
    );
  }
}
