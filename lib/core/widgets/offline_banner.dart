import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return Obx(() {
      if (connectivity.isOnline.value) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        color: AppColors.offlineBanner,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.offlineBannerText),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'You are offline — sales will be saved locally',
                style: TextStyle(
                  color: AppColors.offlineBannerText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
