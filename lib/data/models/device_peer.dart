/// Connection role of the peer relative to this device.
enum PeerConnectionRole {
  outboundCentral, // We connected to them via Central GATT client
  inboundPeripheral, // They connected to us via our GATT server
  meshRelay, // Indirect peer reachable via multi-hop
}

/// Mesh peer lifecycle state machine.
/// discovered → handshaking → active → idle → stale → removed
enum PeerState {
  discovered,
  handshaking,
  active,
  idle,
  stale,
  removed,
}

/// Represents a peer node in the local Bluetooth environment or mesh cluster.
class DevicePeer {
  final int deviceId;
  final String remoteId; // BLE hardware address or CoreBluetooth identifier
  final String advertisedName;
  int rssi;
  int hopCount;
  DateTime lastSeen;
  bool isConnected;
  PeerConnectionRole connectionRole;
  int mtu;
  PeerState state;

  DevicePeer({
    required this.deviceId,
    required this.remoteId,
    required this.advertisedName,
    this.rssi = -70,
    this.hopCount = 1,
    required this.lastSeen,
    this.isConnected = false,
    this.connectionRole = PeerConnectionRole.outboundCentral,
    this.mtu = 23,
    this.state = PeerState.discovered,
  });

  /// Short display identifier.
  String get shortId => deviceId.toRadixString(16).padLeft(8, '0').substring(0, 6);

  DevicePeer copyWith({
    int? deviceId,
    String? remoteId,
    String? advertisedName,
    int? rssi,
    int? hopCount,
    DateTime? lastSeen,
    bool? isConnected,
    PeerConnectionRole? connectionRole,
    int? mtu,
    PeerState? state,
  }) {
    return DevicePeer(
      deviceId: deviceId ?? this.deviceId,
      remoteId: remoteId ?? this.remoteId,
      advertisedName: advertisedName ?? this.advertisedName,
      rssi: rssi ?? this.rssi,
      hopCount: hopCount ?? this.hopCount,
      lastSeen: lastSeen ?? this.lastSeen,
      isConnected: isConnected ?? this.isConnected,
      connectionRole: connectionRole ?? this.connectionRole,
      mtu: mtu ?? this.mtu,
      state: state ?? this.state,
    );
  }
}
