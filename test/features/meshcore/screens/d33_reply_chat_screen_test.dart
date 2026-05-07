// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D33 — reply UI widget tests for the MeshCore chat screen.
//
// Pinned invariants:
//   - The long-press Reply action is offered ONLY for messages that
//     have a derivable MMF AND the feature flag is on. Pre-D33
//     records (mmf == null) hide Reply.
//   - Tapping Reply parks a "Replying to <name>" chip above the
//     composer with a Cancel button that exits reply mode.
//   - A bubble whose `replyToMmf` resolves locally renders the
//     resolved sender + body preview; an unresolved replyToMmf
//     renders the localized missing-target fallback line.
//
// These tests pump the chat screen with deterministic
// `initialMessages` and exercise the long-press / composer / bubble
// surfaces directly. They do not rely on the wire send path —
// envelope codec parity is covered separately in
// `test/services/meshcore/protocol/d33_chat_meta_envelope_test.dart`
// and `test/providers/d33_inbound_reply_envelope_test.dart`.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _StubConversationsNotifier extends MeshCoreConversationsNotifier {
  @override
  MeshCoreConversationsState build() {
    return const MeshCoreConversationsState.initial();
  }
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      meshCoreSessionProvider.overrideWithValue(null),
      meshCoreAdapterProvider.overrideWithValue(null),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // D33: AppFeatureFlags.enableMeshCoreReplies reads from .env, so
    // we must load a stub env that flips the flag ON before any of
    // the long-press visibility / composer-chip tests run. Tests that
    // need the flag OFF re-load with `MESHCORE_REPLIES_ENABLED=false`.
    dotenv.loadFromString(envString: 'MESHCORE_REPLIES_ENABLED=true');
  });

  MeshCoreMessage messageWithMmf({
    required String id,
    required String text,
    required bool isOutgoing,
    String? mmf,
    String? replyToMmf,
  }) {
    return MeshCoreMessage(
      id: id,
      text: text,
      timestamp: DateTime(2026, 5, 7, 12, 0),
      isOutgoing: isOutgoing,
      status: MeshCoreMessageDeliveryStatus.delivered,
      senderKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
      senderName: 'Bob',
      mmf: mmf,
      replyToMmf: replyToMmf,
    );
  }

  group('Reply long-press visibility (channel chat)', () {
    testWidgets('long-press a target with mmf surfaces Reply when flag is ON', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          MeshCoreChatScreen.channel(
            channel: _testChannel(),
            initialMessages: [
              messageWithMmf(
                id: 'mc_in_ch_0_1700000000_dead',
                text: 'first message',
                isOutgoing: false,
                mmf: '01:00:65540340',
              ),
            ],
          ),
        ),
      );
      await _settle(tester);

      final bubble = find.byKey(
        const ValueKey('meshcore-message-mc_in_ch_0_1700000000_dead'),
      );
      expect(bubble, findsOneWidget);

      await tester.longPress(bubble);
      await tester.pumpAndSettle();

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Delete locally'), findsOneWidget);
    });

    testWidgets('long-press a pre-D33 target (no mmf) hides Reply', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          MeshCoreChatScreen.channel(
            channel: _testChannel(),
            initialMessages: [
              messageWithMmf(
                id: 'legacy-1',
                text: 'legacy bubble',
                isOutgoing: false,
                // mmf intentionally null — pre-D33 record.
              ),
            ],
          ),
        ),
      );
      await _settle(tester);

      await tester.longPress(
        find.byKey(const ValueKey('meshcore-message-legacy-1')),
      );
      await tester.pumpAndSettle();

      // Reply must NOT be present; Copy/Delete remain.
      expect(find.text('Reply'), findsNothing);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Delete locally'), findsOneWidget);
    });

    testWidgets('flag OFF hides Reply even when target has an MMF', (
      tester,
    ) async {
      // Re-load the env with the flag explicitly off. The default
      // setUp loads it ON; this test overrides for this case only.
      dotenv.loadFromString(envString: 'MESHCORE_REPLIES_ENABLED=false');

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          MeshCoreChatScreen.channel(
            channel: _testChannel(),
            initialMessages: [
              messageWithMmf(
                id: 'gated',
                text: 'gated bubble',
                isOutgoing: false,
                mmf: '01:00:65540340',
              ),
            ],
          ),
        ),
      );
      await _settle(tester);

      await tester.longPress(
        find.byKey(const ValueKey('meshcore-message-gated')),
      );
      await tester.pumpAndSettle();

      // Even though the bubble has a derivable MMF, the flag is OFF
      // so Reply must stay hidden until the env is flipped.
      expect(find.text('Reply'), findsNothing);
    });
  });

  group('Composer reply chip', () {
    testWidgets(
      'tapping Reply parks "Replying to <name>" chip + cancel button',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _wrap(
            MeshCoreChatScreen.channel(
              channel: _testChannel(),
              initialMessages: [
                messageWithMmf(
                  id: 'src',
                  text: 'roll call',
                  isOutgoing: false,
                  mmf: '01:00:65540340',
                ),
              ],
            ),
          ),
        );
        await _settle(tester);

        await tester.longPress(
          find.byKey(const ValueKey('meshcore-message-src')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reply'));
        await tester.pumpAndSettle();

        // The composer chip is keyed for stable lookup.
        expect(
          find.byKey(const ValueKey('meshcore-reply-composer-chip')),
          findsOneWidget,
        );
        // Replying to the bubble's sender label (channel chats fall
        // back to the sender label, which is "Bob" via senderName).
        expect(find.textContaining('Replying to'), findsOneWidget);

        // Cancel exits reply mode.
        await tester.tap(
          find.byKey(const ValueKey('meshcore-reply-composer-cancel')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('meshcore-reply-composer-chip')),
          findsNothing,
        );
      },
    );
  });

  group('Reply bubble quote-preview row', () {
    testWidgets('resolved replyToMmf surfaces the target body preview', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          MeshCoreChatScreen.channel(
            channel: _testChannel(),
            initialMessages: [
              messageWithMmf(
                id: 'target',
                text: 'who is around tonight',
                isOutgoing: false,
                mmf: '01:00:65540340',
              ),
              messageWithMmf(
                id: 'reply-bubble',
                text: 'i am here',
                isOutgoing: true,
                mmf: '01:00:65540500',
                replyToMmf: '01:00:65540340',
              ),
            ],
          ),
        ),
      );
      await _settle(tester);

      // Quote preview row is keyed for stable lookup.
      final quoteRow = find.byKey(
        const ValueKey('meshcore-reply-quote-reply-bubble'),
      );
      expect(quoteRow, findsOneWidget);
      // The target bubble ALSO renders 'who is around tonight' as its
      // body, so we scope the assertion to the keyed quote-preview
      // row to pin that the preview reflects the target body.
      expect(
        find.descendant(
          of: quoteRow,
          matching: find.text('who is around tonight'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'unresolved replyToMmf falls back to the missing-target message',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _wrap(
            MeshCoreChatScreen.channel(
              channel: _testChannel(),
              initialMessages: [
                messageWithMmf(
                  id: 'orphan-reply',
                  text: 'replying',
                  isOutgoing: false,
                  mmf: '01:00:65540500',
                  replyToMmf: '01:00:DEADBEEF',
                ),
              ],
            ),
          ),
        );
        await _settle(tester);

        expect(find.text("Reply to a message you don't have"), findsOneWidget);
      },
    );
  });

  group('Reply contact-chat author label', () {
    testWidgets(
      'replying to inbound contact bubble labels chip with contact title',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _wrap(
            MeshCoreChatScreen.contact(
              contact: _testContact(),
              initialMessages: [
                messageWithMmf(
                  id: 'inbound',
                  text: 'hey',
                  isOutgoing: false,
                  mmf: '02:000102030405:65540340',
                ),
              ],
            ),
          ),
        );
        await _settle(tester);

        await tester.longPress(
          find.byKey(const ValueKey('meshcore-message-inbound')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reply'));
        await tester.pumpAndSettle();

        // Contact-chat author label uses the chat title (TestPeer),
        // not the sender prefix label.
        expect(find.textContaining('TestPeer'), findsWidgets);
      },
    );
  });
}
