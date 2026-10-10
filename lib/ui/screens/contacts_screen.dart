import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/contact.dart';
import '../providers/ble_provider.dart';
import '../providers/contact_provider.dart';
import '../theme/colors.dart';
import '../widgets/contact_tile.dart';
import '../widgets/empty_state.dart';

/// Screen displaying all nodes currently or recently discovered in the Bluetooth cluster.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(filteredContactsProvider);
    final query = ref.watch(contactSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Receiver', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              'Choose a nearby node to message',
              style: TextStyle(fontSize: 12, color: AppColors.offlineGrey, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => ref.read(contactSearchQueryProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: 'Search by node name or fingerprint...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => ref.read(contactSearchQueryProvider.notifier).state = '',
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: contacts.isEmpty
          ? const EmptyStateView(
              icon: Icons.bluetooth_searching_rounded,
              title: 'No Peers Discovered Yet',
              message: 'Searching for nearby devices running BlueMesh.\nMake sure Bluetooth is enabled on both phones.',
            )
          : ListView.separated(
              itemCount: contacts.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ContactTile(
                  contact: contact,
                  onTap: () {
                    context.push(
                      '/chat?peerId=${contact.deviceId}&peerName=${Uri.encodeComponent(contact.name)}',
                    );
                  },
                  onVerifyFingerprint: () => _showFingerprintVerificationDialog(context, ref, contact),
                );
              },
            ),
    );
  }

  void _showFingerprintVerificationDialog(BuildContext context, WidgetRef ref, Contact contact) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Verify ${contact.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trust On First Use (TOFU) Fingerprint:',
                style: TextStyle(fontSize: 12, color: AppColors.offlineGrey),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  contact.fingerprint,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: AppColors.accentCyan,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Compare this 8-character fingerprint with ${contact.name}\'s screen in person to ensure no man-in-the-middle exists.',
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final bleNotifier = ref.read(bleProvider.notifier);
                await bleNotifier.contactRepository.setVerified(contact.deviceId, true);
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Mark Verified'),
            ),
          ],
        );
      },
    );
  }
}
