// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-A - channels-screen mute UI pins.
//
// Pinned invariants:
//   - Long-press on an un-muted channel tile surfaces the Mute action
//     (and NOT Unmute) in the AppBottomSheet.showActions menu.
//   - A muted channel tile (pre-seeded via SharedPreferences) renders
//     the notifications_off overlay icon AND surfaces Unmute (not
//     Mute) on long-press.
//   - The muted-tile overlay icon carries the canonical a11y label.
//   - Hide / Archive / Reorder / Pin Channel / Sort UI must NOT appear
//     in D37-A; those slices are reserved for D37-B and D37-C.
//   - Pre-existing channel-options actions (Open / Edit / Share /
//     Leave) remain reachable so D37-A does not regress D29 / D31 /
//     D34d flows.
//   - Banned redaction patterns (32-char hex PSK, name:hex channel
//     code) never appear in any rendered `Text` widget.
//
// The mute toggle action also emits a SnackBar via
// `showSuccessSnackBar`, which schedules a 3-second auto-dismiss
// Timer. Triggering it inside the test's FakeAsync zone causes
// "Timer is still pending after dispose" teardown failures. The
// tests below therefore pre-seed the prefs store with the desired
// muted state and assert the resulting rendered shape rather than
// driving the mute() action through the UI. The mute() controller
// path itself is exhaustively pinned by
// `test/providers/d37a_channel_mute_provider_test.dart`.

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
  MeshCoreChannelsState build() {
    return MeshCoreChannelsState(channels: List.unmodifiable(_seed));
  }

  @override
  Future<void> refresh() async {}
}

/// `_ChannelCard` watches `meshCoreConversationsProvider` for the last
/// message preview + unread badge. The production notifier schedules
/// async work via `Future.microtask` / `Future(...)` on dispose, which
/// in FakeAsync surfaces as a pending Timer at test teardown. This
/// stub returns a quiet empty state and overrides `refresh()` to a
/// no-op so the heartbeat path never runs.
class _StubConversationsNotifier extends MeshCoreConversationsNotifier {
  @override
  MeshCoreConversationsState build() {
    return const MeshCoreConversationsState.initial();
  }

  @override
  Future<void> refresh() async {}
}

MeshCoreChannel _privateChannel(int index, String name) {
  return MeshCoreChannel(
    index: index,
    name: name,
    psk: Uint8List.fromList(List.generate(16, (i) => i + 1)),
  );
}

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

/// Pump enough frames to let the prefs notifier's deferred load
/// resolve and the channel tile mount. Two fixed-duration pumps
/// (matching the surrounding channels-screen test) is sufficient.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Dismiss any open modal bottom sheet so the modal route's animation
/// controller has time to dispose cleanly. Without this, test teardown
/// trips "NavigatorState was disposed with an active Ticker" / "Timer
/// is still pending" because the open-sheet animation and any
/// pending modal route timer are still in flight when the widget
/// tree finalizes.
Future<void> _dismissAnyOpenSheet(WidgetTester tester) async {
  // Pop the topmost modal route directly. More reliable than tapping
  // the barrier (which can miss on small viewports).
  final navFinder = find.byType(Navigator);
  if (navFinder.evaluate().isNotEmpty) {
    final navState = tester.state<NavigatorState>(navFinder.last);
    if (navState.canPop()) {
      navState.pop();
    }
  }
  // Drain the sheet's close animation (~250ms) plus a generous margin
  // so any auto-dismissing timer (e.g. lingering modal route timer)
  // fires before the test body returns.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Pre-seed the muted set in SharedPreferences for [devicePubKeyPrefix]
/// before the widget tree builds. The prefs notifier picks this up
/// during its initial load.
Future<void> _seedMutedSlots(
  String devicePubKeyPrefix,
  Set<int> mutedSlots,
) async {
  SharedPreferences.setMockInitialValues({
    'meshcore_channel_prefs_$devicePubKeyPrefix': jsonEncode({
      'muted': mutedSlots.toList()..sort(),
      'hidden': <int>[],
      'order': <int>[],
    }),
  });
}

/// Banned patterns that MUST NEVER appear in any rendered Text widget.
final List<RegExp> _bannedRenderedPatterns = [
  RegExp(r'[0-9a-fA-F]{32}'), // 32-char hex PSK
  RegExp(r'[A-Za-z0-9#_-]+:[0-9a-fA-F]{32}'), // name:hex channel code
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

  testWidgets('long-press on un-muted channel shows Mute action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(channels: [_privateChannel(3, 'TestChannel')]),
    );
    await _settle(tester);

    expect(find.text('TestChannel'), findsOneWidget);

    await tester.longPress(find.text('TestChannel'));
    await _settle(tester);

    expect(find.text(_l10n.meshcoreMuteChannel), findsOneWidget);
    expect(find.text(_l10n.meshcoreUnmuteChannel), findsNothing);

    _expectNoBannedRenderedText(tester);
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('pre-seeded muted channel renders the notifications_off overlay '
      'icon AND long-press surfaces Unmute (not Mute)', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final semantics = tester.ensureSemantics();

    // Pre-seed the muted state on disk so the prefs notifier
    // surfaces it after build.
    await _seedMutedSlots('79426d8d', {3});

    await tester.pumpWidget(
      _wrap(channels: [_privateChannel(3, 'TestChannel')]),
    );
    await _settle(tester);

    // Overlay icon rendered (by glyph + by a11y label).
    expect(
      find.byIcon(Icons.notifications_off_rounded),
      findsAtLeastNWidgets(1),
      reason: 'muted tile must render a notifications_off icon overlay',
    );
    expect(
      find.bySemanticsLabel(_l10n.meshcoreChannelMutedA11yLabel),
      findsAtLeastNWidgets(1),
    );

    // Long-press surfaces Unmute (not Mute) because the channel
    // is already in the muted set.
    await tester.longPress(find.text('TestChannel'));
    await _settle(tester);
    expect(find.text(_l10n.meshcoreUnmuteChannel), findsOneWidget);
    expect(find.text(_l10n.meshcoreMuteChannel), findsNothing);

    _expectNoBannedRenderedText(tester);
    await _dismissAnyOpenSheet(tester);
    semantics.dispose();
  });

  testWidgets('un-muted channel does NOT render the muted overlay icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(channels: [_privateChannel(3, 'TestChannel')]),
    );
    await _settle(tester);

    // Tile rendered, but no muted overlay because nothing seeded.
    expect(find.text('TestChannel'), findsOneWidget);
    expect(
      find.byIcon(Icons.notifications_off_rounded),
      findsNothing,
      reason: 'un-muted channel must not render the muted-icon overlay',
    );
  });

  testWidgets('Hide / Archive / Reorder / Pin Channel / Sort UI is NOT present '
      'in D37-A (deferred to D37-B / D37-C)', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(channels: [_privateChannel(3, 'TestChannel')]),
    );
    await _settle(tester);
    await tester.longPress(find.text('TestChannel'));
    await _settle(tester);

    for (final banned in const [
      'Hide',
      'Archive',
      'Reorder',
      'Pin Channel',
      'Sort',
    ]) {
      expect(
        find.text(banned),
        findsNothing,
        reason: 'D37-A must not introduce "$banned" UI',
      );
    }
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('Open / Edit / Share / Leave actions remain reachable from the '
      'channel options sheet', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(channels: [_privateChannel(3, 'TestChannel')]),
    );
    await _settle(tester);
    await tester.longPress(find.text('TestChannel'));
    await _settle(tester);

    expect(find.text(_l10n.meshcoreOpenChannel), findsOneWidget);
    expect(find.text(_l10n.meshcoreChannelEditTitleEdit), findsOneWidget);
    expect(find.text(_l10n.meshcoreShareChannel), findsOneWidget);
    expect(find.text(_l10n.meshcoreLeaveChannel), findsOneWidget);
    await _dismissAnyOpenSheet(tester);
  });
}
