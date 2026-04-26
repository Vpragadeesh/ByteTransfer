import 'package:flutter_test/flutter_test.dart';
import 'package:byte_transfer/models/share_link.dart';

void main() {
  group('ShareLink', () {
    test('parse extracts file ID from valid link', () {
      final link =
          ShareLink.parse('http://192.168.1.100:8080/file/abc123xyz');
      expect(link, isNotNull);
      expect(link?.fileId, equals('abc123xyz'));
      expect(link?.url, equals('http://192.168.1.100:8080/file/abc123xyz'));
    });

    test('parse returns null for invalid URL', () {
      final link = ShareLink.parse('not a url');
      expect(link, isNull);
    });

    test('parse returns null for wrong path structure', () {
      final link = ShareLink.parse('http://192.168.1.100:8080/invalid/abc123');
      expect(link, isNull);
    });

    test('parse returns null for non-file path', () {
      final link =
          ShareLink.parse('http://192.168.1.100:8080/download/abc123');
      expect(link, isNull);
    });

    test('isValid returns true for valid links', () {
      final link = ShareLink(
        url: 'http://192.168.1.100:8080/file/abc123',
        fileId: 'abc123',
      );
      expect(link.isValid, isTrue);
    });

    test('isValid returns false for invalid scheme', () {
      final link = ShareLink(
        url: 'https://192.168.1.100:8080/file/abc123',
        fileId: 'abc123',
      );
      expect(link.isValid, isFalse);
    });

    test('isValid returns false for wrong path', () {
      final link = ShareLink(
        url: 'http://192.168.1.100:8080/download/abc123',
        fileId: 'abc123',
      );
      expect(link.isValid, isFalse);
    });

    test('equality based on url and fileId', () {
      final link1 = ShareLink(
        url: 'http://192.168.1.100:8080/file/abc123',
        fileId: 'abc123',
      );
      final link2 = ShareLink(
        url: 'http://192.168.1.100:8080/file/abc123',
        fileId: 'abc123',
      );
      expect(link1, equals(link2));
    });

    // Property 9: Share Link Format Validation
    test('Property 9: Share link format validation', () {
      for (int i = 0; i < 100; i++) {
        final ip = _generatePrivateIP();
        final port = 1024 + (i % 64512);
        final fileId = _generateRandomId();

        final link = 'http://$ip:$port/file/$fileId';

        // Verify format
        expect(link, startsWith('http://'));
        expect(link, contains(ip));
        expect(link, contains(':$port'));
        expect(link, endsWith('/file/$fileId'));

        // Verify parsing
        final parsed = ShareLink.parse(link);
        expect(parsed, isNotNull);
        expect(parsed!.fileId, equals(fileId));
      }
    }, tags: ['property', 'share-link-format-validation']);
  });
}

String _generatePrivateIP() {
  final type = i % 3;
  switch (type) {
    case 0:
      return '192.168.${i % 256}.${(i + 1) % 256}';
    case 1:
      return '10.${i % 256}.${(i + 1) % 256}.${(i + 2) % 256}';
    case 2:
      return '172.${16 + (i % 16)}.${i % 256}.${(i + 1) % 256}';
    default:
      return '192.168.1.1';
  }
}

int i = 0;

String _generateRandomId() {
  i++;
  // Simple deterministic ID for testing
  return 'id_$i'.padRight(20, '_');
}
