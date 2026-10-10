/// Application-wide constants for BlueMesh BLE and Mesh protocol.
library;

/// BlueMesh Core Protocol Constants
class BleConstants {
  BleConstants._();

  /// Primary 128-bit GATT Service UUID identifying a BlueMesh node.
  static const String serviceUuid = '0000ffff-0000-1000-8000-00805f9b34fb';

  /// TX Characteristic UUID (Central writes messages to Peripheral without response).
  static const String txCharacteristicUuid = '0000ff01-0000-1000-8000-00805f9b34fb';

  /// RX Characteristic UUID (Peripheral pushes notifications/messages to Central).
  static const String rxCharacteristicUuid = '0000ff02-0000-1000-8000-00805f9b34fb';

  /// CONTACT Characteristic UUID (Bidirectional contact card JSON exchange).
  static const String contactCharacteristicUuid = '0000ff03-0000-1000-8000-00805f9b34fb';

  /// HEARTBEAT Characteristic UUID (Peripheral emits periodic presence pings).
  static const String heartbeatCharacteristicUuid = '0000ff04-0000-1000-8000-00805f9b34fb';

  /// ROUTING Characteristic UUID (Exchange distance-vector routing table).
  static const String routingCharacteristicUuid = '0000ff05-0000-1000-8000-00805f9b34fb';

  /// BlueMesh device name prefix used for BLE discovery filtering.
  static const String advertisedNamePrefix = 'BlueMesh-';

  /// Maximum simultaneous outbound Central connections.
  /// We cap this at 4 to prevent radio starvation and high latency on mobile BLE chips.
  static const int maxOutboundConnections = 4;

  /// Maximum simultaneous inbound Peripheral connections.
  /// Android BLE hardware stack limit is typically 7 simultaneous connections.
  static const int maxInboundConnections = 7;

  /// Central duty-cycle scan window duration.
  static const Duration scanDuration = Duration(seconds: 3);

  /// Central duty-cycle idle duration between active scans (reduces battery drain).
  static const Duration scanPauseDuration = Duration(seconds: 2);

  /// Maximum reconnection backoff delay for an unresponsive peer.
  static const Duration maxReconnectBackoff = Duration(seconds: 32);

  /// Default MTU sizes by platform before negotiation.
  static const int defaultMtuAndroid = 517;
  static const int defaultMtuIos = 185;
  static const int defaultMtuDesktop = 512;
  static const int defaultMtuFallback = 23;

  /// ATT protocol overhead bytes (Opcode 1 byte + Attribute Handle 2 bytes).
  static const int attOverhead = 3;

  /// Custom BlueMesh fragmentation header length:
  /// [msgId: 4 bytes] + [seq: 1 byte] + [total: 1 byte] = 6 bytes.
  static const int fragmentationHeaderSize = 6;
}

/// Mesh Network Routing & Protocol Constants
class MeshConstants {
  MeshConstants._();

  /// Default Time-To-Live for flooded mesh frames.
  static const int defaultTtl = 5;

  /// Minimum allowed TTL in user settings.
  static const int minTtl = 3;

  /// Maximum allowed TTL in user settings.
  static const int maxTtl = 10;

  /// Interval between periodic node heartbeat pings.
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// Time after which a peer is marked offline if no heartbeat was received.
  static const Duration peerOfflineThreshold = Duration(seconds: 30);

  /// Time after which an inactive peer is pruned from the cluster state.
  static const Duration peerPruneThreshold = Duration(minutes: 5);

  /// Lifetime of a dynamic routing table entry before requiring refresh.
  static const Duration routingEntryTtl = Duration(seconds: 60);

  /// Maximum capacity of the LRU deduplication cache for message IDs.
  static const int dedupCacheCapacity = 5000;

  /// Maximum queued store-and-forward messages per offline destination node.
  static const int maxStoreAndForwardPerPeer = 100;

  /// Expiration duration for queued store-and-forward messages.
  static const Duration storeAndForwardMessageTtl = Duration(hours: 24);

  /// Reassembly buffer expiry for incomplete multi-fragment packets.
  static const Duration reassemblyTimeout = Duration(seconds: 30);

  /// Wire protocol frame header length in bytes (unfragmented binary frame).
  static const int wireHeaderLength = 24;

  /// Maximum chat text character count to keep single frames lightweight.
  static const int maxTextMessageLength = 500;
}

/// Hive Box Identifier Strings
class HiveBoxKeys {
  HiveBoxKeys._();

  static const String contactsBox = 'contacts_box';
  static const String chatsBox = 'chats_box';
  static const String messagesBox = 'messages_box';
  static const String settingsBox = 'settings_box';
  static const String dedupCacheBox = 'dedup_cache_box';
  static const String routingTableBox = 'routing_table_box';
}
