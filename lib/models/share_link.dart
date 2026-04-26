/// Represents a shareable link to a file
class ShareLink {
  /// The complete HTTP URL
  final String url;

  /// The file ID extracted from the URL
  final String fileId;

  ShareLink({
    required this.url,
    required this.fileId,
  });

  /// Parse a URL string to extract ShareLink components
  static ShareLink? parse(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      final pathSegments = uri.pathSegments;
      if (pathSegments.length != 2 || pathSegments[0] != 'file') {
        return null;
      }

      return ShareLink(url: url, fileId: pathSegments[1]);
    } catch (e) {
      return null;
    }
  }

  /// Validate if the link has correct format: http://{ip}:{port}/file/{id}
  bool get isValid {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      return uri.scheme == 'http' &&
          uri.pathSegments.length == 2 &&
          uri.pathSegments[0] == 'file' &&
          uri.pathSegments[1].isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareLink &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          fileId == other.fileId;

  @override
  int get hashCode => url.hashCode ^ fileId.hashCode;

  @override
  String toString() => 'ShareLink(fileId: $fileId)';
}
