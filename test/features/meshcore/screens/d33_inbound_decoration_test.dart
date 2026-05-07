// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D33 — chat screen live-inbound decoration tests.
//
// Pins the gap that surfaced in the 2026-05-07 live smoke: the chat
// screen's in-memory inbound bubble was being constructed without
// decoding the chat-meta envelope or stamping `mmf`, so the
// long-press Reply action stayed hidden on a freshly-received
// message until the chat closed and reloaded from the persisted
// store. After the post-0fab0026 fix the chat-screen handlers route
// through `meshCoreInboundContactDecoration` /
// `meshCoreInboundChannelDecoration`, mirroring the provider's
// decode + author-prefix MMF stamp 1:1.
//
// These tests cover the helpers directly. The widget-level
// "Reply visible immediately" check rides on the existing reply
// chat-screen tests + the live smoke; what we pin here is that the
// helper produces the right (displayText, mmf, replyToMmf) record
// for the four scope x envelope combinations.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_chat_screen.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_chat_meta_envelope.dart';

void main() {
  group('meshCoreInboundContactDecoration', () {
    test('plain text inbound stamps mmf with the AUTHOR (sender) prefix '
        'and leaves displayText / replyToMmf untouched', () {
      // 96458be0b1c5 = the iPhone-side test prefix from the 2026-05-07
      // smoke. The decoration must derive `02:96458be0b1c5:<ts>` —
      // post-0fab0026 author-prefix rule.
      final ts = DateTime.fromMillisecondsSinceEpoch(0x69fc1420 * 1000);
      final deco = meshCoreInboundContactDecoration(
        text: 'smoke test 1',
        timestamp: ts,
        senderPrefixHex: '96458be0b1c5',
      );
      expect(deco.displayText, 'smoke test 1');
      expect(deco.mmf, '02:96458be0b1c5:69fc1420');
      expect(deco.replyToMmf, isNull);
    });

    test('REPLY envelope inbound strips the [mrrp] wrapper from displayText, '
        'sets replyToMmf to the embedded target, and stamps own mmf with '
        'the sender prefix', () {
      final target = MeshCoreMmf.contact(
        peerPubkeyPrefix: Uint8List.fromList([
          0x96,
          0x45,
          0x8b,
          0xe0,
          0xb1,
          0xc5,
        ]),
        targetTimestampS: 0x69fbca03,
      );
      // Build a real wire body via the canonical encoder so we exercise
      // the full decode path end-to-end (no test-only shortcuts).
      final wireBody = ChatMetaEnvelopeCodec.encodeReply(
        target: target,
        body: 'ack',
        summary: 'TerryDev2 replied: ack',
      );
      // Sanity: the wire body must contain the literal [mrrp] wrapper —
      // that's what we expect the decoration to strip.
      expect(wireBody, contains('[mrrp]'));
      expect(wireBody, contains('[/mrrp]'));

      final ts = DateTime.fromMillisecondsSinceEpoch(0x69fc34bf * 1000);
      final deco = meshCoreInboundContactDecoration(
        text: wireBody,
        timestamp: ts,
        senderPrefixHex: '79426d8dbb8f',
      );
      expect(
        deco.displayText,
        'ack',
        reason: 'envelope must be stripped, leaving only the reply body',
      );
      expect(
        deco.displayText,
        isNot(contains('[mrrp]')),
        reason: 'raw envelope wrapper must NEVER reach the bubble',
      );
      expect(
        deco.mmf,
        '02:79426d8dbb8f:69fc34bf',
        reason: 'own mmf uses the AUTHOR prefix (= senderPrefixHex on inbound)',
      );
      expect(
        deco.replyToMmf,
        '02:96458be0b1c5:69fbca03',
        reason: 'replyToMmf must equal the embedded reply target',
      );
    });

    test('inbound with malformed senderPrefixHex leaves mmf null '
        '(callers fall through to a non-reply-able bubble until reload)', () {
      final deco = meshCoreInboundContactDecoration(
        text: 'hi',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0x69fc1420 * 1000),
        // 5 bytes (10 hex chars) — short of the required 6.
        senderPrefixHex: 'aabbccddee',
      );
      expect(deco.mmf, isNull);
      expect(deco.displayText, 'hi');
      expect(deco.replyToMmf, isNull);
    });
  });

  group('meshCoreInboundChannelDecoration', () {
    test('plain text inbound stamps mmf with channel_idx + target_ts '
        'and leaves displayText / replyToMmf untouched', () {
      final ts = DateTime.fromMillisecondsSinceEpoch(0x69fc1420 * 1000);
      final deco = meshCoreInboundChannelDecoration(
        text: 'channel ping',
        timestamp: ts,
        channelIndex: 3,
      );
      expect(deco.displayText, 'channel ping');
      expect(deco.mmf, '01:03:69fc1420');
      expect(deco.replyToMmf, isNull);
    });

    test('REPLY envelope on channel strips wrapper, sets replyToMmf, '
        'and stamps own channel mmf', () {
      final target = MeshCoreMmf.channel(
        channelIndex: 0,
        targetTimestampS: 0x65540340,
      );
      final wireBody = ChatMetaEnvelopeCodec.encodeReply(
        target: target,
        body: 'roger',
        summary: 'Sim replied: roger',
      );
      expect(wireBody, contains('[mrrp]'));

      final ts = DateTime.fromMillisecondsSinceEpoch(0x69fc34bf * 1000);
      final deco = meshCoreInboundChannelDecoration(
        text: wireBody,
        timestamp: ts,
        channelIndex: 0,
      );
      expect(deco.displayText, 'roger');
      expect(deco.displayText, isNot(contains('[mrrp]')));
      expect(deco.mmf, '01:00:69fc34bf');
      expect(deco.replyToMmf, '01:00:65540340');
    });
  });
}
