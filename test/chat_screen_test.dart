import 'package:blue_mesh/data/models/chat_message.dart';
import 'package:blue_mesh/ui/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageBubble Widget Tests', () {
    testWidgets('MessageBubble displays outgoing message with status ticks and lock', (tester) async {
      final message = ChatMessage(
        id: 101,
        chatId: 'chat_200',
        senderId: 100,
        recipientId: 200,
        text: 'Offline Bluetooth message',
        timestamp: DateTime(2026, 1, 1, 12, 30),
        status: MessageStatus.delivered,
        isEncrypted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              isOutgoing: true,
            ),
          ),
        ),
      );

      expect(find.text('Offline Bluetooth message'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('MessageBubble displays incoming message without status ticks', (tester) async {
      final message = ChatMessage(
        id: 102,
        chatId: 'chat_200',
        senderId: 200,
        recipientId: 100,
        text: 'Hello from peer!',
        timestamp: DateTime(2026, 1, 1, 12, 31),
        status: MessageStatus.delivered,
        isEncrypted: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              isOutgoing: false,
            ),
          ),
        ),
      );

      expect(find.text('Hello from peer!'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('MessageBubble displays queued, sending, read, and failed statuses', (tester) async {
      for (final status in [
        MessageStatus.queued,
        MessageStatus.sending,
        MessageStatus.read,
        MessageStatus.failed,
      ]) {
        final message = ChatMessage(
          id: 103,
          chatId: 'chat_200',
          senderId: 100,
          recipientId: 200,
          text: 'Status test',
          timestamp: DateTime(2026, 1, 1, 12, 32),
          status: status,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MessageBubble(
                message: message,
                isOutgoing: true,
              ),
            ),
          ),
        );

        switch (status) {
          case MessageStatus.queued:
            expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
            break;
          case MessageStatus.sending:
            expect(find.byIcon(Icons.check), findsOneWidget);
            break;
          case MessageStatus.read:
            expect(find.byIcon(Icons.done_all), findsOneWidget);
            break;
          case MessageStatus.failed:
            expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
            break;
          default:
            break;
        }
      }
    });

    testWidgets('MessageBubble long press opens context menu with copy, resend, and delete', (tester) async {
      bool resendCalled = false;
      bool deleteCalled = false;

      final message = ChatMessage(
        id: 104,
        chatId: 'chat_200',
        senderId: 100,
        recipientId: 200,
        text: 'Actionable message',
        timestamp: DateTime(2026, 1, 1, 12, 33),
        status: MessageStatus.failed,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              isOutgoing: true,
              onResend: () => resendCalled = true,
              onDelete: () => deleteCalled = true,
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Actionable message'));
      await tester.pumpAndSettle();

      expect(find.text('Copy Text'), findsOneWidget);
      expect(find.text('Resend Message'), findsOneWidget);
      expect(find.text('Delete Message'), findsOneWidget);

      await tester.tap(find.text('Resend Message'));
      await tester.pumpAndSettle();
      expect(resendCalled, true);
    });
  });
}
