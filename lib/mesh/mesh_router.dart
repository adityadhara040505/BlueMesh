import 'dart:async';
import '../bluetooth/ble_manager.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../data/models/mesh_message.dart';
import 'deduplicator.dart';

/// Single entry in dynamic distance-vector routing table.
class RoutingEntry {
  final int peerId;
  final int nextHopId;
  final int hopCount;
  DateTime lastSeen;

  RoutingEntry({
    required this.peerId,
    required this.nextHopId,
    required this.hopCount,
    required this.lastSeen,
  });

  bool isExpired() {
    return DateTime.now().difference(lastSeen) > MeshConstants.routingEntryTtl;
  }
}

/// Statistics counters for the Diagnostics screen.
class MeshCounters {
  int sent = 0;
  int received = 0;
  int relayed = 0;
  int dropped = 0;
}

/// Decides whether to deliver, forward, or drop packets based on TTL flooding and routing table.
class MeshRouter {
  final int myDeviceId;
  final BleManager bleManager;
  final MessageDeduplicator deduplicator;
  final void Function(MeshMessage message) onLocalDeliver;

  final Map<int, RoutingEntry> _routingTable = {};
  final MeshCounters counters = MeshCounters();
  Timer? _routingTableExpiryTimer;

  MeshRouter({
    required this.myDeviceId,
    required this.bleManager,
    required this.deduplicator,
    required this.onLocalDeliver,
  }) {
    _startTableCleanupTimer();
  }

  /// Read-only snapshot of dynamic routing table.
  Map<int, RoutingEntry> get routingTable => Map.unmodifiable(_routingTable);

  /// Ingress handler for messages arriving from the Bluetooth transport.
  Future<void> routeIncomingMessage(MeshMessage message, int directSenderHop) async {
    counters.received++;

    // 1. Deduplication check: drop duplicate frames
    if (deduplicator.isDuplicate(message.messageId)) {
      counters.dropped++;
      AppLogger.d('Dropped duplicate mesh message ${message.messageId}');
      return;
    }

    // 2. Update routing table for the original sender
    updateRoute(
      peerId: message.senderId,
      nextHopId: directSenderHop,
      hopCount: message.hopCount + 1,
    );

    // 3. Check if message is addressed to THIS device
    final isForMe = message.recipientId == myDeviceId;
    final isBroadcast = message.isBroadcast;

    if (isForMe || isBroadcast) {
      AppLogger.i('Delivering message ${message.messageId} locally (sender=${message.senderId})');
      onLocalDeliver(message);
    }

    // 4. Relay decision: if TTL > 1, relay to other peers
    if (message.ttl > 1) {
      final relayedMessage = MeshMessage(
        messageId: message.messageId,
        type: message.type,
        ttl: message.ttl - 1,
        hopCount: message.hopCount + 1,
        flags: message.flags,
        senderId: message.senderId,
        recipientId: message.recipientId,
        timestamp: message.timestamp,
        payload: message.payload,
      );

      if (isBroadcast) {
        // Forward broadcast messages to ALL peers except the node that forwarded it to us
        counters.relayed++;
        AppLogger.d('Relaying broadcast message ${message.messageId} (TTL=${relayedMessage.ttl})');
        await bleManager.sendMeshMessage(relayedMessage);
      } else if (!isForMe) {
        // Unicast message destined for someone else: forward along next-hop or flood
        counters.relayed++;
        final route = _routingTable[message.recipientId];
        if (route != null && !route.isExpired()) {
          AppLogger.d('Forwarding unicast message ${message.messageId} to next hop ${route.nextHopId}');
          await bleManager.sendMeshMessage(relayedMessage, specificNextHopId: route.nextHopId);
        } else {
          // Flood to discover/reach target node
          AppLogger.d('Flooding unicast message ${message.messageId} (no direct route)');
          await bleManager.sendMeshMessage(relayedMessage);
        }
      }
    } else {
      counters.dropped++;
      AppLogger.d('Dropped message ${message.messageId}: TTL expired (TTL=${message.ttl})');
    }
  }

  /// Sends a newly authored outgoing message from this device.
  Future<bool> sendOutgoingMessage(MeshMessage message) async {
    counters.sent++;
    // Register own message in deduplicator so we don't process it if echoed back
    deduplicator.isDuplicate(message.messageId);

    if (message.isBroadcast) {
      return await bleManager.sendMeshMessage(message);
    }

    // Check routing table for known next-hop
    final route = _routingTable[message.recipientId];
    if (route != null && !route.isExpired()) {
      return await bleManager.sendMeshMessage(message, specificNextHopId: route.nextHopId);
    }

    // Default to flooding if next-hop unknown
    return await bleManager.sendMeshMessage(message);
  }

  /// Record or refresh a route to a distant node.
  void updateRoute({required int peerId, required int nextHopId, required int hopCount}) {
    if (peerId == myDeviceId) return;

    final existing = _routingTable[peerId];
    if (existing == null || hopCount <= existing.hopCount || existing.isExpired()) {
      _routingTable[peerId] = RoutingEntry(
        peerId: peerId,
        nextHopId: nextHopId,
        hopCount: hopCount,
        lastSeen: DateTime.now(),
      );
      AppLogger.d('Routing table updated: peer $peerId -> next hop $nextHopId ($hopCount hops)');
    }
  }

  /// Periodic cleanup of expired routing table entries (> 60s).
  void _startTableCleanupTimer() {
    _routingTableExpiryTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final now = DateTime.now();
      _routingTable.removeWhere((id, route) {
        final expired = now.difference(route.lastSeen) > MeshConstants.routingEntryTtl;
        return expired;
      });
    });
  }

  void dispose() {
    _routingTableExpiryTimer?.cancel();
    _routingTable.clear();
  }
}
