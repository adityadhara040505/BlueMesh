import 'dart:async';
import 'dart:typed_data';
import '../core/constants.dart';
import '../core/logger.dart';

/// Single packet fragment carrying chunk header and slice of wire frame.
class PacketFragment {
  final int messageId; // uint32
  final int sequence; // uint8 (0-indexed)
  final int totalFragments; // uint8
  final Uint8List payload;

  const PacketFragment({
    required this.messageId,
    required this.sequence,
    required this.totalFragments,
    required this.payload,
  });

  /// Serializes fragment to binary: [msgId: 4][seq: 1][total: 1][payload: N]
  Uint8List toBytes() {
    final bytes = Uint8List(BleConstants.fragmentationHeaderSize + payload.length);
    final byteData = ByteData.sublistView(bytes);

    byteData.setUint32(0, messageId, Endian.little);
    byteData.setUint8(4, sequence);
    byteData.setUint8(5, totalFragments);
    bytes.setRange(BleConstants.fragmentationHeaderSize, bytes.length, payload);

    return bytes;
  }

  /// Parses binary fragment from raw BLE packet bytes.
  static PacketFragment fromBytes(Uint8List bytes) {
    if (bytes.length < BleConstants.fragmentationHeaderSize) {
      throw FormatException('Fragment data smaller than header: ${bytes.length} bytes');
    }

    final byteData = ByteData.sublistView(bytes);
    final msgId = byteData.getUint32(0, Endian.little);
    final seq = byteData.getUint8(4);
    final total = byteData.getUint8(5);
    final data = bytes.sublist(BleConstants.fragmentationHeaderSize);

    return PacketFragment(
      messageId: msgId,
      sequence: seq,
      totalFragments: total,
      payload: data,
    );
  }
}

/// Assembly session for tracking received chunks of an incoming message.
class _AssemblySession {
  final int total;
  final List<Uint8List?> fragments;
  final DateTime createdAt;
  int receivedCount;

  _AssemblySession({required this.total})
      : fragments = List<Uint8List?>.filled(total, null),
        createdAt = DateTime.now(),
        receivedCount = 0;

  bool isComplete() => receivedCount == total;

  Uint8List build() {
    int totalLen = 0;
    for (final frag in fragments) {
      totalLen += frag!.length;
    }

    final full = Uint8List(totalLen);
    int offset = 0;
    for (final frag in fragments) {
      full.setRange(offset, offset + frag!.length, frag);
      offset += frag.length;
    }
    return full;
  }
}

/// Handles MTU chunking and reassembly buffer management.
class PacketFragmenter {
  final Map<int, _AssemblySession> _sessions = {};
  Timer? _cleanupTimer;

  PacketFragmenter() {
    // Periodic sweep to evict abandoned assemblies older than 30s
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _cleanStaleSessions();
    });
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _sessions.clear();
  }

  /// Splits an outgoing binary message frame into MTU-safe fragments.
  /// [effectiveMtu]: The negotiated connection MTU (e.g. 517 on Android, 185 on iOS).
  List<Uint8List> fragment(int messageId, Uint8List rawFrame, int effectiveMtu) {
    // Effective usable size = MTU - 3 ATT bytes - 6 fragment header bytes
    final maxChunkPayload = effectiveMtu - BleConstants.attOverhead - BleConstants.fragmentationHeaderSize;
    final chunkSize = maxChunkPayload < 10 ? 10 : maxChunkPayload; // Safe lower bound

    final totalFragments = (rawFrame.length / chunkSize).ceil();
    if (totalFragments > 255) {
      throw ArgumentError('Frame size (${rawFrame.length} bytes) exceeds maximum 255 fragments');
    }

    final fragments = <Uint8List>[];

    for (int seq = 0; seq < totalFragments; seq++) {
      final start = seq * chunkSize;
      final end = (start + chunkSize > rawFrame.length) ? rawFrame.length : start + chunkSize;
      final chunkPayload = rawFrame.sublist(start, end);

      final frag = PacketFragment(
        messageId: messageId,
        sequence: seq,
        totalFragments: totalFragments,
        payload: chunkPayload,
      );

      fragments.add(frag.toBytes());
    }

    return fragments;
  }

  /// Processes an incoming raw BLE fragment.
  /// Returns the reconstructed full message byte array once all fragments arrive, or null if incomplete.
  Uint8List? processIncomingFragment(Uint8List rawBytes) {
    try {
      final fragment = PacketFragment.fromBytes(rawBytes);

      var session = _sessions[fragment.messageId];
      if (session == null) {
        session = _AssemblySession(total: fragment.totalFragments);
        _sessions[fragment.messageId] = session;
      }

      if (fragment.sequence < session.total && session.fragments[fragment.sequence] == null) {
        session.fragments[fragment.sequence] = fragment.payload;
        session.receivedCount++;
      }

      if (session.isComplete()) {
        _sessions.remove(fragment.messageId);
        return session.build();
      }
    } catch (e, stack) {
      AppLogger.w('Failed to process incoming fragment: $e', e, stack);
    }
    return null;
  }

  void _cleanStaleSessions() {
    final now = DateTime.now();
    _sessions.removeWhere((id, session) {
      final age = now.difference(session.createdAt);
      final isExpired = age > MeshConstants.reassemblyTimeout;
      if (isExpired) {
        AppLogger.d('Reassembly timed out for message $id (${session.receivedCount}/${session.total} frags)');
      }
      return isExpired;
    });
  }
}
