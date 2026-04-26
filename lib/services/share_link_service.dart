/// Service for managing share link operations
abstract class ShareLinkService {
  /// Copy share link to clipboard
  Future<void> copyToClipboard(String shareLink);

  /// Get current clipboard content
  Future<String?> getClipboardContent();

  /// Generate QR code data for share link
  String generateQrCodeData(String shareLink);

  /// Format share link for display
  String formatShareLink(String shareLink);
}
