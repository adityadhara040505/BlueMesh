import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';
import '../providers/ble_provider.dart';
import '../theme/colors.dart';

/// Live diagnostic viewer displaying packet counters, connection pool states, and rolling log buffer.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final bleNotifier = ref.watch(bleProvider.notifier);
    final connections = bleNotifier.bleManager.connectionPool.activeConnections;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy Logs',
            onPressed: () {
              final logText = AppLogger.recentLogs.map((e) => e.toString()).join('\n');
              Clipboard.setData(ClipboardData(text: logText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Diagnostics logs copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear Logs',
            onPressed: () {
              AppLogger.clear();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Packet Counters Overview
          const Text(
            'Mesh Traffic Counters',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.offlineGrey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard('Sent', '${bleState.counters.sent}', AppColors.primaryBlue),
              const SizedBox(width: 8),
              _buildStatCard('Received', '${bleState.counters.received}', AppColors.onlineGreen),
              const SizedBox(width: 8),
              _buildStatCard('Relayed', '${bleState.counters.relayed}', AppColors.accentCyan),
              const SizedBox(width: 8),
              _buildStatCard('Dropped', '${bleState.counters.dropped}', AppColors.errorRed),
            ],
          ),
          const SizedBox(height: 24),

          // Active Connection Pool
          Text(
            'Active Connections (${connections.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.offlineGrey),
          ),
          const SizedBox(height: 8),
          if (connections.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No active physical BLE connections right now.', style: TextStyle(color: AppColors.offlineGrey)),
              ),
            )
          else
            for (final conn in connections)
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.bluetooth_connected_rounded,
                    color: conn.role.name.contains('Central') ? AppColors.primaryBlue : AppColors.accentCyan,
                  ),
                  title: Text('Peer: ${conn.deviceId} (${conn.remoteId})'),
                  subtitle: Text('Role: ${conn.role.name} • MTU: ${conn.mtu} • RSSI: ${conn.rssi} dBm'),
                ),
              ),

          const SizedBox(height: 24),

          // Real-time Event Log Buffer
          const Text(
            'Real-Time BLE & Mesh Event Logs',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.offlineGrey),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: AppLogger.logUpdateNotifier,
            builder: (context, _, __) {
              final logs = AppLogger.recentLogs.toList().reversed.toList();
              return Container(
                height: 380,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log.toString(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: _getLogLevelColor(log.level.name),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: AppColors.offlineGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLogLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'error':
        return AppColors.errorRed;
      case 'warning':
        return AppColors.warningAmber;
      case 'info':
        return AppColors.accentCyan;
      default:
        return AppColors.textSecondaryDark;
    }
  }
}
