/// Share Link Generator for creating shareable URLs and QR codes
class ShareLinkGenerator {
  /// Generate HTTP URL for file in format: http://{ip}:{port}/file/{id}
  String generateShareLink(String fileId, String ipAddress, int port) {
    return 'http://$ipAddress:$port/file/$fileId';
  }

  /// Generate QR code data from share link
  String generateQRCode(String shareLink) {
    // QR code data is the link itself
    return shareLink;
  }

  /// Parse share link to extract file ID
  String? parseFileIdFromLink(String link) {
    try {
      final uri = Uri.tryParse(link);
      if (uri == null) return null;

      final pathSegments = uri.pathSegments;
      if (pathSegments.length != 2 || pathSegments[0] != 'file') {
        return null;
      }

      return pathSegments[1];
    } catch (e) {
      return null;
    }
  }

  /// Validate share link format
  bool isValidShareLink(String link) {
    try {
      final uri = Uri.tryParse(link);
      if (uri == null) return false;

      return uri.scheme == 'http' &&
          uri.pathSegments.length == 2 &&
          uri.pathSegments[0] == 'file' &&
          uri.pathSegments[1].isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
