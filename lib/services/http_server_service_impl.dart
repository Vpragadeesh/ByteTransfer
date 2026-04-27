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
      _handleWebInterface(request);
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

  /// Handle web interface (HTML page for browser access)
  void _handleWebInterface(HttpRequest request) {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_generateWebInterface());
  }

  /// Generate HTML web interface with Tailwind CSS
  String _generateWebInterface() {
    final files = _registeredFiles.values.toList();
    final filesHtml = files.map((file) {
      final downloadUrl = '/file/${file.id}';
      return '''
        <div class="bg-gray-800 border border-gray-700 rounded-lg p-4 hover:border-blue-500 transition-colors">
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <h3 class="text-lg font-semibold text-white mb-1">${_escapeHtml(file.name)}</h3>
              <p class="text-gray-400 text-sm mb-3">${file.formattedSize}</p>
              <div class="flex gap-2">
                <a href="$downloadUrl" 
                   download="${_escapeHtml(file.name)}"
                   class="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
                  </svg>
                  Download
                </a>
                <button onclick="copyLink('$downloadUrl')" 
                        class="inline-flex items-center px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                  </svg>
                  Copy Link
                </button>
              </div>
            </div>
            <div class="ml-4">
              ${_getFileIcon(file.extension)}
            </div>
          </div>
        </div>
      ''';
    }).join('\n');

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ByteTransfer - Receive Files</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(10px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .fade-in {
      animation: fadeIn 0.3s ease-out;
    }
  </style>
</head>
<body class="bg-gray-900 min-h-screen">
  <div class="container mx-auto px-4 py-8 max-w-4xl">
    <!-- Header -->
    <div class="text-center mb-8 fade-in">
      <div class="inline-flex items-center justify-center w-16 h-16 bg-blue-600 rounded-full mb-4">
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
        </svg>
      </div>
      <h1 class="text-4xl font-bold text-white mb-2">ByteTransfer</h1>
      <p class="text-gray-400">Receive files wirelessly over your local network</p>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8 fade-in">
      <div class="bg-gray-800 border border-gray-700 rounded-lg p-4">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="w-8 h-8 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
          </div>
          <div class="ml-4">
            <p class="text-gray-400 text-sm">Available Files</p>
            <p class="text-2xl font-bold text-white">${files.length}</p>
          </div>
        </div>
      </div>
      
      <div class="bg-gray-800 border border-gray-700 rounded-lg p-4">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
          </div>
          <div class="ml-4">
            <p class="text-gray-400 text-sm">Status</p>
            <p class="text-xl font-semibold text-green-400">Online</p>
          </div>
        </div>
      </div>
      
      <div class="bg-gray-800 border border-gray-700 rounded-lg p-4">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <svg class="w-8 h-8 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.141 0M1.394 9.393c5.857-5.857 15.355-5.857 21.213 0"/>
            </svg>
          </div>
          <div class="ml-4">
            <p class="text-gray-400 text-sm">Connection</p>
            <p class="text-xl font-semibold text-purple-400">Local</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Files List -->
    <div class="mb-8">
      <h2 class="text-2xl font-bold text-white mb-4">Available Files</h2>
      ${files.isEmpty ? '''
        <div class="bg-gray-800 border border-gray-700 rounded-lg p-12 text-center">
          <svg class="w-16 h-16 text-gray-600 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
          <p class="text-gray-400 text-lg">No files available</p>
          <p class="text-gray-500 text-sm mt-2">Files shared from the sender will appear here</p>
        </div>
      ''' : '''
        <div class="space-y-4 fade-in">
          $filesHtml
        </div>
      '''}
    </div>

    <!-- Footer -->
    <div class="text-center text-gray-500 text-sm">
      <p>ByteTransfer v1.0.0 • No internet required • Files stay on your local network</p>
    </div>
  </div>

  <!-- Toast Notification -->
  <div id="toast" class="fixed bottom-4 right-4 bg-gray-800 border border-gray-700 text-white px-6 py-3 rounded-lg shadow-lg hidden">
    <p id="toast-message"></p>
  </div>

  <script>
    function copyLink(path) {
      const fullUrl = window.location.origin + path;
      navigator.clipboard.writeText(fullUrl).then(() => {
        showToast('Link copied to clipboard!');
      }).catch(() => {
        showToast('Failed to copy link');
      });
    }

    function showToast(message) {
      const toast = document.getElementById('toast');
      const toastMessage = document.getElementById('toast-message');
      toastMessage.textContent = message;
      toast.classList.remove('hidden');
      setTimeout(() => {
        toast.classList.add('hidden');
      }, 3000);
    }

    // Auto-refresh every 5 seconds to check for new files
    setInterval(() => {
      location.reload();
    }, 5000);
  </script>
</body>
</html>
    ''';
  }

  /// Escape HTML special characters
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Get SVG icon for file type
  String _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return '''<svg class="w-12 h-12 text-red-500" fill="currentColor" viewBox="0 0 20 20">
          <path d="M4 18h12V6h-4V2H4v16zm-2 1V0h12l4 4v16H2v-1z"/>
        </svg>''';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return '''<svg class="w-12 h-12 text-purple-500" fill="currentColor" viewBox="0 0 20 20">
          <path d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z"/>
        </svg>''';
      case 'mp3':
      case 'wav':
      case 'aac':
        return '''<svg class="w-12 h-12 text-orange-500" fill="currentColor" viewBox="0 0 20 20">
          <path d="M18 3a1 1 0 00-1.196-.98l-10 2A1 1 0 006 5v9.114A4.369 4.369 0 005 14c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V7.82l8-1.6v5.894A4.37 4.37 0 0015 12c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V3z"/>
        </svg>''';
      case 'mp4':
      case 'avi':
      case 'mov':
        return '''<svg class="w-12 h-12 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
          <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zm12.553 1.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"/>
        </svg>''';
      case 'zip':
      case 'rar':
      case '7z':
        return '''<svg class="w-12 h-12 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
          <path d="M4 3a2 2 0 100 4h12a2 2 0 100-4H4z"/><path fill-rule="evenodd" d="M3 8h14v7a2 2 0 01-2 2H5a2 2 0 01-2-2V8zm5 3a1 1 0 011-1h2a1 1 0 110 2H9a1 1 0 01-1-1z" clip-rule="evenodd"/>
        </svg>''';
      default:
        return '''<svg class="w-12 h-12 text-gray-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clip-rule="evenodd"/>
        </svg>''';
    }
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
