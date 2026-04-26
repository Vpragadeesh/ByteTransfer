/// Permission status for file access
enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}

/// Abstract interface for permission service operations
abstract class PermissionService {
  /// Request file access permissions
  Future<PermissionStatus> requestFilePermissions();

  /// Request network permissions
  Future<PermissionStatus> requestNetworkPermissions();

  /// Check if permission is granted
  Future<bool> isPermissionGranted(String permission);

  /// Open app settings for manual permission grant
  Future<void> openAppSettings();

  /// Get permission status
  Future<PermissionStatus> getPermissionStatus(String permission);
}
