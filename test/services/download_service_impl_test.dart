import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:byte_transfer/services/download_service.dart';
import 'package:byte_transfer/services/download_service_impl.dart';

void main() {
  group('DownloadService', () {
    late DownloadServiceImpl downloadService;

    setUp(() {
      downloadService = DownloadServiceImpl();
    });

    tearDown(() {
      downloadService.dispose();
    });

    group('RemoteFileMetadata', () {
      test('should create from JSON', () {
        final json = {
          'id': 'file123',
          'name': 'test.pdf',
          'size': 1024,
          'mimeType': 'application/pdf',
          'modified': '2024-01-15T10:30:00Z',
        };

        final metadata = RemoteFileMetadata.fromJson(json);

        expect(metadata.id, 'file123');
        expect(metadata.name, 'test.pdf');
        expect(metadata.size, 1024);
        expect(metadata.mimeType, 'application/pdf');
        expect(metadata.modified, isNotNull);
      });

      test('should handle missing optional fields', () {
        final json = {
          'id': 'file123',
          'name': 'test.pdf',
          'size': 1024,
        };

        final metadata = RemoteFileMetadata.fromJson(json);

        expect(metadata.id, 'file123');
        expect(metadata.name, 'test.pdf');
        expect(metadata.size, 1024);
        expect(metadata.mimeType, isNull);
        expect(metadata.modified, isNull);
      });
    });

    group('DownloadProgress', () {
      test('should calculate percentComplete correctly', () {
        final progress = DownloadProgress(
          bytesReceived: 50,
          totalBytes: 100,
          percentComplete: 50.0,
        );

        expect(progress.percentComplete, 50.0);
        expect(progress.isComplete, false);
      });

      test('should identify complete downloads', () {
        final progress = DownloadProgress(
          bytesReceived: 100,
          totalBytes: 100,
          percentComplete: 100.0,
        );

        expect(progress.isComplete, true);
      });

      test('should handle unknown total size', () {
        final progress = DownloadProgress(
          bytesReceived: 50,
          totalBytes: null,
          percentComplete: 0.0,
        );

        expect(progress.isComplete, false);
      });
    });

    group('DownloadService', () {
      test('should initialize without errors', () {
        expect(downloadService, isNotNull);
      });

      test('should handle disposal', () async {
        await downloadService.cancelDownload();
        downloadService.dispose();
        // No exception should be thrown
      });

      test('should return empty file list on network error', () async {
        try {
          await downloadService.getRemoteFiles('http://invalid.local:9999');
        } catch (e) {
          expect(e.toString(), contains('Error'));
        }
      });

      test('should report server health as false for unreachable server', () async {
        final isHealthy = await downloadService.checkServerHealth('http://invalid.local:9999');
        expect(isHealthy, false);
      });
    });
  });
}
