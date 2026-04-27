import 'dart:io';
import 'package:flutter/services.dart';
import 'notification_service.dart';

/// Service for managing Android foreground service lifecycle
/// Handles starting/stopping the foreground service to keep the app alive
/// while file sharing is active
class AndroidBackgroundService {
  static const String _methodChannel = 'com.example.byte_transfer/background';
  static const String _methodStartForegroundService = 'startForegroundService';
  static const String _methodStopForegroundService = 'stopForegroundService';

  final NotificationService notificationService;
  bool _isServiceRunning = false;

  AndroidBackgroundService({required this.notificationService});

  /// Check if the foreground service is currently running
  bool get isServiceRunning => _isServiceRunning;

  /// Start the foreground service
  /// This keeps the app alive while sharing files
  Future<bool> startForegroundService({
    required String title,
    required String body,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      // Initialize notification first
      await notificationService.initialize();

      // Show foreground service notification
      await notificationService.showForegroundServiceNotification(
        title: title,
        body: body,
        activeConnections: 0,
        totalFiles: 0,
      );

      // Call native method to start foreground service
      final bool result = await _invokeMethod(
        _methodStartForegroundService,
        {
          'title': title,
          'body': body,
        },
      );

      _isServiceRunning = result;
      return result;
    } catch (e) {
      print('Error starting foreground service: $e');
      return false;
    }
  }

  /// Stop the foreground service
  Future<bool> stopForegroundService() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      // Cancel notification
      await notificationService.cancelForegroundServiceNotification();

      // Call native method to stop foreground service
      final bool result = await _invokeMethod(_methodStopForegroundService);

      _isServiceRunning = false;
      return result;
    } catch (e) {
      print('Error stopping foreground service: $e');
      return false;
    }
  }

  /// Update the foreground service notification
  Future<bool> updateNotification({
    required String title,
    required String body,
    required int activeConnections,
    required int totalFiles,
  }) async {
    if (!Platform.isAndroid || !_isServiceRunning) {
      return false;
    }

    try {
      await notificationService.updateForegroundServiceNotification(
        title: title,
        body: body,
        activeConnections: activeConnections,
        totalFiles: totalFiles,
      );
      return true;
    } catch (e) {
      print('Error updating notification: $e');
      return false;
    }
  }

  /// Invoke a native method via MethodChannel
  Future<bool> _invokeMethod(String method, [dynamic arguments]) async {
    try {
      final MethodChannel channel = MethodChannel(_methodChannel);
      final bool result = await channel.invokeMethod<bool>(method, arguments) ?? false;
      return result;
    } on PlatformException catch (e) {
      print('PlatformException: ${e.code} - ${e.message}');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    notificationService.dispose();
  }
}
