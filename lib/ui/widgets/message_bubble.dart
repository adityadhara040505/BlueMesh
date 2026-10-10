import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/chat_message.dart';
import '../../utils/time_ago.dart';
import '../theme/colors.dart';

/// WhatsApp-style chat message bubble with encryption lock and status ticks.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOutgoing;
  final VoidCallback? onResend;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOutgoing,
    this.onResend,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bubbleBg = isOutgoing
        ? (isDark ? AppColors.outgoingBubbleDark : AppColors.outgoingBubbleLight)
        : (isDark ? AppColors.incomingBubbleDark : AppColors.incomingBubbleLight);

    final textColor = isOutgoing
        ? (isDark ? Colors.white : AppColors.textPrimaryLight)
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bubbleBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
              bottomRight: Radius.circular(isOutgoing ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (message.isEncrypted) ...[
                    Icon(
                      Icons.lock_rounded,
                      size: 13,
                      color: isDark ? AppColors.accentCyan : AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    TimeAgo.formatTimeOnly(message.timestamp),
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      fontSize: 11,
                    ),
                  ),
                  if (isOutgoing) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds delivery status ticks:
  /// - queued: clock
  /// - sending: single grey tick
  /// - sent: single tick (✓)
  /// - delivered: double tick (✓✓)
  /// - read: double blue tick (✓✓ blue)
  /// - failed: red error warning
  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.queued:
        return const Icon(Icons.access_time_rounded, size: 14, color: AppColors.offlineGrey);
      case MessageStatus.sending:
        return const Icon(Icons.check, size: 14, color: AppColors.deliveredGrey);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: AppColors.deliveredGrey);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: AppColors.deliveredGrey);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: AppColors.readTickBlue);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.errorRed);
    }
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied to clipboard')),
                  );
                },
              ),
              if (message.status == MessageStatus.failed && onResend != null)
                ListTile(
                  leading: const Icon(Icons.refresh_rounded, color: AppColors.primaryBlue),
                  title: const Text('Resend Message'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onResend?.call();
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                  title: const Text('Delete Message', style: TextStyle(color: AppColors.errorRed)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete?.call();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
