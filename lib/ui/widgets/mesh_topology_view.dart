import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/device_peer.dart';
import '../theme/colors.dart';

/// Graphical topology viewer that renders peer nodes and mesh links using CustomPainter.
class MeshTopologyView extends StatelessWidget {
  final String myName;
  final List<DevicePeer> peers;
  final void Function(DevicePeer peer)? onPeerSelected;

  const MeshTopologyView({
    super.key,
    required this.myName,
    required this.peers,
    this.onPeerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size.width / 2, size.height / 2);

        // Compute peer node layout positions radially
        final Map<int, Offset> nodePositions = {};
        final radius = min(size.width, size.height) * 0.36;

        for (int i = 0; i < peers.length; i++) {
          final angle = (2 * pi / peers.length) * i - (pi / 2);
          final pos = Offset(
            center.dx + radius * cos(angle),
            center.dy + radius * sin(angle),
          );
          nodePositions[peers[i].deviceId] = pos;
        }

        return Stack(
          children: [
            // 1. Canvas drawing links and radar circles
            CustomPaint(
              size: size,
              painter: _TopologyPainter(
                center: center,
                radius: radius,
                nodePositions: nodePositions,
                peers: peers,
              ),
            ),

            // 2. Center "You" node widget
            Positioned(
              left: center.dx - 40,
              top: center.dy - 40,
              child: _buildCenterNode(),
            ),

            // 3. Orbiting peer nodes
            for (final peer in peers)
              if (nodePositions.containsKey(peer.deviceId))
                Positioned(
                  left: nodePositions[peer.deviceId]!.dx - 32,
                  top: nodePositions[peer.deviceId]!.dy - 32,
                  child: GestureDetector(
                    onTap: () => onPeerSelected?.call(peer),
                    child: _buildPeerNode(peer),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _buildCenterNode() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryBlue, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 26),
            const SizedBox(height: 2),
            Text(
              myName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerNode(DevicePeer peer) {
    final isOnline = peer.isConnected;
    final color = isOnline ? AppColors.onlineGreen : AppColors.offlineGrey;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices_rounded, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              peer.advertisedName,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${peer.hopCount}h • ${peer.rssi}dBm',
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopologyPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Map<int, Offset> nodePositions;
  final List<DevicePeer> peers;

  _TopologyPainter({
    required this.center,
    required this.radius,
    required this.nodePositions,
    required this.peers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.primaryBlue.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar range circles
    canvas.drawCircle(center, radius * 0.45, gridPaint);
    canvas.drawCircle(center, radius, gridPaint);
    canvas.drawCircle(center, radius * 1.35, gridPaint);

    final linePaint = Paint()
      ..color = AppColors.accentCyan.withOpacity(0.4)
      ..strokeWidth = 1.5;

    // Draw connection edges from center to peers
    for (final peer in peers) {
      final pos = nodePositions[peer.deviceId];
      if (pos != null) {
        linePaint.color = peer.isConnected
            ? AppColors.accentCyan.withOpacity(0.45)
            : AppColors.offlineGrey.withOpacity(0.25);
        canvas.drawLine(center, pos, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter oldDelegate) => true;
}
