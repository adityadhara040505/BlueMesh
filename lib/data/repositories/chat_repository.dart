import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../core/constants.dart';
import '../local/hive_boxes.dart';
import '../models/chat.dart';
import '../../core/logger.dart';

/// Repository managing chat conversation threads.
class ChatRepository {
  final ValueNotifier<List<Chat>> chatsNotifier = ValueNotifier<List<Chat>>([]);

  ChatRepository() {
    loadChats();
  }

  /// Reload all chats from Hive storage.
  List<Chat> loadChats() {
    if (!Hive.isBoxOpen(HiveBoxKeys.chatsBox)) return [];
    final box = HiveBoxes.chatsBox;
    final List<Chat> list = [];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        try {
          list.add(Chat.fromMap(Map<String, dynamic>.from(raw)));
        } catch (e) {
          AppLogger.w('Failed to parse chat record for key: $key');
        }
      }
    }
    list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    chatsNotifier.value = list;
    return list;
  }

  /// Retrieve a specific chat thread by chatId.
  Chat? getChat(String chatId) {
    if (!Hive.isBoxOpen(HiveBoxKeys.chatsBox)) return null;
    final raw = HiveBoxes.chatsBox.get(chatId);
    if (raw == null) return null;
    return Chat.fromMap(Map<String, dynamic>.from(raw));
  }

  /// Create or update a conversation with a peer.
  Future<void> upsertChat({
    required int peerId,
    required String peerName,
    required String lastMessage,
    required DateTime timestamp,
    bool incrementUnread = false,
  }) async {
    final chatId = 'chat_$peerId';
    final existing = getChat(chatId);
    final unread = (existing?.unreadCount ?? 0) + (incrementUnread ? 1 : 0);

    final chat = Chat(
      chatId: chatId,
      peerId: peerId,
      peerName: peerName,
      lastMessage: lastMessage,
      lastMessageTime: timestamp,
      unreadCount: unread,
    );

    if (Hive.isBoxOpen(HiveBoxKeys.chatsBox)) {
      await HiveBoxes.chatsBox.put(chatId, chat.toMap());
    }
    loadChats();
  }

  /// Mark all unread messages as read for a given chat.
  Future<void> markChatAsRead(String chatId) async {
    final existing = getChat(chatId);
    if (existing != null && existing.unreadCount > 0) {
      existing.unreadCount = 0;
      if (Hive.isBoxOpen(HiveBoxKeys.chatsBox)) {
        await HiveBoxes.chatsBox.put(chatId, existing.toMap());
      }
      loadChats();
    }
  }

  /// Delete a chat thread.
  Future<void> deleteChat(String chatId) async {
    if (Hive.isBoxOpen(HiveBoxKeys.chatsBox)) {
      await HiveBoxes.chatsBox.delete(chatId);
    }
    loadChats();
  }
}
