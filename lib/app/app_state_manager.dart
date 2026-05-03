import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:byte_transfer/models/models.dart';
import 'package:byte_transfer/models/permissions.dart';
import 'package:byte_transfer/services/file_service.dart';
import 'package:byte_transfer/services/network_service.dart';
import 'package:byte_transfer/services/http_server_service.dart';
import 'package:byte_transfer/services/permission_service.dart';
import 'package:byte_transfer/services/download_service.dart';
import 'package:byte_transfer/services/android_background_service.dart';
import 'package:byte_transfer/services/notification_service.dart';

/// Application state management using ChangeNotifier
class AppStateManager extends ChangeNotifier {
  // Services
  final FileService fileService;
  final NetworkService networkService;
  final HTTPServerService httpServerService;
  final PermissionService permissionService;
  final DownloadService? downloadService;
  final AndroidBackgroundService? backgroundService;

  // State variables
  bool _isInitializing = true;
  bool _permissionsGranted = false;
  NetworkStatus? _networkStatus;
  ServerInfo? _serverInfo;
  List<SharedFileWithPermissions> _sharedFiles = [];
  bool _isServerRunning = false;
  String? _shareLink;
  String? _error;
  List<RemoteFileMetadata> _remoteFiles = [];
  DownloadProgress? _downloadProgress;
  bool _isDownloading = false;

  // Subscriptions
  late StreamSubscription<NetworkStatus> _networkSubscription;
  late StreamSubscription<ServerEvent> _eventSubscription;
  StreamSubscription<DownloadProgress>? _downloadSubscription;

  AppStateManager({
    required this.fileService,
    required this.networkService,
    required this.httpServerService,
    required this.permissionService,
    this.downloadService,
    this.backgroundService,
  });

  // Getters
  bool get isInitializing => _isInitializing;
  bool get permissionsGranted => _permissionsGranted;
  NetworkStatus? get networkStatus => _networkStatus;
  ServerInfo? get serverInfo => _serverInfo;
  List<SharedFileWithPermissions> get sharedFiles => List.unmodifiable(_sharedFiles);
  bool get isServerRunning => _isServerRunning;
  String? get shareLink => _shareLink;
  String? get error => _error;
  List<RemoteFileMetadata> get remoteFiles => List.unmodifiable(_remoteFiles);
  DownloadProgress? get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;

  bool get canShare => _networkStatus?.isConnected ?? false;
  bool get isWiFiConnected => _networkStatus?.type == NetworkType.wifi;

  /// Initialize the app state
  Future<void> initialize() async {
    try {
      _isInitializing = true;
      notifyListeners();

      // Request permissions with timeout
      try {
        final filePerms = await permissionService.requestFilePermissions()
            .timeout(const Duration(seconds: 10));
        final networkPerms = await permissionService.requestNetworkPermissions()
            .timeout(const Duration(seconds: 10));

        _permissionsGranted = filePerms == PermissionStatus.granted &&
            networkPerms == PermissionStatus.granted;
      } catch (e) {
        // If permission request times out or fails, continue anyway
        // User can grant permissions later if needed
        _permissionsGranted = true;
        debugPrint('Permission request failed or timed out: $e');
      }

      // Subscribe to network status
      _networkSubscription = networkService.networkStatusStream.listen(
        (status) {
          _networkStatus = status;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Network status stream error: $error');
        },
      );

      // Subscribe to server events
      _eventSubscription = httpServerService.events.listen(
        (event) {
          _handleServerEvent(event);
        },
        onError: (error) {
          debugPrint('Server event stream error: $error');
        },
      );

      // Get initial network status
      try {
        final isWiFi = await networkService.isConnectedToWiFi()
            .timeout(const Duration(seconds: 5));
        final ipAddress = await networkService.getLocalIPAddress()
            .timeout(const Duration(seconds: 5));
        final ssid = await networkService.getWiFiSSID()
            .timeout(const Duration(seconds: 5));

        _networkStatus = NetworkStatus(
          isConnected: isWiFi || ipAddress != null,
          ipAddress: ipAddress,
          ssid: ssid,
          type: isWiFi ? NetworkType.wifi : NetworkType.none,
        );
      } catch (e) {
        debugPrint('Failed to get initial network status: $e');
        // Set a default network status
        _networkStatus = NetworkStatus(
          isConnected: false,
          ipAddress: null,
          ssid: null,
          type: NetworkType.none,
        );
      }

      _error = null;
      _isInitializing = false;
      notifyListeners();
    } catch (e) {
      _error = 'Initialization failed: $e';
      _isInitializing = false;
      _permissionsGranted = true; // Allow app to continue
      notifyListeners();
    }
  }

  /// Pick files for sharing
  Future<void> pickFilesForSharing() async {
    try {
      _error = null;
      final files = await fileService.pickFiles(multiple: true);

      // Wrap SharedFile in SharedFileWithPermissions with default permissions
      _sharedFiles = files
          .map((file) => SharedFileWithPermissions(
                id: file.id,
                name: file.name,
                path: file.path,
                size: file.size,
                mimeType: file.mimeType,
                sharedAt: file.sharedAt,
                requiredPermissions: {}, // Public by default
                isPublic: true, // Public by default
              ))
          .toList();
      
      // Register files with HTTP server
      for (final file in _sharedFiles) {
        httpServerService.registerFileWithPermissions(file);
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to pick files: $e';
      notifyListeners();
    }
  }

  /// Update file permissions
  void updateFilePermissions(
    String fileId, {
    Set<FilePermission>? requiredPermissions,
    bool? isPublic,
  }) {
    final index = _sharedFiles.indexWhere((f) => f.id == fileId);
    if (index != -1) {
      final file = _sharedFiles[index];
      _sharedFiles[index] = file.copyWith(
        requiredPermissions: requiredPermissions ?? file.requiredPermissions,
        isPublic: isPublic ?? file.isPublic,
      );
      notifyListeners();
    }
  }

  /// Generate a permission token for a receiver
  String? generateReceiverToken({
    required String receiverName,
    required Set<FilePermission> roles,
    DateTime? expiresAt,
  }) {
    if (!_isServerRunning || _serverInfo == null) {
      return null;
    }

    // Generate a unique receiver ID
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    final receiverId = base64Url.encode(values).replaceAll('=', '');

    final receiver = ReceiverPermissions(
      id: receiverId,
      name: receiverName,
      roles: roles,
      generatedAt: DateTime.now(),
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 7)),
    );

    // You'll need to provide the server secret from HTTPServerServiceImpl
    // For now, returning null as this needs integration with the server
    return receiver.generateToken(secret: 'default-secret-change-in-production');
  }

  /// Start sharing server
  Future<void> startServer() async {
    try {
      if (_isServerRunning) {
        return;
      }

      if (!canShare) {
        _error = 'Not connected to WiFi';
        notifyListeners();
        return;
      }

      // Get local IP
      final localIp = await networkService.getLocalIPAddress();
      if (localIp == null) {
        _error = 'Could not determine local IP address';
        notifyListeners();
        return;
      }

      _error = null;
      _serverInfo = await httpServerService.startServer(
        ipAddress: localIp,
        port: 8080,
      );

      _isServerRunning = true;
      // Don't set a single share link - we'll generate per-file links in the UI
      _shareLink = _serverInfo!.baseUrl;

      // Start Android foreground service
      if (backgroundService != null && _sharedFiles.isNotEmpty) {
        await backgroundService!.startForegroundService(
          title: 'Libre-Send',
          body: 'Sharing ${_sharedFiles.length} file(s)',
        );
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to start server: $e';
      _isServerRunning = false;
      notifyListeners();
    }
  }

  /// Stop sharing server
  Future<void> stopServer() async {
    try {
      await httpServerService.stopServer();
      
      // Stop Android foreground service
      if (backgroundService != null) {
        await backgroundService!.stopForegroundService();
      }
      
      _isServerRunning = false;
      _shareLink = null;
      _sharedFiles = [];
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to stop server: $e';
      notifyListeners();
    }
  }

  /// Remove file from sharing
  void removeFile(String fileId) {
    httpServerService.unregisterFile(fileId);
    _sharedFiles.removeWhere((f) => f.id == fileId);
    notifyListeners();
  }

  /// Clear all shared files
  void clearAllFiles() {
    for (final file in _sharedFiles) {
      httpServerService.unregisterFile(file.id);
    }
    _sharedFiles = [];
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Handle server events
  void _handleServerEvent(ServerEvent event) {
    // Log events or update UI based on event type
    if (event.type == ServerEventType.error) {
      _error = 'Server error: ${event.message}';
      notifyListeners();
    }
  }

  /// Connect to remote server and fetch file list
  Future<void> connectToRemoteServer(String shareLink) async {
    try {
      _error = null;
      _remoteFiles = [];
      notifyListeners();

      if (downloadService == null) {
        _error = 'Download service not available';
        notifyListeners();
        return;
      }

      // Extract base URL from share link
      final uri = Uri.parse(shareLink);
      final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';

      // Check server health first
      final isHealthy = await downloadService!.checkServerHealth(baseUrl);
      if (!isHealthy) {
        _error = 'Cannot connect to server. Please check the link and try again.';
        notifyListeners();
        return;
      }

      // Fetch file list
      _remoteFiles = await downloadService!.getRemoteFiles(baseUrl);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to connect: $e';
      notifyListeners();
    }
  }

  /// Download a file from remote server
  Future<void> downloadRemoteFile({
    required String baseUrl,
    required String fileId,
    required String fileName,
  }) async {
    try {
      if (downloadService == null) {
        _error = 'Download service not available';
        notifyListeners();
        return;
      }

      _isDownloading = true;
      _downloadProgress = null;
      _error = null;
      notifyListeners();

      // Cancel any previous download
      await _downloadSubscription?.cancel();

      // Start download and listen to progress
      _downloadSubscription = downloadService!
          .downloadFile(
            baseUrl: baseUrl,
            fileId: fileId,
            fileName: fileName,
          )
          .listen(
        (progress) {
          _downloadProgress = progress;
          notifyListeners();

          if (progress.isComplete) {
            _isDownloading = false;
            _error = null;
            notifyListeners();
          }
        },
        onError: (error) {
          _error = 'Download failed: $error';
          _isDownloading = false;
          notifyListeners();
        },
        onDone: () {
          _isDownloading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = 'Failed to start download: $e';
      _isDownloading = false;
      notifyListeners();
    }
  }

  /// Cancel ongoing download
  Future<void> cancelDownload() async {
    try {
      await downloadService?.cancelDownload();
      await _downloadSubscription?.cancel();
      _isDownloading = false;
      _downloadProgress = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to cancel download: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _networkSubscription.cancel();
    _eventSubscription.cancel();
    _downloadSubscription?.cancel();
    httpServerService.dispose();
    backgroundService?.dispose();
    super.dispose();
  }
}
