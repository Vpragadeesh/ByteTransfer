import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:byte_transfer/app/app_state_manager.dart';
import 'package:byte_transfer/services/file_service_impl.dart';
import 'package:byte_transfer/services/file_service_linux.dart';
import 'package:byte_transfer/services/file_service.dart';
import 'package:byte_transfer/services/network_service_impl.dart';
import 'package:byte_transfer/services/http_server_service_impl.dart';
import 'package:byte_transfer/services/permission_service_impl.dart';
import 'package:byte_transfer/services/download_service_impl.dart';
import 'package:byte_transfer/ui/screens/sender_screen.dart';
import 'package:byte_transfer/ui/screens/receiver_screen.dart';
import 'package:byte_transfer/ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ByteTransferApp());
}

class ByteTransferApp extends StatelessWidget {
  const ByteTransferApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Create service instances with platform-specific file service
        Provider<FileService>(
          create: (_) {
            // Use Linux-specific file service on Linux, otherwise use default
            if (!kIsWeb && Platform.isLinux) {
              return FileServiceLinux();
            }
            return FileServiceImpl();
          },
        ),
        Provider<NetworkServiceImpl>(
          create: (_) => NetworkServiceImpl(),
        ),
        Provider<PermissionServiceImpl>(
          create: (_) => PermissionServiceImpl(),
        ),
        Provider<HTTPServerServiceImpl>(
          create: (context) => HTTPServerServiceImpl(
            fileService: context.read<FileService>(),
          ),
        ),
        Provider<DownloadServiceImpl>(
          create: (_) => DownloadServiceImpl(),
        ),
        // Create and initialize app state manager
        ChangeNotifierProvider<AppStateManager>(
          create: (context) => AppStateManager(
            fileService: context.read<FileService>(),
            networkService: context.read<NetworkServiceImpl>(),
            httpServerService: context.read<HTTPServerServiceImpl>(),
            permissionService: context.read<PermissionServiceImpl>(),
            downloadService: context.read<DownloadServiceImpl>(),
          ),
          child: const SizedBox.shrink(),
        ),
      ],
      child: MaterialApp(
        title: 'ByteTransfer',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const _InitializingWrapper(),
      ),
    );
  }
}

/// Wrapper to handle app initialization
class _InitializingWrapper extends StatefulWidget {
  const _InitializingWrapper({Key? key}) : super(key: key);

  @override
  State<_InitializingWrapper> createState() => _InitializingWrapperState();
}

class _InitializingWrapperState extends State<_InitializingWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateManager>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateManager>(
      builder: (context, state, _) {
        if (state.isInitializing) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing ByteTransfer...'),
                ],
              ),
            ),
          );
        }

        // Show home screen even if permissions aren't granted
        // User can grant them when needed
        return const HomeScreen();
      },
    );
  }
}
