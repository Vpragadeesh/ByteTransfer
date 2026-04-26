import 'package:flutter_test/flutter_test.dart';
import 'package:byte_transfer/models/network_status.dart';

void main() {
  group('NetworkStatus', () {
    test('isWiFi returns true for WiFi connection', () {
      final status = NetworkStatus(
        isConnected: true,
        ipAddress: '192.168.1.100',
        ssid: 'MyWiFi',
        type: NetworkType.wifi,
      );
      expect(status.isWiFi, isTrue);
    });

    test('isWiFi returns false for mobile connection', () {
      final status = NetworkStatus(
        isConnected: true,
        ipAddress: '10.0.0.1',
        ssid: null,
        type: NetworkType.mobile,
      );
      expect(status.isWiFi, isFalse);
    });

    test('canShare returns true when connected to WiFi with IP', () {
      final status = NetworkStatus(
        isConnected: true,
        ipAddress: '192.168.1.100',
        ssid: 'MyWiFi',
        type: NetworkType.wifi,
      );
      expect(status.canShare, isTrue);
    });

    test('canShare returns false when not connected', () {
      final status = NetworkStatus(
        isConnected: false,
        ipAddress: null,
        ssid: null,
        type: NetworkType.none,
      );
      expect(status.canShare, isFalse);
    });

    test('canShare returns false when connected but no WiFi', () {
      final status = NetworkStatus(
        isConnected: true,
        ipAddress: '10.0.0.1',
        ssid: null,
        type: NetworkType.mobile,
      );
      expect(status.canShare, isFalse);
    });

    test('canShare returns false when WiFi but no IP', () {
      final status = NetworkStatus(
        isConnected: true,
        ipAddress: null,
        ssid: 'MyWiFi',
        type: NetworkType.wifi,
      );
      expect(status.canShare, isFalse);
    });

    test('equality based on connection, IP, and type', () {
      final status1 = NetworkStatus(
        isConnected: true,
        ipAddress: '192.168.1.100',
        ssid: 'MyWiFi',
        type: NetworkType.wifi,
      );
      final status2 = NetworkStatus(
        isConnected: true,
        ipAddress: '192.168.1.100',
        ssid: 'DifferentSSID',
        type: NetworkType.wifi,
      );
      expect(status1, equals(status2));
    });
  });
}
