// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// "New messages" divider + boundary helper pins for the Meshtastic
// chat screen. Mirrors the MeshCore parity test under
// test/features/meshcore/widgets/d_q1_unread_divider_test.dart so the
// two protocol-isolated implementations stay behaviourally identical.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/widgets/messaging_unread_divider.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';

final _l10n = AppLocalizationsEn();

void main() {
  group('messagingUnreadDividerInsertIndex', () {
    test('zero unread -> -1 (no divider)', () {
      expect(
        messagingUnreadDividerInsertIndex(messageCount: 5, unreadCount: 0),
        -1,
      );
    });

    test('negative unread -> -1', () {
      expect(
        messagingUnreadDividerInsertIndex(messageCount: 5, unreadCount: -3),
        -1,
      );
    });

    test('empty window -> -1', () {
      expect(
        messagingUnreadDividerInsertIndex(messageCount: 0, unreadCount: 3),
        -1,
      );
    });

    test('count smaller than window -> messageCount - unreadCount', () {
      expect(
        messagingUnreadDividerInsertIndex(messageCount: 10, unreadCount: 3),
        7,
      );
    });

    test('count equal to window -> 0 (clamp)', () {
      expect(
        messagingUnreadDividerInsertIndex(messageCount: 5, unreadCount: 5),
        0,
      );
    });

    test('count exceeds window -> 0 (clamp to top, older pages missing)', () {
      expect(
        messagingUnreadDividerInsertIndex(messageCount: 5, unreadCount: 12),
        0,
      );
    });

    test('count of 1 with 1 message -> 0', () {
      expect(
        messagingUnreadDividerInsertIndex(messageCount: 1, unreadCount: 1),
        0,
      );
    });
  });

  group('MessagingUnreadDivider widget', () {
    testWidgets('renders the localized New-messages label + two Dividers', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.dark(),
          home: const Scaffold(body: MessagingUnreadDivider()),
        ),
      );
      await tester.pump();

      expect(find.text(_l10n.messagingChatUnreadDividerLabel), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });
}
