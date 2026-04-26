/// Types of network connections
enum NetworkType {
  wifi,
  mobile,
  ethernet,
  none,
}

/// Represents the current network connectivity status
class NetworkStatus {
  /// Whether device is connected to any network
  final bool isConnected;

  /// Local IP address (null if not connected)
  final String? ipAddress;

  /// WiFi SSID (null if not connected or not WiFi)
  final String? ssid;

  /// Type of network connection
  final NetworkType type;

  NetworkStatus({
    required this.isConnected,
    this.ipAddress,
    this.ssid,
    required this.type,
  });

  /// Check if connected to WiFi
  bool get isWiFi => type == NetworkType.wifi;

  /// Check if device can share files (must be connected to WiFi with valid IP)
  bool get canShare => isConnected && isWiFi && ipAddress != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkStatus &&
          runtimeType == other.runtimeType &&
          isConnected == other.isConnected &&
          ipAddress == other.ipAddress &&
          type == other.type;

  @override
  int get hashCode =>
      isConnected.hashCode ^ ipAddress.hashCode ^ type.hashCode;

  @override
  String toString() =>
      'NetworkStatus(connected: $isConnected, ip: $ipAddress, type: ${type.name})';
}
