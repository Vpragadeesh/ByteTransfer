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
        // Try photos permission first (works for Android 13+)
        // If it fails, fall back to storage permission (Android <13)
        try {
          final photosStatus = await ph.Permission.photos.request();
          if (photosStatus.isGranted || photosStatus.isLimited) {
            return _mapPermissionStatus(photosStatus);
          }
        } catch (e) {
          // Photos permission not available, try storage
        }
        
        // Fall back to storage permission
        final storageStatus = await ph.Permission.storage.request();
        return _mapPermissionStatus(storageStatus);
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
      // If all permission requests fail, grant anyway (desktop or permission not needed)
      return PermissionStatus.granted;
    }
  }

  /// Request network permissions
  @override
  Future<PermissionStatus> requestNetworkPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Try to request nearby WiFi devices permission (Android 12+)
        // If it fails, just grant permission anyway
        try {
          final wifiStatus = await ph.Permission.nearbyWifiDevices.request();
          return _mapPermissionStatus(wifiStatus);
        } catch (e) {
          // Permission not available on this Android version, grant anyway
          return PermissionStatus.granted;
        }
      } else if (Platform.isIOS) {
        // iOS 14+ requires Local Network privacy description
        // Permission is granted through Info.plist declaration
        return PermissionStatus.granted;
      }

      // Other platforms don't require specific network permissions
      return PermissionStatus.granted;
    } catch (e) {
      // If permission request fails, grant anyway (not critical)
      return PermissionStatus.granted;
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
            // Try photos first, fall back to storage
            try {
              permissionHandle = ph.Permission.photos;
              final status = await permissionHandle.status;
              if (status.isGranted || status.isLimited) {
                return _mapPermissionStatus(status);
              }
            } catch (e) {
              // Photos not available
            }
            permissionHandle = ph.Permission.storage;
          } else if (Platform.isIOS) {
            permissionHandle = ph.Permission.photos;
          } else {
            return PermissionStatus.granted;
          }
          break;

        case 'network':
        case 'wifi':
          if (Platform.isAndroid) {
            try {
              permissionHandle = ph.Permission.nearbyWifiDevices;
            } catch (e) {
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
      return PermissionStatus.granted;
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
