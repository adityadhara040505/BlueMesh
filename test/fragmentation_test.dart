import 'dart:typed_data';
import 'package:blue_mesh/bluetooth/fragmentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PacketFragmenter Tests', () {
    late PacketFragmenter fragmenter;

    setUp(() {
      fragmenter = PacketFragmenter();
    });

    tearDown(() {
      fragmenter.dispose();
    });

    test('Single-fragment small frame roundtrip (Android MTU 517)', () {
      const msgId = 0x12345678;
      final payload = Uint8List.fromList(List.generate(100, (i) => i % 256));

      final fragments = fragmenter.fragment(msgId, payload, 517);
      expect(fragments.length, 1);

      final reassembled = fragmenter.processIncomingFragment(fragments.first);
      expect(reassembled, isNotNull);
      expect(reassembled, equals(payload));
    });

    test('Multi-fragment large frame roundtrip across iOS MTU (185)', () {
      final msgId = 0xAABBCCDD;
      final payload = Uint8List.fromList(List.generate(1000, (i) => (i * 7) % 256));

      // Effective chunk size = 185 - 3 - 6 = 176 bytes
      final fragments = fragmenter.fragment(msgId, payload, 185);
      expect(fragments.length, greaterThan(1));

      Uint8List? reassembled;
      for (final frag in fragments) {
        reassembled = fragmenter.processIncomingFragment(frag);
      }

      expect(reassembled, isNotNull);
      expect(reassembled!.length, equals(1000));
      expect(reassembled, equals(payload));
    });

    test('Reassembly succeeds with out-of-order fragment delivery', () {
      final msgId = 0x55667788;
      final payload = Uint8List.fromList(List.generate(500, (i) => i % 128));

      final fragments = fragmenter.fragment(msgId, payload, 100);
      expect(fragments.length, greaterThan(2));

      // Reverse fragment delivery order
      final reversed = fragments.reversed.toList();
      Uint8List? result;
      for (final frag in reversed) {
        result = fragmenter.processIncomingFragment(frag);
      }

      expect(result, isNotNull);
      expect(result, equals(payload));
    });

    test('Fragment packet header serialization', () {
      final frag = PacketFragment(
        messageId: 0x99887766,
        sequence: 2,
        totalFragments: 5,
        payload: Uint8List.fromList([1, 2, 3, 4]),
      );

      final bytes = frag.toBytes();
      final parsed = PacketFragment.fromBytes(bytes);

      expect(parsed.messageId, equals(0x99887766));
      expect(parsed.sequence, equals(2));
      expect(parsed.totalFragments, equals(5));
      expect(parsed.payload, equals([1, 2, 3, 4]));
    });
  });
}
