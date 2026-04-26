import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:byte_transfer/models/models.dart';
import 'package:byte_transfer/services/file_service.dart';
import 'package:byte_transfer/services/network_service.dart';
import 'package:byte_transfer/services/http_server_service.dart';
import 'package:byte_transfer/services/permission_service.dart';

/// Application state management using ChangeNotifier
class AppStateManager extends ChangeNotifier {
  // Services
  final FileService fileService;
  final NetworkService networkService;
  final HTTPServerService httpServerService;
  final PermissionService permissionService;

  // State variables
  bool _isInitializing = true;
  bool _permissionsGranted = false;
  NetworkStatus? _networkStatus;
  ServerInfo? _serverInfo;
  List<SharedFile> _sharedFiles = [];
  bool _isServerRunning = false;
  String? _shareLink;
  String? _error;

  // Subscriptions
  late StreamSubscription<NetworkStatus> _networkSubscription;
  late StreamSubscription<ServerEvent> _eventSubscription;

  AppStateManager({
    required this.fileService,
    required this.networkService,
    required this.httpServerService,
    required this.permissionService,
  });

  // Getters
  bool get isInitializing => _isInitializing;
  bool get permissionsGranted => _permissionsGranted;
  NetworkStatus? get networkStatus => _networkStatus;
  ServerInfo? get serverInfo => _serverInfo;
  List<SharedFile> get sharedFiles => List.unmodifiable(_sharedFiles);
  bool get isServerRunning => _isServerRunning;
  String? get shareLink => _shareLink;
  String? get error => _error;

  bool get canShare => _networkStatus?.isConnected ?? false;
  bool get isWiFiConnected => _networkStatus?.type == NetworkType.wifi;

  /// Initialize the app state
  Future<void> initialize() async {
    try {
      _isInitializing = true;
      notifyListeners();

      // Request permissions
      final filePerms = await permissionService.requestFilePermissions();
      final networkPerms = await permissionService.requestNetworkPermissions();

      _permissionsGranted = filePerms == PermissionStatus.granted &&
          networkPerms == PermissionStatus.granted;

      if (!_permissionsGranted) {
        _error = 'Permissions not granted. Please enable in app settings.';
        notifyListeners();
        return;
      }

      // Subscribe to network status
      _networkSubscription = networkService.networkStatusStream.listen(
        (status) {
          _networkStatus = status;
          notifyListeners();
        },
      );

      // Subscribe to server events
      _eventSubscription = httpServerService.events.listen(
        (event) {
          _handleServerEvent(event);
        },
      );

      _error = null;
      _isInitializing = false;
      notifyListeners();
    } catch (e) {
      _error = 'Initialization failed: $e';
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Pick files for sharing
  Future<void> pickFilesForSharing() async {
    try {
      _error = null;
      final files = await fileService.pickFiles(multiple: true);

      _sharedFiles = files;
      // Register files with HTTP server
      for (final file in files) {
        httpServerService.registerFile(file);
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to pick files: $e';
      notifyListeners();
    }
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
      _shareLink = '${_serverInfo!.baseUrl}/file';

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

  @override
  void dispose() {
    _networkSubscription.cancel();
    _eventSubscription.cancel();
    httpServerService.dispose();
    super.dispose();
  }
}
