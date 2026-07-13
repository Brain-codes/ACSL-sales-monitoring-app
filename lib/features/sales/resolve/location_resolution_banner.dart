import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/features/sales/resolve/location_resolution_screen.dart';

/// Top-of-screen prompt shown when offline sales are waiting for the user to
/// confirm their Google location. Tapping it opens the resolution screen.
class LocationResolutionBanner extends StatelessWidget {
  const LocationResolutionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final queue = Get.find<OfflineQueueService>();
    return Obx(() {
      final n = queue.needsResolutionCount.value;
      if (n == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Material(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const LocationResolutionScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wrong_location_outlined,
                      color: Color(0xFFC2410C), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$n sale${n > 1 ? 's' : ''} need${n > 1 ? '' : 's'} location review',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9A3412)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap to confirm the correct address before syncing',
                          style: TextStyle(fontSize: 12, color: Color(0xFFC2410C)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFC2410C), size: 20),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
