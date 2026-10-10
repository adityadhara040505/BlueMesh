import 'package:flutter_test/flutter_test.dart';
import 'package:blue_mesh/bluetooth/connection_pool.dart';
import 'package:blue_mesh/data/models/device_peer.dart';

void main() {
  group('ConnectionPool Tests', () {
    late ConnectionPool pool;

    setUp(() {
      pool = ConnectionPool();
    });

    tearDown(() {
      pool.dispose();
    });

    test('registerConnection, get, and getByRemoteId', () {
      final conn1 = ManagedPeerConnection(
        deviceId: 101,
        remoteId: 'MAC_101',
        role: PeerConnectionRole.outboundCentral,
        lastActivity: DateTime.now(),
      );

      final conn2 = ManagedPeerConnection(
        deviceId: 102,
        remoteId: 'MAC_102',
        role: PeerConnectionRole.inboundPeripheral,
        lastActivity: DateTime.now(),
      );

      pool.registerConnection(conn1);
      pool.registerConnection(conn2);

      expect(pool.activeConnections.length, 2);
      expect(pool.get(101)?.remoteId, 'MAC_101');
      expect(pool.getByRemoteId('MAC_102')?.deviceId, 102);
      expect(pool.getByRemoteId('UNKNOWN'), isNull);
      expect(pool.outboundCount, 1);
      expect(pool.canConnectOutbound, true);
    });

    test('updateMtu and touchActivity modify connection properties', () {
      final conn = ManagedPeerConnection(
        deviceId: 201,
        remoteId: 'MAC_201',
        role: PeerConnectionRole.outboundCentral,
        mtu: 23,
        lastActivity: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      pool.registerConnection(conn);
      expect(pool.get(201)?.mtu, 23);

      pool.updateMtu(201, 517);
      expect(pool.get(201)?.mtu, 517);

      final oldActivity = pool.get(201)!.lastActivity;
      pool.touchActivity(201);
      final newActivity = pool.get(201)!.lastActivity;
      expect(newActivity.isAfter(oldActivity), true);
    });

    test('removeConnection and clearAll clean up pool', () async {
      final conn = ManagedPeerConnection(
        deviceId: 301,
        remoteId: 'MAC_301',
        role: PeerConnectionRole.inboundPeripheral,
        lastActivity: DateTime.now(),
      );

      pool.registerConnection(conn);
      expect(pool.activeConnections.length, 1);

      await pool.removeConnection(301);
      expect(pool.activeConnections.length, 0);
      expect(pool.get(301), isNull);

      pool.registerConnection(conn);
      await pool.clearAll();
      expect(pool.activeConnections.length, 0);
    });
  });
}
