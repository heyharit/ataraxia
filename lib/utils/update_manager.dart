import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';

class UpdateManager {
  static Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      // ⚠️ REMINDER: Change minimumFetchInterval to Duration(hours: 4) before App Store release!
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(seconds: 0),
        ),
      );

      await remoteConfig.fetchAndActivate();

      // 1. Fetch the semantic version strings from Firebase
      final String latestVersion = remoteConfig.getString('latest_version');
      final String minSupportedVersion = remoteConfig.getString(
        'minimum_supported_version',
      );
      final String updateUrl = remoteConfig.getString('update_url');

      if (latestVersion.isEmpty || updateUrl.isEmpty) return null;

      // 2. Get the app's current installed version from pubspec.yaml
      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // 🚀 3. LOGIC CHECK 1: Is it a FORCED update?
      // If the current version is strictly less than the minimum supported version, lock them out.
      if (minSupportedVersion.isNotEmpty &&
          _isVersionGreater(minSupportedVersion, currentVersion)) {
        return {
          'version':
              latestVersion, // Tell them the version they are upgrading to
          'url': updateUrl,
          'isForced':
              true, // This triggers the inescapable red glass in GlobalUpdateWrapper
        };
      }

      // 🚀 4. LOGIC CHECK 2: Is it an OPTIONAL update?
      // It's not forced, but is there a newer version available than what they have?
      if (_isVersionGreater(latestVersion, currentVersion)) {
        return {
          'version': latestVersion,
          'url': updateUrl,
          'isForced':
              false, // This allows the dismissible cyan modal in DashboardScreen
        };
      }

      // 5. If neither is true, the user is fully up to date!
      return null;
    } catch (e) {
      debugPrint("Update Check Failed: $e");
      return null;
    }
  }

  // Helper to compare semantic versions (e.g., returns true if "1.6.7" > "1.6.0")
  static bool _isVersionGreater(String target, String current) {
    List<int> targetParts = target.split('.').map(int.parse).toList();
    List<int> currentParts = current.split('.').map(int.parse).toList();

    for (int i = 0; i < targetParts.length && i < currentParts.length; i++) {
      if (targetParts[i] > currentParts[i]) return true;
      if (targetParts[i] < currentParts[i]) return false;
    }
    // If the loop finishes and they match up to the length of the shortest string,
    // the longer string is considered greater (e.g., "1.0.1" > "1.0")
    return targetParts.length > currentParts.length;
  }
}
