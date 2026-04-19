// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayEndpointId] — SHA-256 truncated derivation.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_id.dart';

Uint8List _mkKey(int seed) {
  final out = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    out[i] = (seed * 31 + i) & 0xFF;
  }
  return out;
}

void main() {
  test('derive returns 8 bytes', () async {
    final id = await OverlayEndpointId.derive(personaPubKey: _mkKey(1));
    expect(id.length, 8);
  });

  test('derive is deterministic for same key + service_id', () async {
    final k = _mkKey(7);
    final a = await OverlayEndpointId.derive(personaPubKey: k, serviceId: 0);
    final b = await OverlayEndpointId.derive(personaPubKey: k, serviceId: 0);
    expect(a, equals(b));
  });

  test(
    'different service_id yields different endpointId for same key',
    () async {
      final k = _mkKey(42);
      final a = await OverlayEndpointId.derive(personaPubKey: k, serviceId: 0);
      final b = await OverlayEndpointId.derive(personaPubKey: k, serviceId: 1);
      expect(a, isNot(equals(b)));
    },
  );

  test(
    'different keys yield different endpointIds (high probability)',
    () async {
      final a = await OverlayEndpointId.deriveRoot(_mkKey(1));
      final b = await OverlayEndpointId.deriveRoot(_mkKey(2));
      expect(a, isNot(equals(b)));
    },
  );

  test('personaHint is 8 bytes and deterministic', () async {
    final k = _mkKey(99);
    final a = await OverlayEndpointId.personaHint(k);
    final b = await OverlayEndpointId.personaHint(k);
    expect(a.length, 8);
    expect(a, equals(b));
  });

  test('derive rejects wrong-length pubkey', () {
    expect(
      () => OverlayEndpointId.derive(personaPubKey: Uint8List(16)),
      throwsArgumentError,
    );
  });

  test('derive rejects out-of-range service_id', () {
    expect(
      () => OverlayEndpointId.derive(personaPubKey: _mkKey(1), serviceId: -1),
      throwsArgumentError,
    );
    expect(
      () => OverlayEndpointId.derive(
        personaPubKey: _mkKey(1),
        serviceId: 0x1_0000_0000,
      ),
      throwsArgumentError,
    );
  });
}
