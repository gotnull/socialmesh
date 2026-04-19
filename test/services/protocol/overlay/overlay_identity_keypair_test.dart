// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayIdentityKeypair].
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_identity_keypair.dart';

import '_overlay_link_test_harness.dart';

void main() {
  test('generates a fresh keypair on first init', () async {
    final storage = FakeSecureStorage();
    final kp = OverlayIdentityKeypair(storage: storage);
    expect(kp.isInitialized, isFalse);
    await kp.ensureInitialized();
    expect(kp.isInitialized, isTrue);
    expect(kp.publicKey().length, 32);
    expect(kp.publicKeyHint().length, 8);
  });

  test('subsequent init reloads the persisted keypair', () async {
    final storage = FakeSecureStorage();
    final first = OverlayIdentityKeypair(storage: storage);
    await first.ensureInitialized();
    final originalPub = first.publicKey();

    final second = OverlayIdentityKeypair(storage: storage);
    await second.ensureInitialized();
    expect(second.publicKey(), equals(originalPub));
  });

  test('sign produces a 64-byte signature that verifies', () async {
    final kp = OverlayIdentityKeypair(storage: FakeSecureStorage());
    await kp.ensureInitialized();

    final message = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
    final signature = await kp.sign(message);
    expect(signature.length, 64);
    final ok = await kp.verify(message, signature, kp.publicKey());
    expect(ok, isTrue);
  });

  test('verify rejects a tampered message', () async {
    final kp = OverlayIdentityKeypair(storage: FakeSecureStorage());
    await kp.ensureInitialized();

    final message = Uint8List.fromList(<int>[0xAA, 0xBB]);
    final signature = await kp.sign(message);
    final tampered = Uint8List.fromList(<int>[0xAA, 0xBC]);
    expect(await kp.verify(tampered, signature, kp.publicKey()), isFalse);
  });

  test('verify rejects signatures of wrong length (no throw)', () async {
    final kp = OverlayIdentityKeypair(storage: FakeSecureStorage());
    await kp.ensureInitialized();
    expect(
      await kp.verify(Uint8List(4), Uint8List(32), kp.publicKey()),
      isFalse,
    );
  });

  test('sign before init throws StateError', () {
    final kp = OverlayIdentityKeypair(storage: FakeSecureStorage());
    expect(() => kp.sign(Uint8List.fromList([1])), throwsStateError);
  });

  test('debugWipeForTest clears storage and forces regeneration', () async {
    final storage = FakeSecureStorage();
    final a = OverlayIdentityKeypair(storage: storage);
    await a.ensureInitialized();
    final originalPub = a.publicKey();

    await a.debugWipeForTest();
    final b = OverlayIdentityKeypair(storage: storage);
    await b.ensureInitialized();
    expect(b.publicKey(), isNot(equals(originalPub)));
  });
}
