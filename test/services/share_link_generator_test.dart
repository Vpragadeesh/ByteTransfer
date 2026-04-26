import 'package:flutter_test/flutter_test.dart';
import 'package:byte_transfer/services/share_link_generator.dart';

void main() {
  group('ShareLinkGenerator', () {
    final generator = ShareLinkGenerator();

    test('generateShareLink creates correct format', () {
      final link = generator.generateShareLink('abc123', '192.168.1.100', 8080);
      expect(link, equals('http://192.168.1.100:8080/file/abc123'));
    });

    test('generateShareLink works with different IPs', () {
      final link1 =
          generator.generateShareLink('test1', '10.0.0.1', 9090);
      expect(link1, equals('http://10.0.0.1:9090/file/test1'));

      final link2 = generator.generateShareLink(
          'test2', '172.16.0.1', 8081);
      expect(link2, equals('http://172.16.0.1:8081/file/test2'));
    });

    test('parseFileIdFromLink extracts ID correctly', () {
      final fileId = generator
          .parseFileIdFromLink('http://192.168.1.100:8080/file/abc123xyz');
      expect(fileId, equals('abc123xyz'));
    });

    test('parseFileIdFromLink returns null for invalid link', () {
      final fileId =
          generator.parseFileIdFromLink('http://192.168.1.100:8080/invalid/abc123');
      expect(fileId, isNull);
    });

    test('isValidShareLink validates correct format', () {
      expect(
          generator
              .isValidShareLink('http://192.168.1.100:8080/file/abc123'),
          isTrue);
    });

    test('isValidShareLink rejects HTTPS', () {
      expect(
          generator
              .isValidShareLink('https://192.168.1.100:8080/file/abc123'),
          isFalse);
    });

    test('isValidShareLink rejects wrong path', () {
      expect(
          generator
              .isValidShareLink('http://192.168.1.100:8080/download/abc123'),
          isFalse);
    });

    test('isValidShareLink rejects malformed URL', () {
      expect(generator.isValidShareLink('not a url'), isFalse);
    });

    test('generateQRCode returns link', () {
      final link = 'http://192.168.1.100:8080/file/abc123';
      final qrData = generator.generateQRCode(link);
      expect(qrData, equals(link));
    });
  });
}
