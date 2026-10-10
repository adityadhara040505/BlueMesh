import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Top bar status chip indicating BLE radio power and active mesh cluster peer count.
class BluetoothStatusChip extends StatelessWidget {
  final bool isBluetoothOn;
  final bool isScanning;
  final int peerCount;
  final bool isDualRole;

  const BluetoothStatusChip({
    super.key,
    required this.isBluetoothOn,
    required this.isScanning,
    required this.peerCount,
    required this.isDualRole,
  });

  @override
  Widget build(BuildContext context) {
    if (!isBluetoothOn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.errorRed.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_disabled_rounded, size: 14, color: AppColors.errorRed),
            SizedBox(width: 5),
            Text(
              'Bluetooth Off',
              style: TextStyle(
                color: AppColors.errorRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final hasPeers = peerCount > 0;
    final chipColor = hasPeers ? AppColors.onlineGreen : AppColors.primaryBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasPeers ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded,
            size: 14,
            color: chipColor,
          ),
          const SizedBox(width: 5),
          Text(
            hasPeers ? '$peerCount ${peerCount == 1 ? 'Peer' : 'Peers'}' : 'Mesh Scanning',
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
