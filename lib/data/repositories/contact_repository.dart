import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../core/constants.dart';
import '../local/hive_boxes.dart';
import '../models/contact.dart';
import '../../core/logger.dart';

/// Repository managing contacts and cluster peer records.
class ContactRepository {
  final ValueNotifier<List<Contact>> contactsNotifier = ValueNotifier<List<Contact>>([]);

  ContactRepository() {
    loadContacts();
  }

  /// Reload contacts from persistent storage.
  List<Contact> loadContacts() {
    if (!Hive.isBoxOpen(HiveBoxKeys.contactsBox)) return [];
    final box = HiveBoxes.contactsBox;
    final List<Contact> list = [];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        try {
          list.add(Contact.fromMap(Map<String, dynamic>.from(raw)));
        } catch (e) {
          AppLogger.w('Failed to parse contact record for key: $key');
        }
      }
    }
    // Sort online contacts first, then by last seen
    list.sort((a, b) {
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return b.lastSeen.compareTo(a.lastSeen);
    });
    contactsNotifier.value = list;
    return list;
  }

  /// Get a contact by their 32-bit deviceId.
  Contact? getContact(int deviceId) {
    if (!Hive.isBoxOpen(HiveBoxKeys.contactsBox)) return null;
    final raw = HiveBoxes.contactsBox.get(deviceId.toString());
    if (raw == null) return null;
    return Contact.fromMap(Map<String, dynamic>.from(raw));
  }

  /// Save or update a peer contact.
  /// Detects fingerprint change to alert for possible MITM (TOFU).
  Future<bool> upsertContact(Contact contact) async {
    final key = contact.deviceId.toString();
    final existing = getContact(contact.deviceId);
    bool fingerprintChanged = false;

    if (existing != null && existing.fingerprint.isNotEmpty) {
      if (existing.fingerprint != contact.fingerprint) {
        AppLogger.w(
          'SECURITY ALERT: Peer ${contact.deviceId} fingerprint changed from ${existing.fingerprint} to ${contact.fingerprint}!',
        );
        fingerprintChanged = true;
      }
    }

    if (Hive.isBoxOpen(HiveBoxKeys.contactsBox)) {
      await HiveBoxes.contactsBox.put(key, contact.toMap());
    }
    loadContacts();
    return fingerprintChanged;
  }

  /// Update online/offline status and lastSeen timestamp.
  Future<void> updateOnlineStatus(int deviceId, bool isOnline, {int? batteryLevel, int? hopCount}) async {
    final existing = getContact(deviceId);
    if (existing != null) {
      existing.isOnline = isOnline;
      existing.lastSeen = DateTime.now();
      if (batteryLevel != null) existing.batteryLevel = batteryLevel;
      if (hopCount != null) existing.hopCount = hopCount;
      if (Hive.isBoxOpen(HiveBoxKeys.contactsBox)) {
        await HiveBoxes.contactsBox.put(deviceId.toString(), existing.toMap());
      }
      loadContacts();
    }
  }

  /// Toggle manual fingerprint verification.
  Future<void> setVerified(int deviceId, bool verified) async {
    final existing = getContact(deviceId);
    if (existing != null) {
      existing.isVerified = verified;
      if (Hive.isBoxOpen(HiveBoxKeys.contactsBox)) {
        await HiveBoxes.contactsBox.put(deviceId.toString(), existing.toMap());
      }
      loadContacts();
    }
  }
}
