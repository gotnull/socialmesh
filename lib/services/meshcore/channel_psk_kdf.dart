// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore channel PSK helpers (D34d).
//
// Two ways to populate the 16-byte (128-bit) AES PSK firmware expects on a
// channel slot, both designed for the canonical channel edit sheet:
//
//   1. [randomPsk]            — `Random.secure()` 16 bytes for a one-off
//                              private channel.
//   2. [derivePskFromPassphrase] — HMAC-SHA256 of a UTF-8 passphrase under a
//                              SocialMesh-internal label. Deterministic so two
//                              users can agree on a passphrase out-of-band and
//                              both derive the same PSK without exchanging hex.
//
// Wire format is unchanged. The firmware still receives a raw 16-byte PSK via
// `CMD_SET_CHANNEL` (D31). These helpers only generate the bytes.
//
// Privacy:
//   - Passphrases are never persisted.
//   - PSKs and passphrases must NEVER be logged. Callers that pass derived
//     bytes through Settings tiles / snackbars must surface only the
//     formatted hex inside the PSK form field, not in any log line.
//
// Intentional divergence from the upstream meshcore-open reference: the label
// "socialmesh.meshcore.channel.v1" is SocialMesh-internal and does not
// participate in any community-secret exchange. SocialMesh has no shared
// community_secret model; passphrase-derived channels are coordinated
// out-of-band by the participants.
//
// All callers go through the [formatPskHex] helper to produce the lowercase
// 32-char hex form the firmware setter / channel-code parser expects.
//
// Tests pin one passphrase byte vector + length / lowercase invariants in
// `test/services/meshcore/channel_psk_kdf_test.dart`.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Length of the AES-128 PSK the MeshCore firmware writes per channel slot.
const int kMeshCoreChannelPskBytes = 16;

/// HMAC label used by [derivePskFromPassphrase]. Versioned so a future v2
/// derivation can land alongside without breaking existing channels created
/// against this label.
const String kMeshCoreChannelKdfLabel = 'socialmesh.meshcore.channel.v1';

/// Generate a fresh 16-byte PSK from `Random.secure()`. Cryptographically
/// random; non-deterministic across calls.
Uint8List randomPsk() {
  final rng = Random.secure();
  final out = Uint8List(kMeshCoreChannelPskBytes);
  for (int i = 0; i < kMeshCoreChannelPskBytes; i++) {
    out[i] = rng.nextInt(256);
  }
  return out;
}

/// Derive a 16-byte PSK from a UTF-8 passphrase via
/// `HMAC-SHA256(kMeshCoreChannelKdfLabel, passphrase)[:16]`.
///
/// Two devices that enter the same passphrase land on the same PSK without
/// having to type out the 32 hex characters. The label keeps this derivation
/// distinct from any future SocialMesh KDF that reuses the same passphrase.
///
/// Throws [ArgumentError] when the passphrase is empty or contains only
/// whitespace. Surrounding whitespace is preserved on a non-empty passphrase
/// because some passphrases legitimately end in a space (e.g. mnemonic-style
/// "alpha bravo "). Callers should sanitise UI-side if they want to enforce
/// trimmed input.
Uint8List derivePskFromPassphrase(String passphrase) {
  if (passphrase.trim().isEmpty) {
    throw ArgumentError.value(
      passphrase,
      'passphrase',
      'must not be empty or whitespace-only',
    );
  }
  final hmac = Hmac(sha256, utf8.encode(kMeshCoreChannelKdfLabel));
  final digest = hmac.convert(utf8.encode(passphrase));
  final bytes = Uint8List.fromList(digest.bytes);
  return Uint8List.sublistView(bytes, 0, kMeshCoreChannelPskBytes);
}

/// Format a 16-byte PSK as 32 lowercase hex characters — the form the
/// channel edit sheet's PSK field, the channel-code share format, and the
/// firmware setter all expect.
///
/// Throws [ArgumentError] if [bytes] is not exactly 16 bytes long; callers
/// that work with arbitrary buffers must slice or pad before formatting.
String formatPskHex(Uint8List bytes) {
  if (bytes.length != kMeshCoreChannelPskBytes) {
    throw ArgumentError.value(
      bytes.length,
      'bytes.length',
      'must be exactly $kMeshCoreChannelPskBytes',
    );
  }
  final sb = StringBuffer();
  for (final b in bytes) {
    final h = b.toRadixString(16);
    if (h.length == 1) sb.write('0');
    sb.write(h);
  }
  return sb.toString();
}
