import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bluetooth/ble_manager.dart';
import '../../bluetooth/bluetooth_permissions.dart';
import '../../core/constants.dart';
import '../../core/logger.dart';
import '../../crypto/encryption.dart';
import '../../crypto/key_manager.dart';
import '../../crypto/message_signer.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/device_peer.dart';
import '../../data/models/mesh_message.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/contact_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../mesh/deduplicator.dart';
import '../../mesh/heartbeat_service.dart';
import '../../mesh/mesh_router.dart';
import '../../mesh/peer_discovery.dart';
import '../../mesh/store_and_forward.dart';
import '../../services/background_service.dart';
import '../../services/notification_service.dart';
import 'settings_provider.dart';

/// State snapshot for Bluetooth Mesh status banner and cluster overview.
class BleState {
  final bool isBluetoothOn;
  final bool isScanning;
  final bool isPeripheralActive;
  final int connectedPeersCount;
  final List<DevicePeer> discoveredPeers;
  final MeshCounters counters;

  const BleState({
    this.isBluetoothOn = true,
    this.isScanning = true,
    this.isPeripheralActive = false,
    this.connectedPeersCount = 0,
    this.discoveredPeers = const [],
    required this.counters,
  });

  BleState copyWith({
    bool? isBluetoothOn,
    bool? isScanning,
    bool? isPeripheralActive,
    int? connectedPeersCount,
    List<DevicePeer>? discoveredPeers,
    MeshCounters? counters,
  }) {
    return BleState(
      isBluetoothOn: isBluetoothOn ?? this.isBluetoothOn,
      isScanning: isScanning ?? this.isScanning,
      isPeripheralActive: isPeripheralActive ?? this.isPeripheralActive,
      connectedPeersCount: connectedPeersCount ?? this.connectedPeersCount,
      discoveredPeers: discoveredPeers ?? this.discoveredPeers,
      counters: counters ?? this.counters,
    );
  }
}

/// Global mesh system controller that bootstraps all networking and crypto engines.
class BleNotifier extends StateNotifier<BleState> {
  final Ref ref;

  late KeyManager keyManager;
  late ContactRepository contactRepository;
  late ChatRepository chatRepository;
  late MessageRepository messageRepository;
  late MessageDeduplicator deduplicator;
  late BleManager bleManager;
  late MeshRouter meshRouter;
  late HeartbeatService heartbeatService;
  late PeerDiscoveryManager peerDiscoveryManager;
  late StoreAndForwardManager storeAndForwardManager;
  late MessageSigner messageSigner;
  late MeshEncryption encryption;

  bool _initialized = false;
  Timer? _uiRefreshTimer;
  final Completer<void> _readyCompleter = Completer<void>();

  /// Future indicating mesh and cryptography engine initialization is complete.
  Future<void> get whenReady => _readyCompleter.future;

  BleNotifier(this.ref) : super(BleState(counters: MeshCounters())) {
    _initMeshEngine();
  }

  Future<void> _initMeshEngine() async {
    if (_initialized) return;

    try {
      final settings = ref.read(settingsProvider);

      // 1. Initialize Repositories & Cryptography
      contactRepository = ContactRepository();
      chatRepository = ChatRepository();
      messageRepository = MessageRepository();
      deduplicator = MessageDeduplicator();
      messageSigner = MessageSigner();
      encryption = MeshEncryption();

      keyManager = KeyManager();
      await keyManager.initialize();

      // 2. Initialize BLE Orchestrator
      bleManager = BleManager(
        myDeviceId: settings.deviceId,
        myDisplayName: settings.displayName,
        onMessageReceived: (msg) {
          meshRouter.routeIncomingMessage(msg, msg.senderId);
        },
      );

      // 3. Initialize Mesh Router
      meshRouter = MeshRouter(
        myDeviceId: settings.deviceId,
        bleManager: bleManager,
        deduplicator: deduplicator,
        onLocalDeliver: _handleLocalDelivery,
      );

      // 4. Initialize Peer Discovery & Heartbeat
      peerDiscoveryManager = PeerDiscoveryManager(
        myDeviceId: settings.deviceId,
        myDisplayName: settings.displayName,
        myPublicKey: keyManager.publicKeyBase64,
        myFingerprint: keyManager.fingerprint,
        bleManager: bleManager,
        contactRepository: contactRepository,
      );

      heartbeatService = HeartbeatService(
        myDeviceId: settings.deviceId,
        myDisplayName: settings.displayName,
        bleManager: bleManager,
        contactRepository: contactRepository,
      );

      storeAndForwardManager = StoreAndForwardManager(meshRouter: meshRouter);

      // 5. Start BLE stack and services
      await bleManager.initialize();
      peerDiscoveryManager.start();
      heartbeatService.start();
      storeAndForwardManager.start();

      // 6. Monitor discovery streams
      peerDiscoveryManager.onPeerJoined.listen((peer) {
        _updatePeersList();
        storeAndForwardManager.onPeerReconnected(peer.deviceId);
      });

      peerDiscoveryManager.onPeerUpdated.listen((_) => _updatePeersList());
      peerDiscoveryManager.onPeerLeft.listen((_) => _updatePeersList());

      // 7. Adapter status stream
      BluetoothPermissionsManager.adapterStateStream.listen((adapterState) {
        final isOn = adapterState.name == 'on';
        state = state.copyWith(isBluetoothOn: isOn);
      });

      // 8. Periodic UI status refresh timer
      _uiRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _refreshState();
      });

      _initialized = true;
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
      state = state.copyWith(
        isPeripheralActive: bleManager.isPeripheralEnabled,
      );
      AppLogger.i('BlueMesh Engine fully bootstrapped.');
    } catch (e, stack) {
      AppLogger.e('Fatal mesh initialization error: $e', e, stack);
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    }
  }

  /// Restarts mesh engine with updated configuration or newly granted permissions.
  Future<void> restartMeshEngine() async {
    try {
      _uiRefreshTimer?.cancel();
      if (_initialized) {
        await bleManager.dispose();
      }
      _initialized = false;
      await _initMeshEngine();
    } catch (e, stack) {
      AppLogger.e('Error restarting mesh engine: $e', e, stack);
    }
  }

  void _refreshState() {
    if (!_initialized) return;
    final connsCount = bleManager.connectionPool.activeConnections.length;
    AppBackgroundService.updatePeerCount(connsCount);
    state = state.copyWith(
      connectedPeersCount: connsCount,
      isPeripheralActive: bleManager.isPeripheralEnabled,
      counters: meshRouter.counters,
    );
  }

  void _updatePeersList() {
    final Map<int, DevicePeer> peersMap = {};

    // 1. Add all contacts from repository
    for (final c in contactRepository.contactsNotifier.value) {
      peersMap[c.deviceId] = DevicePeer(
        deviceId: c.deviceId,
        remoteId: c.deviceHex,
        advertisedName: c.name,
        lastSeen: c.lastSeen,
        isConnected: c.isOnline,
        hopCount: c.hopCount,
      );
    }

    // 2. Add / merge live discovered BLE peers
    for (final p in peerDiscoveryManager.discoveredPeers.values) {
      final existing = peersMap[p.deviceId];
      if (existing != null) {
        existing.rssi = p.rssi;
        existing.lastSeen = p.lastSeen;
        existing.isConnected = existing.isConnected || p.isConnected;
      } else {
        peersMap[p.deviceId] = p;
      }
    }

    // 3. Mark active connections from connection pool
    for (final conn in bleManager.connectionPool.activeConnections) {
      final existing = peersMap[conn.deviceId];
      if (existing != null) {
        existing.isConnected = true;
        existing.lastSeen = DateTime.now();
      } else {
        peersMap[conn.deviceId] = DevicePeer(
          deviceId: conn.deviceId,
          remoteId: conn.remoteId,
          advertisedName: 'Node-${conn.deviceId.toRadixString(16).padLeft(8, '0')}',
          lastSeen: DateTime.now(),
          isConnected: true,
          hopCount: 1,
        );
      }
    }

    state = state.copyWith(
      discoveredPeers: peersMap.values.toList(),
      connectedPeersCount: bleManager.connectionPool.activeConnections.length,
    );
  }

  /// Ingress handler when a message arrives addressed to THIS node.
  Future<void> _handleLocalDelivery(MeshMessage message) async {
    switch (message.type) {
      case MeshMessageType.text:
        await _processInboundTextMessage(message);
        break;
      case MeshMessageType.heartbeat:
        heartbeatService.handleHeartbeat(message);
        break;
      case MeshMessageType.contactSync:
        await peerDiscoveryManager.handleContactSyncMessage(message);
        break;
      case MeshMessageType.ack:
        await _processInboundAck(message);
        break;
      default:
        AppLogger.d('Unhandled frame type: ${message.type.name}');
    }
  }

  /// Processes text chat frame, decrypts if needed, validates ECDSA signature, and saves to database.
  Future<void> _processInboundTextMessage(MeshMessage message) async {
    try {
      final jsonMap = jsonDecode(message.payloadAsString) as Map<String, dynamic>;
      String textContent = jsonMap['text'] as String? ?? '';
      final signature = jsonMap['sig'] as String?;
      final senderName = jsonMap['senderName'] as String? ?? 'Peer';

      // 1. Verify ECDSA signature if present
      final contact = contactRepository.getContact(message.senderId);
      if (signature != null && contact != null && contact.publicKey.isNotEmpty) {
        final cleartextBytes = utf8.encode(textContent);
        final isValid = await messageSigner.verify(
          data: Uint8List.fromList(cleartextBytes),
          base64Signature: signature,
          base64PublicKey: contact.publicKey,
        );
        if (!isValid) {
          AppLogger.w('Rejecting message ${message.messageId}: Invalid signature from peer ${message.senderId}');
          return;
        }
      }

      // 2. Decrypt if marked encrypted
      if (message.isEncrypted && contact != null && contact.publicKey.isNotEmpty) {
        try {
          final cipherBytes = base64Decode(textContent);
          final decrypted = await encryption.decrypt(
            encryptedData: cipherBytes,
            myKeyPair: keyManager.keyPair,
            peerPublicKeyBase64: contact.publicKey,
          );
          textContent = utf8.decode(decrypted);
        } catch (e) {
          AppLogger.w('Failed to decrypt inbound message: $e');
        }
      }

      final chatId = 'chat_${message.senderId}';
      final chatMsg = ChatMessage(
        id: message.messageId,
        chatId: chatId,
        senderId: message.senderId,
        recipientId: message.recipientId,
        text: textContent,
        timestamp: DateTime.fromMillisecondsSinceEpoch(message.timestamp * 1000),
        status: MessageStatus.delivered,
        isEncrypted: message.isEncrypted,
        hopCount: message.hopCount,
      );

      // Save message to SQLite & Hive
      await messageRepository.saveMessage(chatMsg);

      // Update Chat thread
      await chatRepository.upsertChat(
        peerId: message.senderId,
        peerName: contact?.name ?? senderName,
        lastMessage: textContent,
        timestamp: chatMsg.timestamp,
        incrementUnread: true,
      );

      // Show system notification
      NotificationService.showMessageNotification(
        id: message.messageId,
        senderName: contact?.name ?? senderName,
        messageText: textContent,
      );

      // Return delivery ACK if required
      if (message.isAckRequired) {
        _sendDeliveryAck(message.messageId, message.senderId);
      }
    } catch (e, stack) {
      AppLogger.e('Failed to process inbound text message: $e', e, stack);
    }
  }

  /// Sends a delivery ACK frame back to sender.
  Future<void> _sendDeliveryAck(int originalMsgId, int targetPeerId) async {
    final ackPayload = jsonEncode({'ackId': originalMsgId});
    final msg = MeshMessage(
      messageId: originalMsgId + 1,
      type: MeshMessageType.ack,
      ttl: MeshConstants.defaultTtl,
      flags: MeshMessage.createFlags(isAckRequired: false),
      senderId: ref.read(settingsProvider).deviceId,
      recipientId: targetPeerId,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      payload: Uint8List.fromList(utf8.encode(ackPayload)),
    );
    await meshRouter.sendOutgoingMessage(msg);
  }

  /// Handles incoming delivery ACK from peer.
  Future<void> _processInboundAck(MeshMessage message) async {
    try {
      final jsonMap = jsonDecode(message.payloadAsString) as Map<String, dynamic>;
      final originalId = jsonMap['ackId'] as int?;
      if (originalId != null) {
        await messageRepository.updateMessageStatus(originalId, MessageStatus.delivered);
        AppLogger.i('Message $originalId marked delivered via mesh ACK.');
      }
    } catch (e) {
      AppLogger.w('Failed to process incoming ACK: $e');
    }
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    bleManager.dispose();
    heartbeatService.dispose();
    peerDiscoveryManager.dispose();
    storeAndForwardManager.dispose();
    meshRouter.dispose();
    super.dispose();
  }
}

final bleProvider = StateNotifierProvider<BleNotifier, BleState>((ref) {
  return BleNotifier(ref);
});
