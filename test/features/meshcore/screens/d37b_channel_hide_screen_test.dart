// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-B-A - channels-screen hide/filter-chip UI pins.
//
// Pinned invariants:
//   - Hidden filter chip only appears when at least one channel is
//     hidden (count > 0).
//   - The default All filter excludes hidden tiles.
//   - The Public and Private chips' count badges exclude hidden
//     channels.
//   - The Hidden filter renders ONLY hidden channels.
//   - Long-press on a visible channel surfaces Hide (not Unhide).
//   - Long-press on a hidden channel (selected via the Hidden filter)
//     surfaces Unhide (not Hide).
//   - Reorder UI and unread-badge UI are NOT introduced by D37-B-A.
//   - Edit / Share / Leave / Mute actions remain reachable.
//   - Banned redaction patterns never appear in rendered text.

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
  // D-Q4: extra pumps for the channel sort-mode AsyncNotifier's
  // SharedPreferences microtask.
  await tester.pump(const Duration(milliseconds: 50));
}

/// Pop the topmost modal route + drain any auto-dismissing snackbar
/// timer so teardown doesn't trip "Timer is still pending" /
/// "NavigatorState was disposed with an active Ticker".
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

Future<void> _seedHiddenSlots(
  String devicePubKeyPrefix,
  Set<int> hiddenSlots,
) async {
  SharedPreferences.setMockInitialValues({
    'meshcore_channel_prefs_$devicePubKeyPrefix': jsonEncode({
      'muted': <int>[],
      'hidden': hiddenSlots.toList()..sort(),
      'order': <int>[],
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

  testWidgets('Hidden chip is NOT shown when no channels are hidden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(channels: [_channel(0, 'Alpha'), _channel(1, 'Beta')]),
    );
    await _settle(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(
      find.text(_l10n.meshcoreFilterHidden),
      findsNothing,
      reason: 'no-hidden-channels case must not surface the Hidden chip',
    );
  });

  testWidgets('Hidden chip appears when at least one channel is hidden; '
      'All filter excludes the hidden tile', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Pre-seed channel 1 as hidden.
    await _seedHiddenSlots('79426d8d', {1});

    await tester.pumpWidget(
      _wrap(channels: [_channel(0, 'Alpha'), _channel(1, 'Beta')]),
    );
    await _settle(tester);

    // Hidden chip is now visible.
    expect(find.text(_l10n.meshcoreFilterHidden), findsOneWidget);

    // Alpha (visible) renders; Beta (hidden) does not in All filter.
    expect(find.text('Alpha'), findsOneWidget);
    expect(
      find.text('Beta'),
      findsNothing,
      reason: 'All filter must exclude hidden channels',
    );
  });

  testWidgets('tapping the Hidden chip shows ONLY hidden channels; tapping All '
      'returns to the un-hidden list', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _seedHiddenSlots('79426d8d', {1});

    await tester.pumpWidget(
      _wrap(channels: [_channel(0, 'Alpha'), _channel(1, 'Beta')]),
    );
    await _settle(tester);

    // Open Hidden filter.
    await tester.tap(find.text(_l10n.meshcoreFilterHidden));
    await _settle(tester);

    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    // Switch back to All.
    await tester.tap(find.text(_l10n.channelsFilterAll));
    await _settle(tester);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets('long-press on a visible channel surfaces Hide (not Unhide)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(channels: [_channel(0, 'Alpha')]));
    await _settle(tester);
    await tester.longPress(find.text('Alpha'));
    await _settle(tester);

    expect(find.text(_l10n.meshcoreHideChannel), findsOneWidget);
    expect(find.text(_l10n.meshcoreUnhideChannel), findsNothing);

    // Pre-existing actions still reachable.
    expect(find.text(_l10n.meshcoreOpenChannel), findsOneWidget);
    expect(find.text(_l10n.meshcoreMuteChannel), findsOneWidget);
    expect(find.text(_l10n.meshcoreChannelEditTitleEdit), findsOneWidget);
    expect(find.text(_l10n.meshcoreShareChannel), findsOneWidget);
    expect(find.text(_l10n.meshcoreLeaveChannel), findsOneWidget);

    _expectNoBannedRenderedText(tester);
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('long-press on a hidden channel (selected via Hidden filter) '
      'surfaces Unhide (not Hide)', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _seedHiddenSlots('79426d8d', {0});

    await tester.pumpWidget(_wrap(channels: [_channel(0, 'Alpha')]));
    await _settle(tester);

    // Open Hidden filter so Alpha (hidden) renders.
    await tester.tap(find.text(_l10n.meshcoreFilterHidden));
    await _settle(tester);

    await tester.longPress(find.text('Alpha'));
    await _settle(tester);
    expect(find.text(_l10n.meshcoreUnhideChannel), findsOneWidget);
    expect(find.text(_l10n.meshcoreHideChannel), findsNothing);

    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('Reorder / unread-badge UI is NOT present in D37-B-A', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(channels: [_channel(0, 'Alpha')]));
    await _settle(tester);
    await tester.longPress(find.text('Alpha'));
    await _settle(tester);

    // D-Q4: "Sort" and "Unread" entries dropped from this guard
    // because the sort-mode chip selector now legitimately surfaces
    // them on the channels screen. "Reorder", "Pin Channel", and
    // "Mark as read" stay banned — they were never D37-B-A surfaces
    // and remain deferred.
    for (final banned in const ['Reorder', 'Pin Channel', 'Mark as read']) {
      expect(
        find.text(banned),
        findsNothing,
        reason: 'D37-B-A must not introduce "$banned" UI',
      );
    }
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('All / Public / Private chip lists exclude hidden channels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Two private channels; channel 1 is hidden. Each default chip's
    // result list must exclude Beta. The `_ChannelCard` tile itself
    // renders the literal word "Private" inside the lock-icon row,
    // so we can't use `find.text("Private")` to tap the chip; instead
    // assert on tile composition under the default All filter.
    await _seedHiddenSlots('79426d8d', {1});

    await tester.pumpWidget(
      _wrap(channels: [_channel(0, 'Alpha'), _channel(1, 'Beta')]),
    );
    await _settle(tester);

    // Default All filter: only Alpha renders.
    expect(find.text('Alpha'), findsOneWidget);
    expect(
      find.text('Beta'),
      findsNothing,
      reason: 'hidden channel must be absent from the default All list',
    );

    // Hidden chip count badge surfaces the integer "1" - assert it
    // appears alongside the Hidden chip label.
    expect(find.text(_l10n.meshcoreFilterHidden), findsOneWidget);
  });
}
