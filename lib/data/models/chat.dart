/// Represents a peer conversation thread in the WhatsApp-style chat list.
class Chat {
  final String chatId;
  final int peerId;
  String peerName;
  String lastMessage;
  DateTime lastMessageTime;
  int unreadCount;

  Chat({
    required this.chatId,
    required this.peerId,
    required this.peerName,
    this.lastMessage = '',
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  Chat copyWith({
    String? chatId,
    int? peerId,
    String? peerName,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return Chat(
      chatId: chatId ?? this.chatId,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'peerId': peerId,
      'peerName': peerName,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      chatId: map['chatId'] as String,
      peerId: map['peerId'] as int,
      peerName: map['peerName'] as String,
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageTime: DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'] as int),
      unreadCount: map['unreadCount'] as int? ?? 0,
    );
  }
}
