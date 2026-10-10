import 'dart:collection';
import 'package:hive/hive.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../data/local/hive_boxes.dart';

/// LRU Deduplicator to prevent duplicate flooding in the mesh network.
class MessageDeduplicator {
  final int capacity;
  final LinkedHashMap<int, int> _cache = LinkedHashMap<int, int>();

  MessageDeduplicator({this.capacity = MeshConstants.dedupCacheCapacity}) {
    _loadFromHive();
  }

  /// Total count of remembered message IDs in memory.
  int get count => _cache.length;

  /// Checks if message ID has already been seen.
  /// If not seen, records it in the LRU cache.
  /// Returns `true` if this message is a DUPLICATE (and should be rejected/dropped).
  /// Returns `false` if this message is NEW (and should be processed).
  bool isDuplicate(int messageId) {
    if (_cache.containsKey(messageId)) {
      // Refresh recency
      final ts = _cache.remove(messageId)!;
      _cache[messageId] = ts;
      return true;
    }

    // Evict oldest if at max capacity
    if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first);
    }

    _cache[messageId] = DateTime.now().millisecondsSinceEpoch;
    return false;
  }

  /// Persist cache to Hive on pause/lifecycle events to survive app restarts.
  Future<void> persist() async {
    try {
      if (!Hive.isBoxOpen(HiveBoxKeys.dedupCacheBox)) return;
      final box = HiveBoxes.dedupCacheBox;
      await box.put('recent_ids', _cache.keys.toList());
      AppLogger.d('Persisted ${_cache.length} dedup message IDs to Hive.');
    } catch (e) {
      AppLogger.w('Failed to persist dedup cache: $e');
    }
  }

  /// Reload recent message IDs from persistent Hive box.
  void _loadFromHive() {
    try {
      if (!Hive.isBoxOpen(HiveBoxKeys.dedupCacheBox)) return;
      final box = HiveBoxes.dedupCacheBox;
      final rawList = box.get('recent_ids');
      if (rawList is List) {
        for (final item in rawList) {
          if (item is int) {
            _cache[item] = DateTime.now().millisecondsSinceEpoch;
          }
        }
        AppLogger.i('Restored ${_cache.length} message IDs from persistent dedup cache.');
      }
    } catch (e) {
      AppLogger.w('Failed to restore dedup cache from Hive: $e');
    }
  }

  /// Clear in-memory and persistent cache.
  Future<void> clear() async {
    _cache.clear();
    if (Hive.isBoxOpen(HiveBoxKeys.dedupCacheBox)) {
      await HiveBoxes.dedupCacheBox.clear();
    }
  }
}
