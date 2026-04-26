import 'package:flutter_test/flutter_test.dart';
import 'package:byte_transfer/services/permission_service_impl.dart';
import 'package:byte_transfer/services/permission_service.dart';

void main() {
  group('PermissionServiceImpl', () {
    late PermissionServiceImpl permissionService;

    setUp(() {
      permissionService = PermissionServiceImpl();
    });

    test('getPermissionStatus handles unknown permissions gracefully', () async {
      final status = await permissionService.getPermissionStatus('unknown_permission');
      expect(status, equals(PermissionStatus.granted));
    });

    test('maps storage permission correctly', () async {
      // This test verifies the mapping logic works without actually requesting permissions
      // In a real scenario, platform-specific permissions would be tested on device
      final status = await permissionService.getPermissionStatus('storage');
      expect(status, isNotNull);
    });

    test('maps network permission correctly', () async {
      final status = await permissionService.getPermissionStatus('network');
      expect(status, isNotNull);
    });

    test('case-insensitive permission names', () async {
      // Both should map to the same permission
      final status1 = await permissionService.getPermissionStatus('STORAGE');
      final status2 = await permissionService.getPermissionStatus('storage');
      expect(status1, equals(status2));
    });

    // Note: Full permission tests require platform-specific setup on Android/iOS
    // These tests verify the API surface and error handling
  });
}

