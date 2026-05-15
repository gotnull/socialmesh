// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q1: "New messages" divider + boundary helper pins.
//
// Pinned invariants:
//   - Pure helper returns -1 when unread snapshot is zero or window
//     is empty (no divider).
//   - Pure helper returns 0 when the unread count exceeds the loaded
//     window (clamp to top so the divider still surfaces).
//   - Pure helper returns `messageCount - unreadCount` otherwise.
//   - The standalone widget renders the localized "New messages"
//     label flanked by two `Divider` lines.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_chat_unread_divider.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';

final _l10n = AppLocalizationsEn();

void main() {
  group('chatUnreadDividerInsertIndex - D-Q1', () {
    test('zero unread -> -1 (no divider)', () {
      expect(chatUnreadDividerInsertIndex(messageCount: 5, unreadCount: 0), -1);
    });

    test('negative unread -> -1', () {
      expect(
        chatUnreadDividerInsertIndex(messageCount: 5, unreadCount: -3),
        -1,
      );
    });

    test('empty window -> -1', () {
      expect(chatUnreadDividerInsertIndex(messageCount: 0, unreadCount: 3), -1);
    });

    test('count smaller than window -> messageCount - unreadCount', () {
      expect(chatUnreadDividerInsertIndex(messageCount: 10, unreadCount: 3), 7);
    });

    test('count equal to window -> 0 (clamp)', () {
      expect(chatUnreadDividerInsertIndex(messageCount: 5, unreadCount: 5), 0);
    });

    test('count exceeds window -> 0 (clamp to top, older pages missing)', () {
      expect(chatUnreadDividerInsertIndex(messageCount: 5, unreadCount: 12), 0);
    });

    test('count of 1 with 1 message -> 0', () {
      expect(chatUnreadDividerInsertIndex(messageCount: 1, unreadCount: 1), 0);
    });
  });

  group('MeshCoreChatUnreadDivider widget - D-Q1', () {
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
          home: const Scaffold(body: MeshCoreChatUnreadDivider()),
        ),
      );
      await tester.pump();

      expect(find.text(_l10n.meshcoreChatUnreadDividerLabel), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });
}
