import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/main_layout/controller/layout_controller.dart';
import 'package:stove_transaction/shared/widgets/bottom_nav_item.dart';
import 'package:stove_transaction/core/routes/app_routes.dart';

class AdminBottomNav extends GetView<LayoutController> {
  const AdminBottomNav({Key? key}) : super(key: key);

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
              icon: Icons.dashboard,
              label: 'Dashboard',
              isSelected: controller.tabIndex.value == 0,
              onTap: () => controller.changeTabIndex(0),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: BottomNavItem(
              icon: Icons.point_of_sale,
              label: 'Sales',
              isSelected: controller.tabIndex.value == 1,
              onTap: () => controller.changeTabIndex(1),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: BottomNavItem(
              icon: Icons.monitor,
              label: 'Monitoring',
              isSelected: controller.tabIndex.value == 2,
              onTap: () => controller.changeTabIndex(2),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: BottomNavItem(
              icon: Icons.settings,
              label: 'Settings',
              isSelected: controller.tabIndex.value == 3,
              onTap: () => controller.changeTabIndex(3),
            ),
            label: '',
          ),
        ],
      ),
    );
  }
}
