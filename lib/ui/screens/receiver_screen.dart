import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:byte_transfer/app/app_state_manager.dart';
import 'package:byte_transfer/services/download_service.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({Key? key}) : super(key: key);

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final _linkController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toggleTheme = context.read<VoidCallback>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Files'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Info icon and description
              Column(
                children: [
                  Icon(
                    Icons.download_for_offline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Receive Files',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the share link from another device to download files',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Link input section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share Link',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _linkController,
                      decoration: InputDecoration(
                        hintText: 'e.g., http://192.168.1.100:8080/file/abc123xyz',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      readOnly: _isLoading,
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Connect button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleConnect,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.connect_without_contact),
                label: Text(_isLoading ? 'Connecting...' : 'Connect'),
              ),
              const SizedBox(height: 32),
              // Instructions section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to get the share link:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildInstructionStep(1, 'Open Libre-Send on the sender device'),
                    _buildInstructionStep(2, 'Tap "Send Files" and select files to share'),
                    _buildInstructionStep(3, 'Tap "Start Sharing"'),
                    _buildInstructionStep(4, 'Expand a file and copy its share link'),
                    _buildInstructionStep(5, 'Paste the complete link here and tap "Connect"'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Troubleshooting section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Troubleshooting',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Both devices must be on the same WiFi network\n'
                      '• Make sure you copy the complete link including the port number\n'
                      '• Check that the sender device is still in the sharing screen',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int step, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _handleConnect() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a share link')),
      );
      return;
    }

    // Validate URL format
    if (!link.startsWith('http://') && !link.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share link must start with http:// or https://')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse(link);
      final pathSegments = uri.pathSegments;

      // Check if this is a direct file link (e.g., http://IP:PORT/file/abc123)
      if (pathSegments.length >= 2 && pathSegments[0] == 'file') {
        final fileId = pathSegments[1];
        final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';

        // Try to get file metadata from /files endpoint
        final stateManager = context.read<AppStateManager>();
        await stateManager.connectToRemoteServer(baseUrl);

        if (stateManager.error != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(stateManager.error!)),
            );
          }
        } else {
          // Find the specific file
          final file = stateManager.remoteFiles.firstWhere(
            (f) => f.id == fileId,
            orElse: () => throw Exception('File not found on server'),
          );

          if (mounted) {
            // Download this specific file
            _downloadFile(context, stateManager, file);
          }
        }
      } else {
        // This is a base URL, show file list
        final stateManager = context.read<AppStateManager>();
        await stateManager.connectToRemoteServer(link);

        if (stateManager.error != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(stateManager.error!)),
            );
          }
        } else if (stateManager.remoteFiles.isNotEmpty) {
          // Show file selection dialog
          if (mounted) {
            _showFileSelectionDialog(context, stateManager);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No files available on remote server')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showFileSelectionDialog(
    BuildContext context,
    AppStateManager stateManager,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Available Files'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: stateManager.remoteFiles.length,
            itemBuilder: (context, index) {
              final file = stateManager.remoteFiles[index];
              return ListTile(
                title: Text(file.name),
                subtitle: Text(_formatFileSize(file.size)),
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile(context, stateManager, file);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _downloadFile(
    BuildContext context,
    AppStateManager stateManager,
    RemoteFileMetadata file,
  ) async {
    final uri = Uri.parse(_linkController.text);
    final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';

    await stateManager.downloadRemoteFile(
      baseUrl: baseUrl,
      fileId: file.id,
      fileName: file.name,
    );

    if (mounted) {
      _showDownloadProgressDialog(context, stateManager);
    }
  }

  void _showDownloadProgressDialog(
    BuildContext context,
    AppStateManager stateManager,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Downloading...'),
        content: Consumer<AppStateManager>(
          builder: (context, manager, _) {
            final progress = manager.downloadProgress;
            if (progress == null) {
              return const CircularProgressIndicator();
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress.percentComplete / 100,
                ),
                const SizedBox(height: 16),
                Text(
                  '${progress.percentComplete.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatFileSize(progress.bytesReceived)} / '
                  '${progress.totalBytes != null ? _formatFileSize(progress.totalBytes!) : "?"}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              stateManager.cancelDownload();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
