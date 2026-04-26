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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Files'),
        centerTitle: true,
      ),
      body: Consumer<AppStateManager>(
        builder: (context, state, _) {
          return Column(
            children: [
              // Status section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
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
                  color: Colors.green.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Share Link',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.green.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  state.shareLink!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: state.shareLink!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Share link copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copy to clipboard',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // QR Code
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildQrCode(state.shareLink!),
                        ),
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
                            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
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
    return ListTile(
      leading: _getFileIcon(file.extension),
      title: Text(file.name),
      subtitle: Text(file.formattedSize),
      trailing: state.isServerRunning
          ? null
          : IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => state.removeFile(file.id),
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
      return QrImageView(
        data: shareLink,
        version: QrVersions.auto,
        size: 200.0,
        gapless: true,
      );
    } catch (e) {
      // Fallback if QR generation fails
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('QR Code\nGeneration\nFailed'),
        ),
      );
    }
  }
}
