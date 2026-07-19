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
      // Distinguish a dead-slow ("poor") network from truly no network, so the
      // user understands why the app went offline while their phone still shows
      // bars / a Wi-Fi icon.
      final poor = connectivity.isPoorConnection.value;
      final icon = poor ? Icons.signal_wifi_statusbar_connected_no_internet_4_rounded : Icons.wifi_off_rounded;
      final message = poor
          ? 'Very poor internet — working offline; sales will be saved locally'
          : 'You are offline — sales will be saved locally';
      return Container(
        width: double.infinity,
        color: AppColors.offlineBanner,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.offlineBannerText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
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
