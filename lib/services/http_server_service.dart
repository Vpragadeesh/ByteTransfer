import 'package:byte_transfer/models/models.dart';

enum ServerErrorType {
  portInUse,
  bindFailed,
  startFailed,
  stopFailed,
}

/// Abstract interface for HTTP server operations
abstract class HTTPServerService {
  /// Start HTTP server on available port
  Future<ServerInfo> startServer({String? ipAddress, int? port});

  /// Stop HTTP server gracefully
  Future<void> stopServer();

  /// Check if server is running
  bool get isRunning;

  /// Get current server info
  ServerInfo? get serverInfo;

  /// Register file for serving
  void registerFile(SharedFile file);

  /// Unregister file from serving
  void unregisterFile(String fileId);

  /// Get active connections count
  int get activeConnections;

  /// Stream of server events (requests, errors)
  Stream<ServerEvent> get events;

  /// Get list of all registered files
  List<SharedFile> getRegisteredFiles();
}
