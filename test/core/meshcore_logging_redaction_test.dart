// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Sanitization regression test for AppLogging.meshcore.
//
// Builds canonical "secret" inputs (a known plaintext, a full public key,
// a 16-byte PSK), drives the channel through framePreview /
// publicKeyFingerprint / coordRedact and direct event lines, then asserts
// no secret substring leaks into the captured sink output.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/logging.dart';

void main() {
  group('AppLogging.meshcore secret-blacklist regression', () {
    // Canonical fakes — none of these substrings must appear in any sink
    // entry produced by the helpers below.
    const plaintext = 'this-is-a-secret-message-payload';
    final fullKey = Uint8List.fromList(List.generate(32, (i) => 0xa0 + i));
    final fullKeyHex = fullKey
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final psk = Uint8List.fromList(List.generate(16, (i) => 0x70 + i));
    final pskHex = psk.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    late List<String> sinkLines;

    setUp(() {
      AppLogging.reset();
      sinkLines = [];
      AppLogging.setAppLogSink((level, source, message) {
        sinkLines.add('[$level] [$source] $message');
      });
    });

    tearDown(() {
      AppLogging.reset();
    });

    test('helpers never emit full plaintext / pk / psk', () {
      // Drive every redaction helper.
      AppLogging.meshcore(
        'event=identify.succeeded '
        'pk=${AppLogging.publicKeyFingerprint(fullKey)} '
        'node=${AppLogging.nodeIdShort(0xdeadbeef)}',
      );
      AppLogging.meshcore(
        'event=psk.observed fp=${AppLogging.pskFingerprint(psk)}',
      );
      AppLogging.meshcore(
        'event=codec.frame.decode_error '
        '${AppLogging.framePreview(List.generate(200, (i) => i))}',
        error: true,
      );
      AppLogging.meshcore(
        'event=position.observed coord=${AppLogging.coordRedact(37.77, -122.42)}',
      );

      final joined = sinkLines.join('\n');

      // Plaintext is never emitted by any helper, but assert anyway as a
      // standing guard for future helpers.
      expect(
        joined.contains(plaintext),
        isFalse,
        reason: 'plaintext leaked into log',
      );

      // Full public-key hex must never appear (only fingerprint).
      expect(
        joined.contains(fullKeyHex),
        isFalse,
        reason: 'full public key hex leaked',
      );

      // Full PSK hex must never appear.
      expect(joined.contains(pskHex), isFalse, reason: 'full PSK hex leaked');

      // GPS coords are gated off in test env → must show "redacted".
      expect(joined.contains('coord=redacted'), isTrue);
      expect(joined.contains('37.77'), isFalse);
      expect(joined.contains('-122.42'), isFalse);
    });

    test('publicKeyFingerprint preview shape matches spec', () {
      AppLogging.meshcore(
        'event=test pk=${AppLogging.publicKeyFingerprint(fullKey)}',
      );
      // Expect the format: pk=32B:<8hex>…<8hex>
      expect(sinkLines.single, matches(r'pk=32B:[0-9a-f]{8}…[0-9a-f]{8}'));
    });

    test('framePreview never emits more than 32 bytes of hex', () {
      final bytes = List.generate(500, (i) => 0xff);
      AppLogging.meshcore(
        'event=test ${AppLogging.framePreview(bytes, max: 1024)}',
      );
      final line = sinkLines.single;
      // Count hex pairs (XX) in the head section.
      final head = line.split('head=').last.split(' …').first;
      final pairs = head.split(' ').where((s) => s.isNotEmpty).length;
      expect(pairs, lessThanOrEqualTo(32));
    });

    test('empty pk fingerprint yields canonical 0B:none', () {
      // Helpers never log endpoint host/port/credentials by themselves;
      // confirm they do not silently echo arbitrary input fragments.
      AppLogging.meshcore(
        'event=test pk=${AppLogging.publicKeyFingerprint([])}',
      );
      expect(sinkLines.single, contains('event=test pk=0B:none'));
    });

    // D21.A: pin the redacted `target=` fingerprint format that
    // `event=message.send.attempted type=contact` emits. Without
    // this attribution we couldn't tell from the iPhone log which
    // peer was being targeted, which left the D20 `0x82` ack-source
    // ambiguous. The fingerprint must reuse `publicKeyFingerprint`
    // and never leak full pubkey bytes.
    test('contact send.attempted log emits redacted target=', () {
      const sizeBytes = 12;
      AppLogging.meshcore(
        'event=message.send.attempted type=contact size=$sizeBytes '
        'target=${AppLogging.publicKeyFingerprint(fullKey)}',
      );
      final line = sinkLines.single;

      // Required shape pieces:
      expect(line, contains('event=message.send.attempted'));
      expect(line, contains('type=contact'));
      expect(line, contains('size=12'));
      expect(line, contains('target='));
      expect(line, matches(r'target=32B:[0-9a-f]{8}…[0-9a-f]{8}'));

      // Full pubkey hex must never leak.
      expect(line.contains(fullKeyHex), isFalse);
    });

    test('channel send.attempted log does NOT include target=', () {
      // Channels are flooded with no per-recipient ack, so target
      // attribution doesn't apply. The chat-screen branch skips it.
      const sizeBytes = 7;
      AppLogging.meshcore(
        'event=message.send.attempted type=channel size=$sizeBytes',
      );
      final line = sinkLines.single;
      expect(line, contains('type=channel'));
      expect(line, isNot(contains('target=')));
    });

    // D20.C: pin the unambiguous `name_len=N` redaction format. The
    // previous `name=Nc` shape (where the trailing `c` meant
    // "characters") was misread as a literal short-name value
    // during D20 recon. Switch is intentional and tested.
    test('node name length redaction uses unambiguous name_len=N', () {
      const nodeName = 'WisMeshCore';
      AppLogging.meshcore(
        'event=identify.succeeded '
        'pk=${AppLogging.publicKeyFingerprint(fullKey)} '
        'name_len=${nodeName.length}',
      );
      final joined = sinkLines.join('\n');

      // Length value present.
      expect(
        joined.contains('name_len=11'),
        isTrue,
        reason: 'expected name_len=N format',
      );
      // Old ambiguous shape must never reappear.
      expect(
        joined.contains('name=11c'),
        isFalse,
        reason: 'old ambiguous name=Nc format must not be reintroduced',
      );
      // Plaintext name itself must never leak.
      expect(joined.contains(nodeName), isFalse);
    });
  });
}
