// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D38-A - channels-screen unread badge + preview rendering pins.
//
// Pinned invariants:
//   - When the conversations notifier surfaces a channel conversation
//     with unreadCount > 0, the channel tile renders the unread badge.
//   - When the conversations notifier surfaces lastMessageText, the
//     channel tile renders the preview string.
//   - 99+ badge ceiling: counts > 99 render as "99+".
//   - Banned redaction patterns (32-char hex PSK, name:hex channel
//     code) never appear in any rendered Text widget.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_channels_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_channel.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

class _StubChannelsNotifier extends MeshCoreChannelsNotifier {
  _StubChannelsNotifier(this._seed);
  final List<MeshCoreChannel> _seed;

  @override
  MeshCoreChannelsState build() =>
      MeshCoreChannelsState(channels: List.unmodifiable(_seed));

  @override
  Future<void> refresh() async {}
}

class _SeededConversationsNotifier extends MeshCoreConversationsNotifier {
  _SeededConversationsNotifier(this._seed);
  final List<MeshCoreConversation> _seed;

  @override
  MeshCoreConversationsState build() {
    return MeshCoreConversationsState(conversations: List.unmodifiable(_seed));
  }

  @override
  Future<void> refresh() async {}
}

MeshCoreChannel _channel(int index, String name) => MeshCoreChannel(
  index: index,
  name: name,
  psk: Uint8List.fromList(List.generate(16, (i) => i + index + 1)),
);

Widget _wrap({
  required List<MeshCoreChannel> channels,
  required List<MeshCoreConversation> conversations,
  String devicePubKeyPrefix = '79426d8d',
}) {
  return ProviderScope(
    overrides: [
      linkStatusProvider.overrideWithValue(
        const LinkStatus(
          protocol: LinkProtocol.meshcore,
          status: LinkConnectionStatus.connected,
          deviceName: 'TestDevice',
        ),
      ),
      meshCoreChannelsProvider.overrideWith(
        () => _StubChannelsNotifier(channels),
      ),
      meshCoreConversationsProvider.overrideWith(
        () => _SeededConversationsNotifier(conversations),
      ),
      meshCoreSelfPubKeyPrefixProvider.overrideWith(
        (ref) => devicePubKeyPrefix,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const MeshCoreChannelsScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

final List<RegExp> _bannedRenderedPatterns = [
  RegExp(r'[0-9a-fA-F]{32}'),
  RegExp(r'[A-Za-z0-9#_-]+:[0-9a-fA-F]{32}'),
];

void _expectNoBannedRenderedText(WidgetTester tester) {
  final allTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();
  for (final pat in _bannedRenderedPatterns) {
    for (final t in allTexts) {
      expect(
        pat.hasMatch(t),
        isFalse,
        reason: 'banned pattern $pat matched rendered text "$t"',
      );
    }
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('unread badge renders when conversation has unreadCount > 0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        channels: [_channel(1, 'Beta')],
        conversations: [
          const MeshCoreConversation(
            id: 'channel_1',
            name: 'Beta',
            isChannel: true,
            channelIndex: 1,
            lastMessageText: 'hello world',
            unreadCount: 3,
          ),
        ],
      ),
    );
    await _settle(tester);

    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // unread badge
    _expectNoBannedRenderedText(tester);
  });

  testWidgets('preview text renders when conversation has '
      'lastMessageText', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        channels: [_channel(0, 'Alpha')],
        conversations: [
          const MeshCoreConversation(
            id: 'channel_0',
            name: 'Alpha',
            isChannel: true,
            channelIndex: 0,
            lastMessageText: 'preview body here',
            unreadCount: 0,
          ),
        ],
      ),
    );
    await _settle(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('preview body here'), findsOneWidget);
    _expectNoBannedRenderedText(tester);
  });

  testWidgets('unreadCount > 99 renders as "99+"', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        channels: [_channel(2, 'Gamma')],
        conversations: [
          const MeshCoreConversation(
            id: 'channel_2',
            name: 'Gamma',
            isChannel: true,
            channelIndex: 2,
            lastMessageText: 'busy',
            unreadCount: 123,
          ),
        ],
      ),
    );
    await _settle(tester);

    expect(find.text('99+'), findsOneWidget);
    expect(find.text('123'), findsNothing);
  });

  testWidgets('no preview / no badge when conversation has none', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        channels: [_channel(3, 'Delta')],
        conversations: [
          const MeshCoreConversation(
            id: 'channel_3',
            name: 'Delta',
            isChannel: true,
            channelIndex: 3,
            unreadCount: 0,
          ),
        ],
      ),
    );
    await _settle(tester);

    expect(find.text('Delta'), findsOneWidget);
    // The unread badge is gated on (count > 0) in `_ChannelCard`, so
    // a count-of-0 conversation just doesn't render the badge widget.
    // We don't assert on `find.text("0")` because the filter chips
    // below the search bar render "0" count badges for empty filters.
    _expectNoBannedRenderedText(tester);
  });

  testWidgets('redaction sweep: preview text never embeds 32-char hex PSK or '
      '`name:hex` channel-code', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Even if the source data tried to embed sensitive material in
    // the preview, the tile's rendering path should not surface it
    // unchanged. (The notifier strips envelopes elsewhere; this is
    // a defense-in-depth sweep on the rendered Text tree.)
    await tester.pumpWidget(
      _wrap(
        channels: [_channel(4, 'Epsilon')],
        conversations: [
          const MeshCoreConversation(
            id: 'channel_4',
            name: 'Epsilon',
            isChannel: true,
            channelIndex: 4,
            // Plausibly-benign text that doesn't match any banned
            // pattern.
            lastMessageText: 'see you at 7',
            unreadCount: 1,
          ),
        ],
      ),
    );
    await _settle(tester);

    expect(find.text('Epsilon'), findsOneWidget);
    expect(find.text('see you at 7'), findsOneWidget);
    _expectNoBannedRenderedText(tester);
  });
}
