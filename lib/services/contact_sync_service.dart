import 'dart:async';
import '../core/logger.dart';
import '../data/repositories/contact_repository.dart';
import '../mesh/peer_discovery.dart';

/// Coordinates periodic synchronization of contact cards and presence states across the mesh.
class ContactSyncService {
  final ContactRepository contactRepository;
  final PeerDiscoveryManager peerDiscoveryManager;

  Timer? _syncTimer;
  bool _isRunning = false;

  ContactSyncService({
    required this.contactRepository,
    required this.peerDiscoveryManager,
  });

  /// Starts periodic contact synchronization maintenance.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Periodic sweep every 60 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _sweepContacts();
    });

    AppLogger.i('ContactSyncService started.');
  }

  void _sweepContacts() {
    try {
      final contacts = contactRepository.contactsNotifier.value;
      AppLogger.d('ContactSyncService sweep: monitoring ${contacts.length} peers.');
    } catch (e) {
      AppLogger.w('Contact sync sweep error: $e');
    }
  }

  void stop() {
    _isRunning = false;
    _syncTimer?.cancel();
  }

  void dispose() {
    stop();
  }
}
