import 'package:flutter/services.dart';
import 'share_link_service.dart';

class ShareLinkServiceImpl implements ShareLinkService {
  static const platform = MethodChannel('com.bytetransfer.app/clipboard');

  @override
  Future<void> copyToClipboard(String shareLink) async {
    try {
      await Clipboard.setData(ClipboardData(text: shareLink));
    } catch (e) {
      throw Exception('Failed to copy to clipboard: $e');
    }
  }

  @override
  Future<String?> getClipboardContent() async {
    try {
      final ClipboardData? result = await Clipboard.getData('text/plain');
      return result?.text;
    } catch (e) {
      throw Exception('Failed to get clipboard content: $e');
    }
  }

  @override
  String generateQrCodeData(String shareLink) {
    // QR code data is simply the share link itself
    // qr_flutter will encode it into a QR code
    return shareLink;
  }

  @override
  String formatShareLink(String shareLink) {
    // Extract the host and path from URL for compact display
    try {
      final uri = Uri.parse(shareLink);
      final host = uri.host;
      final port = uri.port;
      final path = uri.path;
      return '$host:$port$path';
    } catch (e) {
      return shareLink;
    }
  }
}
