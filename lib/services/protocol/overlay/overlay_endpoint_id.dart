// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Deterministic derivation of the 8-byte overlay endpoint ID.
///
/// Per `docs/sip/OVERLAY_V0_2.md` §9.2:
/// ```
/// endpointId = SHA-256(persona_pub ‖ u32_be(service_id))[:8]
/// ```
///
/// The derivation is identity-scoped-by-service. `service_id = 0`
/// denotes the root identity (no service scoping). Same `persona_pub`
/// + different `service_id` ⇒ different endpointId — this is
/// intentional and enables service-scoped destinations without
/// leaking the persona across services.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Derive an 8-byte endpoint ID. Synchronous-looking API for tests;
/// internally async because the SHA-256 implementation is async.
abstract final class OverlayEndpointId {
  /// Width of an endpoint ID in bytes.
  static const int length = 8;

  /// `service_id` sentinel for the root (unscoped) endpoint.
  static const int rootServiceId = 0;

  /// Compute the endpoint ID.
  ///
  /// [personaPubKey] MUST be 32 bytes (Ed25519 public key).
  /// [serviceId] is a u32; values outside `[0, 0xFFFFFFFF]` throw.
  static Future<Uint8List> derive({
    required Uint8List personaPubKey,
    int serviceId = rootServiceId,
  }) async {
    if (personaPubKey.length != 32) {
      throw ArgumentError.value(
        personaPubKey.length,
        'personaPubKey.length',
        'Ed25519 public key must be exactly 32 bytes',
      );
    }
    if (serviceId < 0 || serviceId > 0xFFFFFFFF) {
      throw ArgumentError.value(serviceId, 'serviceId', 'must fit in u32');
    }
    final buffer = Uint8List(32 + 4);
    buffer.setRange(0, 32, personaPubKey);
    final bd = ByteData.view(buffer.buffer);
    bd.setUint32(32, serviceId); // big-endian per spec
    final hash = await Sha256().hash(buffer);
    return Uint8List.fromList(hash.bytes.sublist(0, length));
  }

  /// Convenience: derive for the root service (service_id = 0).
  static Future<Uint8List> deriveRoot(Uint8List personaPubKey) =>
      derive(personaPubKey: personaPubKey, serviceId: rootServiceId);

  /// 8-byte persona hint = `SHA-256(personaPubKey)[:8]`. Kept
  /// separate from [derive] so callers distinguish scoped endpoint
  /// IDs from the raw persona hint used elsewhere in SocialMesh.
  static Future<Uint8List> personaHint(Uint8List personaPubKey) async {
    if (personaPubKey.length != 32) {
      throw ArgumentError.value(
        personaPubKey.length,
        'personaPubKey.length',
        'Ed25519 public key must be exactly 32 bytes',
      );
    }
    final hash = await Sha256().hash(personaPubKey);
    return Uint8List.fromList(hash.bytes.sublist(0, 8));
  }
}
