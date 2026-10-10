import 'package:flutter_test/flutter_test.dart';
import 'package:blue_mesh/bluetooth/ble_manager.dart';
import 'package:blue_mesh/mesh/deduplicator.dart';
import 'package:blue_mesh/mesh/store_and_forward.dart';
import 'package:blue_mesh/mesh/mesh_router.dart';
import 'package:blue_mesh/data/models/mesh_message.dart';
import 'dart:typed_data';

class MockBleTransport extends BleManager {
  MockBleTransport()
      : super(
          myDeviceId: 0x1111,
          myDisplayName: 'Node 1111',
          onMessageReceived: (_) {},
        );

  @override
  Future<bool> sendMeshMessage(MeshMessage message, {int? specificNextHopId}) async {
    return true;
  }
}

void main() {
  group('StoreAndForwardManager Tests', () {
    late MockBleTransport mockBle;
    late MessageDeduplicator deduplicator;
    late MeshRouter router;
    late StoreAndForwardManager sfManager;

    setUp(() {
      mockBle = MockBleTransport();
      deduplicator = MessageDeduplicator();
      router = MeshRouter(
        myDeviceId: 0x1111,
        bleManager: mockBle,
        deduplicator: deduplicator,
        onLocalDeliver: (_) {},
      );
      sfManager = StoreAndForwardManager(meshRouter: router);
    });

    tearDown(() {
      sfManager.dispose();
      router.dispose();
    });

    test('enqueue buffers direct messages and ignores broadcasts', () {
      final directMsg = MeshMessage(
        messageId: 1001,
        type: MeshMessageType.text,
        senderId: 0x1111,
        recipientId: 0x2222,
        flags: 0,
        timestamp: 100,
        payload: Uint8List.fromList([1, 2, 3]),
      );

      final broadcastMsg = MeshMessage(
        messageId: 1002,
        type: MeshMessageType.text,
        senderId: 0x1111,
        recipientId: 0, // Broadcast
        flags: 2,
        timestamp: 100,
        payload: Uint8List.fromList([4, 5, 6]),
      );

      expect(sfManager.enqueue(directMsg), true);
      expect(sfManager.totalQueuedCount, 1);

      expect(sfManager.enqueue(broadcastMsg), false);
      expect(sfManager.totalQueuedCount, 1);
    });

    test('QueuedMeshMessage isExpired detects expiration', () {
      final msg = MeshMessage(
        messageId: 2001,
        type: MeshMessageType.text,
        senderId: 0x1111,
        recipientId: 0x2222,
        flags: 0,
        timestamp: 100,
        payload: Uint8List(0),
      );

      final fresh = QueuedMeshMessage(
        message: msg,
        queuedAt: DateTime.now(),
      );
      expect(fresh.isExpired(), false);

      final expired = QueuedMeshMessage(
        message: msg,
        queuedAt: DateTime.now().subtract(const Duration(hours: 25)),
      );
      expect(expired.isExpired(), true);
    });

    test('start, stop, and dispose control lifecycle', () {
      sfManager.start();
      expect(sfManager.totalQueuedCount, 0);
      sfManager.stop();
      sfManager.dispose();
      expect(sfManager.totalQueuedCount, 0);
    });
  });
}
