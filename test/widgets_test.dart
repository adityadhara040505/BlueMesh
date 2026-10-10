import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blue_mesh/ui/widgets/empty_state.dart';
import 'package:blue_mesh/ui/widgets/connection_banner.dart';
import 'package:blue_mesh/ui/widgets/bluetooth_status_chip.dart';
import 'package:blue_mesh/ui/widgets/mesh_topology_view.dart';
import 'package:blue_mesh/data/models/device_peer.dart';

void main() {
  group('UI Widgets Tests', () {
    testWidgets('EmptyStateView renders title, message, and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              icon: Icons.chat_bubble_outline,
              title: 'No Conversations',
              message: 'Discover mesh peers to start chatting',
            ),
          ),
        ),
      );

      expect(find.text('No Conversations'), findsOneWidget);
      expect(find.text('Discover mesh peers to start chatting'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('ConnectionBanner displays warning when offline and hides when online', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionBanner(
              isOnline: false,
              peerName: 'Bob',
            ),
          ),
        ),
      );

      expect(find.textContaining('Waiting for Bob'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionBanner(
              isOnline: true,
              peerName: 'Bob',
            ),
          ),
        ),
      );

      expect(find.textContaining('Waiting for Bob'), findsNothing);
    });

    testWidgets('BluetoothStatusChip shows Bluetooth Off when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BluetoothStatusChip(
              isBluetoothOn: false,
              isScanning: false,
              peerCount: 0,
              isDualRole: true,
            ),
          ),
        ),
      );

      expect(find.text('Bluetooth Off'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth_disabled_rounded), findsOneWidget);
    });

    testWidgets('BluetoothStatusChip shows peer count when active', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BluetoothStatusChip(
              isBluetoothOn: true,
              isScanning: true,
              peerCount: 3,
              isDualRole: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('3 Peers'), findsOneWidget);
    });

    testWidgets('MeshTopologyView renders topology canvas and nodes', (tester) async {
      final peers = [
        DevicePeer(
          deviceId: 0x1111,
          remoteId: 'AA:BB:CC:DD:EE:01',
          advertisedName: 'Node-1',
          lastSeen: DateTime.now(),
          isConnected: true,
        ),
        DevicePeer(
          deviceId: 0x2222,
          remoteId: 'AA:BB:CC:DD:EE:02',
          advertisedName: 'Node-2',
          lastSeen: DateTime.now(),
          isConnected: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: MeshTopologyView(
                myName: 'LocalDevice',
                peers: peers,
              ),
            ),
          ),
        ),
      );

      expect(find.text('LocalDevice'), findsOneWidget);
      expect(find.text('Node-1'), findsOneWidget);
      expect(find.text('Node-2'), findsOneWidget);
    });
  });
}
