import 'package:flutter_test/flutter_test.dart';
import 'package:byte_transfer/services/http_server_service_impl.dart';
import 'package:byte_transfer/models/shared_file.dart';
import 'package:mockito/mockito.dart';
import 'package:byte_transfer/services/file_service.dart';

class MockFileService extends Mock implements FileService {}

void main() {
  group('HTTPServerServiceImpl', () {
    late HTTPServerServiceImpl httpServerService;
    late MockFileService mockFileService;

    setUp(() {
      mockFileService = MockFileService();
      httpServerService = HTTPServerServiceImpl(fileService: mockFileService);
    });

    tearDown(() async {
      if (httpServerService.isRunning) {
        await httpServerService.stopServer();
      }
      httpServerService.dispose();
    });

    test('isRunning returns false before server start', () {
      expect(httpServerService.isRunning, isFalse);
    });

    test('serverInfo is null before server start', () {
      expect(httpServerService.serverInfo, isNull);
    });

    test('activeConnections starts at 0', () {
      expect(httpServerService.activeConnections, equals(0));
    });

    test('registerFile stores file for serving', () {
      final sharedFile = SharedFile(
        id: 'test-id-1',
        name: 'test.txt',
        path: '/path/to/test.txt',
        size: 1024,
        mimeType: 'text/plain',
        sharedAt: DateTime.now(),
      );

      httpServerService.registerFile(sharedFile);
      expect(httpServerService.getRegisteredFiles().length, equals(1));
      expect(httpServerService.getRegisteredFiles()[0].id, equals('test-id-1'));
    });

    test('unregisterFile removes file from registry', () {
      final sharedFile = SharedFile(
        id: 'test-id-2',
        name: 'test.txt',
        path: '/path/to/test.txt',
        size: 1024,
        mimeType: 'text/plain',
        sharedAt: DateTime.now(),
      );

      httpServerService.registerFile(sharedFile);
      expect(httpServerService.getRegisteredFiles().length, equals(1));

      httpServerService.unregisterFile('test-id-2');
      expect(httpServerService.getRegisteredFiles().length, equals(0));
    });

    test('getRegisteredFiles returns all registered files', () {
      for (int i = 0; i < 5; i++) {
        final sharedFile = SharedFile(
          id: 'test-id-$i',
          name: 'test$i.txt',
          path: '/path/to/test$i.txt',
          size: 1024 * (i + 1),
          mimeType: 'text/plain',
          sharedAt: DateTime.now(),
        );
        httpServerService.registerFile(sharedFile);
      }

      expect(httpServerService.getRegisteredFiles().length, equals(5));
    });

    test('events stream is available', () {
      expect(httpServerService.events, isA<Stream>());
    });

    test('startServer throws when already running', () async {
      final serverInfo1 = await httpServerService.startServer(
        ipAddress: '127.0.0.1',
        port: 0,
      );

      expect(serverInfo1, isNotNull);
      expect(httpServerService.isRunning, isTrue);

      expect(
        () => httpServerService.startServer(ipAddress: '127.0.0.1', port: 0),
        throwsStateError,
      );

      await httpServerService.stopServer();
    });

    test('stopServer stops running server', () async {
      final serverInfo = await httpServerService.startServer(
        ipAddress: '127.0.0.1',
        port: 0,
      );

      expect(serverInfo, isNotNull);
      expect(httpServerService.isRunning, isTrue);

      await httpServerService.stopServer();

      expect(httpServerService.isRunning, isFalse);
      expect(httpServerService.serverInfo, isNull);
      expect(httpServerService.activeConnections, equals(0));
    });

    test('stopServer is idempotent', () async {
      // Should not throw when stopping non-running server
      expect(
        () => httpServerService.stopServer(),
        returnsNormally,
      );
    });
  });
}
