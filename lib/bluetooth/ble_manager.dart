import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../core/platform_capabilities.dart';
import '../data/models/device_peer.dart';
import '../data/models/mesh_message.dart';
import 'ble_central.dart';
import 'ble_peripheral.dart';
import 'bluetooth_permissions.dart';
import 'connection_pool.dart';
import 'fragmentation.dart';

/// Callback when a fully reassembled mesh message is received over BLE.
typedef OnMeshMessageReceived = void Function(MeshMessage message);

/// High-level orchestrator coordinating dual-role BLE (Central + Peripheral),
/// MTU negotiation, packet fragmentation, and dispatching.
class BleManager {
  final int myDeviceId;
  final String myDisplayName;
  final OnMeshMessageReceived onMessageReceived;

  final ConnectionPool connectionPool = ConnectionPool();
  final PacketFragmenter fragmenter = PacketFragmenter();

  BlePeripheralManager? _peripheral;
  BleCentralManager? _central;

  bool _isInitialized = false;
  bool _isPeripheralEnabled = false;

  final StreamController<DevicePeer> _peerDiscoveryController =
      StreamController<DevicePeer>.broadcast();

  Stream<DevicePeer> get peerDiscoveryStream => _peerDiscoveryController.stream;
  bool get isPeripheralEnabled => _isPeripheralEnabled;

  BleManager({
    required this.myDeviceId,
    required this.myDisplayName,
    required this.onMessageReceived,
  });

  /// Initializes hardware permissions, detects platform capabilities, and starts dual-role stack.
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.i('Initializing BlueMesh BLE dual-role orchestrator...');

    // 1. Request OS permissions
    final hasPermissions = await BluetoothPermissionsManager.requestPermissions();
    if (!hasPermissions) {
      AppLogger.w('Bluetooth permissions were not fully granted. Operations may be restricted.');
    }

    // 2. Check Peripheral support (Desktop/unsupported platforms fall back to Central-only)
    _isPeripheralEnabled = await PlatformCapabilities.isPeripheralSupported();

    // 3. Initialize BLE Peripheral GATT Server (if supported)
    if (_isPeripheralEnabled) {
      _peripheral = BlePeripheralManager(
        myDeviceId: myDeviceId,
        myDisplayName: myDisplayName,
        onPacketReceived: _handleInboundFragment,
      );
      await _peripheral!.start();
    } else {
      AppLogger.i('Operating in Central-Only mode (Peripheral advertising disabled).');
      // On Linux desktop, announce presence via BlueZ system alias and discoverable LE advertising
      if (!kIsWeb && Platform.isLinux) {
        _startLinuxAdvertising();
      }
    }

    // 4. Initialize BLE Central GATT Client & Duty-Cycle Scanner
    _central = BleCentralManager(
      myDeviceId: myDeviceId,
      connectionPool: connectionPool,
      onPacketReceived: (peerId, packet) => _handleInboundFragment(packet),
      onPeerDiscovered: _handlePeerDiscovered,
    );
    await _central!.startDutyCycle();

    _isInitialized = true;
    AppLogger.i('BlueMesh BLE Orchestrator ready.');
  }

  /// Broadcasts BLE presence on Linux desktop via BlueZ bluetoothctl.
  Future<void> _startLinuxAdvertising() async {
    try {
      final advertisedName = '${BleConstants.advertisedNamePrefix}${myDeviceId.toRadixString(16).padLeft(8, '0')}';
      AppLogger.i('Configuring Linux Bluetooth adapter as "$advertisedName"...');
      await Process.run('bluetoothctl', ['system-alias', advertisedName]);
      await Process.run('bluetoothctl', ['discoverable', 'on']);
      await Process.run('bluetoothctl', ['advertise', 'on']);
      AppLogger.i('Linux Bluetooth advertising active as "$advertisedName".');
    } catch (e) {
      AppLogger.w('Linux bluetoothctl setup error: $e');
    }
  }

  /// Handles incoming raw fragment from Central or Peripheral role.
  void _handleInboundFragment(Uint8List rawFragment) {
    try {
      final completeFrame = fragmenter.processIncomingFragment(rawFragment);
      if (completeFrame != null) {
        final message = MeshMessage.fromBytes(completeFrame);
        AppLogger.d('Reassembled full message ${message.messageId} (type=${message.type.name}, from=${message.senderId})');
        onMessageReceived(message);
      }
    } catch (e, stack) {
      AppLogger.e('Error handling inbound fragment: $e', e, stack);
    }
  }

  /// Handles discovery of a nearby peer advertisement.
  void _handlePeerDiscovered(int peerId, String remoteId, String advName, int rssi) {
    final peer = DevicePeer(
      deviceId: peerId,
      remoteId: remoteId,
      advertisedName: advName,
      rssi: rssi,
      lastSeen: DateTime.now(),
      state: PeerState.discovered,
    );
    _peerDiscoveryController.add(peer);
  }

  /// Sends a mesh message to a target peer or broadcasts to all connected peers.
  Future<bool> sendMeshMessage(MeshMessage message, {int? specificNextHopId}) async {
    final rawFrame = message.toBytes();
    final activeConns = connectionPool.activeConnections;

    if (activeConns.isEmpty && !_isPeripheralEnabled) {
      AppLogger.w('Cannot send message ${message.messageId}: no active peer connections.');
      return false;
    }

    bool success = false;

    // Direct unicast to a specific connected peer
    if (specificNextHopId != null && specificNextHopId != 0) {
      final conn = connectionPool.get(specificNextHopId);
      if (conn != null) {
        final fragments = fragmenter.fragment(message.messageId, rawFrame, conn.mtu);
        for (final frag in fragments) {
          if (conn.role == PeerConnectionRole.outboundCentral) {
            await _central?.sendPacketToPeer(specificNextHopId, frag);
          } else {
            await _peripheral?.notifyMessage(frag);
          }
        }
        return true;
      }
    }

    // Broadcast or flooded message: transmit across all active links
    for (final conn in activeConns) {
      final fragments = fragmenter.fragment(message.messageId, rawFrame, conn.mtu);
      for (final frag in fragments) {
        if (conn.role == PeerConnectionRole.outboundCentral) {
          await _central?.sendPacketToPeer(conn.deviceId, frag);
        }
      }
      success = true;
    }

    // If acting as Peripheral, also notify connected Central subscribers
    if (_isPeripheralEnabled && _peripheral != null) {
      final fragments = fragmenter.fragment(
        message.messageId,
        rawFrame,
        BleConstants.defaultMtuAndroid,
      );
      for (final frag in fragments) {
        await _peripheral!.notifyMessage(frag);
      }
      success = true;
    }

    return success;
  }

  /// Transmit a presence ping through GATT notification.
  Future<void> sendHeartbeatPing(Uint8List heartbeatPayload) async {
    if (_isPeripheralEnabled && _peripheral != null) {
      await _peripheral!.notifyHeartbeat(heartbeatPayload);
    }
  }

  /// Shut down BLE subsystems and release connections.
  Future<void> dispose() async {
    _isInitialized = false;
    fragmenter.dispose();
    if (!kIsWeb && Platform.isLinux) {
      try {
        await Process.run('bluetoothctl', ['advertise', 'off']);
      } catch (_) {}
    }
    await _central?.stop();
    await _peripheral?.stop();
    await connectionPool.clearAll();
    _peerDiscoveryController.close();
    AppLogger.i('BleManager disposed.');
  }
}
