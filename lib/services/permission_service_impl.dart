import 'dart:io';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'permission_service.dart';

/// Implementation of PermissionService using permission_handler
class PermissionServiceImpl implements PermissionService {
  /// Request file access permissions
  @override
  Future<PermissionStatus> requestFilePermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android 13+ requires READ_MEDIA_* permissions
        final androidVersion = int.parse(Platform.version.split(' ').first.split('.').first);

        if (androidVersion >= 13) {
          // Request media permissions for Android 13+
          final storageStatus = await ph.Permission.photos.request();
          return _mapPermissionStatus(storageStatus);
        } else {
          // Android <13 requires READ_EXTERNAL_STORAGE
          final storageStatus = await ph.Permission.storage.request();
          return _mapPermissionStatus(storageStatus);
        }
      } else if (Platform.isIOS) {
        // iOS requires Photos permission
        final photosStatus = await ph.Permission.photos.request();
        return _mapPermissionStatus(photosStatus);
      } else if (Platform.isMacOS) {
        // macOS doesn't typically require special permissions for file access
        return PermissionStatus.granted;
      } else if (Platform.isLinux || Platform.isWindows) {
        // Desktop platforms don't require special permissions
        return PermissionStatus.granted;
      }

      return PermissionStatus.granted;
    } catch (e) {
      return PermissionStatus.denied;
    }
  }

  /// Request network permissions
  @override
  Future<PermissionStatus> requestNetworkPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Android 12+ requires NEARBY_WIFI_DEVICES permission
        final androidVersion = int.parse(Platform.version.split(' ').first.split('.').first);

        if (androidVersion >= 12) {
          final wifiStatus = await ph.Permission.nearbyWifiDevices.request();
          return _mapPermissionStatus(wifiStatus);
        }
      } else if (Platform.isIOS) {
        // iOS 14+ requires Local Network privacy description
        // Permission is granted through Info.plist declaration
        return PermissionStatus.granted;
      }

      // Other platforms don't require specific network permissions
      return PermissionStatus.granted;
    } catch (e) {
      return PermissionStatus.denied;
    }
  }

  /// Check if permission is granted
  @override
  Future<bool> isPermissionGranted(String permission) async {
    try {
      final status = await getPermissionStatus(permission);
      return status == PermissionStatus.granted || status == PermissionStatus.limited;
    } catch (e) {
      return false;
    }
  }

  /// Open app settings for manual permission grant
  @override
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  /// Get permission status
  @override
  Future<PermissionStatus> getPermissionStatus(String permission) async {
    try {
      late ph.Permission permissionHandle;

      // Map string permission to permission_handler Permission
      switch (permission.toLowerCase()) {
        case 'storage':
        case 'files':
          if (Platform.isAndroid) {
            final androidVersion = int.parse(Platform.version.split(' ').first.split('.').first);
            permissionHandle = androidVersion >= 13 ? ph.Permission.photos : ph.Permission.storage;
          } else if (Platform.isIOS) {
            permissionHandle = ph.Permission.photos;
          } else {
            return PermissionStatus.granted;
          }
          break;

        case 'network':
        case 'wifi':
          if (Platform.isAndroid) {
            final androidVersion = int.parse(Platform.version.split(' ').first.split('.').first);
            if (androidVersion >= 12) {
              permissionHandle = ph.Permission.nearbyWifiDevices;
            } else {
              return PermissionStatus.granted;
            }
          } else {
            return PermissionStatus.granted;
          }
          break;

        default:
          return PermissionStatus.granted;
      }

      final status = await permissionHandle.status;
      return _mapPermissionStatus(status);
    } catch (e) {
      return PermissionStatus.denied;
    }
  }

  /// Map permission_handler status to our PermissionStatus
  PermissionStatus _mapPermissionStatus(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
        return PermissionStatus.granted;
      case ph.PermissionStatus.denied:
        return PermissionStatus.denied;
      case ph.PermissionStatus.permanentlyDenied:
        return PermissionStatus.permanentlyDenied;
      case ph.PermissionStatus.restricted:
        return PermissionStatus.restricted;
      case ph.PermissionStatus.limited:
        return PermissionStatus.limited;
      case ph.PermissionStatus.provisional:
        // Treat provisional as granted for our purposes
        return PermissionStatus.granted;
    }
  }
}
