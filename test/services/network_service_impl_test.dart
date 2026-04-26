import 'package:flutter_test/flutter_test.dart';
import 'package:byte_transfer/services/network_service_impl.dart';

void main() {
  group('NetworkServiceImpl', () {
    late NetworkServiceImpl networkService;

    setUp(() {
      networkService = NetworkServiceImpl();
    });

    test('isLocalNetworkAddress validates 192.168.x.x range', () {
      expect(networkService.isLocalNetworkAddress('192.168.1.1'), isTrue);
      expect(networkService.isLocalNetworkAddress('192.168.0.100'), isTrue);
      expect(networkService.isLocalNetworkAddress('192.168.255.254'), isTrue);
      expect(networkService.isLocalNetworkAddress('192.169.1.1'), isFalse);
      expect(networkService.isLocalNetworkAddress('192.167.1.1'), isFalse);
    });

    test('isLocalNetworkAddress validates 10.x.x.x range', () {
      expect(networkService.isLocalNetworkAddress('10.0.0.1'), isTrue);
      expect(networkService.isLocalNetworkAddress('10.255.255.254'), isTrue);
      expect(networkService.isLocalNetworkAddress('9.255.255.254'), isFalse);
      expect(networkService.isLocalNetworkAddress('11.0.0.1'), isFalse);
    });

    test('isLocalNetworkAddress validates 172.16-31.x.x range', () {
      expect(networkService.isLocalNetworkAddress('172.16.0.1'), isTrue);
      expect(networkService.isLocalNetworkAddress('172.24.0.1'), isTrue);
      expect(networkService.isLocalNetworkAddress('172.31.255.254'), isTrue);
      expect(networkService.isLocalNetworkAddress('172.15.0.1'), isFalse);
      expect(networkService.isLocalNetworkAddress('172.32.0.1'), isFalse);
    });

    test('isLocalNetworkAddress validates 169.254.x.x range (link-local)', () {
      expect(networkService.isLocalNetworkAddress('169.254.1.1'), isTrue);
      expect(networkService.isLocalNetworkAddress('169.254.255.254'), isTrue);
      expect(networkService.isLocalNetworkAddress('169.253.1.1'), isFalse);
      expect(networkService.isLocalNetworkAddress('169.255.1.1'), isFalse);
    });

    test('isLocalhost identifies loopback addresses', () {
      expect(networkService.isLocalhost('127.0.0.1'), isTrue);
      expect(networkService.isLocalhost('::1'), isTrue);
      expect(networkService.isLocalhost('localhost'), isTrue);
      expect(networkService.isLocalhost('127.0.0.2'), isFalse);
      expect(networkService.isLocalhost('192.168.1.1'), isFalse);
    });

    test('isLocalNetworkAddress includes localhost', () {
      expect(networkService.isLocalNetworkAddress('127.0.0.1'), isTrue);
      expect(networkService.isLocalNetworkAddress('localhost'), isTrue);
    });

    test('isLocalNetworkAddress rejects invalid IP formats', () {
      expect(networkService.isLocalNetworkAddress('256.1.1.1'), isFalse);
      expect(networkService.isLocalNetworkAddress('192.168.1'), isFalse);
      expect(networkService.isLocalNetworkAddress('192.168.1.1.1'), isFalse);
      expect(networkService.isLocalNetworkAddress('not.an.ip.address'), isFalse);
      expect(networkService.isLocalNetworkAddress(''), isFalse);
    });

    test('isLocalNetworkAddress rejects public IP ranges', () {
      // Google DNS
      expect(networkService.isLocalNetworkAddress('8.8.8.8'), isFalse);
      // Cloudflare DNS
      expect(networkService.isLocalNetworkAddress('1.1.1.1'), isFalse);
      // Quad9 DNS
      expect(networkService.isLocalNetworkAddress('9.9.9.9'), isFalse);
    });

    // Property 3: Local Network Address Validation
    test('Property 3: Local network address validation', () {
      final validPrivateRanges = [
        ('192.168.0.0', true),
        ('192.168.1.100', true),
        ('192.168.255.255', true),
        ('10.0.0.1', true),
        ('10.255.255.254', true),
        ('172.16.0.0', true),
        ('172.31.255.255', true),
        ('169.254.1.1', true),
        ('127.0.0.1', true),
        ('8.8.8.8', false),
        ('1.1.1.1', false),
        ('200.100.50.25', false),
      ];

      for (final (ip, expected) in validPrivateRanges) {
        expect(networkService.isLocalNetworkAddress(ip), equals(expected),
            reason: 'IP $ip should return $expected');
      }
    }, tags: ['property', 'local-network-address-validation']);
  });
}
