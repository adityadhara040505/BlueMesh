import 'dart:convert';
import 'dart:typed_data';
import 'package:blue_mesh/data/models/mesh_message.dart';
import 'package:blue_mesh/utils/encoding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Wire Protocol & Encoding Tests', () {
    test('MeshMessage binary roundtrip preserves all 24 header bytes and payload', () {
      final payloadBytes = Uint8List.fromList(utf8.encode('{"hello":"mesh"}'));

      final original = MeshMessage(
        messageId: 0xDEADBEEF,
        type: MeshMessageType.text,
        ttl: 5,
        hopCount: 2,
        flags: MeshMessage.createFlags(isEncrypted: true, isAckRequired: true),
        senderId: 0x11223344,
        recipientId: 0x55667788,
        timestamp: 1700000000,
        payload: payloadBytes,
      );

      final bytes = original.toBytes();
      expect(bytes.length, 24 + payloadBytes.length);

      final decoded = MeshMessage.fromBytes(bytes);
      expect(decoded.messageId, equals(original.messageId));
      expect(decoded.type, equals(MeshMessageType.text));
      expect(decoded.ttl, equals(5));
      expect(decoded.hopCount, equals(2));
      expect(decoded.isEncrypted, isTrue);
      expect(decoded.isAckRequired, isTrue);
      expect(decoded.senderId, equals(original.senderId));
      expect(decoded.recipientId, equals(original.recipientId));
      expect(decoded.timestamp, equals(original.timestamp));
      expect(decoded.payloadAsString, equals('{"hello":"mesh"}'));
    });

    test('FNV-1a 32-bit hashing produces consistent positive hash', () {
      final h1 = ProtocolEncoding.hashUuid('uuid-device-1234');
      final h2 = ProtocolEncoding.hashUuid('uuid-device-1234');
      final h3 = ProtocolEncoding.hashUuid('different-uuid');

      expect(h1, equals(h2));
      expect(h1, isNot(equals(h3)));
      expect(h1, greaterThanOrEqualTo(0));
    });

    test('Hex string and byte array roundtrip', () {
      final originalBytes = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]);
      final hex = ProtocolEncoding.bytesToHex(originalBytes);
      expect(hex.toLowerCase(), 'deadbeef');

      final reconstructed = ProtocolEncoding.hexToBytes(hex);
      expect(reconstructed, equals(originalBytes));
    });
  });
}
