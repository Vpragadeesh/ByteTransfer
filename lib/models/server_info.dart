/// Server configuration and status information
class ServerInfo {
  /// Local LAN IP address of the server
  final String ipAddress;

  /// Port number the server is listening on
  final int port;

  /// Timestamp when server was started
  final DateTime startedAt;

  ServerInfo({
    required this.ipAddress,
    required this.port,
    required this.startedAt,
  });

  /// Get server base URL
  String get baseUrl => 'http://$ipAddress:$port';

  /// Get server uptime duration
  Duration get uptime => DateTime.now().difference(startedAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerInfo &&
          runtimeType == other.runtimeType &&
          ipAddress == other.ipAddress &&
          port == other.port;

  @override
  int get hashCode => ipAddress.hashCode ^ port.hashCode;

  @override
  String toString() => 'ServerInfo(baseUrl: $baseUrl, uptime: ${uptime.inSeconds}s)';
}
