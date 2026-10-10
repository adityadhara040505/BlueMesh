import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/local/sqflite_database.dart';
import '../providers/ble_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';

/// Application and mesh configuration screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final bleNotifier = ref.watch(bleProvider.notifier);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // User Identity Card
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
                child: const Icon(Icons.person_rounded, color: AppColors.primaryBlue),
              ),
              title: Text(
                settings.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              subtitle: Text(
                'Node ID: ${settings.shortHexId} • Fingerprint: ${bleNotifier.keyManager.fingerprint}',
                style: const TextStyle(fontSize: 12, color: AppColors.offlineGrey),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                onPressed: () => _showEditNameDialog(context, ref, settings.displayName),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Mesh Network Configuration',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.offlineGrey),
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Flooding Time-To-Live (TTL)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${settings.meshTtl} hops',
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Maximum number of multi-hop relays a packet travels across the cluster before being dropped.',
                    style: TextStyle(fontSize: 12, color: AppColors.offlineGrey),
                  ),
                  Slider(
                    value: settings.meshTtl.toDouble(),
                    min: MeshConstants.minTtl.toDouble(),
                    max: MeshConstants.maxTtl.toDouble(),
                    divisions: MeshConstants.maxTtl - MeshConstants.minTtl,
                    label: '${settings.meshTtl} hops',
                    onChanged: (val) {
                      ref.read(settingsProvider.notifier).setMeshTtl(val.toInt());
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Preferences',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.offlineGrey),
          ),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark Mode'),
                  subtitle: const Text('High contrast dark theme for OLED screens'),
                  value: settings.isDarkMode,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).toggleDarkMode(val);
                  },
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_none_rounded),
                  title: const Text('Background Notifications'),
                  subtitle: const Text('Alert when new mesh messages arrive'),
                  value: settings.notificationsEnabled,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).toggleNotifications(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Danger Zone',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.errorRed),
          ),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.errorRed),
              title: const Text('Clear Data & Reset Identity', style: TextStyle(color: AppColors.errorRed)),
              subtitle: const Text('Purges all chats, keys, and reset to factory onboarding'),
              onTap: () => _showResetConfirmDialog(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Display Name'),
          content: TextField(
            controller: controller,
            maxLength: 24,
            decoration: const InputDecoration(hintText: 'Enter name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(settingsProvider.notifier).setDisplayName(newName);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Reset Everything?'),
          content: const Text(
            'This action is irreversible. All chat records, messages, and cryptographic keys will be wiped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
              onPressed: () async {
                Navigator.pop(ctx);
                await HiveBoxes.clearAll();
                await AppDatabase.closeAndClear();
                if (context.mounted) {
                  context.go('/onboarding');
                }
              },
              child: const Text('Confirm Reset'),
            ),
          ],
        );
      },
    );
  }
}
