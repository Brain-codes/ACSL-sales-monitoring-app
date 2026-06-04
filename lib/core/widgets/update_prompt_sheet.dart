import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stove_transaction/core/services/app_release_service.dart';

const _kSnoozeKey = 'update_snoozed_until';
const _kSnoozeDuration = Duration(hours: 12);

/// Shows the update bottom sheet only if:
///   • an update is available, AND
///   • the user hasn't snoozed within the last 12 hours.
///
/// Call this on pull-to-refresh on the dashboard / profile screen.
void showUpdatePromptIfNeeded({bool forceShow = false}) {
  final service = Get.find<AppReleaseService>();

  void tryShow() {
    if (!service.hasUpdate.value) return;

    if (!forceShow) {
      final box = GetStorage();
      final raw = box.read<String?>(_kSnoozeKey);
      if (raw != null) {
        final until = DateTime.tryParse(raw);
        if (until != null && DateTime.now().isBefore(until)) return;
      }
    }

    final info = service.latestRelease.value;
    if (info == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.context == null) return;
      showModalBottomSheet(
        context: Get.context!,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: !service.isForceUpdate.value,
        enableDrag: !service.isForceUpdate.value,
        builder: (_) => UpdatePromptSheet(info: info, isForce: service.isForceUpdate.value),
      );
    });
  }

  if (service.hasUpdate.value) {
    tryShow();
  } else {
    ever(service.hasUpdate, (bool hasUpdate) {
      if (hasUpdate) tryShow();
    });
  }
}

/// Legacy alias used on app first-launch (no snooze check).
void checkAndShowUpdatePrompt() => showUpdatePromptIfNeeded(forceShow: true);

void _snooze() {
  final box = GetStorage();
  box.write(_kSnoozeKey, DateTime.now().add(_kSnoozeDuration).toIso8601String());
}

class UpdatePromptSheet extends StatelessWidget {
  final AppReleaseInfo info;
  final bool isForce;

  const UpdatePromptSheet({super.key, required this.info, required this.isForce});

  Future<void> _openUpdatePage() async {
    final uri = Uri.parse(info.downloadUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback: try platform default mode
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      // Fallback: try platform default mode if externalApplication fails
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + title
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.smartphone_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'New Update Available',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Version ${info.version} is ready to download',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // What's new
                if (info.releaseNotes.isNotEmpty) ...[
                  Text(
                    "What's new",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    info.releaseNotes,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                ],

                // Force-update warning
                if (isForce) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This update is required to continue using the app.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Update button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openUpdatePage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF01875F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Download & Update',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                if (!isForce) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            _snooze();
                            Get.back();
                          },
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: Text(
                            'Remind me later',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: Text(
                            'Skip',
                            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
