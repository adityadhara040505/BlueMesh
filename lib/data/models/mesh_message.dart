import 'dart:convert';
import 'dart:typed_data';
import '../../core/constants.dart';

/// Types of frames supported in the BlueMesh wire protocol.
enum MeshMessageType {
  text(0),
  ping(1),
  ack(2),
  contactSync(3),
  heartbeat(4),
  routingUpdate(5),
  keyExchange(6);

  final int value;
  const MeshMessageType(this.value);

  static MeshMessageType fromValue(int val) {
    return MeshMessageType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => MeshMessageType.text,
    );
  }
}

/// In-memory and wire-protocol representation of a BlueMesh message frame.
/// Follows the 24-byte little-endian header specification.
class MeshMessage {
  final int messageId; // uint32 (FNV-1a hash of UUID)
  final MeshMessageType type; // uint8
  int ttl; // uint8 (Time To Live)
  int hopCount; // uint8
  final int flags; // uint8 (bit0=encrypted, bit1=broadcast, bit2=ack_required)
  final int senderId; // uint32
  final int recipientId; // uint32 (0 = broadcast)
  final int timestamp; // uint32 (Unix epoch seconds)
  final Uint8List payload; // UTF-8 JSON / ciphertext

  MeshMessage({
    required this.messageId,
    required this.type,
    this.ttl = MeshConstants.defaultTtl,
    this.hopCount = 0,
    required this.flags,
    required this.senderId,
    this.recipientId = 0,
    required this.timestamp,
    required this.payload,
  });

  /// Bit 0: Encrypted payload.
  bool get isEncrypted => (flags & 0x01) != 0;

  /// Bit 1: Broadcast to all nodes.
  bool get isBroadcast => (flags & 0x02) != 0 || recipientId == 0;

  /// Bit 2: Delivery ACK requested.
  bool get isAckRequired => (flags & 0x04) != 0;

  /// Constructs a bitmask integer for flags.
  static int createFlags({
    bool isEncrypted = false,
    bool isBroadcast = false,
    bool isAckRequired = false,
  }) {
    int f = 0;
    if (isEncrypted) f |= 0x01;
    if (isBroadcast) f |= 0x02;
    if (isAckRequired) f |= 0x04;
    return f;
  }

  /// Encodes this message frame into binary format (little-endian 24-byte header + payload).
  Uint8List toBytes() {
    final payloadBytes = payload;
    final totalLen = MeshConstants.wireHeaderLength + payloadBytes.length;
    final data = Uint8List(totalLen);
    final byteData = ByteData.sublistView(data);

    // Offset 0: Message ID (uint32)
    byteData.setUint32(0, messageId, Endian.little);
    // Offset 4: Type (uint8)
    byteData.setUint8(4, type.value);
    // Offset 5: TTL (uint8)
    byteData.setUint8(5, ttl);
    // Offset 6: Hop Count (uint8)
    byteData.setUint8(6, hopCount);
    // Offset 7: Flags (uint8)
    byteData.setUint8(7, flags);
    // Offset 8: Sender ID (uint32)
    byteData.setUint32(8, senderId, Endian.little);
    // Offset 12: Recipient ID (uint32)
    byteData.setUint32(12, recipientId, Endian.little);
    // Offset 16: Timestamp (uint32)
    byteData.setUint32(16, timestamp, Endian.little);
    // Offset 20: Payload Length (uint32)
    byteData.setUint32(20, payloadBytes.length, Endian.little);

    // Offset 24: Payload
    data.setRange(MeshConstants.wireHeaderLength, totalLen, payloadBytes);
    return data;
  }

  /// Decodes a binary frame into a [MeshMessage].
  static MeshMessage fromBytes(Uint8List bytes) {
    if (bytes.length < MeshConstants.wireHeaderLength) {
      throw FormatException('Frame length ${bytes.length} is shorter than wire header 24 bytes');
    }

    final byteData = ByteData.sublistView(bytes);
    final msgId = byteData.getUint32(0, Endian.little);
    final typeVal = byteData.getUint8(4);
    final ttlVal = byteData.getUint8(5);
    final hopsVal = byteData.getUint8(6);
    final flagsVal = byteData.getUint8(7);
    final sender = byteData.getUint32(8, Endian.little);
    final recipient = byteData.getUint32(12, Endian.little);
    final timeVal = byteData.getUint32(16, Endian.little);
    final payloadLen = byteData.getUint32(20, Endian.little);

    if (bytes.length < MeshConstants.wireHeaderLength + payloadLen) {
      throw FormatException('Incomplete frame: expected ${MeshConstants.wireHeaderLength + payloadLen} bytes, got ${bytes.length}');
    }

    final payloadData = bytes.sublist(
      MeshConstants.wireHeaderLength,
      MeshConstants.wireHeaderLength + payloadLen,
    );

    return MeshMessage(
      messageId: msgId,
      type: MeshMessageType.fromValue(typeVal),
      ttl: ttlVal,
      hopCount: hopsVal,
      flags: flagsVal,
      senderId: sender,
      recipientId: recipient,
      timestamp: timeVal,
      payload: payloadData,
    );
  }

  /// Helper to decode payload as UTF-8 string.
  String get payloadAsString => utf8.decode(payload, allowMalformed: true);

  /// Map serialization for Hive / JSON.
  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'type': type.value,
      'ttl': ttl,
      'hopCount': hopCount,
      'flags': flags,
      'senderId': senderId,
      'recipientId': recipientId,
      'timestamp': timestamp,
      'payload': base64Encode(payload),
    };
  }

  factory MeshMessage.fromMap(Map<String, dynamic> map) {
    return MeshMessage(
      messageId: map['messageId'] as int,
      type: MeshMessageType.fromValue(map['type'] as int),
      ttl: map['ttl'] as int,
      hopCount: map['hopCount'] as int,
      flags: map['flags'] as int,
      senderId: map['senderId'] as int,
      recipientId: map['recipientId'] as int,
      timestamp: map['timestamp'] as int,
      payload: base64Decode(map['payload'] as String),
    );
  }
}
