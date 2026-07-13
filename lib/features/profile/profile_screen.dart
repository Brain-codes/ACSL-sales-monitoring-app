import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/services/app_release_service.dart';
import 'package:stove_transaction/core/services/connectivity_service.dart';
import 'package:stove_transaction/core/services/local_cache_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';
import 'package:stove_transaction/core/services/sync_service.dart';
import 'package:stove_transaction/core/widgets/offline_banner.dart';
import 'package:stove_transaction/core/widgets/update_prompt_sheet.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';
import 'offline_cache_debug_screen.dart';
import 'profile_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ProfileController());
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => showUpdatePromptIfNeeded(),
              child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.brandHeader,
                    child: Text(c.initials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 16),
                  Text(c.displayName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.brandPrimary),
                    ),
                    child: Text(c.roleLabel, style: const TextStyle(color: AppColors.brandPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 32),
                  _InfoCard(items: [
                    _InfoRow(icon: Icons.email_outlined, label: 'Email', value: c.email),
                    if (c.orgName.isNotEmpty) _InfoRow(icon: Icons.business_outlined, label: 'Organisation', value: c.orgName),
                    if (c.orgBranch.isNotEmpty) _InfoRow(icon: Icons.store_outlined, label: 'Branch', value: c.orgBranch),
                    if (c.orgState.isNotEmpty) _InfoRow(icon: Icons.location_on_outlined, label: 'State', value: c.orgState),
                  ]),
                  const SizedBox(height: 24),
                  _SyncCard(c: c),
                  const SizedBox(height: 16),
                  const _AutoSyncCard(),
                  const SizedBox(height: 16),
                  // Dev-only tools (test autofill + offline cache debug).
                  // kDebugMode is compiled to false in release/profile builds, so
                  // this is stripped from the shipped APK automatically — no more
                  // manual commenting before a build.
                  if (kDebugMode) ...[
                    const _DevToolsCard(),
                    const SizedBox(height: 16),
                  ],
                  _UpdateBanner(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout, color: AppColors.error),
                      label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                      onPressed: () => _confirmLogout(context, c),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, ProfileController c) async {
    final hasPending = await c.hasPendingSales();
    if (!context.mounted) return;

    if (hasPending) {
      final count = c.pendingCount;
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Unsynced Sales'),
          content: Text(
            'You have $count unsynced sale${count > 1 ? 's' : ''}. '
            'If you sign out now, they will be lost permanently. Are you sure?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () { Navigator.of(dialogCtx).pop(); c.logout(); },
              child: const Text('Sign Out Anyway', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () { Navigator.of(dialogCtx).pop(); c.logout(); },
              child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    }
  }
}

class _UpdateBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = Get.find<AppReleaseService>();
    return Obx(() {
      if (!service.hasUpdate.value) return const SizedBox.shrink();
      final info = service.latestRelease.value;
      return GestureDetector(
        onTap: () async {
          if (info == null) return;
          // Guard: opening the download URL offline lands on the browser's
          // "You're offline" page, which looks like an app bug. Warn instead.
          if (!Get.find<ConnectivityService>().isOnline.value) {
            toastification.show(
              title: const Text('No internet connection'),
              description: const Text('Connect to the internet to download the update.'),
              type: ToastificationType.warning,
              autoCloseDuration: const Duration(seconds: 4),
            );
            return;
          }
          final uri = Uri.parse(info.downloadUrl);
          try {
            final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (!launched) await launchUrl(uri, mode: LaunchMode.platformDefault);
          } catch (_) {
            try { await launchUrl(uri, mode: LaunchMode.platformDefault); } catch (_) {}
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF93C5FD)),
          ),
          child: Row(
            children: [
              const Icon(Icons.system_update_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update available${info != null ? ' — v${info.version}' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap to download the latest version',
                      style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF3B82F6), size: 20),
            ],
          ),
        ),
      );
    });
  }
}

class _SyncCard extends StatelessWidget {
  final ProfileController c;
  const _SyncCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return GetBuilder<ProfileController>(
      builder: (ctrl) {
        return Obx(() {
          final online = connectivity.isOnline.value;
          final refreshSvc = ctrl;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FiveTapDetector(
                    onActivate: () {
                      // Dev-only: gated behind the same dev-tools flag, so users
                      // can never reach the cache debug page in release builds.
                      if (!Get.find<LocalCacheService>().devAutofillEnabled) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OfflineCacheDebugScreen()),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.sync, size: 18, color: AppColors.brandPrimary),
                        const SizedBox(width: 8),
                        const Text('Data Sync', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    refreshSvc.lastSyncedLabel,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  if (refreshSvc.pendingCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${refreshSvc.pendingCount} sale${refreshSvc.pendingCount > 1 ? 's' : ''} pending sync',
                      style: const TextStyle(fontSize: 13, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Tooltip(
                      message: online ? '' : 'No internet connection',
                      child: ElevatedButton.icon(
                        icon: refreshSvc.isRefreshing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(refreshSvc.isRefreshing ? 'Refreshing...' : 'Refresh Data'),
                        onPressed: (!online || refreshSvc.isRefreshing)
                            ? null
                            : () async {
                                await Get.find<SyncService>().syncPendingSales();
                                await ctrl.refreshData();
                                ctrl.update();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

// ── Hidden 5-tap gesture (opens the offline cache debug page) ────────────────

class _FiveTapDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onActivate;
  const _FiveTapDetector({required this.child, required this.onActivate});

  @override
  State<_FiveTapDetector> createState() => _FiveTapDetectorState();
}

class _FiveTapDetectorState extends State<_FiveTapDetector> {
  int _taps = 0;
  DateTime _first = DateTime.fromMillisecondsSinceEpoch(0);

  void _onTap() {
    final now = DateTime.now();
    // Reset the counter if taps aren't within a 2s burst.
    if (now.difference(_first) > const Duration(seconds: 2)) {
      _taps = 0;
      _first = now;
    }
    _taps++;
    if (_taps >= 5) {
      _taps = 0;
      widget.onActivate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: widget.child,
    );
  }
}

// ── Auto-sync toggle ────────────────────────────────────────────────────────

/// Lets the user opt into automatic upload of queued sales. Default is OFF
/// (manual) — the offline-first flow is: create sales in the field, review
/// them, then press sync. Turning this on uploads queued sales automatically
/// whenever connectivity returns.
class _AutoSyncCard extends StatelessWidget {
  const _AutoSyncCard();

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionManager>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Obx(() => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: session.autoSyncEnabled.value,
              activeThumbColor: AppColors.brandPrimary,
              title: const Text('Auto-sync sales',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                session.autoSyncEnabled.value
                    ? 'Queued sales upload automatically when you’re back online.'
                    : 'Manual: review your sales, then sync them yourself. (Recommended)',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              secondary: const Icon(Icons.sync, color: AppColors.brandPrimary),
              onChanged: session.setAutoSync,
            )),
      ),
    );
  }
}

// ── Developer tools — test-autofill toggle ──────────────────────────────────

class _DevToolsCard extends StatefulWidget {
  const _DevToolsCard();

  @override
  State<_DevToolsCard> createState() => _DevToolsCardState();
}

class _DevToolsCardState extends State<_DevToolsCard> {
  final _cache = Get.find<LocalCacheService>();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _cache.devAutofillEnabled,
              activeThumbColor: AppColors.brandPrimary,
              title: const Text('Test autofill (create sale)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'Triple-tap the “Create Sale” title to fill the form with sample data.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              secondary: const Icon(Icons.build_outlined, color: AppColors.brandPrimary),
              onChanged: (v) => setState(() => _cache.devAutofillEnabled = v),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storage_outlined, color: AppColors.brandPrimary),
              title: const Text('Offline cache debug',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'Inspect cached partners, stove IDs & payment models.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OfflineCacheDebugScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: items.map((item) => Column(children: [
            item,
            if (item != items.last) const Divider(height: 1),
          ])).toList(),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
