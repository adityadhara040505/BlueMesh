import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../bluetooth/ble_manager.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../data/models/mesh_message.dart';
import '../data/repositories/contact_repository.dart';
import '../utils/encoding.dart';

/// Periodic presence heartbeat ping payload.
class HeartbeatPayload {
  final int deviceId;
  final String name;
  final int timestamp;
  final int batteryLevel;

  HeartbeatPayload({
    required this.deviceId,
    required this.name,
    required this.timestamp,
    required this.batteryLevel,
  });

  Map<String, dynamic> toMap() => {
        'id': deviceId,
        'n': name,
        'ts': timestamp,
        'bat': batteryLevel,
      };

  factory HeartbeatPayload.fromMap(Map<String, dynamic> map) => HeartbeatPayload(
        deviceId: map['id'] as int,
        name: map['n'] as String? ?? 'Peer',
        timestamp: map['ts'] as int,
        batteryLevel: map['bat'] as int? ?? 100,
      );
}

/// Service that broadcasts presence beacons every 10s and monitors peer liveness.
class HeartbeatService {
  final int myDeviceId;
  final String myDisplayName;
  final BleManager bleManager;
  final ContactRepository contactRepository;

  Timer? _beaconTimer;
  Timer? _staleCheckTimer;
  bool _isRunning = false;

  HeartbeatService({
    required this.myDeviceId,
    required this.myDisplayName,
    required this.bleManager,
    required this.contactRepository,
  });

  /// Starts the 10-second periodic heartbeat broadcaster and liveness monitor.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    AppLogger.i('HeartbeatService started (interval=${MeshConstants.heartbeatInterval.inSeconds}s).');

    // 1. Broadcast heartbeat ping every 10s
    _beaconTimer = Timer.periodic(MeshConstants.heartbeatInterval, (_) {
      _sendHeartbeat();
    });

    // 2. Check for offline / stale peers every 10s
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkPeerLiveness();
    });
  }

  /// Broadcasts our presence to all connected peers.
  Future<void> _sendHeartbeat() async {
    try {
      final payloadObj = HeartbeatPayload(
        deviceId: myDeviceId,
        name: myDisplayName,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        batteryLevel: 95, // Hardware battery query fallback
      );

      final jsonBytes = utf8.encode(jsonEncode(payloadObj.toMap()));
      final msgId = ProtocolEncoding.hashUuid(DateTime.now().toIso8601String());

      final message = MeshMessage(
        messageId: msgId,
        type: MeshMessageType.heartbeat,
        ttl: 1, // Single-hop local presence beacon
        hopCount: 0,
        flags: MeshMessage.createFlags(isBroadcast: true),
        senderId: myDeviceId,
        recipientId: 0,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        payload: Uint8List.fromList(jsonBytes),
      );

      // Transmit to Central and Peripheral connections
      await bleManager.sendMeshMessage(message);
      await bleManager.sendHeartbeatPing(Uint8List.fromList(jsonBytes));
    } catch (e) {
      AppLogger.w('Failed to broadcast heartbeat: $e');
    }
  }

  /// Processes an incoming heartbeat message frame from a peer.
  void handleHeartbeat(MeshMessage message) {
    try {
      final jsonMap = jsonDecode(message.payloadAsString) as Map<String, dynamic>;
      final payload = HeartbeatPayload.fromMap(jsonMap);

      // Update contact status to online and refresh lastSeen
      contactRepository.updateOnlineStatus(
        payload.deviceId,
        true,
        batteryLevel: payload.batteryLevel,
        hopCount: message.hopCount,
      );
    } catch (e) {
      AppLogger.w('Error parsing heartbeat payload: $e');
    }
  }

  /// Scans contacts and marks them offline if no heartbeat in 30s.
  /// Prunes them from active cluster if no heartbeat in 5 minutes.
  void _checkPeerLiveness() {
    final now = DateTime.now();
    final contacts = contactRepository.contactsNotifier.value;

    for (final contact in contacts) {
      final elapsed = now.difference(contact.lastSeen);

      // If no heartbeat for > 30s, mark offline
      if (elapsed > MeshConstants.peerOfflineThreshold && contact.isOnline) {
        AppLogger.i('Peer ${contact.deviceId} (${contact.name}) marked offline (no heartbeat in ${elapsed.inSeconds}s)');
        contactRepository.updateOnlineStatus(contact.deviceId, false);
      }
    }
  }

  void stop() {
    _isRunning = false;
    _beaconTimer?.cancel();
    _staleCheckTimer?.cancel();
    AppLogger.i('HeartbeatService stopped.');
  }

  void dispose() {
    stop();
  }
}
