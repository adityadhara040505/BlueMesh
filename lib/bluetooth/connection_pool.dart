import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../data/models/device_peer.dart';

/// Active connection descriptor stored in the connection pool.
class ManagedPeerConnection {
  final int deviceId;
  final String remoteId;
  final BluetoothDevice? device; // Null if inbound Peripheral connection
  final PeerConnectionRole role;
  int mtu;
  int rssi;
  DateTime lastActivity;
  int reconnectAttempts;
  BluetoothCharacteristic? txCharacteristic; // For writing to peer
  BluetoothCharacteristic? rxCharacteristic; // For reading/notifications
  BluetoothCharacteristic? heartbeatCharacteristic;
  StreamSubscription? rxSubscription;
  StreamSubscription? heartbeatSubscription;
  StreamSubscription? connectionStateSubscription;

  ManagedPeerConnection({
    required this.deviceId,
    required this.remoteId,
    this.device,
    required this.role,
    this.mtu = BleConstants.defaultMtuFallback,
    this.rssi = -70,
    required this.lastActivity,
    this.reconnectAttempts = 0,
    this.txCharacteristic,
    this.rxCharacteristic,
    this.heartbeatCharacteristic,
  });

  void dispose() {
    rxSubscription?.cancel();
    heartbeatSubscription?.cancel();
    connectionStateSubscription?.cancel();
  }
}

/// Thread-safe pool managing multiple concurrent BLE connections.
class ConnectionPool {
  final Map<int, ManagedPeerConnection> _connections = {};
  final StreamController<DevicePeer> _peerStateController = StreamController<DevicePeer>.broadcast();

  Stream<DevicePeer> get peerStateStream => _peerStateController.stream;

  /// Retrieve all currently connected peers.
  List<ManagedPeerConnection> get activeConnections => _connections.values.toList();

  /// Total count of outbound Central connections currently active.
  int get outboundCount =>
      _connections.values.where((c) => c.role == PeerConnectionRole.outboundCentral).length;

  /// Whether we have available slots for a new outbound Central connection.
  bool get canConnectOutbound => outboundCount < BleConstants.maxOutboundConnections;

  /// Look up an active connection by peer 32-bit deviceId.
  ManagedPeerConnection? get(int deviceId) => _connections[deviceId];

  /// Look up an active connection by Bluetooth MAC / UUID address string.
  ManagedPeerConnection? getByRemoteId(String remoteId) {
    for (final conn in _connections.values) {
      if (conn.remoteId == remoteId) return conn;
    }
    return null;
  }

  /// Register or update an active connection in the pool.
  void registerConnection(ManagedPeerConnection connection) {
    _connections[connection.deviceId] = connection;
    AppLogger.i('Connection registered in pool: peer=${connection.deviceId} (${connection.role.name}), total=${_connections.length}');
  }

  /// Remove a connection and release its subscriptions.
  Future<void> removeConnection(int deviceId) async {
    final conn = _connections.remove(deviceId);
    if (conn != null) {
      conn.dispose();
      try {
        if (conn.device != null) {
          await conn.device!.disconnect();
        }
      } catch (e) {
        AppLogger.w('Error disconnecting device for peer $deviceId: $e');
      }
      AppLogger.i('Connection removed from pool: peer=$deviceId, remaining=${_connections.length}');
    }
  }

  /// Updates negotiated MTU for a given connection.
  void updateMtu(int deviceId, int mtu) {
    final conn = _connections[deviceId];
    if (conn != null) {
      conn.mtu = mtu;
      AppLogger.d('Updated MTU for peer $deviceId to $mtu');
    }
  }

  /// Updates last activity timestamp to prevent idle timeouts.
  void touchActivity(int deviceId) {
    final conn = _connections[deviceId];
    if (conn != null) {
      conn.lastActivity = DateTime.now();
    }
  }

  /// Disconnect and wipe all connections.
  Future<void> clearAll() async {
    for (final conn in _connections.values) {
      conn.dispose();
      try {
        if (conn.device != null) {
          await conn.device!.disconnect();
        }
      } catch (_) {}
    }
    _connections.clear();
  }

  void dispose() {
    clearAll();
    _peerStateController.close();
  }
}
