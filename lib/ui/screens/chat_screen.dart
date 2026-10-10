import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/models/chat_message.dart';
import '../../utils/validators.dart';
import '../providers/ble_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../widgets/connection_banner.dart';
import '../widgets/message_bubble.dart';

/// Conversation thread screen with WhatsApp-style bubbles, status ticks, and end-to-end encryption.
class ChatScreen extends ConsumerStatefulWidget {
  final int peerId;
  final String peerName;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _enableEncryption = true;

  @override
  void initState() {
    super.initState();
    // Mark conversation thread as read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bleNotifier = ref.read(bleProvider.notifier);
      bleNotifier.chatRepository.markChatAsRead('chat_${widget.peerId}');
    });
  }

  Future<void> _sendMessage(String receiverName) async {
    final text = _textController.text.trim();
    final validation = InputValidators.validateMessageText(text);
    if (validation != null) return;

    _textController.clear();

    await ref.read(chatActionsProvider).sendMessage(
      recipientPeerId: widget.peerId,
      peerName: receiverName,
      text: text,
      enableEncryption: _enableEncryption,
    );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatId = 'chat_${widget.peerId}';
    final messagesAsync = ref.watch(chatMessagesFamily(chatId));
    final contacts = ref.watch(filteredContactsProvider);

    final contact = contacts.cast<dynamic>().firstWhere(
      (c) => c.deviceId == widget.peerId,
      orElse: () => null,
    );
    final isOnline = contact?.isOnline ?? false;
    final receiverName = (contact != null && contact.name.isNotEmpty) ? contact.name : widget.peerName;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryDark.withOpacity(0.35),
              child: Text(
                receiverName.isNotEmpty ? receiverName[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          receiverName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'RECEIVER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isOnline ? 'Online in cluster' : 'Offline (Queued)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOnline ? AppColors.onlineGreen : AppColors.offlineGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _enableEncryption ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: _enableEncryption ? AppColors.accentCyan : AppColors.offlineGrey,
            ),
            tooltip: _enableEncryption ? 'End-to-End Encryption ON' : 'Encryption OFF',
            onPressed: () {
              setState(() => _enableEncryption = !_enableEncryption);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_enableEncryption ? 'Encryption enabled (AES-256-GCM)' : 'Encryption disabled'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Store-and-forward indicator if peer is offline
          ConnectionBanner(isOnline: isOnline, peerName: receiverName),

          // Conversation messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages with $receiverName yet.\nType below to start peer-to-peer chat.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.offlineGrey, fontSize: 13),
                    ),
                  );
                }

                final myId = ref.watch(settingsProvider).deviceId;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return MessageBubble(
                      message: msg,
                      isOutgoing: msg.isOutgoing(myId),
                      onResend: () => ref.read(chatActionsProvider).resendMessage(msg, receiverName),
                      onDelete: () async {
                        final bleNotifier = ref.read(bleProvider.notifier);
                        await bleNotifier.messageRepository.deleteMessage(msg.id, chatId);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading messages: $e')),
            ),
          ),

          // Bottom message composer with prominent receiver name indicator
          _buildInputBar(receiverName, isOnline),
        ],
      ),
    );
  }

  Widget _buildInputBar(String receiverName, bool isOnline) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              color: AppColors.primaryDark.withOpacity(0.2),
              child: Row(
                children: [
                  Icon(
                    _enableEncryption ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                    size: 13,
                    color: _enableEncryption ? AppColors.accentCyan : AppColors.offlineGrey,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'To: ',
                    style: TextStyle(fontSize: 11, color: AppColors.offlineGrey),
                  ),
                  Expanded(
                    child: Text(
                      receiverName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.onlineGreen : AppColors.offlineGrey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isOnline ? 'Online' : 'Queued',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isOnline ? AppColors.onlineGreen : AppColors.offlineGrey,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLength: MeshConstants.maxTextMessageLength,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(receiverName),
                      decoration: InputDecoration(
                        hintText: 'Message to $receiverName...',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(receiverName),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
