// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-B-B: `showMeshCoreManualPathSheet` widget pins.
//
// Pinned invariants:
//   - Sheet renders the input + clear + apply ValueKeys.
//   - Tapping a repeater in the picker appends its 2-char hex
//     prefix + comma into the input.
//   - Empty input apply -> closes the sheet without firing any
//     wire-side mutation (returns false to the caller).
//   - Invalid hex token surfaces the inline error message.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_manual_path_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

MeshCoreContact _contact({
  required int firstByte,
  required int type,
  String? name,
}) {
  final pubKey = Uint8List(32);
  pubKey[0] = firstByte;
  // Distinct trailing bytes so publicKeyHex differs across contacts.
  pubKey[1] = firstByte ^ 0x55;
  return MeshCoreContact(
    publicKey: pubKey,
    name: name ?? 'Node$firstByte',
    type: type,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 15, 12),
  );
}

class _StubContactsNotifier extends MeshCoreContactsNotifier {
  _StubContactsNotifier(this._seed);
  final List<MeshCoreContact> _seed;
  @override
  MeshCoreContactsState build() =>
      MeshCoreContactsState(contacts: List.unmodifiable(_seed));
}

Widget _wrap({
  required MeshCoreContact target,
  required List<MeshCoreContact> contacts,
  required void Function(bool?) onClosed,
}) {
  return ProviderScope(
    overrides: [
      meshCoreContactsProvider.overrideWith(
        () => _StubContactsNotifier(contacts),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () async {
                final result = await showMeshCoreManualPathSheet(
                  ctx,
                  contact: target,
                );
                onClosed(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders the canonical ValueKeys', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final target = _contact(firstByte: 0xA0, type: MeshCoreAdvType.chat);
    final r1 = _contact(firstByte: 0xAB, type: MeshCoreAdvType.repeater);
    await tester.pumpWidget(
      _wrap(target: target, contacts: [target, r1], onClosed: (_) {}),
    );
    await tester.pump();
    await _openSheet(tester);

    expect(
      find.byKey(const ValueKey('meshcore-manual-path-input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-manual-path-clear')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-manual-path-apply')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('meshcore-manual-path-picker-${r1.publicKeyHex}')),
      findsOneWidget,
    );
  });

  testWidgets('contact tap appends its hex prefix to the input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final target = _contact(firstByte: 0xA0, type: MeshCoreAdvType.chat);
    final r1 = _contact(firstByte: 0xAB, type: MeshCoreAdvType.repeater);
    final r2 = _contact(firstByte: 0xCD, type: MeshCoreAdvType.repeater);

    await tester.pumpWidget(
      _wrap(target: target, contacts: [target, r1, r2], onClosed: (_) {}),
    );
    await tester.pump();
    await _openSheet(tester);

    await tester.tap(
      find.byKey(ValueKey('meshcore-manual-path-picker-${r1.publicKeyHex}')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(ValueKey('meshcore-manual-path-picker-${r2.publicKeyHex}')),
    );
    await tester.pump();

    final tf = tester.widget<TextField>(
      find.byKey(const ValueKey('meshcore-manual-path-input')),
    );
    expect(tf.controller!.text, 'AB,CD,');
  });

  testWidgets('empty apply pops false without snackbar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final target = _contact(firstByte: 0xA0, type: MeshCoreAdvType.chat);
    bool? closedWith;

    await tester.pumpWidget(
      _wrap(
        target: target,
        contacts: [target],
        onClosed: (v) => closedWith = v,
      ),
    );
    await tester.pump();
    await _openSheet(tester);

    await tester.tap(
      find.byKey(const ValueKey('meshcore-manual-path-apply')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(closedWith, isFalse);
  });

  testWidgets('invalid hex token surfaces the inline error', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final target = _contact(firstByte: 0xA0, type: MeshCoreAdvType.chat);
    await tester.pumpWidget(
      _wrap(target: target, contacts: [target], onClosed: (_) {}),
    );
    await tester.pump();
    await _openSheet(tester);

    // Filter only allows [0-9A-Fa-f, ]; type something that ends up
    // as a too-short token so the parser flags it as invalid.
    await tester.enterText(
      find.byKey(const ValueKey('meshcore-manual-path-input')),
      'AB,C',
    );
    await tester.pump();
    // The preview line below the input renders the invalid-token
    // message.
    expect(
      find.text(_l10n.meshcoreManualPathInvalidToken('C')),
      findsOneWidget,
    );
  });
}
