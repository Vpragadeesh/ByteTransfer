import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:byte_transfer/models/models.dart';
import 'package:byte_transfer/services/file_service.dart';
import 'http_server_service.dart';

/// Implementation of HTTPServerService using dart:io HttpServer
class HTTPServerServiceImpl implements HTTPServerService {
  HttpServer? _server;
  ServerInfo? _serverInfo;
  final FileService _fileService;
  final Map<String, SharedFile> _registeredFiles = {};
  final StreamController<ServerEvent> _eventsController =
      StreamController<ServerEvent>.broadcast();
  int _activeConnections = 0;

  HTTPServerServiceImpl({required FileService fileService})
      : _fileService = fileService;

  /// Start HTTP server on available port
  @override
  Future<ServerInfo> startServer({String? ipAddress, int? port}) async {
    if (_server != null) {
      throw StateError('Server already running');
    }

    try {
      final bindAddress = ipAddress ?? '0.0.0.0';
      final bindPort = port ?? 0; // 0 means OS will choose available port

      _server = await HttpServer.bind(bindAddress, bindPort);

      // Handle incoming requests
      _server!.listen((request) async {
        _activeConnections++;
        try {
          await _handleRequest(request);
        } catch (e) {
          _recordEvent(
            type: ServerEventType.error,
            message: 'Request handling error: $e',
          );
          try {
            request.response.statusCode = 500;
            request.response.write(jsonEncode({'error': 'Internal server error'}));
          } catch (_) {}
        } finally {
          _activeConnections--;
          try {
            await request.response.close();
          } catch (_) {}
        }
      });

      final actualPort = _server!.port;
      final actualAddress = ipAddress ?? 'localhost';

      _serverInfo = ServerInfo(
        ipAddress: actualAddress,
        port: actualPort,
        startedAt: DateTime.now(),
      );

      _recordEvent(
        type: ServerEventType.connectionOpened,
        message: 'Server started on http://$actualAddress:$actualPort',
      );

      return _serverInfo!;
    } catch (e) {
      _recordEvent(
        type: ServerEventType.error,
        message: 'Server start failed: $e',
      );
      rethrow;
    }
  }

  /// Handle incoming HTTP request
  Future<void> _handleRequest(HttpRequest request) async {
    final pathParts = request.uri.path.split('/').where((p) => p.isNotEmpty).toList();

    if (request.uri.path == '/') {
      _handleRoot(request);
    } else if (request.uri.path == '/health') {
      _handleHealth(request);
    } else if (request.uri.path == '/files') {
      _handleListFiles(request);
    } else if (pathParts.isNotEmpty && pathParts[0] == 'file') {
      await _handleFileDownload(request, pathParts.length > 1 ? pathParts[1] : '');
    } else {
      request.response.statusCode = 404;
      request.response.write(jsonEncode({'error': 'not_found'}));
    }
  }

  /// Handle root endpoint
  void _handleRoot(HttpRequest request) {
    request.response.headers.contentType =
        ContentType.json;
    request.response.write(jsonEncode({
      'app': 'ByteTransfer',
      'version': '1.0.0',
      'status': 'running',
      'endpoint': '/file/{id}',
    }));
  }

  /// Handle health check endpoint
  void _handleHealth(HttpRequest request) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'status': 'ok',
      'uptime': _serverInfo?.uptime.inSeconds ?? 0,
    }));
  }

  /// Handle file download endpoint
  Future<void> _handleFileDownload(HttpRequest request, String fileId) async {
    if (fileId.isEmpty) {
      request.response.statusCode = 400;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': 'invalid_file_id'}));
      return;
    }

    final file = _registeredFiles[fileId];
    if (file == null) {
      _recordEvent(
        type: ServerEventType.error,
        message: 'File not found: $fileId',
      );
      request.response.statusCode = 404;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': 'file_not_found'}));
      return;
    }

    try {
      _recordEvent(
        type: ServerEventType.request,
        fileId: fileId,
        clientIp: request.connectionInfo?.remoteAddress.address,
        message: 'Download started: ${file.name} (${file.formattedSize})',
      );

      request.response.headers.contentType = ContentType.parse(file.mimeType);
      request.response.headers.add('Content-Length', file.size.toString());
      request.response.headers.add(
        'Content-Disposition',
        'attachment; filename="${file.name}"',
      );
      request.response.headers.add('Cache-Control', 'no-cache, no-store, must-revalidate');

      // Stream file content
      final fileStream = _fileService.getFileStream(fileId);
      await for (final chunk in fileStream) {
        request.response.add(chunk);
      }
    } catch (e) {
      _recordEvent(
        type: ServerEventType.error,
        fileId: fileId,
        message: 'Download failed: $e',
      );
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': 'download_failed'}));
    }
  }

  /// Handle list files endpoint
  void _handleListFiles(HttpRequest request) {
    final files = _registeredFiles.values
        .map((f) => {
              'id': f.id,
              'name': f.name,
              'size': f.size,
              'formattedSize': f.formattedSize,
              'mimeType': f.mimeType,
              'sharedAt': f.sharedAt.toIso8601String(),
            })
        .toList();

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'files': files,
      'count': files.length,
    }));
  }

  /// Stop HTTP server gracefully
  @override
  Future<void> stopServer() async {
    if (_server == null) {
      return;
    }

    try {
      await _server!.close();
      _server = null;
      _serverInfo = null;
      _activeConnections = 0;
      _registeredFiles.clear();

      _recordEvent(
        type: ServerEventType.connectionClosed,
        message: 'Server stopped gracefully',
      );
    } catch (e) {
      _recordEvent(
        type: ServerEventType.error,
        message: 'Server stop failed: $e',
      );
      rethrow;
    }
  }

  /// Check if server is running
  @override
  bool get isRunning => _server != null;

  /// Get current server info
  @override
  ServerInfo? get serverInfo => _serverInfo;

  /// Register file for serving
  @override
  void registerFile(SharedFile file) {
    _registeredFiles[file.id] = file;
  }

  /// Unregister file from serving
  @override
  void unregisterFile(String fileId) {
    _registeredFiles.remove(fileId);
  }

  /// Get active connections count
  @override
  int get activeConnections => _activeConnections;

  /// Stream of server events
  @override
  Stream<ServerEvent> get events => _eventsController.stream;

  /// Get list of all registered files
  @override
  List<SharedFile> getRegisteredFiles() {
    return List.unmodifiable(_registeredFiles.values);
  }

  /// Record server event
  void _recordEvent({
    required ServerEventType type,
    String? fileId,
    String? clientIp,
    String? message,
  }) {
    final event = ServerEvent(
      type: type,
      fileId: fileId,
      clientIp: clientIp,
      timestamp: DateTime.now(),
      message: message,
    );
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  /// Dispose resources
  void dispose() {
    _eventsController.close();
  }
}
