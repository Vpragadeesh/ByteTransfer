import 'package:byte_transfer/models/models.dart';

enum NetworkErrorType {
  noWiFi,
  noIPAddress,
  serverStartFailed,
  connectionLost,
}

/// Abstract interface for network service operations
abstract class NetworkService {
  /// Get device's local IP address on LAN
  Future<String?> getLocalIPAddress();

  /// Get current WiFi SSID
  Future<String?> getWiFiSSID();

  /// Check if connected to WiFi
  Future<bool> isConnectedToWiFi();

  /// Stream of network connectivity changes
  Stream<NetworkStatus> get networkStatusStream;

  /// Validate IP address is on local network (private ranges)
  bool isLocalNetworkAddress(String ip);

  /// Check if address is localhost
  bool isLocalhost(String ip);
}
