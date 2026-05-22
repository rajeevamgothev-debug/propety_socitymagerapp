import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';

enum AppUpdateType { none, soft, force }

class AppUpdateDecision {
  const AppUpdateDecision({
    required this.type,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.minimumSupportedVersion,
    required this.updateUrl,
    required this.releaseNotes,
  });

  final AppUpdateType type;
  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final String minimumSupportedVersion;
  final String updateUrl;
  final String releaseNotes;

  bool get requiresUpdate => type != AppUpdateType.none;
  bool get isForce => type == AppUpdateType.force;
}

class VersionUpdateService {
  VersionUpdateService._();

  static const Duration _timeout = Duration(seconds: 8);

  static Future<AppUpdateDecision> check({required String appCode}) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final String platform = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
        ? 'android'
        : 'other';

    if (platform == 'other') {
      return _noUpdate(packageInfo, currentBuild);
    }

    try {
      final ApiResponse response = await ApiClient.instance
          .post(ApiConfig.fetchAppUpdateConfig, <String, dynamic>{
            'App_Code': appCode,
            'Platform': platform,
            'Current_Version': packageInfo.version,
            'Current_Build_Number': currentBuild,
          })
          .timeout(_timeout);

      if (!response.success) {
        return _noUpdate(packageInfo, currentBuild);
      }

      final Map<String, dynamic> data = _asMap(response.data);
      if (data.isEmpty) {
        return _noUpdate(packageInfo, currentBuild);
      }

      final String latestVersion =
          _stringValue(data, <String>['latest_version', 'Latest_Version']) ??
          packageInfo.version;
      final String minimumVersion =
          _stringValue(data, <String>[
            'minimum_supported_version',
            'Minimum_Supported_Version',
          ]) ??
          packageInfo.version;
      final int? latestBuild = _intValue(data, <String>[
        'latest_build_number',
        'Latest_Build_Number',
      ]);
      final int? minimumBuild = _intValue(data, <String>[
        'minimum_supported_build_number',
        'Minimum_Supported_Build_Number',
      ]);
      final String configuredType =
          (_stringValue(data, <String>['update_type', 'Update_Type']) ?? '')
              .toLowerCase()
              .trim();

      AppUpdateType type = AppUpdateType.none;
      if (configuredType == 'force' ||
          _isBuildOlder(currentBuild, minimumBuild) ||
          _isVersionOlder(packageInfo.version, minimumVersion)) {
        type = AppUpdateType.force;
      } else if (configuredType == 'soft' ||
          _isBuildOlder(currentBuild, latestBuild) ||
          _isVersionOlder(packageInfo.version, latestVersion)) {
        type = AppUpdateType.soft;
      }

      return AppUpdateDecision(
        type: type,
        currentVersion: packageInfo.version,
        currentBuildNumber: currentBuild,
        latestVersion: latestVersion,
        minimumSupportedVersion: minimumVersion,
        updateUrl:
            _stringValue(data, <String>[
              'update_url',
              'Update_URL',
              'app_store_url',
              'App_Store_URL',
              'testflight_url',
              'TestFlight_URL',
            ]) ??
            '',
        releaseNotes:
            _stringValue(data, <String>['release_notes', 'Release_Notes']) ??
            'Update to the latest version for improved reliability and security.',
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('VersionUpdateService check skipped: $error');
      }
      return _noUpdate(packageInfo, currentBuild);
    }
  }

  static Future<bool> openUpdate(AppUpdateDecision decision) async {
    final Uri? uri = Uri.tryParse(decision.updateUrl);
    if (uri == null || !uri.hasScheme) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static AppUpdateDecision _noUpdate(
    PackageInfo packageInfo,
    int currentBuild,
  ) {
    return AppUpdateDecision(
      type: AppUpdateType.none,
      currentVersion: packageInfo.version,
      currentBuildNumber: currentBuild,
      latestVersion: packageInfo.version,
      minimumSupportedVersion: packageInfo.version,
      updateUrl: '',
      releaseNotes: '',
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  static String? _stringValue(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final Object? value = data[key];
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static int? _intValue(Map<String, dynamic> data, List<String> keys) {
    final String? text = _stringValue(data, keys);
    return text == null ? null : int.tryParse(text);
  }

  static bool _isBuildOlder(int current, int? target) {
    return target != null && target > 0 && current > 0 && current < target;
  }

  static bool _isVersionOlder(String current, String target) {
    final List<int> currentParts = _versionParts(current);
    final List<int> targetParts = _versionParts(target);
    for (int index = 0; index < 3; index += 1) {
      if (currentParts[index] < targetParts[index]) {
        return true;
      }
      if (currentParts[index] > targetParts[index]) {
        return false;
      }
    }
    return false;
  }

  static List<int> _versionParts(String version) {
    final String normalized = version.split('+').first;
    final List<String> parts = normalized.split('.');
    return List<int>.generate(
      3,
      (int index) => index < parts.length ? int.tryParse(parts[index]) ?? 0 : 0,
    );
  }
}
