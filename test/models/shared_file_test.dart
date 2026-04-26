import 'package:flutter_test/flutter_test.dart';
import 'package:byte_transfer/models/shared_file.dart';

void main() {
  group('SharedFile', () {
    test('generateId creates unique identifiers', () {
      final id1 = SharedFile.generateId();
      final id2 = SharedFile.generateId();
      expect(id1, isNot(equals(id2)));
      expect(id1.length, greaterThanOrEqualTo(20));
      expect(id2.length, greaterThanOrEqualTo(20));
    });

    test('formattedSize formats bytes correctly', () {
      final file = SharedFile(
        id: 'test1',
        name: 'test.txt',
        path: '/path/test.txt',
        size: 512,
        mimeType: 'text/plain',
        sharedAt: DateTime.now(),
      );
      expect(file.formattedSize, equals('512 B'));
    });

    test('formattedSize formats kilobytes correctly', () {
      final file = SharedFile(
        id: 'test2',
        name: 'test.txt',
        path: '/path/test.txt',
        size: 1536, // 1.5 KB
        mimeType: 'text/plain',
        sharedAt: DateTime.now(),
      );
      expect(file.formattedSize, equals('1.5 KB'));
    });

    test('formattedSize formats megabytes correctly', () {
      final file = SharedFile(
        id: 'test3',
        name: 'test.pdf',
        path: '/path/test.pdf',
        size: 5242880, // 5 MB
        mimeType: 'application/pdf',
        sharedAt: DateTime.now(),
      );
      expect(file.formattedSize, equals('5.0 MB'));
    });

    test('formattedSize formats gigabytes correctly', () {
      final file = SharedFile(
        id: 'test4',
        name: 'video.mp4',
        path: '/path/video.mp4',
        size: 1073741824, // 1 GB
        mimeType: 'video/mp4',
        sharedAt: DateTime.now(),
      );
      expect(file.formattedSize, equals('1.0 GB'));
    });

    test('extension extracts file extension', () {
      final file = SharedFile(
        id: 'test',
        name: 'document.pdf',
        path: '/path/document.pdf',
        size: 1000,
        mimeType: 'application/pdf',
        sharedAt: DateTime.now(),
      );
      expect(file.extension, equals('pdf'));
    });

    test('extension handles files without extension', () {
      final file = SharedFile(
        id: 'test',
        name: 'README',
        path: '/path/README',
        size: 1000,
        mimeType: 'text/plain',
        sharedAt: DateTime.now(),
      );
      expect(file.extension, equals(''));
    });

    test('equality based on id and path', () {
      final file1 = SharedFile(
        id: 'test1',
        name: 'file.txt',
        path: '/path/file.txt',
        size: 100,
        mimeType: 'text/plain',
        sharedAt: DateTime.now(),
      );
      final file2 = SharedFile(
        id: 'test1',
        name: 'different.txt',
        path: '/path/file.txt',
        size: 200,
        mimeType: 'text/plain',
        sharedAt: DateTime.now(),
      );
      expect(file1, equals(file2));
    });

    // Property 5: File Identifier Uniqueness
    test('Property 5: File identifier uniqueness', () {
      final ids = <String>{};

      for (int i = 0; i < 100; i++) {
        final id = SharedFile.generateId();
        expect(ids.contains(id), isFalse, reason: 'ID $id should be unique');
        expect(id.length, greaterThanOrEqualTo(20),
            reason: 'ID should have sufficient length for 128-bit entropy');
        ids.add(id);
      }
    }, tags: ['property', 'file-identifier-uniqueness']);
  });
}
