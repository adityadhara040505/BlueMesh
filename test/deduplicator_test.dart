import 'package:blue_mesh/mesh/deduplicator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageDeduplicator Tests', () {
    test('Correctly identifies duplicate and unique message IDs', () {
      final dedup = MessageDeduplicator(capacity: 100);

      expect(dedup.isDuplicate(1001), isFalse);
      expect(dedup.isDuplicate(1002), isFalse);
      expect(dedup.isDuplicate(1001), isTrue); // Duplicate
      expect(dedup.isDuplicate(1002), isTrue); // Duplicate
      expect(dedup.isDuplicate(1003), isFalse);
    });

    test('Evicts oldest entry when LRU capacity limit is exceeded', () {
      final dedup = MessageDeduplicator(capacity: 3);

      expect(dedup.isDuplicate(1), isFalse);
      expect(dedup.isDuplicate(2), isFalse);
      expect(dedup.isDuplicate(3), isFalse);
      expect(dedup.count, 3);

      // Adding 4th item must evict item 1 (the oldest)
      expect(dedup.isDuplicate(4), isFalse);
      expect(dedup.count, 3);

      // Item 1 has been evicted, so it is treated as new again
      expect(dedup.isDuplicate(1), isFalse);

      // Now item 2 is the oldest and gets evicted
      expect(dedup.isDuplicate(5), isFalse);
      expect(dedup.isDuplicate(2), isFalse);
    });

    test('clear resets count and persist handles offline state gracefully', () async {
      final dedup = MessageDeduplicator(capacity: 10);
      dedup.isDuplicate(100);
      dedup.isDuplicate(200);
      expect(dedup.count, 2);

      await dedup.persist(); // Should handle Hive gracefully
      await dedup.clear();
      expect(dedup.count, 0);
    });
  });
}
