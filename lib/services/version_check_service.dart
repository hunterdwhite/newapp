import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

class VersionCheckService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if the app version is up to date
  /// Returns true if update is required, false otherwise
  Future<VersionCheckResult> checkVersion() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = packageInfo.buildNumber;

      print('🔍 Current app version: $currentVersion (build $currentBuildNumber)');

      // Get minimum required version from Firestore
      final doc = await _firestore.collection('app_config').doc('version_control').get();

      if (!doc.exists) {
        print('⚠️ Version control document not found - skipping check');
        return VersionCheckResult(
          updateRequired: false,
          currentVersion: currentVersion,
          minimumVersion: null,
        );
      }

      final data = doc.data()!;
      final platform = Platform.isIOS ? 'ios' : 'android';
      final minimumVersion = data['minimum_version_$platform'] as String?;
      final recommendedVersion = data['recommended_version_$platform'] as String?;
      final forceUpdate = data['force_update_$platform'] as bool? ?? false;
      final updateMessage = data['update_message'] as String? ?? 
          'A new version is available. Please update to continue.';
      final storeUrl = platform == 'ios' 
          ? data['ios_store_url'] as String?
          : data['android_store_url'] as String?;

      print('📱 Platform: $platform');
      print('📦 Minimum required version: $minimumVersion');
      print('✨ Recommended version: $recommendedVersion');
      print('🔒 Force update: $forceUpdate');

      if (minimumVersion == null) {
        print('⚠️ No minimum version set - skipping check');
        return VersionCheckResult(
          updateRequired: false,
          currentVersion: currentVersion,
          minimumVersion: null,
        );
      }

      // Compare versions
      final updateRequired = _isVersionLowerThan(currentVersion, minimumVersion);
      final recommendedUpdateAvailable = recommendedVersion != null && 
          _isVersionLowerThan(currentVersion, recommendedVersion);

      if (updateRequired) {
        print('❌ Update REQUIRED: $currentVersion < $minimumVersion');
      } else if (recommendedUpdateAvailable) {
        print('💡 Update recommended: $currentVersion < $recommendedVersion');
      } else {
        print('✅ App version is up to date');
      }

      return VersionCheckResult(
        updateRequired: updateRequired && forceUpdate,
        recommendedUpdate: recommendedUpdateAvailable,
        currentVersion: currentVersion,
        minimumVersion: minimumVersion,
        recommendedVersion: recommendedVersion,
        updateMessage: updateMessage,
        storeUrl: storeUrl,
        forceUpdate: forceUpdate,
      );
    } catch (e) {
      print('❌ Error checking version: $e');
      // On error, don't block the user
      return VersionCheckResult(
        updateRequired: false,
        currentVersion: 'unknown',
        minimumVersion: null,
      );
    }
  }

  /// Compare two version strings
  /// Returns true if current is lower than minimum
  bool _isVersionLowerThan(String current, String minimum) {
    try {
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final minimumParts = minimum.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // Ensure both have 3 parts (major.minor.patch)
      while (currentParts.length < 3) currentParts.add(0);
      while (minimumParts.length < 3) minimumParts.add(0);

      // Compare major.minor.patch
      for (int i = 0; i < 3; i++) {
        if (currentParts[i] < minimumParts[i]) {
          return true; // Current is lower
        } else if (currentParts[i] > minimumParts[i]) {
          return false; // Current is higher
        }
      }

      return false; // Versions are equal
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }
}

class VersionCheckResult {
  final bool updateRequired;
  final bool recommendedUpdate;
  final String currentVersion;
  final String? minimumVersion;
  final String? recommendedVersion;
  final String? updateMessage;
  final String? storeUrl;
  final bool forceUpdate;

  VersionCheckResult({
    required this.updateRequired,
    this.recommendedUpdate = false,
    required this.currentVersion,
    required this.minimumVersion,
    this.recommendedVersion,
    this.updateMessage,
    this.storeUrl,
    this.forceUpdate = false,
  });
}







