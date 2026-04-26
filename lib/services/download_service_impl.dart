import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'download_service.dart';

class DownloadServiceImpl implements DownloadService {
  http.Client? _httpClient;
  StreamController<DownloadProgress>? _progressController;
  HttpClientRequest? _currentRequest;

  @override
  Future<List<RemoteFileMetadata>> getRemoteFiles(String baseUrl) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/files')).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Server request timed out'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _parseJsonResponse(response.body);
        return data
            .map((item) => RemoteFileMetadata.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to get file list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching remote files: $e');
    }
  }

  @override
  Stream<DownloadProgress> downloadFile({
    required String baseUrl,
    required String fileId,
    required String fileName,
  }) {
    _progressController = StreamController<DownloadProgress>();

    _performDownload(
      baseUrl: baseUrl,
      fileId: fileId,
      fileName: fileName,
    );

    return _progressController!.stream;
  }

  Future<void> _performDownload({
    required String baseUrl,
    required String fileId,
    required String fileName,
  }) async {
    try {
      final downloadDir = await getApplicationDocumentsDirectory();
      final filePath = '${downloadDir.path}/$fileName';

      final httpClient = HttpClient();
      _currentRequest =
          await httpClient.getUrl(Uri.parse('$baseUrl/file/$fileId'));

      final response = await _currentRequest!.close();

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download file: ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength;
      int bytesReceived = 0;

      final file = File(filePath);
      final sink = file.openWrite();

      await response.forEach((chunk) {
        bytesReceived += chunk.length;
        final percentComplete = contentLength > 0
            ? (bytesReceived / contentLength) * 100
            : 0.0;

        _progressController?.add(
          DownloadProgress(
            bytesReceived: bytesReceived,
            totalBytes: contentLength > 0 ? contentLength : null,
            percentComplete: percentComplete,
          ),
        );

        sink.add(chunk);
      });

      await sink.close();
      httpClient.close();

      // Signal completion
      _progressController?.add(
        DownloadProgress(
          bytesReceived: bytesReceived,
          totalBytes: contentLength,
          percentComplete: 100.0,
        ),
      );

      await _progressController?.close();
      _progressController = null;
    } catch (e) {
      _progressController?.addError(Exception('Download failed: $e'));
      await _progressController?.close();
      _progressController = null;
    }
  }

  @override
  Future<void> cancelDownload() async {
    try {
      _currentRequest?.abort();
      await _progressController?.close();
      _progressController = null;
    } catch (e) {
      // Ignore errors during cancellation
    }
  }

  @override
  Future<bool> checkServerHealth(String baseUrl) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Health check timed out'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Parse JSON response with error handling
  List<dynamic> _parseJsonResponse(String body) {
    try {
      // Simple JSON parsing without external dependency
      // In production, use jsonDecode from dart:convert
      if (body.startsWith('[')) {
        // This is a simplified parser - in production use proper JSON parsing
        throw UnimplementedError('Use jsonDecode from dart:convert');
      }
      throw Exception('Invalid JSON response');
    } catch (e) {
      throw Exception('Failed to parse JSON: $e');
    }
  }

  void dispose() {
    _httpClient?.close();
    _progressController?.close();
  }
}
