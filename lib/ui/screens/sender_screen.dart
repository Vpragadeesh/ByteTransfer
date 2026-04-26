import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:byte_transfer/app/app_state_manager.dart';
import 'package:byte_transfer/models/shared_file.dart';

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
}
