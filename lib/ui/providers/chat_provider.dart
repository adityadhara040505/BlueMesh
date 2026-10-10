import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/logger.dart';
import '../../data/models/chat.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/mesh_message.dart';
import '../../utils/encoding.dart';
import 'ble_provider.dart';
import 'settings_provider.dart';

/// Provider of all active chat conversation threads.
final chatsListProvider = StreamProvider<List<Chat>>((ref) async* {
  final bleNotifier = ref.watch(bleProvider.notifier);
  final repo = bleNotifier.chatRepository;

  yield repo.loadChats();

  final stream = Stream<List<Chat>>.periodic(
    const Duration(seconds: 1),
    (_) => repo.chatsNotifier.value,
  );
  yield* stream;
});

/// Family provider yielding real-time messages for an open conversation thread.
final chatMessagesFamily =
    StreamProvider.family<List<ChatMessage>, String>((ref, chatId) async* {
  final bleNotifier = ref.watch(bleProvider.notifier);
  final repo = bleNotifier.messageRepository;

  final initial = await repo.loadMessagesForChat(chatId);
  yield initial;

  final notifier = repo.getNotifierForChat(chatId);
  final stream = Stream<List<ChatMessage>>.periodic(
    const Duration(milliseconds: 500),
    (_) => notifier.value,
  );
  yield* stream;
});

/// Message sending actions and orchestrations.
class ChatActions {
  final Ref ref;
  ChatActions(this.ref);

  /// Authors, signs, encrypts, and transmits a new chat message over the BLE mesh.
  Future<bool> sendMessage({
    required int recipientPeerId,
    required String peerName,
    required String text,
    bool enableEncryption = false,
  }) async {
    final bleNotifier = ref.read(bleProvider.notifier);
    final settings = ref.read(settingsProvider);
    final myDeviceId = settings.deviceId;

    final msgId = ProtocolEncoding.hashUuid(
      'msg_${DateTime.now().microsecondsSinceEpoch}_$myDeviceId',
    );
    final chatId = 'chat_$recipientPeerId';
    final now = DateTime.now();

    // 1. Initial Local ChatMessage record (status: sending)
    final localMsg = ChatMessage(
      id: msgId,
      chatId: chatId,
      senderId: myDeviceId,
      recipientId: recipientPeerId,
      text: text,
      timestamp: now,
      status: MessageStatus.sending,
      isEncrypted: enableEncryption,
      hopCount: 0,
    );

    await bleNotifier.messageRepository.saveMessage(localMsg);
    await bleNotifier.chatRepository.upsertChat(
      peerId: recipientPeerId,
      peerName: peerName,
      lastMessage: text,
      timestamp: now,
    );

    try {
      // 2. Sign cleartext payload with ECDSA
      final cleartextBytes = Uint8List.fromList(utf8.encode(text));
      final signature = await bleNotifier.messageSigner.sign(
        cleartextBytes,
        bleNotifier.keyManager.keyPair,
      );

      // 3. Encrypt payload if requested and peer public key is known
      String payloadText = text;
      final contact = bleNotifier.contactRepository.getContact(recipientPeerId);
      if (enableEncryption && contact != null && contact.publicKey.isNotEmpty) {
        final cipherBytes = await bleNotifier.encryption.encrypt(
          cleartext: cleartextBytes,
          myKeyPair: bleNotifier.keyManager.keyPair,
          peerPublicKeyBase64: contact.publicKey,
        );
        payloadText = base64Encode(cipherBytes);
      }

      // 4. Wrap in wire JSON payload
      final wirePayload = {
        'text': payloadText,
        'sig': signature,
        'senderName': settings.displayName,
      };

      final payloadBytes = utf8.encode(jsonEncode(wirePayload));

      // 5. Construct binary mesh message frame
      final meshMessage = MeshMessage(
        messageId: msgId,
        type: MeshMessageType.text,
        ttl: settings.meshTtl,
        hopCount: 0,
        flags: MeshMessage.createFlags(
          isEncrypted: enableEncryption,
          isBroadcast: false,
          isAckRequired: true,
        ),
        senderId: myDeviceId,
        recipientId: recipientPeerId,
        timestamp: now.millisecondsSinceEpoch ~/ 1000,
        payload: Uint8List.fromList(payloadBytes),
      );

      // 6. Transmit via Mesh Router
      final sent = await bleNotifier.meshRouter.sendOutgoingMessage(meshMessage);

      if (sent) {
        await bleNotifier.messageRepository.updateMessageStatus(msgId, MessageStatus.sent);
        return true;
      } else {
        // Enqueue into Store-and-Forward if peer is currently offline
        bleNotifier.storeAndForwardManager.enqueue(meshMessage);
        await bleNotifier.messageRepository.updateMessageStatus(msgId, MessageStatus.queued);
        AppLogger.i('Peer $recipientPeerId offline: queued message $msgId for store-and-forward.');
        return true;
      }
    } catch (e, stack) {
      AppLogger.e('Failed to transmit message: $e', e, stack);
      await bleNotifier.messageRepository.updateMessageStatus(msgId, MessageStatus.failed);
      return false;
    }
  }

  /// Resends a previously failed or queued message.
  Future<void> resendMessage(ChatMessage message, String peerName) async {
    await sendMessage(
      recipientPeerId: message.recipientId,
      peerName: peerName,
      text: message.text,
      enableEncryption: message.isEncrypted,
    );
  }
}

final chatActionsProvider = Provider<ChatActions>((ref) {
  return ChatActions(ref);
});
