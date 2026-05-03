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

class ByteTransferApp extends StatefulWidget {
  const ByteTransferApp({Key? key}) : super(key: key);

  @override
  State<ByteTransferApp> createState() => _ByteTransferAppState();
}

class _ByteTransferAppState extends State<ByteTransferApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<VoidCallback>(
          create: (_) => _toggleTheme,
        ),
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
        themeMode: _themeMode,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        home: const _InitializingWrapper(),
      ),
    );
  }

  // Light theme
  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: Colors.blue.shade700,
        secondary: Colors.blueAccent,
        surface: Colors.white,
        background: Colors.grey.shade50,
        error: Colors.red.shade700,
      ),
      scaffoldBackgroundColor: Colors.grey.shade50,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // AMOLED Dark theme (GitHub Dark inspired)
  ThemeData _buildDarkTheme() {
    const Color amoledBlack = Color(0xFF0D1117); // GitHub dark background
    const Color surfaceBlack = Color(0xFF161B22); // GitHub dark surface
    const Color borderGray = Color(0xFF30363D); // GitHub dark border
    const Color textPrimary = Color(0xFFC9D1D9); // GitHub dark text
    const Color textSecondary = Color(0xFF8B949E); // GitHub dark muted text
    const Color accentBlue = Color(0xFF58A6FF); // GitHub blue
    const Color accentGreen = Color(0xFF3FB950); // GitHub green

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentGreen,
        surface: surfaceBlack,
        background: amoledBlack,
        error: Color(0xFFF85149), // GitHub red
        onPrimary: amoledBlack,
        onSecondary: amoledBlack,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      scaffoldBackgroundColor: amoledBlack,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceBlack,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceBlack,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderGray, width: 1),
        ),
      ),
      dividerColor: borderGray,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
        titleLarge: TextStyle(color: textPrimary),
        titleMedium: TextStyle(color: textPrimary),
        titleSmall: TextStyle(color: textSecondary),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: amoledBlack,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: amoledBlack,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentBlue,
          side: const BorderSide(color: borderGray),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
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
