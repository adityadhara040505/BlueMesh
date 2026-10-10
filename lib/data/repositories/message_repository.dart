import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants.dart';
import '../local/sqflite_database.dart';
import '../local/hive_boxes.dart';
import '../models/chat_message.dart';
import '../../core/logger.dart';

/// Repository managing chat messages with SQLite storage and full-text search.
class MessageRepository {
  final Map<String, ValueNotifier<List<ChatMessage>>> _chatNotifiers = {};

  /// Retrieve a reactive ValueNotifier for a specific conversation.
  ValueNotifier<List<ChatMessage>> getNotifierForChat(String chatId) {
    if (!_chatNotifiers.containsKey(chatId)) {
      _chatNotifiers[chatId] = ValueNotifier<List<ChatMessage>>([]);
      loadMessagesForChat(chatId);
    }
    return _chatNotifiers[chatId]!;
  }

  /// Load historical messages for a chat from SQLite.
  Future<List<ChatMessage>> loadMessagesForChat(String chatId) async {
    try {
      final db = await AppDatabase.instance;
      final results = await db.query(
        'messages',
        where: 'chat_id = ?',
        whereArgs: [chatId],
        orderBy: 'timestamp ASC',
      );

      final messages = results.map((e) => ChatMessage.fromSqlite(e)).toList();
      _chatNotifiers[chatId]?.value = messages;
      return messages;
    } catch (e, stack) {
      AppLogger.e('Failed to load messages for chat $chatId: $e', e, stack);
      return [];
    }
  }

  /// Insert a new message into SQLite and update fast-lookup Hive.
  Future<void> saveMessage(ChatMessage message) async {
    try {
      final db = await AppDatabase.instance;
      await db.insert(
        'messages',
        message.toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Fast lookup key in Hive
      if (Hive.isBoxOpen(HiveBoxKeys.messagesBox)) {
        await HiveBoxes.messagesBox.put(message.id.toString(), message.toMap());
      }

      await loadMessagesForChat(message.chatId);
    } catch (e, stack) {
      AppLogger.e('Failed to save message ${message.id}: $e', e, stack);
    }
  }

  /// Update the status of an existing message (e.g. sent, delivered, read).
  Future<void> updateMessageStatus(int messageId, MessageStatus status) async {
    try {
      final db = await AppDatabase.instance;
      await db.update(
        'messages',
        {'status': status.name},
        where: 'id = ?',
        whereArgs: [messageId],
      );

      if (Hive.isBoxOpen(HiveBoxKeys.messagesBox)) {
        final rawHive = HiveBoxes.messagesBox.get(messageId.toString());
        if (rawHive != null) {
          final msg = ChatMessage.fromMap(Map<String, dynamic>.from(rawHive));
          msg.status = status;
          await HiveBoxes.messagesBox.put(messageId.toString(), msg.toMap());
          await loadMessagesForChat(msg.chatId);
        }
      }
    } catch (e, stack) {
      AppLogger.e('Failed to update message status for $messageId: $e', e, stack);
    }
  }

  /// Perform offline full-text search across messages using FTS5 virtual table.
  Future<List<ChatMessage>> searchMessages(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final db = await AppDatabase.instance;
      // Sanitize input for FTS5 syntax
      final sanitized = query.replaceAll('"', '""');
      final results = await db.rawQuery('''
        SELECT m.* FROM messages m
        JOIN messages_fts fts ON m.id = fts.rowid
        WHERE messages_fts MATCH ?
        ORDER BY m.timestamp DESC
      ''', ['"$sanitized"*']);

      return results.map((e) => ChatMessage.fromSqlite(e)).toList();
    } catch (e, stack) {
      AppLogger.w('FTS5 search failed, falling back to LIKE query: $e', e, stack);
      // Graceful fallback to standard LIKE query
      final db = await AppDatabase.instance;
      final results = await db.query(
        'messages',
        where: 'text LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'timestamp DESC',
      );
      return results.map((e) => ChatMessage.fromSqlite(e)).toList();
    }
  }

  /// Delete a single message.
  Future<void> deleteMessage(int messageId, String chatId) async {
    try {
      final db = await AppDatabase.instance;
      await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
      if (Hive.isBoxOpen(HiveBoxKeys.messagesBox)) {
        await HiveBoxes.messagesBox.delete(messageId.toString());
      }
      await loadMessagesForChat(chatId);
    } catch (e, stack) {
      AppLogger.e('Failed to delete message $messageId: $e', e, stack);
    }
  }
}
