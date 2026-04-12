// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/mrrp_providers.dart';
import 'package:socialmesh/providers/sip_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_engine.dart';
import 'package:socialmesh/services/protocol/sip/sip_discovery.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_cap.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

class _FakeTransport implements DeviceTransport {
  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

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
  Future<void> refreshNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  bool get isConnected => false;

  @override
  Future<void> dispose() async {}
}

class _SpyProtocolService extends ProtocolService {
  _SpyProtocolService() : super(_FakeTransport());

  int sipDiscoveryAttachCount = 0;
  int mrrpEngineAttachCount = 0;

  @override
  void attachSipDiscovery(SipDiscovery? discovery) {
    if (discovery != null) {
      sipDiscoveryAttachCount++;
    }
    super.attachSipDiscovery(discovery);
  }

  @override
  void attachMrrpEngine(MrrpEngine? engine) {
    if (engine != null) {
      mrrpEngineAttachCount++;
    }
    super.attachMrrpEngine(engine);
  }
}

Uint8List _buildBeaconPayload() {
  final beacon = SipCapBeacon(
    features: SipFeatureBits.allV01,
    deviceClass: 1,
    maxProtoMinor: SipConstants.sipVersionMinor,
    mtuHint: SipConstants.sipMaxPayload,
    rxWindowS: 10,
  );
  final beaconPayload = SipCapMessages.encodeCapBeacon(beacon);
  final frame = SipFrame(
    versionMajor: SipConstants.sipVersionMajor,
    versionMinor: SipConstants.sipVersionMinor,
    msgType: SipMessageType.capBeacon,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: 0,
    nonce: SipCodec.generateNonce(),
    timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    payloadLen: beaconPayload.length,
    payload: beaconPayload,
  );
  return SipCodec.encode(frame)!;
}

pb.MeshPacket _makePacket(int senderNodeId) {
  final packet = pb.MeshPacket();
  packet.from = senderNodeId;
  return packet;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reading mrrpEngineProvider also attaches SIP discovery and drains early SIP frames',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.init();

      final protocol = _SpyProtocolService();

      // Simulate the real failure mode: a SIP packet arrives before any SIP
      // UI screen has forced sipDiscoveryProvider to build.
      protocol.injectSipPacketForTest(
        _makePacket(0x11223344),
        _buildBeaconPayload(),
      );
      expect(protocol.sipStartupBufferLength, 1);

      final container = ProviderContainer(
        overrides: [
          protocolServiceProvider.overrideWithValue(protocol),
          settingsServiceProvider.overrideWithValue(AsyncValue.data(settings)),
        ],
      );
      addTearDown(container.dispose);

      container.read(sipEnabledProvider.notifier).setEnabled(true);
      container.read(mrrpEnabledProvider.notifier).setEnabled(true);

      final engine = container.read(mrrpEngineProvider);
      expect(engine, isNotNull);

      // attachSipDiscovery and attachMrrpEngine both schedule startup drains
      // in microtasks.
      await Future<void>.delayed(Duration.zero);

      expect(
        protocol.sipDiscoveryAttachCount,
        1,
        reason: 'MRRP bootstrap must not depend on a SIP UI screen',
      );
      expect(protocol.mrrpEngineAttachCount, 1);
      expect(
        protocol.sipStartupBufferLength,
        0,
        reason:
            'early SIP frames must be drained once mrrpEngineProvider builds',
      );
    },
  );
}
