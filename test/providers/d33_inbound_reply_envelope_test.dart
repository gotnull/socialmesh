// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D33 — provider-level inbound envelope routing tests.
//
// These exercise the chat-meta envelope helpers that the
// `MeshCoreConversationsNotifier` calls inline on every inbound
// contact / channel frame. We don't pump the notifier itself
// (that would require a Riverpod ProviderContainer + frame stream
// scaffolding); instead we drive `ChatMetaEnvelopeCodec.decode` +
// `ChatMetaReplyPayload.parse` directly with the same inputs the
// notifier sees, and assert the post-decode state is exactly what
// gets persisted.
//
// Pinned invariants:
//   - A wire body that decodes as a REPLY produces a stripped body
//     and a non-null `replyToMmf` matching the embedded target.
//   - A plain-text wire body produces the body verbatim and a null
//     `replyToMmf`.
//   - A malformed envelope falls through to plain text without
//     throwing.
//   - The own-message MMF derives correctly from inbound metadata
//     (channel: idx + ts; contact: senderPrefix + ts).
//   - Idempotency: re-decoding the same body produces the same
//     result, and the deterministic id used by the conversations
//     notifier is unchanged by the envelope decode.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_chat_meta_envelope.dart';

void main() {
  group('inbound channel reply routing', () {
    test('reply envelope produces stripped body + replyToMmf, '
        'while own MMF derives from channel + ts', () {
      final target = MeshCoreMmf.channel(
        channelIndex: 0,
        targetTimestampS: 0x67ABC100,
      );
      final wire = ChatMetaEnvelopeCodec.encodeReply(
        target: target,
        body: 'yes I agree',
        summary: 'Bob replied: yes I agree',
      );

      // Decode (mirrors the inbound handler's first step).
      final decoded = ChatMetaEnvelopeCodec.decode(wire);
      expect(decoded.envelope, isNotNull);
      expect(decoded.envelope!.op, ChatMetaOps.reply);

      final reply = ChatMetaReplyPayload.parse(decoded.envelope!.payload);
      expect(reply, isNotNull);
      expect(reply!.body, 'yes I agree');
      expect(
        reply.target.toStableString(),
        target.toStableString(),
        reason: 'target MMF round-trips byte-for-byte',
      );

      // What the provider would persist:
      final replyToMmf = reply.target.toStableString();
      final ownMmf = MeshCoreMmf.channel(
        channelIndex: 1,
        targetTimestampS: 0x67ABC1D2,
      ).toStableString();

      expect(replyToMmf, '01:00:67abc100');
      expect(ownMmf, '01:01:67abc1d2');
      // The two MMFs must be distinct (own ≠ target).
      expect(ownMmf, isNot(replyToMmf));
    });

    test('plain-text channel wire body keeps the body verbatim', () {
      const wire = 'a normal channel chat line';
      final decoded = ChatMetaEnvelopeCodec.decode(wire);
      expect(decoded.isPlainText, isTrue);
      expect(decoded.envelope, isNull);
      expect(decoded.displayText, wire);
    });

    test('malformed envelope (bad base64) falls through to plain text — '
        'no exception', () {
      const wire = '[mrrp]not_valid_base64!![/mrrp] human summary';
      final decoded = ChatMetaEnvelopeCodec.decode(wire);
      expect(decoded.isPlainText, isTrue);
      expect(decoded.envelope, isNull);
    });
  });

  group('inbound contact reply routing', () {
    test('reply envelope sets replyToMmf and own MMF derives from '
        'sender prefix + ts', () {
      final senderPrefix = Uint8List.fromList([
        0x79,
        0x42,
        0x6D,
        0x8D,
        0xB8,
        0xFD,
      ]);
      final target = MeshCoreMmf.contact(
        peerPubkeyPrefix: senderPrefix,
        targetTimestampS: 0x67ABC100,
      );
      final wire = ChatMetaEnvelopeCodec.encodeReply(
        target: target,
        body: 'on it',
        summary: 'Alice replied: on it',
      );

      final decoded = ChatMetaEnvelopeCodec.decode(wire);
      final reply = ChatMetaReplyPayload.parse(decoded.envelope!.payload);
      expect(reply!.body, 'on it');
      expect(reply.target.toStableString(), '02:79426d8db8fd:67abc100');

      // The receiver's own MMF for THIS message uses the SAME
      // sender prefix (because both ends use the OTHER party's
      // prefix on their respective sides). For the receiver, the
      // sender's prefix IS the other party.
      final ownMmf = MeshCoreMmf.contact(
        peerPubkeyPrefix: senderPrefix,
        targetTimestampS: 0x67ABC200,
      ).toStableString();
      expect(ownMmf, '02:79426d8db8fd:67abc200');
    });
  });

  group('idempotency', () {
    test('decoding the same wire body twice yields identical results', () {
      final target = MeshCoreMmf.channel(
        channelIndex: 3,
        targetTimestampS: 0xCAFEBABE,
      );
      final wire = ChatMetaEnvelopeCodec.encodeReply(
        target: target,
        body: 'idempotent',
        summary: 'Bob replied: idempotent',
      );
      final a = ChatMetaEnvelopeCodec.decode(wire);
      final b = ChatMetaEnvelopeCodec.decode(wire);
      expect(a.envelope!.op, b.envelope!.op);
      expect(a.envelope!.payload, b.envelope!.payload);
      expect(a.envelope!.summary, b.envelope!.summary);
    });

    test('the existing D19 deterministic id is unchanged by envelope '
        'decode (still derived from the original wire text)', () {
      final target = MeshCoreMmf.channel(
        channelIndex: 0,
        targetTimestampS: 0x67ABC100,
      );
      final wire = ChatMetaEnvelopeCodec.encodeReply(
        target: target,
        body: 'X',
        summary: 'Bob replied: X',
      );
      final ts = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      // The provider derives id from the RAW wire text. Two
      // identical inbound frames produce the same id regardless
      // of envelope decode outcome.
      final id1 = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: ts,
        text: wire,
      );
      final id2 = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: ts,
        text: wire,
      );
      expect(id1, id2);
      // And the id is structurally what the dedupe layer expects.
      expect(id1, startsWith('mc_in_ch_0_'));
    });
  });

  group('MeshCoreMessage model surface', () {
    test('mmf and replyToMmf round-trip through copyWith', () {
      final m = MeshCoreMessage(
        id: 'x',
        text: 'reply body',
        timestamp: DateTime(2026, 5, 7),
        isOutgoing: false,
        status: MeshCoreMessageDeliveryStatus.delivered,
        mmf: '01:00:67abc1d2',
        replyToMmf: '01:00:67abc100',
      );

      final flipped = m.copyWith(status: MeshCoreMessageDeliveryStatus.sent);
      expect(flipped.mmf, '01:00:67abc1d2');
      expect(flipped.replyToMmf, '01:00:67abc100');
      expect(flipped.status, MeshCoreMessageDeliveryStatus.sent);

      final overridden = m.copyWith(replyToMmf: '01:00:00000000');
      expect(overridden.replyToMmf, '01:00:00000000');
      expect(overridden.mmf, '01:00:67abc1d2');
    });
  });
}
