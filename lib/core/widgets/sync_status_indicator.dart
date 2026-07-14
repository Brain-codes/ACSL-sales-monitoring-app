import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/data_refresh_service.dart';
import 'package:stove_transaction/core/services/offline_queue_service.dart';
import 'package:stove_transaction/core/services/sync_service.dart';

/// Floating, always-visible status pill anchored to the top of the app shell.
///
/// It answers the question "is anything happening in the background?" without
/// the user having to open Profile → Refresh. It surfaces, in priority order:
///   1. Downloading  — reference data is being pulled after login/reconnect.
///   2. Syncing      — queued offline sales are being pushed to the server.
///   3. Offline + N pending — no connectivity; N sales waiting to sync.
///   4. Offline      — no connectivity, nothing queued.
/// When online, idle, and with an empty queue it renders nothing.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    final refresh = Get.find<DataRefreshService>();
    final sync = Get.find<SyncService>();
    final queue = Get.find<OfflineQueueService>();

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Obx(() {
          final online = connectivity.isOnline.value;
          final downloading = refresh.isRefreshing.value;
          final syncing = sync.isSyncing.value;
          final pending = queue.pendingCount.value;
          final stage = refresh.syncStage.value;

          final pill = _resolvePill(
            online: online,
            downloading: downloading,
            syncing: syncing,
            pending: pending,
            stage: stage,
          );
          if (pill == null) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Pill(data: pill),
          );
        }),
      ),
    );
  }

  _PillData? _resolvePill({
    required bool online,
    required bool downloading,
    required bool syncing,
    required int pending,
    String stage = '',
  }) {
    if (downloading) {
      // Show the live stage + percentage when available so the user sees the
      // sync genuinely moving ("Getting stoves… 40%") instead of a static label.
      final label = stage.isNotEmpty ? stage : 'Syncing data…';
      return _PillData(
        label: label,
        bg: AppColors.brandPrimary,
        fg: AppColors.white,
        spinning: true,
      );
    }
    if (syncing) {
      return const _PillData(
        label: 'Uploading sales…',
        bg: AppColors.brandPrimary,
        fg: AppColors.white,
        spinning: true,
      );
    }
    if (!online) {
      final label = pending > 0
          ? 'Offline · $pending sale${pending > 1 ? 's' : ''} pending'
          : 'Offline';
      return _PillData(
        label: label,
        bg: AppColors.offlineBanner,
        fg: AppColors.offlineBannerText,
        spinning: false,
        icon: Icons.cloud_off,
      );
    }
    // Online, idle, but sales still waiting (e.g. held for resolution).
    if (pending > 0) {
      return _PillData(
        label: '$pending sale${pending > 1 ? 's' : ''} to sync',
        bg: AppColors.offlineBanner,
        fg: AppColors.offlineBannerText,
        spinning: false,
        icon: Icons.cloud_upload_outlined,
      );
    }
    return null;
  }
}

class _PillData {
  const _PillData({
    required this.label,
    required this.bg,
    required this.fg,
    required this.spinning,
    this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final bool spinning;
  final IconData? icon;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.data});

  final _PillData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: data.bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.spinning)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: data.fg),
              )
            else if (data.icon != null)
              Icon(data.icon, size: 16, color: data.fg),
            const SizedBox(width: 8),
            Text(
              data.label,
              style: TextStyle(
                color: data.fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
