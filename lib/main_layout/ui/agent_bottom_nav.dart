import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/main_layout/controller/layout_controller.dart';
import 'package:stove_transaction/shared/widgets/bottom_nav_item.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';

class AgentBottomNav extends GetView<LayoutController> {
  const AgentBottomNav({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => BottomNavigationBar(
        currentIndex: controller.tabIndex.value,
        onTap: controller.changeTabIndex,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: BottomNavItem(
              icon: Icons.edit_note,
              label: 'Sales Form',
              isSelected: controller.tabIndex.value == 0,
              onTap: () => controller.changeTabIndex(0),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: BottomNavItem(
              icon: Icons.history,
              label: 'History',
              isSelected: controller.tabIndex.value == 1,
              onTap: () => controller.changeTabIndex(1),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: BottomNavItem(
              icon: Icons.settings,
              label: 'Settings',
              isSelected: controller.tabIndex.value == 2,
              onTap: () => controller.changeTabIndex(2),
            ),
            label: '',
          ),
        ],
      ),
    );
  }
}
