// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D31 Part C: widget tests for `MeshCoreChannelEditSheet`.
//
// Pins the canonical UX shape — slot picker, name field, PSK paste
// field, channel-code import affordance — and the validation
// behaviour. Wire-level concerns (`CMD_SET_CHANNEL` byte layout,
// post-ACK refresh) are pinned by the session and provider tests
// elsewhere; these tests only exercise the sheet surface.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_channel_edit_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_channel.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
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

  void simulateOk() {
    final ok = MeshCoreFrame(
      command: MeshCoreResponses.ok,
      payload: Uint8List(0),
    );
    _rx.add(ok.toBytes());
  }

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
      // Disconnected so the channels notifier doesn't auto-load
      // during the test setup.
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'add mode: renders all canonical sections + slot/name/PSK fields',
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
              occupiedSlots: const {0, 1},
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Sheet opens to the canonical Add title.
      expect(find.text('Add channel'), findsOneWidget);

      // Sections render in canonical order.
      expect(find.text('Slot'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Pre-shared key'), findsWidgets);

      // PSK paste-from-code button is present.
      expect(find.text('Paste from channel code'), findsOneWidget);

      // First-free slot picker chose 2 (skipped occupied 0 and 1).
      expect(find.textContaining('Slot 2'), findsWidgets);
    },
  );

  testWidgets('edit mode: pre-populates name, PSK, and slot from existing', (
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

    final existing = MeshCoreChannel.fromHex(
      4,
      'Squad',
      '8b3387e9c5cdea6ac9e5edbaa115cd72',
    );

    await tester.pumpWidget(
      _wrap(
        transport: transport,
        session: session,
        launcher: (context) => ElevatedButton(
          onPressed: () => showMeshCoreChannelEditSheet(
            context: context,
            mode: MeshCoreChannelEditMode.edit,
            existing: existing,
          ),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Edit channel'), findsOneWidget);
    // Name field pre-populated with the existing name.
    expect(find.text('Squad'), findsWidgets);
    // PSK field shows the hex form.
    expect(find.text('8b3387e9c5cdea6ac9e5edbaa115cd72'), findsOneWidget);
    // Slot tile shows the existing slot.
    expect(find.textContaining('Slot 4'), findsWidgets);
  });

  testWidgets('validation: empty name rejected with "Name is required"', (
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

    // Tap Save without filling anything.
    await tester.tap(find.text('Save channel'));
    await tester.pump();

    expect(find.text('Name is required'), findsOneWidget);
    // No wire op fired.
    expect(transport.sent, isEmpty);
  });

  testWidgets('validation: PSK with wrong hex length rejected', (tester) async {
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

    // Fill name + a too-short PSK.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Channel name'),
      'BadPsk',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Pre-shared key'),
      'cafebabe', // 8 hex chars, not 32
    );
    await tester.tap(find.text('Save channel'));
    await tester.pump();

    expect(
      find.text('PSK must be 32 hex characters (16 bytes)'),
      findsOneWidget,
    );
    expect(transport.sent, isEmpty);
  });

  testWidgets(
    'channel-code import: pasting "name:hex" splits into name + PSK',
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

      // Paste a full channel code into the PSK field, then tap import.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pre-shared key'),
        'Public:8b3387e9c5cdea6ac9e5edbaa115cd72',
      );
      await tester.tap(find.text('Paste from channel code'));
      await tester.pumpAndSettle();

      // Name field now shows "Public" and PSK field is just the hex.
      expect(find.text('Public'), findsWidgets);
      expect(find.text('8b3387e9c5cdea6ac9e5edbaa115cd72'), findsOneWidget);
    },
  );
}
