// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The advert packet CMD_EXPORT_CONTACT returns, captured on 24th Nov 2026
// from a Heltec Tracker V2 (MeshCore v1.18.0) exporting the RAK4631
// "WisMeshCore" contact it had just heard.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_advert_packet.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_contact_url.dart';

const _capturedUrl =
    'meshcore://110096458be0b1c55901f07463099ade0b7523f8d40f58a614f3dfd3a6b2e877e3127c0d056b032c7e4da3bb05ec4921a608289436074e3109731fac64637b699bd8a5c4be5bc8c9615328e5a75f4b36182b6b34e21a16cc218c20d6411faeec821f53d4e40e815769734d657368436f7265';

void main() {
  test('a captured export decodes and parses as the contact it carries', () {
    final packet = MeshCoreContactUrl.decode(_capturedUrl);
    expect(packet, isNotNull);

    final advert = MeshCoreAdvertPacket.parse(packet!)!;
    expect(advert.name, 'WisMeshCore');
    expect(advert.advType, 1);
    expect(advert.timestamp, 1795493244);
    expect(advert.publicKey.first, 0x96);
    expect(advert.latitude, isNull);
    expect(advert.longitude, isNull);
  });

  test('the captured packet round-trips through encode', () {
    final packet = MeshCoreContactUrl.decode(_capturedUrl)!;
    expect(MeshCoreContactUrl.encode(packet), _capturedUrl);
  });

  test('a non-advert packet is rejected', () {
    final packet = Uint8List.fromList(MeshCoreContactUrl.decode(_capturedUrl)!);
    packet[0] = 0x09; // payload type 2 (text message), flood route
    expect(MeshCoreAdvertPacket.parse(packet), isNull);
  });

  test('a packet shorter than an advert is rejected', () {
    expect(MeshCoreAdvertPacket.parse(Uint8List(97)), isNull);
    expect(MeshCoreContactUrl.decode('meshcore://${'00' * 97}'), isNull);
  });
}
