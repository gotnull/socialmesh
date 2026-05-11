// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-C-A - channels-screen reorder UI pins.
//
// Pinned invariants:
//   - Drag handle (notifications-off / chevron neighbours) renders on
//     every tile when search is empty (reorder enabled).
//   - Chevron renders and drag handle disappears when search query is
//     active (reorder disabled).
//   - A pre-seeded order list reorders the tiles in the visible
//     SliverReorderableList: the user-listed channel renders first.
//   - Long-press menu still surfaces Mute / Hide / Edit / Share /
//     Leave even with reorder mounted.
//   - Hide / Mute long-press actions remain reachable.
//   - No sort-mode UI, no unread UI, no pin UI.
//   - Banned redaction patterns never appear in any rendered Text.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_channels_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_channel.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

class _StubChannelsNotifier extends MeshCoreChannelsNotifier {
  _StubChannelsNotifier(this._seed);
  final List<MeshCoreChannel> _seed;

  @override
  MeshCoreChannelsState build() =>
      MeshCoreChannelsState(channels: List.unmodifiable(_seed));

  @override
  Future<void> refresh() async {}
}

class _StubConversationsNotifier extends MeshCoreConversationsNotifier {
  @override
  MeshCoreConversationsState build() =>
      const MeshCoreConversationsState.initial();

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
        _StubConversationsNotifier.new,
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

Future<void> _dismissAnyOpenSheet(WidgetTester tester) async {
  final navFinder = find.byType(Navigator);
  if (navFinder.evaluate().isNotEmpty) {
    final navState = tester.state<NavigatorState>(navFinder.last);
    if (navState.canPop()) navState.pop();
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _seedOrder(
  String devicePubKeyPrefix,
  List<int> order, {
  Set<int> hidden = const <int>{},
}) async {
  SharedPreferences.setMockInitialValues({
    'meshcore_channel_prefs_$devicePubKeyPrefix': jsonEncode({
      'muted': <int>[],
      'hidden': hidden.toList()..sort(),
      'order': order,
    }),
  });
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

  testWidgets('drag handle renders on every tile when search is empty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        channels: [
          _channel(0, 'Alpha'),
          _channel(1, 'Beta'),
          _channel(2, 'Gamma'),
        ],
      ),
    );
    await _settle(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    // One drag-handle per tile.
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(3));
    // No chevron while reorder is enabled.
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    _expectNoBannedRenderedText(tester);
  });

  testWidgets('typing a search query disables reorder: chevrons return, drag '
      'handles disappear', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(channels: [_channel(0, 'Alpha'), _channel(1, 'Beta')]),
    );
    await _settle(tester);

    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));

    // Type into the search field. The screen rebuilds with the new
    // _searchQuery on the next frame.
    await tester.enterText(find.byType(TextField).first, 'al');
    await _settle(tester);

    // Drag handles gone; chevrons back.
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    // The filtered list contains only Alpha; one chevron present.
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets('pre-seeded order list applies on first render', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // User-defined order: [Gamma, Alpha, Beta] (slots [2, 0, 1]).
    await _seedOrder('79426d8d', [2, 0, 1]);

    await tester.pumpWidget(
      _wrap(
        channels: [
          _channel(0, 'Alpha'),
          _channel(1, 'Beta'),
          _channel(2, 'Gamma'),
        ],
      ),
    );
    await _settle(tester);

    // All three tiles present.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);

    // Visually, Gamma should sit above Alpha which sits above Beta.
    final gammaY = tester.getCenter(find.text('Gamma')).dy;
    final alphaY = tester.getCenter(find.text('Alpha')).dy;
    final betaY = tester.getCenter(find.text('Beta')).dy;
    expect(
      gammaY < alphaY,
      isTrue,
      reason: 'pre-seeded order [2,0,1]: Gamma must render above Alpha',
    );
    expect(
      alphaY < betaY,
      isTrue,
      reason: 'pre-seeded order [2,0,1]: Alpha must render above Beta',
    );
  });

  testWidgets('channels not in the user order render after listed ones in '
      'firmware slot order', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // User listed only slot 2; slots 0 and 1 render after, in slot
    // order (Alpha before Beta).
    await _seedOrder('79426d8d', [2]);

    await tester.pumpWidget(
      _wrap(
        channels: [
          _channel(0, 'Alpha'),
          _channel(1, 'Beta'),
          _channel(2, 'Gamma'),
        ],
      ),
    );
    await _settle(tester);

    final gammaY = tester.getCenter(find.text('Gamma')).dy;
    final alphaY = tester.getCenter(find.text('Alpha')).dy;
    final betaY = tester.getCenter(find.text('Beta')).dy;
    expect(gammaY < alphaY, isTrue);
    expect(alphaY < betaY, isTrue);
  });

  testWidgets(
    'stale order entries (slot no longer exists) are silently dropped',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Order references slot 9 which doesn't exist; it must not break
      // the render.
      await _seedOrder('79426d8d', [9, 1, 0]);

      await tester.pumpWidget(
        _wrap(channels: [_channel(0, 'Alpha'), _channel(1, 'Beta')]),
      );
      await _settle(tester);

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      // Listed: [1, 0] (9 dropped) -> Beta above Alpha.
      final betaY = tester.getCenter(find.text('Beta')).dy;
      final alphaY = tester.getCenter(find.text('Alpha')).dy;
      expect(betaY < alphaY, isTrue);
    },
  );

  testWidgets(
    'long-press menu still surfaces Mute / Hide / Edit / Share / Leave '
    'with reorder mounted',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(channels: [_channel(0, 'Alpha')]));
      await _settle(tester);

      // Tile is rendered with a drag handle but long-press still
      // opens the options sheet.
      await tester.longPress(find.text('Alpha'));
      await _settle(tester);

      expect(find.text(_l10n.meshcoreOpenChannel), findsOneWidget);
      expect(find.text(_l10n.meshcoreMuteChannel), findsOneWidget);
      expect(find.text(_l10n.meshcoreHideChannel), findsOneWidget);
      expect(find.text(_l10n.meshcoreChannelEditTitleEdit), findsOneWidget);
      expect(find.text(_l10n.meshcoreShareChannel), findsOneWidget);
      expect(find.text(_l10n.meshcoreLeaveChannel), findsOneWidget);

      await _dismissAnyOpenSheet(tester);
    },
  );

  testWidgets('no sort-mode / unread / pin UI is introduced by D37-C-A', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(channels: [_channel(0, 'Alpha')]));
    await _settle(tester);
    await tester.longPress(find.text('Alpha'));
    await _settle(tester);

    for (final banned in const [
      'Sort',
      'Sort by',
      'Sort by name',
      'Latest message',
      'Pin Channel',
      'Pin',
      'Mark as read',
      'Mark unread',
    ]) {
      expect(
        find.text(banned),
        findsNothing,
        reason: 'D37-C-A must not introduce "$banned" UI',
      );
    }
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('hidden channel order is preserved under the Hidden filter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Channels 0 and 1 are both hidden. User order = [1, 0] means
    // Beta renders above Alpha under the Hidden chip.
    await _seedOrder('79426d8d', [1, 0], hidden: {0, 1});

    await tester.pumpWidget(
      _wrap(channels: [_channel(0, 'Alpha'), _channel(1, 'Beta')]),
    );
    await _settle(tester);

    // Switch to Hidden chip.
    await tester.tap(find.text(_l10n.meshcoreFilterHidden));
    await _settle(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    final betaY = tester.getCenter(find.text('Beta')).dy;
    final alphaY = tester.getCenter(find.text('Alpha')).dy;
    expect(
      betaY < alphaY,
      isTrue,
      reason: 'hidden filter must honour user-defined order',
    );
  });
}
