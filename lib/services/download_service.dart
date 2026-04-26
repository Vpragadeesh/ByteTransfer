import 'dart:async';

/// Download progress event for tracking file downloads
class DownloadProgress {
  final int bytesReceived;
  final int? totalBytes;
  final double percentComplete;

  DownloadProgress({
    required this.bytesReceived,
    required this.totalBytes,
    required this.percentComplete,
  });

  bool get isComplete => totalBytes != null && bytesReceived >= totalBytes!;
}

/// File metadata received from remote server
class RemoteFileMetadata {
  final String id;
  final String name;
  final int size;
  final String? mimeType;
  final DateTime? modified;

  RemoteFileMetadata({
    required this.id,
    required this.name,
    required this.size,
    this.mimeType,
    this.modified,
  });

  factory RemoteFileMetadata.fromJson(Map<String, dynamic> json) {
    return RemoteFileMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
      mimeType: json['mimeType'] as String?,
      modified: json['modified'] != null
          ? DateTime.parse(json['modified'] as String)
          : null,
    );
  }
}

/// Abstract download service for receiving files
abstract class DownloadService {
  /// Get list of available files from remote server
  /// Returns list of file metadata
  Future<List<RemoteFileMetadata>> getRemoteFiles(String baseUrl);

  /// Download a file from remote server with progress tracking
  /// [baseUrl]: Base URL of the remote server (e.g., http://192.168.1.100:8080)
  /// [fileId]: ID of the file to download
  /// [fileName]: Name to save the file as
  /// Returns stream of download progress events
  Stream<DownloadProgress> downloadFile({
    required String baseUrl,
    required String fileId,
    required String fileName,
  });

  /// Cancel an ongoing download
  Future<void> cancelDownload();

  /// Get health status of remote server
  Future<bool> checkServerHealth(String baseUrl);
}
