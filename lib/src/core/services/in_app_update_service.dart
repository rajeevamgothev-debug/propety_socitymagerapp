import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class AppUpdateService {
  AppUpdateService._();

  static const Duration _timeout = Duration(seconds: 12);
  static bool _hasCheckedThisSession = false;

  static Future<void> checkForUpdate() async {
    if (_hasCheckedThisSession || kIsWeb) {
      return;
    }
    _hasCheckedThisSession = true;

    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      _debugLog('Checking Play in-app update availability.');
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate()
          .timeout(_timeout);

      if (updateInfo.updateAvailability !=
          UpdateAvailability.updateAvailable) {
        _debugLog('No Play update available.');
        return;
      }

      if (updateInfo.immediateUpdateAllowed) {
        _debugLog('Starting immediate Play update.');
        await InAppUpdate.performImmediateUpdate().timeout(_timeout);
        return;
      }

      if (!updateInfo.flexibleUpdateAllowed) {
        _debugLog('Play update available but no allowed update flow.');
        return;
      }

      _debugLog('Starting flexible Play update.');
      final AppUpdateResult result =
          await InAppUpdate.startFlexibleUpdate().timeout(_timeout);
      if (result == AppUpdateResult.success) {
        _debugLog('Completing flexible Play update.');
        await InAppUpdate.completeFlexibleUpdate().timeout(_timeout);
      } else {
        _debugLog('Flexible Play update ended with $result.');
      }
    } catch (error) {
      // Non-critical. This can throw for debug, sideloaded, or non-Play installs.
      _debugLog('Play in-app update check skipped/failed: $error');
    }
  }

  static void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('AppUpdateService: $message');
    }
  }
}
