import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../bluetooth/ble_manager.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../data/models/contact.dart';
import '../data/models/device_peer.dart';
import '../data/models/mesh_message.dart';
import '../data/repositories/contact_repository.dart';
import '../utils/encoding.dart';

/// Manages discovery events and contact card synchronization between newly linked peers.
class PeerDiscoveryManager {
  final int myDeviceId;
  final String myDisplayName;
  final String myPublicKey;
  final String myFingerprint;
  final BleManager bleManager;
  final ContactRepository contactRepository;

  final Map<int, DevicePeer> _discoveredPeers = {};
  final StreamController<DevicePeer> _peerJoinedController = StreamController.broadcast();
  final StreamController<int> _peerLeftController = StreamController.broadcast();
  final StreamController<DevicePeer> _peerUpdatedController = StreamController.broadcast();

  Stream<DevicePeer> get onPeerJoined => _peerJoinedController.stream;
  Stream<int> get onPeerLeft => _peerLeftController.stream;
  Stream<DevicePeer> get onPeerUpdated => _peerUpdatedController.stream;

  StreamSubscription? _bleDiscoverySub;
  StreamSubscription? _poolSub;

  PeerDiscoveryManager({
    required this.myDeviceId,
    required this.myDisplayName,
    required this.myPublicKey,
    required this.myFingerprint,
    required this.bleManager,
    required this.contactRepository,
  });

  /// Starts listening to BLE discovery events and connection pool updates.
  void start() {
    _bleDiscoverySub = bleManager.peerDiscoveryStream.listen(_onDiscoveredPeer);
    _poolSub = bleManager.connectionPool.peerStateStream.listen(_onConnectionPoolPeerChanged);
    AppLogger.i('PeerDiscoveryManager started.');
  }

  /// Handles incoming BLE discovery event.
  void _onDiscoveredPeer(DevicePeer peer) {
    final existing = _discoveredPeers[peer.deviceId];
    if (existing == null) {
      _discoveredPeers[peer.deviceId] = peer;
      _peerJoinedController.add(peer);
      AppLogger.i('Peer joined cluster: ${peer.advertisedName} (${peer.deviceId})');

      // Schedule contact card exchange
      _sendContactCard(peer.deviceId);
    } else {
      existing.rssi = peer.rssi;
      existing.lastSeen = DateTime.now();
      _peerUpdatedController.add(existing);
    }
  }

  void _onConnectionPoolPeerChanged(DevicePeer peer) {
    if (peer.state == PeerState.removed) {
      _discoveredPeers.remove(peer.deviceId);
      _peerLeftController.add(peer.deviceId);
    } else {
      _discoveredPeers[peer.deviceId] = peer;
      _peerUpdatedController.add(peer);
    }
  }

  /// Sends this device's JSON Contact Card to a peer.
  Future<void> _sendContactCard(int peerId) async {
    try {
      final card = {
        'id': myDeviceId,
        'name': myDisplayName,
        'pub': myPublicKey,
        'fp': myFingerprint,
      };

      final payloadBytes = utf8.encode(jsonEncode(card));
      final msgId = ProtocolEncoding.hashUuid('contact_sync_${DateTime.now().microsecondsSinceEpoch}');

      final message = MeshMessage(
        messageId: msgId,
        type: MeshMessageType.contactSync,
        ttl: 2, // Up to 2 hops for adjacent neighbors
        flags: MeshMessage.createFlags(isBroadcast: false),
        senderId: myDeviceId,
        recipientId: peerId,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        payload: Uint8List.fromList(payloadBytes),
      );

      await bleManager.sendMeshMessage(message, specificNextHopId: peerId);
      AppLogger.d('Sent Contact Card to peer $peerId');
    } catch (e) {
      AppLogger.w('Failed to send contact card: $e');
    }
  }

  /// Processes an incoming contact card message from a peer.
  Future<void> handleContactSyncMessage(MeshMessage message) async {
    try {
      final jsonMap = jsonDecode(message.payloadAsString) as Map<String, dynamic>;
      final peerId = jsonMap['id'] as int;
      final name = jsonMap['name'] as String? ?? 'Peer';
      final pubKey = jsonMap['pub'] as String? ?? '';
      final fp = jsonMap['fp'] as String? ?? '';

      final contact = Contact(
        deviceId: peerId,
        name: name,
        publicKey: pubKey,
        fingerprint: fp,
        lastSeen: DateTime.now(),
        isOnline: true,
        hopCount: message.hopCount,
      );

      final changed = await contactRepository.upsertContact(contact);
      if (changed) {
        AppLogger.w('Warning: Fingerprint changed for peer $name ($peerId)! Potential MITM.');
      }
    } catch (e) {
      AppLogger.w('Failed to parse incoming contact card: $e');
    }
  }

  void dispose() {
    _bleDiscoverySub?.cancel();
    _poolSub?.cancel();
    _peerJoinedController.close();
    _peerLeftController.close();
    _peerUpdatedController.close();
  }
}
