import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final appConfigRepositoryProvider = Provider((ref) => AppConfigRepository());

/// Provides the minimum required build number based on platform
final requiredBuildNumberProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(appConfigRepositoryProvider);
  return repo.getMinRequiredBuildNumber();
});

/// Checks if the current app version is out of date and must be updated
final needsForceUpdateProvider = FutureProvider<bool>((ref) async {
  final requiredBuild = await ref.watch(requiredBuildNumberProvider.future);
  final packageInfo = await PackageInfo.fromPlatform();

  final currentBuildStr = packageInfo.buildNumber;
  if (currentBuildStr.isEmpty) {
    return false; // Fail safe for web/simulators if empty
  }

  final currentBuild = int.tryParse(currentBuildStr) ?? 0;

  return currentBuild < requiredBuild;
});

class AppConfigRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> getMinRequiredBuildNumber() async {
    try {
      final doc = await _firestore
          .collection('config')
          .doc('appSettings')
          .get();

      if (!doc.exists) return 0; // If config doesn't exist, don't force update

      final data = doc.data();
      if (data == null) return 0;

      // Check which platform we are on and return the corresponding min build
      if (Platform.isIOS || Platform.isMacOS) {
        return (data['minIosBuild'] as num?)?.toInt() ?? 0;
      } else if (Platform.isAndroid) {
        return (data['minAndroidBuild'] as num?)?.toInt() ?? 0;
      }

      return 0; // Web or other platforms pass by default
    } catch (e) {
      // In case of network errors fetching config, let the user into the app
      return 0;
    }
  }
}
