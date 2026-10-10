import 'package:flutter_test/flutter_test.dart';
import 'package:blue_mesh/data/models/chat.dart';
import 'package:blue_mesh/data/models/chat_message.dart';
import 'package:blue_mesh/data/models/contact.dart';
import 'package:blue_mesh/data/models/device_peer.dart';
import 'package:blue_mesh/data/models/mesh_message.dart';
import 'dart:typed_data';

void main() {
  group('Data Models Tests', () {
    test('ChatMessage serialization toMap and fromMap roundtrip', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 12345,
        chatId: 'chat_1',
        senderId: 100,
        recipientId: 200,
        text: 'Hello Mesh!',
        timestamp: now,
        status: MessageStatus.delivered,
        isEncrypted: true,
        hopCount: 2,
        synced: true,
      );

      final map = msg.toMap();
      expect(map['id'], 12345);
      expect(map['status'], 'delivered');
      expect(map['isEncrypted'], 1);

      final restored = ChatMessage.fromMap(map);
      expect(restored.id, msg.id);
      expect(restored.text, msg.text);
      expect(restored.status, MessageStatus.delivered);
      expect(restored.isEncrypted, true);
      expect(restored.synced, true);
      expect(restored.isOutgoing(100), true);
      expect(restored.isOutgoing(200), false);
    });

    test('ChatMessage SQLite serialization roundtrip', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 999,
        chatId: 'chat_999',
        senderId: 50,
        recipientId: 60,
        text: 'SQLite test',
        timestamp: now,
        status: MessageStatus.sent,
      );

      final sqliteMap = msg.toSqlite();
      expect(sqliteMap['id'], 999);
      expect(sqliteMap['chat_id'], 'chat_999');

      final fromSqlite = ChatMessage.fromSqlite(sqliteMap);
      expect(fromSqlite.id, 999);
      expect(fromSqlite.status, MessageStatus.sent);
    });

    test('ChatMessage copyWith works correctly', () {
      final msg = ChatMessage(
        id: 1,
        chatId: 'c1',
        senderId: 10,
        recipientId: 20,
        text: 'original',
        timestamp: DateTime.now(),
      );

      final updated = msg.copyWith(
        text: 'modified',
        status: MessageStatus.read,
      );

      expect(updated.text, 'modified');
      expect(updated.status, MessageStatus.read);
      expect(updated.id, 1);
    });

    test('Contact serialization and copyWith', () {
      final now = DateTime.now();
      final contact = Contact(
        deviceId: 0xA1B2C3D4,
        name: 'Alice',
        publicKey: 'pubKeyBase64==',
        fingerprint: 'A1B2C3D4',
        lastSeen: now,
        isOnline: true,
        batteryLevel: 85,
        hopCount: 1,
        isVerified: true,
      );

      expect(contact.deviceHex, 'a1b2c3d4');

      final map = contact.toMap();
      expect(map['name'], 'Alice');

      final restored = Contact.fromMap(map);
      expect(restored.deviceId, contact.deviceId);
      expect(restored.name, 'Alice');
      expect(restored.isVerified, true);

      final copy = contact.copyWith(name: 'Alice Cooper', batteryLevel: 90);
      expect(copy.name, 'Alice Cooper');
      expect(copy.batteryLevel, 90);
    });

    test('DevicePeer attributes and copyWith', () {
      final peer = DevicePeer(
        deviceId: 0x12345678,
        remoteId: 'AA:BB:CC:DD:EE:FF',
        advertisedName: 'Node-1',
        lastSeen: DateTime.now(),
        rssi: -65,
        hopCount: 1,
        isConnected: true,
        connectionRole: PeerConnectionRole.outboundCentral,
        state: PeerState.active,
      );

      expect(peer.shortId, '123456');

      final copy = peer.copyWith(rssi: -50, isConnected: false);
      expect(copy.rssi, -50);
      expect(copy.isConnected, false);
      expect(copy.advertisedName, 'Node-1');
    });

    test('MeshMessage binary roundtrip and flags', () {
      final msg = MeshMessage(
        messageId: 0x55667788,
        type: MeshMessageType.text,
        senderId: 10,
        recipientId: 20,
        flags: MeshMessage.createFlags(isEncrypted: true, isAckRequired: true),
        timestamp: 1700000000,
        ttl: 5,
        hopCount: 1,
        payload: Uint8List.fromList([1, 2, 3, 4, 5]),
      );

      final bytes = msg.toBytes();
      final restored = MeshMessage.fromBytes(bytes);

      expect(restored.messageId, 0x55667788);
      expect(restored.ttl, 5);
      expect(restored.hopCount, 1);
      expect(restored.isBroadcast, false);
      expect(restored.isEncrypted, true);
      expect(restored.isAckRequired, true);
      expect(restored.payload, msg.payload);
    });

    test('Chat model serialization toMap/fromMap and copyWith', () {
      final now = DateTime.now();
      final chat = Chat(
        chatId: 'chat_alice',
        peerId: 0x1234,
        peerName: 'Alice',
        lastMessage: 'Hey there',
        lastMessageTime: now,
        unreadCount: 2,
      );

      final map = chat.toMap();
      expect(map['chatId'], 'chat_alice');
      expect(map['unreadCount'], 2);

      final restored = Chat.fromMap(map);
      expect(restored.chatId, 'chat_alice');
      expect(restored.peerName, 'Alice');
      expect(restored.lastMessage, 'Hey there');
      expect(restored.unreadCount, 2);

      final copy = chat.copyWith(unreadCount: 0, lastMessage: 'All caught up');
      expect(copy.unreadCount, 0);
      expect(copy.lastMessage, 'All caught up');
      expect(copy.peerName, 'Alice');
    });
  });
}
