// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/requires_connection_guard.dart';
import 'package:socialmesh/core/widgets/status_banner.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';

void main() {
  // Pump a route stack: home is "parent", and we push a guarded screen
  // labelled "guarded" on top. Tests can assert which is on screen
  // after a state transition by looking for the label text.
  Future<void> pumpGuarded(
    WidgetTester tester, {
    required _FakeTransport transport,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [transportProvider.overrideWithValue(transport)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RequiresConnectionGuard(
                          child: Scaffold(body: Text('guarded')),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('guarded'), findsOneWidget);
  }

  Finder bannerFinder() => find.byType(StatusBanner);

  group('RequiresConnectionGuard', () {
    testWidgets('no banner / no pop on initial disconnected mount', (
      tester,
    ) async {
      final transport = _FakeTransport(
        initial: DeviceConnectionState.disconnected,
      );
      await pumpGuarded(tester, transport: transport);

      // Stay disconnected for well past the grace window.
      await tester.pump(
        kRequiresConnectionGuardGraceWindow + const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('guarded'),
        findsOneWidget,
        reason: 'should still be on guarded screen',
      );
      expect(bannerFinder(), findsNothing);

      transport.dispose();
    });

    testWidgets('no banner during reconnecting → connected', (tester) async {
      final transport = _FakeTransport(
        initial: DeviceConnectionState.connecting,
      );
      await pumpGuarded(tester, transport: transport);

      transport.emit(DeviceConnectionState.connected);
      await tester.pump();

      expect(find.text('guarded'), findsOneWidget);
      expect(bannerFinder(), findsNothing);

      transport.dispose();
    });

    testWidgets(
      'brief blip is silent — banner shows then disappears, no pop, no snackbar',
      (tester) async {
        final transport = _FakeTransport(
          initial: DeviceConnectionState.connected,
        );
        await pumpGuarded(tester, transport: transport);

        transport.emit(DeviceConnectionState.disconnected);
        // Two pumps: first drains the stream microtask so the listener
        // fires + setState schedules a frame; second runs that frame so
        // the banner is in the tree.
        await tester.pump();
        await tester.pump();
        expect(
          bannerFinder(),
          findsOneWidget,
          reason: 'banner appears immediately on disconnect',
        );
        expect(
          find.text('guarded'),
          findsOneWidget,
          reason: 'still on guarded screen',
        );

        // Reconnect well within the grace window.
        await tester.pump(const Duration(seconds: 5));
        transport.emit(DeviceConnectionState.connected);
        await tester.pump();

        expect(
          bannerFinder(),
          findsNothing,
          reason: 'banner removed on recovery',
        );
        expect(find.text('guarded'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);

        // Drain the (cancelled) timer just in case — should not pop or snack.
        await tester.pump(
          kRequiresConnectionGuardGraceWindow + const Duration(seconds: 2),
        );
        expect(find.text('guarded'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);

        transport.dispose();
      },
    );

    testWidgets(
      'persistent disconnect pops + shows snackbar after grace window',
      (tester) async {
        final transport = _FakeTransport(
          initial: DeviceConnectionState.connected,
        );
        await pumpGuarded(tester, transport: transport);

        transport.emit(DeviceConnectionState.disconnected);
        await tester.pump();

        // Wait past the grace window.
        await tester.pump(
          kRequiresConnectionGuardGraceWindow + const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('guarded'),
          findsNothing,
          reason: 'should have popped back to parent',
        );
        expect(find.text('open'), findsOneWidget);

        // Snackbar text should match the existing key (we did not change it).
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(
          find.text(l10n.requiresConnectionGuardDisconnected),
          findsOneWidget,
        );

        transport.dispose();
      },
    );

    testWidgets(
      'multiple disconnect/reconnect cycles within window do not pop',
      (tester) async {
        final transport = _FakeTransport(
          initial: DeviceConnectionState.connected,
        );
        await pumpGuarded(tester, transport: transport);

        // Cycle 1: disconnect → reconnect at 3s
        transport.emit(DeviceConnectionState.disconnected);
        await tester.pump(const Duration(seconds: 3));
        transport.emit(DeviceConnectionState.connected);
        await tester.pump();
        expect(bannerFinder(), findsNothing);

        // Cycle 2: disconnect again → reconnect at 4s
        transport.emit(DeviceConnectionState.disconnected);
        await tester.pump(const Duration(seconds: 4));
        transport.emit(DeviceConnectionState.connected);
        await tester.pump();
        expect(bannerFinder(), findsNothing);

        // Drain past the grace window — neither timer should fire.
        await tester.pump(
          kRequiresConnectionGuardGraceWindow + const Duration(seconds: 2),
        );
        expect(find.text('guarded'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);

        transport.dispose();
      },
    );

    testWidgets('dispose during grace window cancels the timer (no late pop)', (
      tester,
    ) async {
      final transport = _FakeTransport(
        initial: DeviceConnectionState.connected,
      );
      await pumpGuarded(tester, transport: transport);

      transport.emit(DeviceConnectionState.disconnected);
      await tester.pump();
      await tester.pump();
      expect(bannerFinder(), findsOneWidget);

      // User manually navigates back during the grace window.
      await tester.pump(const Duration(seconds: 3));
      final BuildContext ctx = tester.element(find.text('guarded'));
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);

      // Drain past the grace window — the cancelled timer must not fire,
      // i.e. no snackbar appears after the user has already left.
      await tester.pump(
        kRequiresConnectionGuardGraceWindow + const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      transport.dispose();
    });
  });
}

/// Minimal `DeviceTransport` test double — only the surface that
/// `connectionStateProvider` reads (`state` + `stateStream`) is
/// exercised. All other interface methods are no-ops.
class _FakeTransport implements DeviceTransport {
  _FakeTransport({required DeviceConnectionState initial}) : _state = initial;

  final StreamController<DeviceConnectionState> _controller =
      StreamController<DeviceConnectionState>.broadcast();
  DeviceConnectionState _state;

  void emit(DeviceConnectionState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  DeviceConnectionState get state => _state;

  @override
  Stream<DeviceConnectionState> get stateStream => _controller.stream;

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleManufacturerName => null;

  @override
  String? get bleModelNumber => null;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
