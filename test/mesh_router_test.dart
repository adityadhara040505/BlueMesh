import 'dart:typed_data';
import 'package:blue_mesh/bluetooth/ble_manager.dart';
import 'package:blue_mesh/data/models/mesh_message.dart';
import 'package:blue_mesh/mesh/deduplicator.dart';
import 'package:blue_mesh/mesh/mesh_router.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal in-memory mock BleManager for testing routing decisions without hardware
class MockBleTransport extends BleManager {
  final List<MeshMessage> sentMessages = [];

  MockBleTransport()
      : super(
          myDeviceId: 100,
          myDisplayName: 'Node 100',
          onMessageReceived: (_) {},
        );

  @override
  Future<bool> sendMeshMessage(MeshMessage message, {int? specificNextHopId}) async {
    sentMessages.add(message);
    return true;
  }
}

void main() {
  group('MeshRouter Routing & TTL Tests', () {
    late MockBleTransport mockBle;
    late MessageDeduplicator deduplicator;
    late MeshRouter router;
    late List<MeshMessage> locallyDelivered;

    setUp(() {
      mockBle = MockBleTransport();
      deduplicator = MessageDeduplicator(capacity: 500);
      locallyDelivered = [];

      router = MeshRouter(
        myDeviceId: 100, // My device ID
        bleManager: mockBle,
        deduplicator: deduplicator,
        onLocalDeliver: (msg) => locallyDelivered.add(msg),
      );
    });

    tearDown(() {
      router.dispose();
    });

    test('Incoming broadcast message is delivered locally AND relayed with decremented TTL', () async {
      final incoming = MeshMessage(
        messageId: 0x1111,
        type: MeshMessageType.text,
        ttl: 5,
        hopCount: 1,
        flags: MeshMessage.createFlags(isBroadcast: true),
        senderId: 200,
        recipientId: 0,
        timestamp: 1700000000,
        payload: Uint8List.fromList([1, 2, 3]),
      );

      await router.routeIncomingMessage(incoming, 200);

      // Delivered locally
      expect(locallyDelivered.length, 1);
      expect(locallyDelivered.first.messageId, 0x1111);

      // Relayed to other peers with TTL = 4 and hopCount = 2
      expect(mockBle.sentMessages.length, 1);
      final relayed = mockBle.sentMessages.first;
      expect(relayed.ttl, 4);
      expect(relayed.hopCount, 2);
      expect(router.counters.relayed, 1);
    });

    test('Incoming message with TTL=1 is dropped from relaying', () async {
      final incoming = MeshMessage(
        messageId: 0x2222,
        type: MeshMessageType.text,
        ttl: 1, // Will decrement to 0 -> should NOT relay
        hopCount: 4,
        flags: MeshMessage.createFlags(isBroadcast: false),
        senderId: 300,
        recipientId: 400, // For someone else
        timestamp: 1700000000,
        payload: Uint8List.fromList([4, 5, 6]),
      );

      await router.routeIncomingMessage(incoming, 300);

      expect(locallyDelivered, isEmpty);
      expect(mockBle.sentMessages, isEmpty); // Dropped
      expect(router.counters.dropped, 1);
    });

    test('Routing table records shortest path hop count', () {
      router.updateRoute(peerId: 500, nextHopId: 200, hopCount: 3);
      expect(router.routingTable[500]?.hopCount, 3);
      expect(router.routingTable[500]?.nextHopId, 200);

      // Longer hop count should NOT overwrite shorter path
      router.updateRoute(peerId: 500, nextHopId: 201, hopCount: 4);
      expect(router.routingTable[500]?.hopCount, 3);

      // Shorter hop count SHOULD overwrite
      router.updateRoute(peerId: 500, nextHopId: 202, hopCount: 1);
      expect(router.routingTable[500]?.hopCount, 1);
      expect(router.routingTable[500]?.nextHopId, 202);

      // Route to self should be ignored
      router.updateRoute(peerId: 100, nextHopId: 100, hopCount: 0);
      expect(router.routingTable.containsKey(100), false);
    });

    test('Duplicate incoming message is dropped', () async {
      final msg = MeshMessage(
        messageId: 0x9999,
        type: MeshMessageType.text,
        ttl: 5,
        hopCount: 1,
        flags: MeshMessage.createFlags(isBroadcast: true),
        senderId: 200,
        recipientId: 0,
        timestamp: 1700000000,
        payload: Uint8List.fromList([1]),
      );

      await router.routeIncomingMessage(msg, 200);
      expect(router.counters.received, 1);

      // Second time should be dropped as duplicate
      await router.routeIncomingMessage(msg, 200);
      expect(router.counters.received, 2);
      expect(router.counters.dropped, 1);
    });

    test('sendOutgoingMessage handles broadcast and unicast routes', () async {
      final broadcast = MeshMessage(
        messageId: 0x8881,
        type: MeshMessageType.text,
        ttl: 5,
        hopCount: 0,
        flags: MeshMessage.createFlags(isBroadcast: true),
        senderId: 100,
        recipientId: 0,
        timestamp: 1700000000,
        payload: Uint8List.fromList([1]),
      );

      expect(await router.sendOutgoingMessage(broadcast), true);
      expect(router.counters.sent, 1);

      // Unicast with route
      router.updateRoute(peerId: 600, nextHopId: 205, hopCount: 2);
      final unicastWithRoute = MeshMessage(
        messageId: 0x8882,
        type: MeshMessageType.text,
        ttl: 5,
        hopCount: 0,
        flags: 0,
        senderId: 100,
        recipientId: 600,
        timestamp: 1700000000,
        payload: Uint8List.fromList([2]),
      );

      expect(await router.sendOutgoingMessage(unicastWithRoute), true);
      expect(router.counters.sent, 2);

      // Unicast without route (flood)
      final unicastNoRoute = MeshMessage(
        messageId: 0x8883,
        type: MeshMessageType.text,
        ttl: 5,
        hopCount: 0,
        flags: 0,
        senderId: 100,
        recipientId: 999,
        timestamp: 1700000000,
        payload: Uint8List.fromList([3]),
      );

      expect(await router.sendOutgoingMessage(unicastNoRoute), true);
      expect(router.counters.sent, 3);
    });

    test('RoutingEntry isExpired detects staleness', () {
      final fresh = RoutingEntry(
        peerId: 1,
        nextHopId: 1,
        hopCount: 1,
        lastSeen: DateTime.now(),
      );
      expect(fresh.isExpired(), false);

      final expired = RoutingEntry(
        peerId: 2,
        nextHopId: 2,
        hopCount: 1,
        lastSeen: DateTime.now().subtract(const Duration(seconds: 70)),
      );
      expect(expired.isExpired(), true);
    });
  });
}
