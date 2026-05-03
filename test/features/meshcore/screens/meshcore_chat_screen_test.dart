// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_chat_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_channel.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

MeshCoreContact _testContact() {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List.generate(32, (i) => i)),
    name: 'TestPeer',
    type: MeshCoreAdvType.chat,
    pathLength: 0,
    path: Uint8List(0),
    lastSeen: DateTime.now(),
  );
}

MeshCoreChannel _testChannel() {
  return MeshCoreChannel(index: 0, name: 'general', psk: Uint8List(16));
}

/// A no-op stand-in for [MeshCoreConversationsNotifier] that keeps an empty
/// initial state without ever touching the message/contact stores. This
/// avoids the sqlite-init path that would otherwise blow up under
/// flutter_test, and short-circuits the `_loadConversations()` call that
/// reads `state` while the notifier is still being constructed (which is
/// what causes the "uninitialized provider" error in production code under
/// test).
class _StubConversationsNotifier extends MeshCoreConversationsNotifier {
  @override
  MeshCoreConversationsState build() {
    return const MeshCoreConversationsState.initial();
  }
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      // Stub session/adapter to null so the chat screen's
      // _subscribeToIncomingMessages takes the no-op branch and we don't
      // pull in the connection-coordinator chain.
      meshCoreSessionProvider.overrideWithValue(null),
      meshCoreAdapterProvider.overrideWithValue(null),
      // Stub the conversations notifier so the contact-chat path's
      // markAsRead() call resolves cleanly without touching sqlite.
      meshCoreConversationsProvider.overrideWith(
        _StubConversationsNotifier.new,
      ),
      linkStatusProvider.overrideWithValue(
        const LinkStatus(
          protocol: LinkProtocol.meshcore,
          status: LinkConnectionStatus.connected,
          deviceName: 'TestDevice',
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: child,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  // The screen kicks off async storage init in initState. The screen's
  // _loadMessages already swallows storage errors (sqlite is not available
  // in flutter_test). Just pump a few frames so the build settles.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'contact chat: renders the canonical AnimatedEmptyState when no messages',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(MeshCoreChatScreen.contact(contact: _testContact())),
      );
      await _settle(tester);

      // The hand-rolled Icon+Text empty state has been replaced with the
      // canonical AnimatedEmptyState. Pin the canonical primitive renders
      // when there are no messages — and that the contact-only markAsRead
      // path doesn't crash with a stubbed conversations notifier.
      expect(find.byType(AnimatedEmptyState), findsOneWidget);
    },
  );

  testWidgets(
    'channel chat: renders the canonical AnimatedEmptyState when no messages',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(MeshCoreChatScreen.channel(channel: _testChannel())),
      );
      await _settle(tester);

      // Same canonical primitive used for both contact and channel chats.
      expect(find.byType(AnimatedEmptyState), findsOneWidget);
    },
  );
}
