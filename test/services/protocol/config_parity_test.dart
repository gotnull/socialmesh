// SPDX-License-Identifier: GPL-3.0-or-later

/// Regression tests for the config screen parity audit.
///
/// These tests verify protocol service changes made during the parity audit:
/// - Canned messages text stream (request/response handling)
/// - Ringtone text stream (request/response handling)
/// - getCannedMessages / getRingtone routing
/// - Admin message response parsing for text payloads
/// - Cache isolation: remote admin responses must not overwrite local cache
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/module_config.pb.dart'
    as module_pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// A transport that captures sent bytes so tests can decode and inspect them.
class _CapturingTransport implements DeviceTransport {
  final List<List<int>> sentBytes = [];

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  bool get isConnected => true;

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
  Future<void> send(List<int> data) async {
    sentBytes.add(data);
  }

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
  Future<void> dispose() async {}

  pb.MeshPacket get lastPacket {
    final toRadio = pb.ToRadio.fromBuffer(sentBytes.last);
    return toRadio.packet;
  }

  admin.AdminMessage get lastAdminMessage {
    final packet = lastPacket;
    return admin.AdminMessage.fromBuffer(packet.decoded.payload);
  }

  void clear() => sentBytes.clear();
}

const _myNodeNum = 0xAABBCCDD;
const _remoteNodeNum = 0x12345678;

Future<void> _primeNodeNum(ProtocolService protocol) async {
  final myInfo = pb.MyNodeInfo()..myNodeNum = _myNodeNum;
  final fromRadio = pb.FromRadio()..myInfo = myInfo;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

/// Simulate an admin response from a node, as if the device sent it.
Future<void> _injectAdminResponse(
  ProtocolService protocol,
  admin.AdminMessage adminMsg, {
  int fromNode = _myNodeNum,
}) async {
  final data = pb.Data()
    ..portnum = pn.PortNum.ADMIN_APP
    ..payload = adminMsg.writeToBuffer();

  final packet = pb.MeshPacket()
    ..from = fromNode
    ..to = _myNodeNum
    ..decoded = data;

  final fromRadio = pb.FromRadio()..packet = packet;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _CapturingTransport transport;
  late ProtocolService protocol;

  setUp(() async {
    transport = _CapturingTransport();
    protocol = ProtocolService(transport);
    await _primeNodeNum(protocol);
  });

  // ──────────────────────────────────────────────────────────
  // getCannedMessages routing
  // ──────────────────────────────────────────────────────────

  group('getCannedMessages routing', () {
    test('sends request to local device by default', () async {
      await protocol.getCannedMessages();

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.getCannedMessageModuleMessagesRequest, isTrue);
    });

    test('sends request to remote node when target provided', () async {
      await protocol.getCannedMessages(
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.getCannedMessageModuleMessagesRequest, isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────
  // getRingtone routing
  // ──────────────────────────────────────────────────────────

  group('getRingtone routing', () {
    test('sends request to local device by default', () async {
      await protocol.getRingtone();

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.getRingtoneRequest, isTrue);
    });

    test('sends request to remote node when target provided', () async {
      await protocol.getRingtone(
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.getRingtoneRequest, isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────
  // Canned messages text response parsing
  // ──────────────────────────────────────────────────────────

  group('Canned messages text response parsing', () {
    test('emits canned messages text on cannedMessageTextStream', () async {
      const testMessages = 'Hello|World|SOS|OK';

      final completer = Completer<String>();
      final sub = protocol.cannedMessageTextStream.listen((text) {
        completer.complete(text);
      });

      final adminMsg = admin.AdminMessage()
        ..getCannedMessageModuleMessagesResponse = testMessages;
      await _injectAdminResponse(protocol, adminMsg);

      final result = await completer.future.timeout(const Duration(seconds: 2));
      expect(result, testMessages);

      await sub.cancel();
    });

    test('handles empty canned messages response', () async {
      final completer = Completer<String>();
      final sub = protocol.cannedMessageTextStream.listen((text) {
        completer.complete(text);
      });

      final adminMsg = admin.AdminMessage()
        ..getCannedMessageModuleMessagesResponse = '';
      await _injectAdminResponse(protocol, adminMsg);

      final result = await completer.future.timeout(const Duration(seconds: 2));
      expect(result, isEmpty);

      await sub.cancel();
    });
  });

  // ──────────────────────────────────────────────────────────
  // Ringtone text response parsing
  // ──────────────────────────────────────────────────────────

  group('Ringtone text response parsing', () {
    test('emits ringtone text on ringtoneTextStream', () async {
      const testRtttl = '24:d=32,o=5,b=565:f6,p,f6,4p,p,f6,p,f6,2p';

      final completer = Completer<String>();
      final sub = protocol.ringtoneTextStream.listen((text) {
        completer.complete(text);
      });

      final adminMsg = admin.AdminMessage()..getRingtoneResponse = testRtttl;
      await _injectAdminResponse(protocol, adminMsg);

      final result = await completer.future.timeout(const Duration(seconds: 2));
      expect(result, testRtttl);

      await sub.cancel();
    });

    test('handles empty ringtone response', () async {
      final completer = Completer<String>();
      final sub = protocol.ringtoneTextStream.listen((text) {
        completer.complete(text);
      });

      final adminMsg = admin.AdminMessage()..getRingtoneResponse = '';
      await _injectAdminResponse(protocol, adminMsg);

      final result = await completer.future.timeout(const Duration(seconds: 2));
      expect(result, isEmpty);

      await sub.cancel();
    });
  });

  // ──────────────────────────────────────────────────────────
  // setCannedMessages routing
  // ──────────────────────────────────────────────────────────

  group('setCannedMessages routing', () {
    test('sends messages to local device by default', () async {
      await protocol.setCannedMessages('Hello|World');

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.setCannedMessageModuleMessages, 'Hello|World');
    });

    test('sends messages to remote node when target provided', () async {
      await protocol.setCannedMessages(
        'Hello|World',
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.setCannedMessageModuleMessages, 'Hello|World');
    });
  });

  // ──────────────────────────────────────────────────────────
  // setRingtone routing
  // ──────────────────────────────────────────────────────────

  group('setRingtone routing', () {
    test('sends ringtone to local device by default', () async {
      await protocol.setRingtone('24:d=4,o=5,b=120:c6,p,c6');

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.setRingtoneMessage, '24:d=4,o=5,b=120:c6,p,c6');
    });

    test('sends ringtone to remote node when target provided', () async {
      await protocol.setRingtone(
        '24:d=4,o=5,b=120:c6,p,c6',
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _remoteNodeNum);
      expect(packet.wantAck, isTrue);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.setRingtoneMessage, '24:d=4,o=5,b=120:c6,p,c6');
    });
  });

  // ──────────────────────────────────────────────────────────
  // setFixedPosition is local-only
  // ──────────────────────────────────────────────────────────

  group('setFixedPosition is local-only', () {
    test('always sends to local device', () async {
      await protocol.setFixedPosition(
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 10,
      );

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.hasSetFixedPosition(), isTrue);
    });
  });

  group('removeFixedPosition is local-only', () {
    test('always sends to local device', () async {
      await protocol.removeFixedPosition();

      final packet = transport.lastPacket;
      expect(packet.from, _myNodeNum);
      expect(packet.to, _myNodeNum);
      expect(packet.wantAck, isFalse);

      final adminMsg = transport.lastAdminMessage;
      expect(adminMsg.removeFixedPosition, isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────
  // Cache isolation: remote admin must not overwrite local cache
  // ──────────────────────────────────────────────────────────

  group('Cache isolation — remote admin responses', () {
    test('local config response caches LoRa config', () async {
      final loraConfig = config_pb.Config_LoRaConfig()
        ..region = config_pb.Config_LoRaConfig_RegionCode.US;
      final configResponse = config_pb.Config()..lora = loraConfig;
      final adminMsg = admin.AdminMessage()..getConfigResponse = configResponse;

      await _injectAdminResponse(protocol, adminMsg, fromNode: _myNodeNum);

      expect(protocol.currentLoraConfig, isNotNull);
      expect(
        protocol.currentLoraConfig!.region,
        config_pb.Config_LoRaConfig_RegionCode.US,
      );
    });

    test('remote config response does NOT cache LoRa config', () async {
      // Pre-populate local cache
      final localLora = config_pb.Config_LoRaConfig()
        ..region = config_pb.Config_LoRaConfig_RegionCode.US;
      final localConfig = config_pb.Config()..lora = localLora;
      final localAdmin = admin.AdminMessage()..getConfigResponse = localConfig;
      await _injectAdminResponse(protocol, localAdmin, fromNode: _myNodeNum);

      expect(
        protocol.currentLoraConfig!.region,
        config_pb.Config_LoRaConfig_RegionCode.US,
      );

      // Remote response with different region
      final remoteLora = config_pb.Config_LoRaConfig()
        ..region = config_pb.Config_LoRaConfig_RegionCode.EU_868;
      final remoteConfig = config_pb.Config()..lora = remoteLora;
      final remoteAdmin = admin.AdminMessage()
        ..getConfigResponse = remoteConfig;
      await _injectAdminResponse(
        protocol,
        remoteAdmin,
        fromNode: _remoteNodeNum,
      );

      // Local cache must still hold the original US region
      expect(
        protocol.currentLoraConfig!.region,
        config_pb.Config_LoRaConfig_RegionCode.US,
      );
    });

    test('remote config response still emits to stream', () async {
      final completer = Completer<config_pb.Config_LoRaConfig>();
      final sub = protocol.loraConfigStream.listen((config) {
        if (!completer.isCompleted) completer.complete(config);
      });

      final remoteLora = config_pb.Config_LoRaConfig()
        ..region = config_pb.Config_LoRaConfig_RegionCode.EU_868;
      final remoteConfig = config_pb.Config()..lora = remoteLora;
      final remoteAdmin = admin.AdminMessage()
        ..getConfigResponse = remoteConfig;
      await _injectAdminResponse(
        protocol,
        remoteAdmin,
        fromNode: _remoteNodeNum,
      );

      final result = await completer.future.timeout(const Duration(seconds: 2));
      expect(result.region, config_pb.Config_LoRaConfig_RegionCode.EU_868);

      await sub.cancel();
    });

    test('remote module config response does NOT cache MQTT config', () async {
      // Pre-populate local cache
      final localMqtt = module_pb.ModuleConfig_MQTTConfig()
        ..enabled = true
        ..address = 'local.mqtt.server';
      final localModuleConfig = module_pb.ModuleConfig()..mqtt = localMqtt;
      final localAdmin = admin.AdminMessage()
        ..getModuleConfigResponse = localModuleConfig;
      await _injectAdminResponse(protocol, localAdmin, fromNode: _myNodeNum);

      expect(protocol.currentMqttConfig!.enabled, isTrue);
      expect(protocol.currentMqttConfig!.address, 'local.mqtt.server');

      // Remote response with different MQTT config
      final remoteMqtt = module_pb.ModuleConfig_MQTTConfig()
        ..enabled = false
        ..address = 'remote.mqtt.server';
      final remoteModuleConfig = module_pb.ModuleConfig()..mqtt = remoteMqtt;
      final remoteAdmin = admin.AdminMessage()
        ..getModuleConfigResponse = remoteModuleConfig;
      await _injectAdminResponse(
        protocol,
        remoteAdmin,
        fromNode: _remoteNodeNum,
      );

      // Local cache must still hold the original local config
      expect(protocol.currentMqttConfig!.enabled, isTrue);
      expect(protocol.currentMqttConfig!.address, 'local.mqtt.server');
    });

    test('remote module config response still emits to stream', () async {
      final completer = Completer<module_pb.ModuleConfig_MQTTConfig>();
      final sub = protocol.mqttConfigStream.listen((config) {
        if (!completer.isCompleted) completer.complete(config);
      });

      final remoteMqtt = module_pb.ModuleConfig_MQTTConfig()
        ..enabled = false
        ..address = 'remote.mqtt.server';
      final remoteModuleConfig = module_pb.ModuleConfig()..mqtt = remoteMqtt;
      final remoteAdmin = admin.AdminMessage()
        ..getModuleConfigResponse = remoteModuleConfig;
      await _injectAdminResponse(
        protocol,
        remoteAdmin,
        fromNode: _remoteNodeNum,
      );

      final result = await completer.future.timeout(const Duration(seconds: 2));
      expect(result.enabled, isFalse);
      expect(result.address, 'remote.mqtt.server');

      await sub.cancel();
    });

    test('remote config response does NOT cache device config', () async {
      // Pre-populate local cache
      final localDevice = config_pb.Config_DeviceConfig()
        ..role = config_pb.Config_DeviceConfig_Role.CLIENT;
      final localConfig = config_pb.Config()..device = localDevice;
      final localAdmin = admin.AdminMessage()..getConfigResponse = localConfig;
      await _injectAdminResponse(protocol, localAdmin, fromNode: _myNodeNum);

      expect(
        protocol.currentDeviceConfig!.role,
        config_pb.Config_DeviceConfig_Role.CLIENT,
      );

      // Remote response with different role
      final remoteDevice = config_pb.Config_DeviceConfig()
        ..role = config_pb.Config_DeviceConfig_Role.ROUTER;
      final remoteConfig = config_pb.Config()..device = remoteDevice;
      final remoteAdmin = admin.AdminMessage()
        ..getConfigResponse = remoteConfig;
      await _injectAdminResponse(
        protocol,
        remoteAdmin,
        fromNode: _remoteNodeNum,
      );

      // Local cache must retain CLIENT
      expect(
        protocol.currentDeviceConfig!.role,
        config_pb.Config_DeviceConfig_Role.CLIENT,
      );
    });

    test('remote response does NOT overwrite null cache', () async {
      // Without any local cache, verify remote response does NOT populate it
      expect(protocol.currentLoraConfig, isNull);

      final remoteLora = config_pb.Config_LoRaConfig()
        ..region = config_pb.Config_LoRaConfig_RegionCode.EU_868;
      final remoteConfig = config_pb.Config()..lora = remoteLora;
      final remoteAdmin = admin.AdminMessage()
        ..getConfigResponse = remoteConfig;
      await _injectAdminResponse(
        protocol,
        remoteAdmin,
        fromNode: _remoteNodeNum,
      );

      // Cache must remain null
      expect(protocol.currentLoraConfig, isNull);
    });
  });
}
