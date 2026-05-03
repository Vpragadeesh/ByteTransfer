import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:byte_transfer/app/app_state_manager.dart';
import 'package:byte_transfer/models/permissions.dart';
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
    final toggleTheme = context.read<VoidCallback>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Files'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleTheme,
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
    SharedFileWithPermissions file,
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Permission section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Access Control:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: !state.isServerRunning
                                ? () => _showPermissionDialog(context, state, file)
                                : null,
                            icon: const Icon(Icons.lock, size: 16),
                            label: const Text('Manage'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        file.isPublic
                            ? '🌐 Public - Anyone can download'
                            : '🔒 Private - Role-based access',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      if (file.requiredPermissions.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Roles: ${file.requiredPermissions.map((r) => r.toString().split('.').last).join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (fileLink != null) ...[
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show dialog to manage file permissions
  void _showPermissionDialog(
    BuildContext context,
    AppStateManager state,
    SharedFileWithPermissions file,
  ) {
    showDialog(
      context: context,
      builder: (context) => _PermissionDialog(
        file: file,
        onPermissionsChanged: (isPublic, roles) {
          state.updateFilePermissions(
            file.id,
            isPublic: isPublic,
            requiredPermissions: roles,
          );
          Navigator.pop(context);
        },
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

/// Permission management dialog
class _PermissionDialog extends StatefulWidget {
  final SharedFileWithPermissions file;
  final Function(bool isPublic, Set<FilePermission> roles) onPermissionsChanged;

  const _PermissionDialog({
    required this.file,
    required this.onPermissionsChanged,
  });

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog> {
  late bool isPublic;
  late Set<FilePermission> selectedRoles;

  @override
  void initState() {
    super.initState();
    isPublic = widget.file.isPublic;
    selectedRoles = Set.from(widget.file.requiredPermissions);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage File Access'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Public toggle
            SwitchListTile(
              title: const Text('Public Access'),
              subtitle: const Text('Allow anyone to download'),
              value: isPublic,
              onChanged: (value) {
                setState(() {
                  isPublic = value;
                  if (value) {
                    selectedRoles.clear(); // Clear roles if public
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            if (!isPublic) ...[
              const Text(
                'Select access roles:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _buildRoleCheckbox(FilePermission.admin, 'Admin', 'Full system access'),
              _buildRoleCheckbox(FilePermission.editor, 'Editor', 'Read/write documents'),
              _buildRoleCheckbox(FilePermission.viewer, 'Viewer', 'Read-only access'),
              _buildRoleCheckbox(FilePermission.manager, 'Manager', 'Reports & analytics'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onPermissionsChanged(isPublic, selectedRoles);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildRoleCheckbox(
    FilePermission role,
    String label,
    String description,
  ) {
    return CheckboxListTile(
      title: Text(label),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      value: selectedRoles.contains(role),
      onChanged: (value) {
        setState(() {
          if (value ?? false) {
            selectedRoles.add(role);
          } else {
            selectedRoles.remove(role);
          }
        });
      },
      dense: true,
    );
  }
}
