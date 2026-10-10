import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Offline state banner indicating Store-and-Forward queuing.
class ConnectionBanner extends StatelessWidget {
  final bool isOnline;
  final String peerName;

  const ConnectionBanner({
    super.key,
    required this.isOnline,
    required this.peerName,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.warningAmber.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.warningAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Waiting for $peerName... Messages will queue and auto-deliver when reconnected.',
              style: const TextStyle(
                color: AppColors.warningAmber,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
