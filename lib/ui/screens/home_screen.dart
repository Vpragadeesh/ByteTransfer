import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:byte_transfer/app/app_state_manager.dart';
import 'sender_screen.dart';
import 'receiver_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final toggleTheme = Provider.of<Function>(context, listen: false);
    final currentTheme = Theme.of(context).brightness;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ByteTransfer'),
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
          return SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Network status
                    _buildNetworkStatus(context, state),
                    const SizedBox(height: 40),
                    // Error message
                    if (state.error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    state.error!,
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.red.shade300
                                        : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: state.clearError,
                                child: const Text('Dismiss'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                    // Main action buttons
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: state.canShare
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SenderScreen(),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.upload),
                            label: const Text('Send Files'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReceiverScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.download),
                            label: const Text('Receive Files'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Information section
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
                          Text(
                            'About ByteTransfer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Share files wirelessly over your local network. No internet required.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            context,
                            'Network Status',
                            state.networkStatus?.isConnected ?? false
                                ? 'Connected (${state.networkStatus!.type.name})'
                                : 'Not connected',
                            state.networkStatus?.isConnected ?? false
                                ? Colors.green
                                : Colors.red,
                          ),
                          if (state.networkStatus?.ipAddress != null) ...[
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              context,
                              'Local IP',
                              state.networkStatus!.ipAddress!,
                              Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNetworkStatus(BuildContext context, AppStateManager state) {
    final isConnected = state.networkStatus?.isConnected ?? false;
    final icon = isConnected
        ? Icons.wifi
        : Icons.wifi_off;
    final color = isConnected ? Colors.green : Colors.grey;

    return Column(
      children: [
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 16),
        Text(
          isConnected ? 'Connected' : 'Disconnected',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (isConnected && state.networkStatus!.ssid != null) ...[
          const SizedBox(height: 8),
          Text(
            'Network: ${state.networkStatus!.ssid}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
