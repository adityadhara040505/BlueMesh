import 'package:blue_mesh/data/models/contact.dart';
import 'package:blue_mesh/ui/widgets/contact_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ContactTile displays name, online status, and fingerprint', (tester) async {
    final contact = Contact(
      deviceId: 0x12345678,
      name: 'Alice Mesh',
      publicKey: 'dGVzdA==',
      fingerprint: 'A1B2C3D4',
      lastSeen: DateTime.now(),
      isOnline: true,
      hopCount: 2,
      isVerified: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactTile(
            contact: contact,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Alice Mesh'), findsOneWidget);
    expect(find.textContaining('Online • 2 hop'), findsOneWidget);
    expect(find.text('FP: A1B2C3D4'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });
}
