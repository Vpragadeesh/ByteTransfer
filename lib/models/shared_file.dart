import 'dart:math';
import 'dart:convert';

/// Represents a file being shared via the HTTP server
class SharedFile {
  /// Unique cryptographic identifier for this file
  final String id;

  /// Original filename
  final String name;

  /// Absolute file path
  final String path;

  /// File size in bytes
  final int size;

  /// MIME type for Content-Type header
  final String mimeType;

  /// Timestamp when file was shared
  final DateTime sharedAt;

  SharedFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.mimeType,
    required this.sharedAt,
  });

  /// Generate unique cryptographic identifier with 128-bit entropy
  static String generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Get file extension
  String get extension {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last : '';
  }

  /// Format file size for human-readable display
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedFile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path;

  @override
  int get hashCode => id.hashCode ^ path.hashCode;

  @override
  String toString() => 'SharedFile(id: $id, name: $name, size: $size)';
}
