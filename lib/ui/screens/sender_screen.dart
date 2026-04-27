import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:byte_transfer/app/app_state_manager.dart';
import 'package:byte_transfer/models/shared_file.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({Key? key}) : super(key: key);

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppStateManager>();
      if (state.sharedFiles.isEmpty) {
        state.pickFilesForSharing();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final toggleTheme = Provider.of<Function>(context, listen: false);
    final currentTheme = Theme.of(context).brightness;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Files'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              currentTheme == Brightness.dark 
                ? Icons.light_mode 
                : Icons.dark_mode,
            ),
            onPressed: () => toggleTheme(),
            tooltip: currentTheme == Brightness.dark 
              ? 'Switch to Light Mode' 
              : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: Consumer<AppStateManager>(
        builder: (context, state, _) {
          return Column(
            children: [
              // Status section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (state.isServerRunning)
                      const Icon(Icons.check_circle, color: Colors.green)
                    else
                      const Icon(Icons.radio_button_off, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.isServerRunning ? 'Server Active' : 'Ready to Share',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (state.isServerRunning && state.serverInfo != null)
                            Text(
                              state.serverInfo!.baseUrl,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Share link section (when server is running)
              if (state.isServerRunning && state.shareLink != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: Colors.green),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Server is running! Expand each file below to get its share link.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Server: ${state.shareLink}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Files: ${state.sharedFiles.length}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
              // Files list
              Expanded(
                child: state.sharedFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No files selected',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => state.pickFilesForSharing(),
                              icon: const Icon(Icons.add),
                              label: const Text('Select Files'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.sharedFiles.length,
                        itemBuilder: (context, index) {
                          final file = state.sharedFiles[index];
                          return _buildFileListItem(context, state, file);
                        },
                      ),
              ),
              // Action buttons
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.sharedFiles.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: state.isServerRunning
                            ? null
                            : () async {
                                await state.startServer();
                              },
                        icon: const Icon(Icons.play_circle),
                        label: Text(
                          state.isServerRunning ? 'Server Running' : 'Start Sharing',
                        ),
                      ),
                    if (state.isServerRunning) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await state.stopServer();
                        },
                        icon: const Icon(Icons.stop_circle),
                        label: const Text('Stop Sharing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => state.pickFilesForSharing(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add More Files'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFileListItem(
    BuildContext context,
    AppStateManager state,
    SharedFile file,
  ) {
    final fileLink = state.isServerRunning && state.serverInfo != null
        ? '${state.serverInfo!.baseUrl}/file/${file.id}'
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: _getFileIcon(file.extension),
        title: Text(file.name),
        subtitle: Text(file.formattedSize),
        trailing: state.isServerRunning
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => state.removeFile(file.id),
              ),
        children: [
          if (fileLink != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Share Link:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: SelectableText(
                            fileLink,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: fileLink));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Link copied for ${file.name}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Copy link',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: _buildQrCode(fileLink),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Icon _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf, color: Colors.red);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return const Icon(Icons.image, color: Colors.purple);
      case 'mp3':
      case 'wav':
      case 'aac':
        return const Icon(Icons.audio_file, color: Colors.orange);
      case 'mp4':
      case 'avi':
      case 'mov':
        return const Icon(Icons.video_file, color: Colors.blue);
      case 'zip':
      case 'rar':
      case '7z':
        return const Icon(Icons.archive, color: Colors.brown);
      default:
        return const Icon(Icons.description, color: Colors.grey);
    }
  }

  Widget _buildQrCode(String shareLink) {
    try {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, // Always white background for QR code
          borderRadius: BorderRadius.circular(8),
        ),
        child: QrImageView(
          data: shareLink,
          version: QrVersions.auto,
          size: 200.0,
          gapless: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      );
    } catch (e) {
      // Fallback if QR generation fails
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'QR Code\nGeneration\nFailed',
            style: TextStyle(color: Colors.black),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }
}
