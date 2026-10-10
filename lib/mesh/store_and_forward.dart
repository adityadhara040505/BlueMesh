import 'dart:async';
import '../core/constants.dart';
import '../core/logger.dart';
import '../data/models/mesh_message.dart';
import 'mesh_router.dart';

/// Item stored in the Store-and-Forward queue.
class QueuedMeshMessage {
  final MeshMessage message;
  final DateTime queuedAt;
  int retryAttempts;

  QueuedMeshMessage({
    required this.message,
    required this.queuedAt,
    this.retryAttempts = 0,
  });

  bool isExpired() {
    return DateTime.now().difference(queuedAt) > MeshConstants.storeAndForwardMessageTtl;
  }
}

/// Store-and-Forward manager to buffer and deliver messages across intermittent network partitions.
class StoreAndForwardManager {
  final MeshRouter meshRouter;
  final Map<int, List<QueuedMeshMessage>> _queues = {};
  Timer? _retryTimer;
  bool _isRunning = false;

  StoreAndForwardManager({required this.meshRouter});

  /// Starts the 30-second periodic retry worker.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _retryQueuedMessages();
    });
    AppLogger.i('StoreAndForwardManager started.');
  }

  /// Total queued message count across all peers.
  int get totalQueuedCount {
    int count = 0;
    for (final q in _queues.values) {
      count += q.length;
    }
    return count;
  }

  /// Queues an undelivered message for an offline peer.
  bool enqueue(MeshMessage message) {
    final recipientId = message.recipientId;
    if (recipientId == 0) return false; // Broadcast messages are not store-and-forwarded

    final queue = _queues.putIfAbsent(recipientId, () => []);

    // Enforce max 100 messages per peer
    if (queue.length >= MeshConstants.maxStoreAndForwardPerPeer) {
      queue.removeAt(0); // Evict oldest
    }

    queue.add(QueuedMeshMessage(
      message: message,
      queuedAt: DateTime.now(),
    ));

    AppLogger.i('Message ${message.messageId} enqueued in Store-and-Forward for peer $recipientId (Queue size: ${queue.length})');
    return true;
  }

  /// Called when a peer comes online to immediately flush pending messages.
  Future<void> onPeerReconnected(int peerId) async {
    final queue = _queues[peerId];
    if (queue == null || queue.isEmpty) return;

    AppLogger.i('Flushing ${queue.length} Store-and-Forward messages for peer $peerId');
    final pending = List<QueuedMeshMessage>.from(queue);
    queue.clear();

    for (final item in pending) {
      if (!item.isExpired()) {
        final success = await meshRouter.sendOutgoingMessage(item.message);
        if (!success) {
          item.retryAttempts++;
          queue.add(item); // Re-queue if still failed
        }
      }
    }
  }

  /// Periodic retry job run every 30s.
  Future<void> _retryQueuedMessages() async {
    final now = DateTime.now();

    for (final peerId in _queues.keys.toList()) {
      final queue = _queues[peerId];
      if (queue == null) continue;

      // Clean expired (> 24 hours)
      queue.removeWhere((item) => item.isExpired());

      if (queue.isEmpty) {
        _queues.remove(peerId);
        continue;
      }

      // Check if route or peer exists now
      final route = meshRouter.routingTable[peerId];
      if (route != null && !route.isExpired()) {
        final item = queue.removeAt(0);
        item.retryAttempts++;
        final sent = await meshRouter.sendOutgoingMessage(item.message);
        if (!sent && item.retryAttempts < 5) {
          queue.add(item);
        }
      }
    }
  }

  void stop() {
    _isRunning = false;
    _retryTimer?.cancel();
  }

  void dispose() {
    stop();
    _queues.clear();
  }
}
