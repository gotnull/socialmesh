// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D43-A3: chat-screen paging integration pins.
//
// We stub `meshCoreChatHistoryProvider` directly so each test can
// drive the screen into a specific window state (loading / partial /
// full-page / end-of-history) without exercising the store.
//
// Pinned invariants (this file):
//   - "No older messages" footer renders ABOVE the oldest bubble
//     when `hasMore == false` AND the window is non-empty.
//   - Footer is hidden when `hasMore == true` (typical mid-load).
//   - Footer is hidden when the window is empty (the empty state
//     takes over instead).
//   - Initial-loading state renders the spinner empty-state while
//     `isInitialLoading == true` AND the window is empty.
//   - A scroll near the top arms a `loadOlder` call on the notifier
//     (only when `hasMore && !isLoadingOlder && !isInitialLoading`).
//   - A scroll near the top is a no-op when `hasMore == false` — no
//     `loadOlder` call is recorded.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_chat_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

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

MeshCoreMessage _msg(String id, String text, {bool isOutgoing = false}) {
  return MeshCoreMessage(
    id: id,
    text: text,
    timestamp: DateTime(2026, 5, 4, 10, 30),
    isOutgoing: isOutgoing,
    status: MeshCoreMessageDeliveryStatus.delivered,
    senderKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
  );
}

class _StubConversationsNotifier extends MeshCoreConversationsNotifier {
  @override
  MeshCoreConversationsState build() =>
      const MeshCoreConversationsState.initial();
}

/// Stub history notifier that exposes a fixed initial state and a
/// `loadOlder` call counter so widget tests can verify the screen
/// drives the notifier on near-top scrolls.
class _StubChatHistoryNotifier extends MeshCoreChatHistoryNotifier {
  _StubChatHistoryNotifier(super.key, this._initial);
  final MeshCoreChatHistoryState _initial;
  int loadInitialCalls = 0;
  int loadOlderCalls = 0;

  @override
  MeshCoreChatHistoryState build() => _initial;

  @override
  Future<void> loadInitial() async {
    loadInitialCalls++;
    // No state mutation; tests want the stub state to remain.
  }

  @override
  Future<void> loadOlder() async {
    loadOlderCalls++;
  }
}

Widget _wrap(
  Widget child, {
  required MeshCoreChatHistoryKey historyKey,
  required _StubChatHistoryNotifier Function() historyNotifierFactory,
}) {
  return ProviderScope(
    overrides: [
      meshCoreSessionProvider.overrideWithValue(null),
      meshCoreAdapterProvider.overrideWithValue(null),
      meshCoreConversationsProvider.overrideWith(
        _StubConversationsNotifier.new,
      ),
      meshCoreChatHistoryProvider(
        historyKey,
      ).overrideWith(historyNotifierFactory),
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
      builder: (context, mediaChild) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: true),
          child: mediaChild!,
        );
      },
      home: child,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'history-end footer renders when hasMore=false and window is non-empty',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final contact = _testContact();
      final key = MeshCoreChatContactKey(contact.publicKeyHex);
      final state = MeshCoreChatHistoryState(
        messages: [
          _msg('m1', 'oldest'),
          _msg('m2', 'middle'),
          _msg('m3', 'newest'),
        ],
        hasMore: false,
      );

      await tester.pumpWidget(
        _wrap(
          MeshCoreChatScreen.contact(contact: contact),
          historyKey: key,
          historyNotifierFactory: () => _StubChatHistoryNotifier(key, state),
        ),
      );
      await _settle(tester);

      expect(find.text(_l10n.meshcoreChatHistoryEnd), findsOneWidget);
    },
  );

  testWidgets(
    'history-end footer is hidden when hasMore=true (mid-load state)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final contact = _testContact();
      final key = MeshCoreChatContactKey(contact.publicKeyHex);
      final state = MeshCoreChatHistoryState(
        messages: [_msg('m1', 'only'), _msg('m2', 'two')],
      );

      await tester.pumpWidget(
        _wrap(
          MeshCoreChatScreen.contact(contact: contact),
          historyKey: key,
          historyNotifierFactory: () => _StubChatHistoryNotifier(key, state),
        ),
      );
      await _settle(tester);

      expect(find.text(_l10n.meshcoreChatHistoryEnd), findsNothing);
    },
  );

  testWidgets(
    'history-end footer is hidden when window is empty (empty state takes over)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final contact = _testContact();
      final key = MeshCoreChatContactKey(contact.publicKeyHex);
      const state = MeshCoreChatHistoryState(messages: [], hasMore: false);

      await tester.pumpWidget(
        _wrap(
          MeshCoreChatScreen.contact(contact: contact),
          historyKey: key,
          historyNotifierFactory: () => _StubChatHistoryNotifier(key, state),
        ),
      );
      await _settle(tester);

      expect(find.text(_l10n.meshcoreChatHistoryEnd), findsNothing);
    },
  );

  testWidgets('initial-loading state renders the spinner empty state while '
      'isInitialLoading=true and window is empty', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final contact = _testContact();
    final key = MeshCoreChatContactKey(contact.publicKeyHex);
    const state = MeshCoreChatHistoryState(
      messages: [],
      isInitialLoading: true,
    );

    await tester.pumpWidget(
      _wrap(
        MeshCoreChatScreen.contact(contact: contact),
        historyKey: key,
        historyNotifierFactory: () => _StubChatHistoryNotifier(key, state),
      ),
    );
    await _settle(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(_l10n.meshcoreLoadingMessages), findsOneWidget);
  });

  testWidgets(
    'scroll near top triggers loadOlder when hasMore=true and not loading',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final contact = _testContact();
      final key = MeshCoreChatContactKey(contact.publicKeyHex);
      // Enough messages to make the list scrollable.
      final state = MeshCoreChatHistoryState(
        messages: List.generate(50, (i) => _msg('m-$i', 'message $i')),
        hasMore: true,
      );
      late _StubChatHistoryNotifier stub;

      await tester.pumpWidget(
        _wrap(
          MeshCoreChatScreen.contact(contact: contact),
          historyKey: key,
          historyNotifierFactory: () {
            stub = _StubChatHistoryNotifier(key, state);
            return stub;
          },
        ),
      );
      await _settle(tester);

      // Initial render scrolls to the bottom in a post-frame callback;
      // confirm the listener path is reachable, then scroll to the top
      // and verify loadOlder fires.
      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);
      final initialCalls = stub.loadOlderCalls;

      // Drag downward (positive dy) to scroll the list back toward the
      // top. A 1200px drag from near-bottom puts the offset well below
      // the 240px near-top threshold.
      await tester.drag(listFinder, const Offset(0, 1200));
      await _settle(tester);

      expect(
        stub.loadOlderCalls,
        greaterThan(initialCalls),
        reason: 'near-top scroll must arm loadOlder when hasMore=true',
      );
    },
  );

  testWidgets('scroll near top is a no-op when hasMore=false', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final contact = _testContact();
    final key = MeshCoreChatContactKey(contact.publicKeyHex);
    // Enough messages for the list to scroll, but hasMore=false so
    // the near-top trigger must skip.
    final state = MeshCoreChatHistoryState(
      messages: List.generate(50, (i) => _msg('m-$i', 'message $i')),
      hasMore: false,
    );
    late _StubChatHistoryNotifier stub;

    await tester.pumpWidget(
      _wrap(
        MeshCoreChatScreen.contact(contact: contact),
        historyKey: key,
        historyNotifierFactory: () {
          stub = _StubChatHistoryNotifier(key, state);
          return stub;
        },
      ),
    );
    await _settle(tester);

    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);

    await tester.drag(listFinder, const Offset(0, 1200));
    await _settle(tester);

    expect(
      stub.loadOlderCalls,
      0,
      reason: 'near-top scroll must not arm loadOlder when hasMore=false',
    );
  });
}
