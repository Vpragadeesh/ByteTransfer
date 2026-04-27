import 'dart:io';
import 'package:byte_transfer/models/models.dart';
import 'file_service.dart';

/// Linux-specific implementation of FileService using native file dialogs
class FileServiceLinux implements FileService {
  // In-memory map of file ID -> SharedFile for quick lookup
  final Map<String, SharedFile> _sharedFiles = {};

  /// Pick files from device storage using zenity (Linux native dialog)
  @override
  Future<List<SharedFile>> pickFiles({bool multiple = true}) async {
    try {
      // Try zenity first (most common on Linux)
      final result = await _pickFilesWithZenity(multiple);
      if (result.isNotEmpty) {
        return result;
      }

      // Fallback to kdialog (KDE)
      final kdeResult = await _pickFilesWithKDialog(multiple);
      if (kdeResult.isNotEmpty) {
        return kdeResult;
      }

      // If no dialog available, throw error
      throw Exception(
        'No file picker available. Please install zenity or kdialog:\n'
        'Ubuntu/Debian: sudo apt install zenity\n'
        'Arch Linux: sudo pacman -S zenity\n'
        'Fedora: sudo dnf install zenity',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Pick files using zenity (GNOME/GTK file dialog)
  Future<List<SharedFile>> _pickFilesWithZenity(bool multiple) async {
    try {
      final args = [
        '--file-selection',
        '--title=Select Files',
      ];

      if (multiple) {
        args.add('--multiple');
        args.add('--separator=\n');
      }

      final result = await Process.run('zenity', args);

      if (result.exitCode != 0) {
        return [];
      }

      final output = (result.stdout as String).trim();
      if (output.isEmpty) {
        return [];
      }

      final paths = output.split('\n').where((p) => p.isNotEmpty).toList();
      return await _createSharedFilesFromPaths(paths);
    } catch (e) {
      return [];
    }
  }

  /// Pick files using kdialog (KDE file dialog)
  Future<List<SharedFile>> _pickFilesWithKDialog(bool multiple) async {
    try {
      final args = [
        '--getopenfilename',
        Platform.environment['HOME'] ?? '~',
      ];

      if (multiple) {
        args[0] = '--getopenfilename';
        args.add('--multiple');
        args.add('--separate-output');
      }

      final result = await Process.run('kdialog', args);

      if (result.exitCode != 0) {
        return [];
      }

      final output = (result.stdout as String).trim();
      if (output.isEmpty) {
        return [];
      }

      final paths = output.split('\n').where((p) => p.isNotEmpty).toList();
      return await _createSharedFilesFromPaths(paths);
    } catch (e) {
      return [];
    }
  }

  /// Create SharedFile objects from file paths
  Future<List<SharedFile>> _createSharedFilesFromPaths(List<String> paths) async {
    final files = <SharedFile>[];

    for (final path in paths) {
      try {
        if (await validateFile(path)) {
          final file = File(path);
          final stat = await file.stat();
          final name = path.split(Platform.pathSeparator).last;

          final sharedFile = SharedFile(
            id: SharedFile.generateId(),
            name: name,
            path: path,
            size: stat.size,
            mimeType: _getMimeType(_getExtension(path)),
            sharedAt: DateTime.now(),
          );

          _sharedFiles[sharedFile.id] = sharedFile;
          files.add(sharedFile);
        }
      } catch (e) {
        // Skip files that can't be accessed
        continue;
      }
    }

    return files;
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
      'html': 'text/html',
      'css': 'text/css',
      'js': 'application/javascript',
      'xml': 'application/xml',
      'csv': 'text/csv',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  /// Extract file extension from path
  String _getExtension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last : '';
  }
}
