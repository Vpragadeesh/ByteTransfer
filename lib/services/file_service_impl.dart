import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:byte_transfer/models/models.dart';
import 'file_service.dart';

/// Implementation of FileService using file_picker
class FileServiceImpl implements FileService {
  // In-memory map of file ID -> SharedFile for quick lookup
  final Map<String, SharedFile> _sharedFiles = {};

  /// Pick files from device storage
  @override
  Future<List<SharedFile>> pickFiles({bool multiple = true}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: multiple,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final files = <SharedFile>[];
      for (final file in result.files) {
        if (file.path != null) {
          // Validate file is readable before adding
          if (await validateFile(file.path!)) {
            final sharedFile = SharedFile(
              id: SharedFile.generateId(),
              name: file.name,
              path: file.path!,
              size: file.size,
              mimeType: _getMimeType(file.extension ?? ''),
              sharedAt: DateTime.now(),
            );
            _sharedFiles[sharedFile.id] = sharedFile;
            files.add(sharedFile);
          }
        }
      }

      return files;
    } catch (e) {
      rethrow;
    }
  }

  /// Get file metadata without reading full content
  @override
  Future<FileMetadata> getFileMetadata(String path) async {
    try {
      final file = File(path);
      final stat = await file.stat();

      return FileMetadata(
        name: file.path.split(Platform.pathSeparator).last,
        size: stat.size,
        mimeType: _getMimeType(_getExtension(path)),
        lastModified: stat.modified,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get file stream for HTTP serving (64 KB chunks)
  @override
  Stream<List<int>> getFileStream(String fileId) async* {
    final sharedFile = _sharedFiles[fileId];
    if (sharedFile == null) {
      throw FileSystemException('File not found', fileId);
    }

    try {
      final file = File(sharedFile.path);

      // Verify file still exists and is readable
      if (!await file.exists()) {
        throw FileSystemException('File no longer exists', sharedFile.path);
      }

      const chunkSize = 64 * 1024; // 64 KB chunks
      final stream = file.openRead();

      await for (final chunk in stream) {
        // Ensure chunk doesn't exceed size limit
        if (chunk.length <= chunkSize) {
          yield chunk;
        } else {
          // Split oversized chunk (shouldn't happen with openRead)
          for (int i = 0; i < chunk.length; i += chunkSize) {
            final end = (i + chunkSize > chunk.length) ? chunk.length : i + chunkSize;
            yield chunk.sublist(i, end);
          }
        }
      }
    } catch (e) {
      throw FileSystemException('Error reading file', fileId);
    }
  }

  /// Validate file is readable
  @override
  Future<bool> validateFile(String path) async {
    try {
      final file = File(path);

      // Check file exists
      if (!await file.exists()) {
        return false;
      }

      // Check file is readable (try accessing metadata)
      await file.stat();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get file by identifier
  @override
  SharedFile? getFileById(String fileId) {
    return _sharedFiles[fileId];
  }

  /// Remove file from shared list
  @override
  void removeFile(String fileId) {
    _sharedFiles.remove(fileId);
  }

  /// Clear all shared files
  @override
  void clearAllFiles() {
    _sharedFiles.clear();
  }

  /// Get all shared files
  @override
  List<SharedFile> getAllSharedFiles() {
    return List.unmodifiable(_sharedFiles.values);
  }

  /// Get MIME type from file extension
  String _getMimeType(String extension) {
    final ext = extension.toLowerCase();
    const mimeTypes = {
      'txt': 'text/plain',
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'zip': 'application/zip',
      'json': 'application/json',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  /// Extract file extension from path
  String _getExtension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last : '';
  }
}
