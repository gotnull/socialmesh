// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-B-A — `MeshCoreContactDetailScreen` path-override sheet flow.
//
// Pinned invariants (this file):
//   - The "Path override" tile opens an action sheet exposing
//     Force Flood, Force Direct, and Reset to Auto.
//   - Force Direct fires a confirmation sheet with the warning copy
//     before applying.
//   - Manual N-hop entry / raw path-byte editor UI never surfaces.
//   - The routing card is read-only — there is no override-write
//     entry point inside it; tapping the path label does nothing.
//   - Rendered text never leaks raw payload bytes, full pubkeys,
//     channel names, MMFs, or `[mrrp]` envelope content.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_contact_detail_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_contact.dart';

MeshCoreContact _contact({
  String name = 'WisMeshCore',
  int pathLength = 2,
  Uint8List? path,
  int? pathOverride,
}) {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
    name: name,
    type: MeshCoreAdvType.chat,
    pathLength: pathLength,
    path: path ?? Uint8List.fromList([0xAB, 0xCD]),
    pathOverride: pathOverride,
    lastSeen: DateTime(2026, 5, 7, 14, 30),
  );
}

Widget _wrap(MeshCoreContact contact) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MeshCoreContactDetailScreen(initialContact: contact),
    ),
  );
}

/// Patterns that MUST NEVER appear in any rendered text node on this
/// screen — the override flow does not need to display message
/// content, full pubkeys, channel names, MMFs, or envelope bytes.
final List<RegExp> _bannedRenderTextPatterns = [
  RegExp(r'\[mrrp\]'),
  RegExp(r'\[/mrrp\]'),
  RegExp(r'02:[0-9a-f]{12}:'),
  RegExp(r'01:[0-9a-f]{2}:'),
  // 32-byte hex pubkey (any case) — the screen only ever shows the
  // redacted <8B…8T> fingerprint.
  RegExp(r'[0-9a-fA-F]{64}'),
  // Long base64-ish runs (envelope content).
  RegExp(r'[A-Za-z0-9+/_-]{32,}={0,2}'),
];

void _expectNoBannedText(WidgetTester tester) {
  final allTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();
  for (final pat in _bannedRenderTextPatterns) {
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

  testWidgets('Path override tile is keyed and labelled, and tapping '
      'it opens an action sheet with Force Flood / Force Direct / '
      'Reset to Auto', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(_contact()));
    await tester.pumpAndSettle();

    final tile = find.byKey(
      const ValueKey('meshcore-contact-detail-path-override'),
    );
    expect(tile, findsOneWidget);

    // Tile's localized title.
    expect(find.text('Path override'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    // All three sheet rows render.
    expect(find.text('Force flood'), findsOneWidget);
    expect(find.text('Force direct'), findsOneWidget);
    expect(find.text('Reset to auto'), findsOneWidget);

    _expectNoBannedText(tester);
  });

  testWidgets('Force Direct opens a confirmation sheet with the warning '
      'message — cancel is a no-op (no wire write happens)', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(_contact()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('meshcore-contact-detail-path-override')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Force direct'));
    await tester.pumpAndSettle();

    // Confirm sheet title appears.
    expect(find.text('Force direct delivery?'), findsOneWidget);
    // Warning copy mentions the contact name.
    expect(find.textContaining('WisMeshCore'), findsWidgets);
    // Cancel + confirm buttons present.
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Confirm sheet dismissed; nothing else surfaces.
    expect(find.text('Force direct delivery?'), findsNothing);

    _expectNoBannedText(tester);
  });

  testWidgets('Manual N-hop entry UI is intentionally absent', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(_contact()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('meshcore-contact-detail-path-override')),
    );
    await tester.pumpAndSettle();

    // No "Manual" / "N-hop" / "Edit path" labels in the action sheet.
    expect(find.textContaining('Manual'), findsNothing);
    expect(find.textContaining('N-hop'), findsNothing);
    expect(find.textContaining('Edit path'), findsNothing);
    // No TextField / TextFormField in the sheet — D34c-B-A is
    // tap-only.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('routing card stays read-only — tapping the Path row '
      'does NOT open the override sheet', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(_contact()));
    await tester.pumpAndSettle();

    // Tapping the "Path" cell in the routing InfoTable should not
    // open a sheet (InfoTable is read-only by contract). We assert
    // the action sheet labels are absent before AND after a tap.
    expect(find.text('Force flood'), findsNothing);
    await tester.tap(find.text('Path'));
    await tester.pumpAndSettle();
    expect(find.text('Force flood'), findsNothing);
  });

  testWidgets('"(forced)" pill renders when the contact carries a '
      'pathOverride flag', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Contact with pathOverride = -1 → label "Flood (forced)" via
    // the existing `localizedPathLabel` extension (D34c-A pre-wired).
    await tester.pumpWidget(
      _wrap(_contact(pathLength: -1, path: Uint8List(0), pathOverride: -1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Flood (forced)'), findsOneWidget);
  });
}
