import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/contact.dart';
import 'ble_provider.dart';

/// Provider exposing the reactive list of contacts in the mesh cluster.
final contactsListProvider = StreamProvider<List<Contact>>((ref) async* {
  final bleNotifier = ref.watch(bleProvider.notifier);
  final repo = bleNotifier.contactRepository;

  // Yield initial list
  yield repo.loadContacts();

  // Listen to repository changes
  final controller = Stream<List<Contact>>.periodic(
    const Duration(seconds: 2),
    (_) => repo.contactsNotifier.value,
  );

  yield* controller;
});

/// Query filter provider for searching contacts.
final contactSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered contacts provider matching search query.
final filteredContactsProvider = Provider<List<Contact>>((ref) {
  final contactsAsync = ref.watch(contactsListProvider);
  final query = ref.watch(contactSearchQueryProvider).trim().toLowerCase();

  final contacts = contactsAsync.value ?? [];
  if (query.isEmpty) return contacts;

  return contacts.where((c) {
    return c.name.toLowerCase().contains(query) ||
        c.fingerprint.toLowerCase().contains(query) ||
        c.deviceHex.toLowerCase().contains(query);
  }).toList();
});
