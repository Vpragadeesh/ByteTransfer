import 'package:byte_transfer/models/models.dart';

/// File metadata information
class FileMetadata {
  final String name;
  final int size;
  final String mimeType;
  final DateTime lastModified;

  FileMetadata({
    required this.name,
    required this.size,
    required this.mimeType,
    required this.lastModified,
  });
}

/// Abstract interface for file service operations
abstract class FileService {
  /// Pick single or multiple files from device storage
  Future<List<SharedFile>> pickFiles({bool multiple = true});

  /// Get file metadata without reading content
  Future<FileMetadata> getFileMetadata(String path);

  /// Get file stream for HTTP serving (64 KB chunks)
  Stream<List<int>> getFileStream(String fileId);

  /// Validate file is readable
  Future<bool> validateFile(String path);

  /// Get file by identifier
  SharedFile? getFileById(String fileId);

  /// Remove file from shared list
  void removeFile(String fileId);

  /// Clear all shared files
  void clearAllFiles();

  /// Get all shared files
  List<SharedFile> getAllSharedFiles();
}
