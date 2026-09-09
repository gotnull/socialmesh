// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/device/device_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';

// While auto-reconnect is searching for a radio that went out of range,
// the device sheet used to hide every button, leaving no way to stop the
// search and pick another radio. The sheet now offers Cancel reconnect,
// which runs the authoritative cancel and routes to the Scanner.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSheet(WidgetTester tester, ProviderContainer container) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme(AccentColors.magenta),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDeviceSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        transportProvider.overrideWithValue(_FakeTransport()),
        connectionStateProvider.overrideWith(
          (ref) => Stream.value(DeviceConnectionState.disconnected),
        ),
        currentRssiProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    container.read(appInitProvider.notifier).setReady();
    return container;
  }

  testWidgets('offers Cancel reconnect while auto-reconnect is scanning', (
    tester,
  ) async {
    final container = buildContainer();
    addTearDown(container.dispose);
    container
        .read(autoReconnectStateProvider.notifier)
        .setState(AutoReconnectState.scanning);

    await pumpSheet(tester, container);
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Cancel reconnect'), findsOneWidget);
    expect(find.text('Scan for Devices'), findsNothing);
    expect(container.read(userDisconnectedProvider), isFalse);

    await tester.tap(find.text('Cancel reconnect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(container.read(userDisconnectedProvider), isTrue);
    expect(container.read(autoReconnectStateProvider), AutoReconnectState.idle);
    expect(container.read(appInitProvider), AppInitState.needsScanner);
  });

  // The link being up is not the session being usable. While readiness
  // is still configuring, the sheet must not say "Connected" next to a
  // "Still configuring" refusal on send.
  testWidgets('reads Configuring while the link is up but not ready', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        transportProvider.overrideWithValue(_FakeTransport()),
        connectionStateProvider.overrideWith(
          (ref) => Stream.value(DeviceConnectionState.connected),
        ),
        currentRssiProvider.overrideWith((ref) => const Stream<int>.empty()),
        meshtasticBannerStateProvider.overrideWithValue(
          MeshtasticBannerState.configuring,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(appInitProvider.notifier).setReady();

    await pumpSheet(tester, container);
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Header and Status row both carry the readiness label.
    expect(find.text('Configuring...'), findsNWidgets(2));
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('offers Scan for Devices when idle and disconnected', (
    tester,
  ) async {
    final container = buildContainer();
    addTearDown(container.dispose);

    await pumpSheet(tester, container);
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Scan for Devices'), findsOneWidget);
    expect(find.text('Cancel reconnect'), findsNothing);
  });
}

class _FakeTransport implements DeviceTransport {
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();

  DeviceConnectionState _state = DeviceConnectionState.disconnected;

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => _state;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  String? get bleManufacturerName => null;

  @override
  String? get bleModelNumber => null;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {
    _state = DeviceConnectionState.connected;
    _stateController.add(_state);
  }

  @override
  Future<void> disconnect() async {
    _state = DeviceConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}
