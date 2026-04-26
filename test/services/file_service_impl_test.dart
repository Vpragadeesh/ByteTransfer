import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:byte_transfer/services/file_service_impl.dart';
import 'package:byte_transfer/models/shared_file.dart';

void main() {
  group('FileServiceImpl', () {
    late FileServiceImpl fileService;
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('byte_transfer_test_');
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    setUp(() {
      fileService = FileServiceImpl();
    });

    test('validateFile returns true for existing readable file', () async {
      // Create a test file
      final testFile = File('${tempDir.path}/test.txt');
      await testFile.writeAsString('test content');

      final result = await fileService.validateFile(testFile.path);
      expect(result, isTrue);

      await testFile.delete();
    });

    test('validateFile returns false for non-existent file', () async {
      final result = await fileService.validateFile('${tempDir.path}/nonexistent.txt');
      expect(result, isFalse);
    });

    test('getFileMetadata returns correct metadata', () async {
      final testFile = File('${tempDir.path}/metadata.txt');
      await testFile.writeAsString('test content for metadata');

      final metadata = await fileService.getFileMetadata(testFile.path);

      expect(metadata.name, equals('metadata.txt'));
      expect(metadata.size, equals(25));
      expect(metadata.mimeType, equals('text/plain'));
      expect(metadata.lastModified, isNotNull);

      await testFile.delete();
    });

    test('getFileMetadata detects correct MIME types', () async {
      // Test various file types
      final testCases = {
        'test.pdf': 'application/pdf',
        'image.png': 'image/png',
        'audio.mp3': 'audio/mpeg',
        'data.json': 'application/json',
        'unknown.xyz': 'application/octet-stream',
      };

      for (final testCase in testCases.entries) {
        final testFile = File('${tempDir.path}/${testCase.key}');
        await testFile.writeAsString('content');

        final metadata = await fileService.getFileMetadata(testFile.path);
        expect(metadata.mimeType, equals(testCase.value),
            reason: 'MIME type for ${testCase.key}');

        await testFile.delete();
      }
    });



    test('getFileStream throws for non-existent file', () async {
      expect(
        () => fileService.getFileStream('nonexistent').toList(),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
