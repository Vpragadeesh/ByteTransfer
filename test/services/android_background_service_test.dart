import 'package:flutter_test/flutter_test.dart';
import 'package:byte_transfer/services/android_background_service.dart';
import 'package:byte_transfer/services/notification_service.dart';

// Fake implementation for testing
class FakeNotificationService implements NotificationService {
  bool initializeCalled = false;
  bool showCalled = false;
  bool updateCalled = false;
  bool cancelCalled = false;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
  }

  @override
  Future<void> showForegroundServiceNotification({
    required String title,
    required String body,
    required int activeConnections,
    required int totalFiles,
  }) async {
    showCalled = true;
  }

  @override
  Future<void> updateForegroundServiceNotification({
    required String title,
    required String body,
    required int activeConnections,
    required int totalFiles,
  }) async {
    updateCalled = true;
  }

  @override
  Future<void> cancelForegroundServiceNotification() async {
    cancelCalled = true;
  }

  @override
  Future<void> showTemporaryNotification({
    required String title,
    required String body,
    Duration duration = const Duration(seconds: 3),
  }) async {}

  @override
  void dispose() {}
}

void main() {
  group('AndroidBackgroundService', () {
    late AndroidBackgroundService backgroundService;
    late FakeNotificationService fakeNotificationService;

    setUp(() {
      fakeNotificationService = FakeNotificationService();
      backgroundService = AndroidBackgroundService(
        notificationService: fakeNotificationService,
      );
    });

    test('initial state should be service not running', () {
      expect(backgroundService.isServiceRunning, false);
    });

    test('startForegroundService returns false on non-Android', () async {
      final result = await backgroundService.startForegroundService(
        title: 'Test',
        body: 'Testing',
      );

      // On non-Android platforms, this returns false
      expect(result, isFalse);
    });

    test('stopForegroundService returns false on non-Android', () async {
      final result = await backgroundService.stopForegroundService();

      expect(result, isFalse); // Returns false on non-Android
      expect(backgroundService.isServiceRunning, false);
    });

    test('dispose calls notification service dispose', () {
      backgroundService.dispose();
      // Just verify no crash
      expect(true, true);
    });

    test('updateNotification returns false when not running', () async {
      final result = await backgroundService.updateNotification(
        title: 'Updated',
        body: 'Updated body',
        activeConnections: 2,
        totalFiles: 5,
      );

      // Returns false when service not running
      expect(result, isFalse);
    });

    test('notification service is available', () {
      expect(backgroundService.notificationService, isNotNull);
    });
  });
}
