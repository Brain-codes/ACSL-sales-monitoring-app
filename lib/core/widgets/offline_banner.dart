import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';

class OfflineBanner extends StatelessWidget {
  /// Keep the banner visible even when connectivity reports online.
  ///
  /// Screens that LATCH themselves offline on a flapping link (create-sale) are
  /// still working offline while the probe says "up" — without this the banner
  /// would vanish and the agent would think they were back online when their
  /// sale is still headed for the local queue.
  final bool forceOffline;

  /// When set, the banner offers an explicit way back online *once the link is
  /// genuinely stable*. This is the persistent escape hatch: the "connection
  /// restored" snackbar is dismissable, and without this a latched screen could
  /// strand the agent in offline mode for the rest of the sale.
  final VoidCallback? onGoOnline;

  const OfflineBanner({super.key, this.forceOffline = false, this.onGoOnline});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return Obx(() {
      final reallyOffline = !connectivity.isOnline.value;
      if (!reallyOffline && !forceOffline) return const SizedBox.shrink();

      // Only invite the user back on a settled link — never on a bare reconnect
      // that may be the "up" half of a flap.
      final canGoOnline =
          forceOffline && !reallyOffline && connectivity.isStable.value && onGoOnline != null;

      // Distinguish a dead-slow ("poor") network from truly no network, so the
      // user understands why the app went offline while their phone still shows
      // bars / a Wi-Fi icon.
      final poor = connectivity.isPoorConnection.value;

      final IconData icon;
      final String message;
      if (canGoOnline) {
        icon = Icons.wifi_rounded;
        message = 'Stable connection available — this sale is still offline';
      } else if (reallyOffline && poor) {
        icon = Icons.signal_wifi_statusbar_connected_no_internet_4_rounded;
        message = 'Very poor internet — working offline; sales will be saved locally';
      } else if (reallyOffline) {
        icon = Icons.wifi_off_rounded;
        message = 'You are offline — sales will be saved locally';
      } else {
        // Latched offline while the link bounces: say so plainly rather than
        // claiming the phone has no network.
        icon = Icons.wifi_off_rounded;
        message = 'Unstable connection — working offline; this sale is saved locally';
      }

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
            if (canGoOnline)
              TextButton(
                onPressed: onGoOnline,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.offlineBannerText,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Go online',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
