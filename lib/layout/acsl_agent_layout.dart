import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/features/dashboard/dashboard_screen.dart';
import 'package:stove_transaction/features/partners/partners_screen.dart';
import 'package:stove_transaction/features/profile/profile_screen.dart';
import 'package:stove_transaction/features/sales/list/sales_list_screen.dart';

class AcslAgentLayout extends StatefulWidget {
  const AcslAgentLayout({super.key});

  @override
  State<AcslAgentLayout> createState() => _AcslAgentLayoutState();
}

class _AcslAgentLayoutState extends State<AcslAgentLayout> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    SalesListScreen(),
    PartnersScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final queue = Get.find<OfflineQueueService>();
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Obx(() {
        final pending = queue.pendingCount.value;
        return BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(
              icon: pending > 0
                  ? Badge(label: Text('$pending'), child: const Icon(Icons.receipt_long_outlined))
                  : const Icon(Icons.receipt_long_outlined),
              activeIcon: const Icon(Icons.receipt_long),
              label: 'Sales',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Partners'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        );
      }),
    );
  }
}
