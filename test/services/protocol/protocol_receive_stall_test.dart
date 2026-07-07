// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/core/logging.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_feature_flag.dart';

/// Fake transport that exposes the diagnostic surface required by
/// ProtocolService.receivePipelineDiagnostics and lets the test drive
/// `lastNotificationAt`, refresh / disconnect call counts, and the
/// connection state.
class _StallFakeTransport extends DeviceTransport
    implements ReceiveDiagnosticsSupport {
  _StallFakeTransport({this.refreshFailureMode = _RefreshFailureMode.none});

  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();

  DeviceConnectionState _state = DeviceConnectionState.connected;
  DateTime? _lastNotificationAt;
  int _fromNumNotificationCount = 0;
  int _refreshNotificationsCount = 0;
  int _refreshNotificationsFailureCount = 0;
  int disconnectCallCount = 0;

  /// Causes tagged via [noteDisconnectCause], in call order. Lets tests
  /// assert the watchdogs identify themselves BEFORE forcing the
  /// disconnect.
  final List<String> notedDisconnectCauses = [];

  _RefreshFailureMode refreshFailureMode;

  void setLastNotificationAt(DateTime? t) => _lastNotificationAt = t;
  void bumpFromNumNotificationCount() => _fromNumNotificationCount++;

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
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {
    disconnectCallCount++;
    _state = DeviceConnectionState.disconnected;
  }

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> refreshNotifications() async {
    switch (refreshFailureMode) {
      case _RefreshFailureMode.none:
        _refreshNotificationsCount++;
        break;
      case _RefreshFailureMode.preserved:
        _refreshNotificationsFailureCount++;
        // Simulates the BleTransport branch where setNotifyValue throws
        // and the prior subscription is preserved — counter bumps but
        // no state transition.
        break;
      case _RefreshFailureMode.dropped:
        _refreshNotificationsCount++;
        _refreshNotificationsFailureCount++;
        // Simulates the BleTransport branch where the post-cancel
        // listener install fails and the transport transitions to
        // disconnected for auto-reconnect.
        _state = DeviceConnectionState.disconnected;
        break;
    }
  }

  @override
  DateTime? get lastNotificationAt => _lastNotificationAt;

  @override
  int get fromNumNotificationCount => _fromNumNotificationCount;

  @override
  int get rxBytesReadCount => 0;

  @override
  int get rxReadFailureCount => 0;

  @override
  int get refreshNotificationsCount => _refreshNotificationsCount;

  @override
  int get refreshNotificationsFailureCount => _refreshNotificationsFailureCount;

  @override
  BleDisconnectDetail? get lastDisconnectDetail => null;

  @override
  void noteDisconnectCause(String cause) {
    notedDisconnectCauses.add(cause);
  }

  @override
  Future<void> dispose() async {
    await _dataController.close();
    await _stateController.close();
  }

  void emitData(List<int> bytes) => _dataController.add(bytes);
}

enum _RefreshFailureMode { none, preserved, dropped }

List<int> _buildTextMessage({
  required int packetId,
  required int fromNode,
  int channel = 1,
  String text = 'hello',
}) {
  final payload = pb.Data()
    ..portnum = pn.PortNum.TEXT_MESSAGE_APP
    ..payload = utf8.encode(text);
  final packet = pb.MeshPacket()
    ..from = fromNode
    ..to = 0xFFFFFFFF
    ..channel = channel
    ..id = packetId
    ..decoded = payload;

  final frame = pb.FromRadio()..packet = packet;
  return frame.writeToBuffer();
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('protocol_stall');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

ProtocolService _buildProtocol({
  required _StallFakeTransport transport,
  required MeshPacketDedupeStore dedupeStore,
  required SmFeatureFlag featureFlag,
}) {
  return ProtocolService(
    transport,
    dedupeStore: dedupeStore,
    smFeatureFlag: featureFlag,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('BLE_RX_STALL_SUSPECTED warning', () {
    test('fires once per stall episode at severity 2', () async {
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();

        final flag = SmFeatureFlag(
          bleReceiveStallDetectionEnabled: true,
          bleReceiveStallRecoveryResubscribe: false,
          bleReceiveStallRecoveryReconnect: false,
        );
        final transport = _StallFakeTransport();
        final protocol = _buildProtocol(
          transport: transport,
          dedupeStore: dedupeStore,
          featureFlag: flag,
        );

        final warnings = <String>[];
        AppLogging.setAppLogSink((level, source, message) {
          if (level == 2 && source == 'ble') warnings.add(message);
        });
        addTearDown(AppLogging.reset);

        try {
          protocol.debugSetConfigurationComplete(value: true);
          // Stale by 2 minutes — past the 90 s suspected threshold.
          transport.setLastNotificationAt(
            DateTime.now().subtract(const Duration(minutes: 2)),
          );

          protocol.debugRunReceiveStallCheck();
          protocol.debugRunReceiveStallCheck();
          protocol.debugRunReceiveStallCheck();

          expect(warnings.length, 1);
          expect(warnings.single, contains('BLE_RX_STALL_SUSPECTED'));
          expect(warnings.single, contains('stalenessSeconds='));
          expect(
            warnings.single,
            contains('refreshNotificationsFailureCount='),
          );
        } finally {
          protocol.stop();
          await transport.dispose();
          await dedupeStore.dispose();
        }
      });
    });

    test(
      'fresh data resets the episode and a subsequent stall warns again',
      () async {
        await _withTempDirectory((dir) async {
          final dedupeStore = MeshPacketDedupeStore(
            dbPathOverride: p.join(dir, 'dedupe.db'),
          );
          await dedupeStore.init();

          final flag = SmFeatureFlag(
            bleReceiveStallDetectionEnabled: true,
            bleReceiveStallRecoveryResubscribe: false,
            bleReceiveStallRecoveryReconnect: false,
          );
          final transport = _StallFakeTransport();
          final protocol = _buildProtocol(
            transport: transport,
            dedupeStore: dedupeStore,
            featureFlag: flag,
          );

          final warnings = <String>[];
          AppLogging.setAppLogSink((level, source, message) {
            if (level == 2 && source == 'ble') warnings.add(message);
          });
          addTearDown(AppLogging.reset);

          try {
            protocol.debugSetConfigurationComplete(value: true);

            // First stall.
            transport.setLastNotificationAt(
              DateTime.now().subtract(const Duration(minutes: 2)),
            );
            protocol.debugRunReceiveStallCheck();
            expect(warnings.length, 1);

            // Fresh data arrives — should reset the episode flag.
            await protocol.handleIncomingPacket(
              _buildTextMessage(packetId: 42, fromNode: 0x10),
            );
            await Future<void>.delayed(const Duration(milliseconds: 20));

            // Second stall.
            transport.setLastNotificationAt(
              DateTime.now().subtract(const Duration(minutes: 2)),
            );
            protocol.debugRunReceiveStallCheck();
            expect(warnings.length, 2);
          } finally {
            protocol.stop();
            await transport.dispose();
            await dedupeStore.dispose();
          }
        });
      },
    );

    test(
      'no warning when transport notification is fresh (under 90 s)',
      () async {
        await _withTempDirectory((dir) async {
          final dedupeStore = MeshPacketDedupeStore(
            dbPathOverride: p.join(dir, 'dedupe.db'),
          );
          await dedupeStore.init();

          final flag = SmFeatureFlag(bleReceiveStallDetectionEnabled: true);
          final transport = _StallFakeTransport();
          final protocol = _buildProtocol(
            transport: transport,
            dedupeStore: dedupeStore,
            featureFlag: flag,
          );

          final warnings = <String>[];
          AppLogging.setAppLogSink((level, source, message) {
            if (level == 2 && source == 'ble') warnings.add(message);
          });
          addTearDown(AppLogging.reset);

          try {
            protocol.debugSetConfigurationComplete(value: true);
            transport.setLastNotificationAt(
              DateTime.now().subtract(const Duration(seconds: 30)),
            );

            protocol.debugRunReceiveStallCheck();
            protocol.debugRunReceiveStallCheck();

            expect(warnings, isEmpty);
          } finally {
            protocol.stop();
            await transport.dispose();
            await dedupeStore.dispose();
          }
        });
      },
    );

    test(
      'detection disabled by feature flag emits no warning even when stale',
      () async {
        await _withTempDirectory((dir) async {
          final dedupeStore = MeshPacketDedupeStore(
            dbPathOverride: p.join(dir, 'dedupe.db'),
          );
          await dedupeStore.init();

          final flag = SmFeatureFlag(bleReceiveStallDetectionEnabled: false);
          final transport = _StallFakeTransport();
          final protocol = _buildProtocol(
            transport: transport,
            dedupeStore: dedupeStore,
            featureFlag: flag,
          );

          final warnings = <String>[];
          AppLogging.setAppLogSink((level, source, message) {
            if (level == 2 && source == 'ble') warnings.add(message);
          });
          addTearDown(AppLogging.reset);

          try {
            protocol.debugSetConfigurationComplete(value: true);
            transport.setLastNotificationAt(
              DateTime.now().subtract(const Duration(minutes: 2)),
            );

            protocol.debugRunReceiveStallCheck();

            expect(warnings, isEmpty);
            expect(transport.refreshNotificationsCount, 0);
          } finally {
            protocol.stop();
            await transport.dispose();
            await dedupeStore.dispose();
          }
        });
      },
    );
  });

  group('Recovery dispatch', () {
    test('resubscribe recovery fires exactly once per stall episode '
        '(idempotent across repeat ticks)', () async {
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();

        final flag = SmFeatureFlag(
          bleReceiveStallDetectionEnabled: true,
          bleReceiveStallRecoveryResubscribe: true,
          bleReceiveStallRecoveryReconnect: false,
        );
        final transport = _StallFakeTransport();
        final protocol = _buildProtocol(
          transport: transport,
          dedupeStore: dedupeStore,
          featureFlag: flag,
        );

        try {
          protocol.debugSetConfigurationComplete(value: true);
          transport.setLastNotificationAt(
            DateTime.now().subtract(const Duration(minutes: 2)),
          );

          protocol.debugRunReceiveStallCheck();
          protocol.debugRunReceiveStallCheck();
          protocol.debugRunReceiveStallCheck();

          await Future<void>.delayed(const Duration(milliseconds: 20));

          // One stall episode → one accepted refresh call.
          expect(transport.refreshNotificationsCount, 1);
          expect(transport.disconnectCallCount, 0);
        } finally {
          protocol.stop();
          await transport.dispose();
          await dedupeStore.dispose();
        }
      });
    });

    test('hard-reconnect recovery fires when staleness exceeds the hard '
        'threshold and the flag is enabled', () async {
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();

        final flag = SmFeatureFlag(
          bleReceiveStallDetectionEnabled: true,
          bleReceiveStallRecoveryResubscribe: false,
          bleReceiveStallRecoveryReconnect: true,
        );
        final transport = _StallFakeTransport();
        final protocol = _buildProtocol(
          transport: transport,
          dedupeStore: dedupeStore,
          featureFlag: flag,
        );

        try {
          protocol.debugSetConfigurationComplete(value: true);
          // Past the 4-minute hard threshold.
          transport.setLastNotificationAt(
            DateTime.now().subtract(const Duration(minutes: 5)),
          );

          protocol.debugRunReceiveStallCheck();
          await Future<void>.delayed(const Duration(milliseconds: 20));

          expect(transport.disconnectCallCount, 1);
          expect(
            transport.notedDisconnectCauses,
            ['rx_stall_hard_reconnect'],
            reason:
                'The watchdog must tag the teardown initiator before '
                'forcing the disconnect so BLE_DISCONNECT logs and bug '
                'reports name it instead of "unexpected disconnect".',
          );
        } finally {
          protocol.stop();
          await transport.dispose();
          await dedupeStore.dispose();
        }
      });
    });

    test(
      'no recovery is dispatched when both recovery flags are off',
      () async {
        await _withTempDirectory((dir) async {
          final dedupeStore = MeshPacketDedupeStore(
            dbPathOverride: p.join(dir, 'dedupe.db'),
          );
          await dedupeStore.init();

          final flag = SmFeatureFlag(
            bleReceiveStallDetectionEnabled: true,
            bleReceiveStallRecoveryResubscribe: false,
            bleReceiveStallRecoveryReconnect: false,
          );
          final transport = _StallFakeTransport();
          final protocol = _buildProtocol(
            transport: transport,
            dedupeStore: dedupeStore,
            featureFlag: flag,
          );

          try {
            protocol.debugSetConfigurationComplete(value: true);
            transport.setLastNotificationAt(
              DateTime.now().subtract(const Duration(minutes: 5)),
            );

            protocol.debugRunReceiveStallCheck();
            await Future<void>.delayed(const Duration(milliseconds: 20));

            expect(transport.refreshNotificationsCount, 0);
            expect(transport.disconnectCallCount, 0);
          } finally {
            protocol.stop();
            await transport.dispose();
            await dedupeStore.dispose();
          }
        });
      },
    );
  });

  group('Foreground/background gating', () {
    test('stall check is NOT logically gated on _rssiPaused', () async {
      // The 30-min iOS-background stall is the bug we are fixing.
      // The legacy `_checkDataFlowHealth` path skips when paused; the
      // new `_checkReceiveStall` must NOT skip — that is what allows
      // recovery to be triggered on resume even though Dart timers
      // may have been suspended by iOS while backgrounded.
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();

        final flag = SmFeatureFlag(
          bleReceiveStallDetectionEnabled: true,
          bleReceiveStallRecoveryResubscribe: true,
        );
        final transport = _StallFakeTransport();
        final protocol = _buildProtocol(
          transport: transport,
          dedupeStore: dedupeStore,
          featureFlag: flag,
        );

        final warnings = <String>[];
        AppLogging.setAppLogSink((level, source, message) {
          if (level == 2 && source == 'ble') warnings.add(message);
        });
        addTearDown(AppLogging.reset);

        try {
          protocol.debugSetConfigurationComplete(value: true);
          protocol.debugSetRssiPaused(paused: true);
          transport.setLastNotificationAt(
            DateTime.now().subtract(const Duration(minutes: 2)),
          );

          protocol.debugRunReceiveStallCheck();
          await Future<void>.delayed(const Duration(milliseconds: 20));

          expect(warnings.length, 1);
          expect(transport.refreshNotificationsCount, 1);
        } finally {
          protocol.stop();
          await transport.dispose();
          await dedupeStore.dispose();
        }
      });
    });

    test('resumeRssiPolling triggers an immediate stall check when '
        'lastNotificationAt is already stale on resume', () async {
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();

        final flag = SmFeatureFlag(
          bleReceiveStallDetectionEnabled: true,
          bleReceiveStallRecoveryResubscribe: true,
        );
        final transport = _StallFakeTransport();
        final protocol = _buildProtocol(
          transport: transport,
          dedupeStore: dedupeStore,
          featureFlag: flag,
        );

        final warnings = <String>[];
        AppLogging.setAppLogSink((level, source, message) {
          if (level == 2 && source == 'ble') warnings.add(message);
        });
        addTearDown(AppLogging.reset);

        try {
          protocol.debugSetConfigurationComplete(value: true);
          protocol.debugSetRssiPaused(paused: true);
          // Last notification 2 minutes ago — stale.
          transport.setLastNotificationAt(
            DateTime.now().subtract(const Duration(minutes: 2)),
          );

          protocol.resumeRssiPolling();
          await Future<void>.delayed(const Duration(milliseconds: 20));

          expect(
            warnings.length,
            1,
            reason: 'resume should fire the immediate-check backstop',
          );
        } finally {
          protocol.stop();
          await transport.dispose();
          await dedupeStore.dispose();
        }
      });
    });
  });

  group('Diagnostic snapshot', () {
    test('receivePipelineDiagnostics surfaces every counter (failure '
        'recovery shows up)', () async {
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();

        final flag = SmFeatureFlag(
          bleReceiveStallDetectionEnabled: true,
          bleReceiveStallRecoveryResubscribe: true,
        );
        final transport = _StallFakeTransport(
          refreshFailureMode: _RefreshFailureMode.preserved,
        );
        final protocol = _buildProtocol(
          transport: transport,
          dedupeStore: dedupeStore,
          featureFlag: flag,
        );

        try {
          protocol.debugSetConfigurationComplete(value: true);
          transport.setLastNotificationAt(
            DateTime.now().subtract(const Duration(minutes: 2)),
          );

          protocol.debugRunReceiveStallCheck();
          await Future<void>.delayed(const Duration(milliseconds: 20));

          final diag = protocol.receivePipelineDiagnostics;
          expect(diag.refreshNotificationsFailureCount, 1);
          expect(diag.stallEpisodeStartedAt, isNotNull);
          expect(diag.isConnected, isTrue);
          expect(
            diag.toLogPayload(),
            contains('refreshNotificationsFailureCount=1'),
          );
          expect(diag.toLogPayload(), contains('stallEpisodeStartedAt='));
        } finally {
          protocol.stop();
          await transport.dispose();
          await dedupeStore.dispose();
        }
      });
    });

    test('end-to-end emits one Message via the message stream', () async {
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();

        final transport = _StallFakeTransport();
        final protocol = ProtocolService(transport, dedupeStore: dedupeStore);

        final messages = <Message>[];
        final sub = protocol.messageStream.listen(messages.add);

        try {
          await protocol.handleIncomingPacket(
            _buildTextMessage(
              packetId: 0x900,
              fromNode: 0x42,
              text: 'end-to-end',
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(messages, hasLength(1));
          expect(messages.single.text, 'end-to-end');

          final diag = protocol.receivePipelineDiagnostics;
          expect(diag.lastDataReceivedAt, isNotNull);
          expect(diag.lastSuccessfulDecodeAt, isNotNull);
          expect(diag.lastTextMessageEmittedAt, isNotNull);
        } finally {
          await sub.cancel();
          protocol.stop();
          await transport.dispose();
          await dedupeStore.dispose();
        }
      });
    });
  });
}
