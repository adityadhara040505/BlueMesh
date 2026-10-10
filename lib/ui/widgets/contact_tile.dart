import 'package:flutter/material.dart';
import '../../data/models/contact.dart';
import '../../utils/time_ago.dart';
import '../theme/colors.dart';

/// Contact item tile with online status, RSSI bars, and TOFU fingerprint badge.
class ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback? onVerifyFingerprint;

  const ContactTile({
    super.key,
    required this.contact,
    required this.onTap,
    this.onVerifyFingerprint,
  });

  @override
  Widget build(BuildContext context) {
    final initials = contact.name.trim().isNotEmpty
        ? contact.name.trim().substring(0, 1).toUpperCase()
        : '?';

    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryDark.withOpacity(0.35),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: contact.isOnline ? AppColors.onlineGreen : AppColors.offlineGrey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              contact.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (contact.isVerified)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.verified_rounded, size: 16, color: AppColors.primaryBlue),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Text(
            contact.isOnline ? 'Online • ${contact.hopCount} hop' : 'Seen ${TimeAgo.format(contact.lastSeen)}',
            style: TextStyle(
              color: contact.isOnline ? AppColors.onlineGreen : AppColors.offlineGrey,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            'FP: ${contact.fingerprint}',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppColors.offlineGrey,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue.withOpacity(0.18),
              foregroundColor: AppColors.primaryLight,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onTap,
            child: const Text('Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          if (onVerifyFingerprint != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              tooltip: 'Verify Fingerprint',
              onPressed: onVerifyFingerprint,
            ),
          ],
        ],
      ),
    );
  }
}
