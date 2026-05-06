import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Checks the Google Play Store for available updates and prompts the user
/// using the native Android In-App Updates API.
///
/// - **Immediate update**: full-screen blocking UI (used for high-priority updates).
/// - **Flexible update**: downloads in background, then shows a snackbar to restart.
///
/// This only works on Android when the app is installed from the Play Store.
/// Fails silently on iOS, emulators, debug builds, and sideloaded APKs.
class InAppUpdateService {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability !=
          UpdateAvailability.updateAvailable) {
        return;
      }

      // High-priority (>= 4) or stale (> 3 days) → immediate update.
      final bool isHighPriority = updateInfo.updatePriority >= 4;
      final bool isStale =
          (updateInfo.clientVersionStalenessDays ?? 0) > 3;

      if (updateInfo.immediateUpdateAllowed &&
          (isHighPriority || isStale)) {
        await InAppUpdate.performImmediateUpdate();
      } else if (updateInfo.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Update downloaded. Restart to install.'),
              action: SnackBarAction(
                label: 'RESTART',
                onPressed: () => InAppUpdate.completeFlexibleUpdate(),
              ),
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }
    } catch (_) {
      // Silently fail — in-app update is non-critical.
      // Throws on iOS, emulators, debug/sideloaded builds.
    }
  }
}
