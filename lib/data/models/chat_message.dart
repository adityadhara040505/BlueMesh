/// Message delivery and read state for UI ticks.
enum MessageStatus {
  queued,
  sending,
  sent, // ✓ sent
  delivered, // ✓✓ delivered
  read, // ✓✓ blue = read
  failed; // ⚠️ failed

  static MessageStatus fromString(String status) {
    return MessageStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => MessageStatus.queued,
    );
  }
}

/// A single chat message stored locally and displayed in the conversation thread.
class ChatMessage {
  final int id; // uint32 messageId
  final String chatId;
  final int senderId;
  final int recipientId;
  final String text;
  final DateTime timestamp;
  MessageStatus status;
  final bool isEncrypted;
  final int hopCount;
  final bool synced;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.queued,
    this.isEncrypted = false,
    this.hopCount = 0,
    this.synced = false,
  });

  bool isOutgoing(int myDeviceId) => senderId == myDeviceId;

  ChatMessage copyWith({
    int? id,
    String? chatId,
    int? senderId,
    int? recipientId,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isEncrypted,
    int? hopCount,
    bool? synced,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      hopCount: hopCount ?? this.hopCount,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'recipientId': recipientId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
      'isEncrypted': isEncrypted ? 1 : 0,
      'hopCount': hopCount,
      'synced': synced ? 1 : 0,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int,
      chatId: map['chatId'] as String,
      senderId: map['senderId'] as int,
      recipientId: map['recipientId'] as int,
      text: map['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      status: MessageStatus.fromString(map['status'] as String),
      isEncrypted: (map['isEncrypted'] as int? ?? 0) == 1,
      hopCount: map['hopCount'] as int? ?? 0,
      synced: (map['synced'] as int? ?? 0) == 1,
    );
  }

  /// SQLite column mapping
  Map<String, dynamic> toSqlite() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
      'is_encrypted': isEncrypted ? 1 : 0,
      'hop_count': hopCount,
      'synced': synced ? 1 : 0,
    };
  }

  factory ChatMessage.fromSqlite(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int,
      chatId: map['chat_id'] as String,
      senderId: map['sender_id'] as int,
      recipientId: map['recipient_id'] as int? ?? 0,
      text: map['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      status: MessageStatus.fromString(map['status'] as String),
      isEncrypted: (map['is_encrypted'] as int? ?? 0) == 1,
      hopCount: map['hop_count'] as int? ?? 0,
      synced: (map['synced'] as int? ?? 0) == 1,
    );
  }
}
