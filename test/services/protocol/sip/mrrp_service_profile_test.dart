// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_profile.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

MrrpFrame _makeRequest({required int actionId, Uint8List? payload}) {
  final p = payload ?? Uint8List(0);
  return MrrpFrame(
    versionMajor: 0,
    versionMinor: 1,
    msgType: MrrpMessageType.request,
    flags: 0,
    headerLen: 20,
    requestId: 0x0001,
    serviceId: MrrpServiceId.profileV1,
    actionId: actionId,
    payloadLen: p.length,
    payload: p,
  );
}

void main() {
  late MrrpServiceProfile handler;
  late MrrpProfileConfig config;
  late bool identityVerified;

  setUp(() {
    config = const MrrpProfileConfig(
      displayName: 'TestUser', // lint-allow: hardcoded-string
      statusText: 'On mesh', // lint-allow: hardcoded-string
      deviceClass: 1,
      availability: 1,
      contactCard: 'contact@example.org', // lint-allow: hardcoded-string
      registeredServices: [
        MrrpServiceId.meetupV1,
        MrrpServiceId.profileV1,
        MrrpServiceId.boardV1,
      ],
      sipFeatures: 0x0003,
      mrrpFeatures: 0x0007,
    );
    identityVerified = true;

    handler = MrrpServiceProfile(
      configProvider: () => config,
      identityChecker: (nodeId) => identityVerified,
    );
  });

  test('serviceId and supportedActions', () {
    expect(handler.serviceId, MrrpServiceId.profileV1);
    expect(handler.supportedActions, contains(ProfileAction.getSummary));
    expect(handler.supportedActions, contains(ProfileAction.getContactCard));
    expect(handler.supportedActions, contains(ProfileAction.getCapabilities));
  });

  group('get_summary', () {
    test('returns configured fields', () async {
      final request = _makeRequest(actionId: ProfileAction.getSummary);
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.response);

      final payload = response.payload;
      var offset = 0;
      final nameLen = payload[offset++];
      final name = String.fromCharCodes(
        payload.sublist(offset, offset + nameLen),
      );
      offset += nameLen;
      final statusLen = payload[offset++];
      final status = String.fromCharCodes(
        payload.sublist(offset, offset + statusLen),
      );
      offset += statusLen;
      final deviceClass = payload[offset++];
      final availability = payload[offset++];

      expect(name, 'TestUser'); // lint-allow: hardcoded-string
      expect(status, 'On mesh'); // lint-allow: hardcoded-string
      expect(deviceClass, 1);
      expect(availability, 1);
    });

    test('long display name truncated to 32 bytes', () async {
      config = MrrpProfileConfig(
        displayName: 'A' * 100, // lint-allow: hardcoded-string
        registeredServices: const [],
      );
      handler = MrrpServiceProfile(configProvider: () => config);

      final request = _makeRequest(actionId: ProfileAction.getSummary);
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.payload[0], 32);
    });
  });

  group('get_contact_card', () {
    test('returns contact card when identity verified', () async {
      final request = _makeRequest(actionId: ProfileAction.getContactCard);
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.response);

      final contactLen = response.payload[0];
      final contact = String.fromCharCodes(
        response.payload.sublist(1, 1 + contactLen),
      );
      expect(contact, 'contact@example.org'); // lint-allow: hardcoded-string
    });

    test('returns UNAUTHORIZED when identity not verified', () async {
      identityVerified = false;
      final request = _makeRequest(actionId: ProfileAction.getContactCard);
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.unauthorized.code);
    });

    test('returns UNAUTHORIZED when no identity checker', () async {
      handler = MrrpServiceProfile(configProvider: () => config);
      final request = _makeRequest(actionId: ProfileAction.getContactCard);
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.error);
      expect(response.payload[0], MrrpStatusCode.unauthorized.code);
    });
  });

  group('get_capabilities', () {
    test('returns service list and feature bitmaps', () async {
      final request = _makeRequest(actionId: ProfileAction.getCapabilities);
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.msgType, MrrpMessageType.response);

      final bd = ByteData.sublistView(response.payload);
      final sipFeatures = bd.getUint16(0, Endian.little);
      final mrrpFeatures = bd.getUint16(2, Endian.little);
      final serviceCount = response.payload[4];

      expect(sipFeatures, 0x0003);
      expect(mrrpFeatures, 0x0007);
      expect(serviceCount, 3);

      // Parse service IDs.
      final services = <int>[];
      for (var i = 0; i < serviceCount; i++) {
        services.add(bd.getUint32(5 + i * 4, Endian.little));
      }
      expect(services, contains(MrrpServiceId.meetupV1));
      expect(services, contains(MrrpServiceId.profileV1));
      expect(services, contains(MrrpServiceId.boardV1));
    });

    test('fits within MRRP_MAX_PAYLOAD', () async {
      final request = _makeRequest(actionId: ProfileAction.getCapabilities);
      final response = await handler.handleRequest(request, 0xABCD);
      expect(response.payloadLen, lessThanOrEqualTo(195));
    });
  });

  test('unsupported action returns ERROR', () async {
    final request = _makeRequest(actionId: 0xFFFF);
    final response = await handler.handleRequest(request, 0xABCD);
    expect(response.msgType, MrrpMessageType.error);
    expect(response.payload[0], MrrpStatusCode.unsupported.code);
  });
}
