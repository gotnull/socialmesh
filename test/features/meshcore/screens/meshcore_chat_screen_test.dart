// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/core/widgets/chat_composer.dart';
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
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(disableAnimations: true),
          child: child!,
        );
      },
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

  MeshCoreMessage testMessage({
    required String id,
    required String text,
    required bool isOutgoing,
    MeshCoreMessageDeliveryStatus status =
        MeshCoreMessageDeliveryStatus.delivered,
  }) {
    return MeshCoreMessage(
      id: id,
      text: text,
      timestamp: DateTime(2026, 5, 4, 10, 30),
      isOutgoing: isOutgoing,
      status: status,
      senderKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
      senderName: 'RelayPeer',
    );
  }

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
      // when there are no messages, and that the contact-only markAsRead
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

  testWidgets('chat renders the canonical Meshtastic-style composer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(MeshCoreChatScreen.contact(contact: _testContact())),
    );
    await _settle(tester);

    expect(find.byType(ChatComposer), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ChatComposer),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ChatComposer),
        matching: find.byIcon(Icons.send),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'chat aligns incoming and outgoing bubbles like Meshtastic chat',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          MeshCoreChatScreen.contact(
            contact: _testContact(),
            initialMessages: [
              testMessage(
                id: 'incoming',
                text: 'incoming packet',
                isOutgoing: false,
              ),
              testMessage(
                id: 'outgoing',
                text: 'outgoing packet',
                isOutgoing: true,
              ),
            ],
          ),
        ),
      );
      await _settle(tester);

      final incomingRect = tester.getRect(find.text('incoming packet'));
      final outgoingRect = tester.getRect(find.text('outgoing packet'));

      expect(incomingRect.left, lessThan(outgoingRect.left));
      expect(outgoingRect.right, greaterThan(incomingRect.right));
    },
  );

  testWidgets('chat send button stays inert for empty drafts and sends text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(MeshCoreChatScreen.contact(contact: _testContact())),
    );
    await _settle(tester);

    final sendTapTarget = find
        .descendant(
          of: find.byType(ChatComposer),
          matching: find.byType(GestureDetector),
        )
        .last;

    await tester.tap(sendTapTarget, warnIfMissed: false);
    await tester.pump();
    expect(find.text('fresh meshcore message'), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byType(ChatComposer),
        matching: find.byType(TextField),
      ),
      'fresh meshcore message',
    );
    await tester.pump();
    await tester.tap(sendTapTarget, warnIfMissed: false);
    await tester.pump();

    expect(find.text('fresh meshcore message'), findsOneWidget);
  });

  testWidgets('chat info sheet opens from the header action', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(MeshCoreChatScreen.contact(contact: _testContact())),
    );
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('TestPeer'), findsWidgets);
    expect(find.textContaining('00010203'), findsOneWidget);

    Navigator.of(tester.element(find.byType(MeshCoreChatScreen))).pop();
    await tester.pump();
  });

  // D14: send-semantics regression pins. The bug was that `_sendMessage`
  // waited for RESP_CODE_OK on both chat types, but firmware actually
  // returns RESP_CODE_SENT (0x06) for contact sends. iPhone bridge
  // captured a real false `send.timeout` on a contact whose 0x82
  // routed-ack already arrived. These three pure helpers are extracted
  // so the wire-level behaviour is testable independently of the
  // widget tree.
  group('meshCoreExpectedSendResponseCode (D14)', () {
    test('contact send waits for RESP_CODE_SENT (0x06) not OK (0x00)', () {
      // The actual D14 bug: pre-fix this returned ok for both, causing
      // a 5s false timeout on every contact send despite firmware
      // having queued the message and a routed-ack arriving.
      expect(
        meshCoreExpectedSendResponseCode(MeshCoreChatType.contact),
        equals(MeshCoreResponses.sent),
      );
      expect(
        meshCoreExpectedSendResponseCode(MeshCoreChatType.contact),
        equals(0x06),
      );
    });

    test('channel send still waits for RESP_CODE_OK (0x00)', () {
      // Regression pin: the channel path was working pre-D14 and must
      // not change. Channels are flooded with no per-recipient ack so
      // OK with empty payload IS the entire firmware confirmation.
      expect(
        meshCoreExpectedSendResponseCode(MeshCoreChatType.channel),
        equals(MeshCoreResponses.ok),
      );
      expect(
        meshCoreExpectedSendResponseCode(MeshCoreChatType.channel),
        equals(0x00),
      );
    });

    test('contact and channel return distinct codes', () {
      // Defensive: if someone refactors `MeshCoreResponses` and
      // accidentally aliases sent and ok, the bug returns silently.
      // This test would catch that even if the individual asserts
      // above were updated to use the constants.
      expect(
        meshCoreExpectedSendResponseCode(MeshCoreChatType.contact),
        isNot(
          equals(meshCoreExpectedSendResponseCode(MeshCoreChatType.channel)),
        ),
      );
    });
  });

  group('meshCoreIsTerminalDeliveryStatus (D14 idempotent failure)', () {
    test('sent is terminal: a late timeout must not flip sent -> failed', () {
      // The iPhone bridge log showed 0x82 arriving BEFORE the 5s
      // timeout fired. Pre-D14, _markMessageFailed unconditionally
      // overwrote the bubble to failed, clobbering the just-confirmed
      // delivery. With this predicate guarding _markMessageFailed,
      // sent (and delivered) are protected.
      expect(
        meshCoreIsTerminalDeliveryStatus(MeshCoreMessageDeliveryStatus.sent),
        isTrue,
      );
    });

    test('delivered is terminal: routed-ack must not regress to failed', () {
      expect(
        meshCoreIsTerminalDeliveryStatus(
          MeshCoreMessageDeliveryStatus.delivered,
        ),
        isTrue,
      );
    });

    test('pending is NOT terminal: real timeout must still fail it', () {
      // Real failures (firmware never acks, transport drops) need to
      // surface as failed. Pending is the only non-terminal state for
      // outgoing messages.
      expect(
        meshCoreIsTerminalDeliveryStatus(MeshCoreMessageDeliveryStatus.pending),
        isFalse,
      );
    });

    test('failed is NOT terminal: a retry path can re-flip it', () {
      // Failed is a terminal *sad* state but not a *success* state,
      // so the predicate returns false. This means a manual retry
      // could in theory flip a failed bubble back to sent / delivered
      // without _markMessageFailed re-blocking; the helper only
      // guards against downgrading SUCCESS, not against flipping
      // failed -> failed.
      expect(
        meshCoreIsTerminalDeliveryStatus(MeshCoreMessageDeliveryStatus.failed),
        isFalse,
      );
    });
  });

  group('meshCoreIsUnconfirmedOutgoingStatus (D14 routed-ack flip)', () {
    test('pending is unconfirmed: 0x82 flips it to delivered', () {
      // The pre-D14 behaviour: only matched pending. Kept here as a
      // regression pin so anyone tightening the predicate has to
      // explicitly justify it.
      expect(
        meshCoreIsUnconfirmedOutgoingStatus(
          MeshCoreMessageDeliveryStatus.pending,
        ),
        isTrue,
      );
    });

    test('sent is unconfirmed: 0x82 flips sent -> delivered (D14)', () {
      // Post-D14 contact sends transition pending -> sent immediately
      // on RESP_CODE_SENT. The routed-ack 0x82 may arrive later. The
      // delivery confirmation handler MUST accept sent as a
      // candidate for the flip; pre-D14 it silently dropped these.
      expect(
        meshCoreIsUnconfirmedOutgoingStatus(MeshCoreMessageDeliveryStatus.sent),
        isTrue,
      );
    });

    test('delivered is NOT unconfirmed: a second 0x82 is a no-op', () {
      // A duplicate routed-ack (e.g. firmware retry, routing churn)
      // must not re-flip an already-delivered message. The handler's
      // lastIndexWhere skips delivered.
      expect(
        meshCoreIsUnconfirmedOutgoingStatus(
          MeshCoreMessageDeliveryStatus.delivered,
        ),
        isFalse,
      );
    });

    test('failed is NOT unconfirmed: routed-ack does not resurrect a fail', () {
      // If we already gave up and showed the user a failure, a
      // late routed-ack must not silently flip the bubble back to
      // delivered. (Edge case: if D14 idempotent-failure is working
      // correctly we should never reach failed when an ack arrives,
      // but this defends if the idempotency is regressed.)
      expect(
        meshCoreIsUnconfirmedOutgoingStatus(
          MeshCoreMessageDeliveryStatus.failed,
        ),
        isFalse,
      );
    });
  });
}
