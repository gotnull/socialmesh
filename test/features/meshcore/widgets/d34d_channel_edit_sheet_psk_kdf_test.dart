// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34d: widget tests for the random PSK + passphrase-derive affordances
// added to `MeshCoreChannelEditSheet` on top of the D31 base.
//
// Pins:
//   - dice / random key button fills the PSK field with 32 lowercase hex
//     chars and is NOT the canonical `[0..15]` sequence (defensive vs an
//     accidentally-stubbed RNG).
//   - "Generate from passphrase" tile opens the passphrase sheet.
//   - Submitting a passphrase fills the PSK field with the deterministic
//     KDF output for that passphrase under
//     `kMeshCoreChannelKdfLabel = "socialmesh.meshcore.channel.v1"`.
//   - Empty / whitespace-only passphrase blocks submission with the
//     localized validation message.
//
// Wire-format invariants live in the D31 + KDF unit tests; this file only
// exercises the UI surface added in D34d.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_channel_edit_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _RecordingTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = [];
  bool connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => connected;

  Future<void> dispose() async {
    await _rx.close();
  }
}

Widget _wrap({
  required _RecordingTransport transport,
  required MeshCoreSession session,
  required Widget Function(BuildContext) launcher,
}) {
  return ProviderScope(
    overrides: [
      linkStatusProvider.overrideWithValue(
        const LinkStatus(
          protocol: LinkProtocol.meshcore,
          status: LinkConnectionStatus.disconnected,
        ),
      ),
      meshCoreSessionProvider.overrideWithValue(session),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: launcher)),
    ),
  );
}

String _readPskFieldValue(WidgetTester tester) {
  // The PSK field is the only TextFormField inside the sheet whose
  // labelText is the localized "Pre-shared key" string; in the unit
  // test default locale (en) that's the literal we match against.
  final field = tester.widget<TextFormField>(
    find.widgetWithText(TextFormField, 'Pre-shared key'),
  );
  return field.controller!.text;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('dice button fills PSK field with 32 lowercase hex characters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final transport = _RecordingTransport();
    final session = MeshCoreSession(transport);
    addTearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    await tester.pumpWidget(
      _wrap(
        transport: transport,
        session: session,
        launcher: (context) => ElevatedButton(
          onPressed: () => showMeshCoreChannelEditSheet(
            context: context,
            mode: MeshCoreChannelEditMode.add,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap the dice icon in the PSK field's suffixIcon slot.
    await tester.tap(
      find.byKey(const ValueKey('meshcore-channel-edit-random-psk-button')),
    );
    await tester.pumpAndSettle();

    final value = _readPskFieldValue(tester);
    expect(value.length, 32);
    expect(value, value.toLowerCase());
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(value), isTrue);
    expect(transport.sent, isEmpty);
  });

  testWidgets('dice button does NOT generate the canonical [0..15] sequence', (
    tester,
  ) async {
    // Defensive against a future regression that swaps `Random.secure()`
    // for a seeded test stub. The canonical [0..15] sequence is the
    // most common smoke pattern used in helpers across this repo.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const banned = '000102030405060708090a0b0c0d0e0f';

    final transport = _RecordingTransport();
    final session = MeshCoreSession(transport);
    addTearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    await tester.pumpWidget(
      _wrap(
        transport: transport,
        session: session,
        launcher: (context) => ElevatedButton(
          onPressed: () => showMeshCoreChannelEditSheet(
            context: context,
            mode: MeshCoreChannelEditMode.add,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap the dice multiple times; at least one value must differ
    // from the banned canonical sequence (`Random.secure()` collision
    // probability with [0..15] is negligible).
    var sawNonCanonical = false;
    for (var i = 0; i < 4; i++) {
      await tester.tap(
        find.byKey(const ValueKey('meshcore-channel-edit-random-psk-button')),
      );
      await tester.pumpAndSettle();
      if (_readPskFieldValue(tester) != banned) {
        sawNonCanonical = true;
        break;
      }
    }
    expect(sawNonCanonical, isTrue);
  });

  testWidgets('"Generate from passphrase" tile opens the passphrase sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final transport = _RecordingTransport();
    final session = MeshCoreSession(transport);
    addTearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    await tester.pumpWidget(
      _wrap(
        transport: transport,
        session: session,
        launcher: (context) => ElevatedButton(
          onPressed: () => showMeshCoreChannelEditSheet(
            context: context,
            mode: MeshCoreChannelEditMode.add,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The action tile is the localized title in the parent sheet.
    // After tapping it, the passphrase sheet's primary button (also
    // localized) should be on screen.
    await tester.tap(
      find.byKey(
        const ValueKey('meshcore-channel-edit-derive-passphrase-tile'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('meshcore-channel-edit-passphrase-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-channel-edit-passphrase-submit')),
      findsOneWidget,
    );
  });

  testWidgets(
    'submitting "test phrase" fills PSK field with the pinned KDF byte vector',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);
      addTearDown(() async {
        await session.dispose();
        await transport.dispose();
      });

      await tester.pumpWidget(
        _wrap(
          transport: transport,
          session: session,
          launcher: (context) => ElevatedButton(
            onPressed: () => showMeshCoreChannelEditSheet(
              context: context,
              mode: MeshCoreChannelEditMode.add,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('meshcore-channel-edit-derive-passphrase-tile'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('meshcore-channel-edit-passphrase-field')),
        'test phrase',
      );
      await tester.tap(
        find.byKey(const ValueKey('meshcore-channel-edit-passphrase-submit')),
      );
      await tester.pumpAndSettle();

      // KDF byte vector pinned in the unit test:
      //   HMAC-SHA256("socialmesh.meshcore.channel.v1", "test phrase")[:16]
      //   == 5f37102be03ffac2f2f329df52bd365d
      expect(_readPskFieldValue(tester), '5f37102be03ffac2f2f329df52bd365d');
      expect(transport.sent, isEmpty);
    },
  );

  testWidgets('empty passphrase blocks submission with localized validation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final transport = _RecordingTransport();
    final session = MeshCoreSession(transport);
    addTearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    await tester.pumpWidget(
      _wrap(
        transport: transport,
        session: session,
        launcher: (context) => ElevatedButton(
          onPressed: () => showMeshCoreChannelEditSheet(
            context: context,
            mode: MeshCoreChannelEditMode.add,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('meshcore-channel-edit-derive-passphrase-tile'),
      ),
    );
    await tester.pumpAndSettle();

    // Submit with the field empty.
    await tester.tap(
      find.byKey(const ValueKey('meshcore-channel-edit-passphrase-submit')),
    );
    await tester.pump();

    // Localized 'Enter a passphrase' surface in en.arb.
    expect(find.text('Enter a passphrase'), findsOneWidget);
    // Sheet still open; no PSK leaked.
    expect(
      find.byKey(const ValueKey('meshcore-channel-edit-passphrase-field')),
      findsOneWidget,
    );
  });

  testWidgets('whitespace-only passphrase is also rejected', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final transport = _RecordingTransport();
    final session = MeshCoreSession(transport);
    addTearDown(() async {
      await session.dispose();
      await transport.dispose();
    });

    await tester.pumpWidget(
      _wrap(
        transport: transport,
        session: session,
        launcher: (context) => ElevatedButton(
          onPressed: () => showMeshCoreChannelEditSheet(
            context: context,
            mode: MeshCoreChannelEditMode.add,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('meshcore-channel-edit-derive-passphrase-tile'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('meshcore-channel-edit-passphrase-field')),
      '   ',
    );
    await tester.tap(
      find.byKey(const ValueKey('meshcore-channel-edit-passphrase-submit')),
    );
    await tester.pump();

    expect(find.text('Enter a passphrase'), findsOneWidget);
  });
}
