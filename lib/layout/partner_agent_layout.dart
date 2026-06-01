import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/features/profile/profile_screen.dart';
import 'package:stove_transaction/features/sales/list/sales_list_screen.dart';

class PartnerAgentLayout extends StatefulWidget {
  const PartnerAgentLayout({super.key});

  @override
  State<PartnerAgentLayout> createState() => _PartnerAgentLayoutState();
}

class _PartnerAgentLayoutState extends State<PartnerAgentLayout> {
  int _index = 0;

  final _pages = const [
    SalesListScreen(),
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
            BottomNavigationBarItem(
              icon: pending > 0
                  ? Badge(label: Text('$pending'), child: const Icon(Icons.receipt_long_outlined))
                  : const Icon(Icons.receipt_long_outlined),
              activeIcon: const Icon(Icons.receipt_long),
              label: 'Sales',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        );
      }),
    );
  }
}
