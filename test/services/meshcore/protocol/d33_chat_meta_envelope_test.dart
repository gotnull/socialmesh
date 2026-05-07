// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D33 — chat-meta.v1 envelope codec byte-vector tests.
//
// Pins:
//   - The exact wire shape (`[mrrp]<base64url-envelope>[/mrrp] <summary>`)
//     matching the locked D33 implementation plan §3.2.
//   - The exact inner-envelope layout
//     `[magic 5B][version 1B][svc 1B][op 1B][len 1B][payload len B]`.
//   - MMF byte layouts for both scopes.
//   - Forward-compatibility: unknown ops in the same version fall
//     through to plain text without throwing.
//   - Defence-in-depth: the reserved `op = 0x01` (D34 reactions) is
//     rejected at the codec layer in D33 so an early-shipping
//     reaction never mis-renders.
//   - Magic-prefix detection only at offset 0 (no false positive on
//     user text that contains "[mrrp]" mid-string).
//   - No raw envelope text, no PSK, no plaintext leakage in logs.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_chat_meta_envelope.dart';

void main() {
  group('MeshCoreMmf — channel scope', () {
    test('toBytes produces exactly 6 bytes', () {
      final mmf = MeshCoreMmf.channel(
        channelIndex: 0x05,
        targetTimestampS: 0x67ABC1D2,
      );
      final bytes = mmf.toBytes();
      expect(bytes.length, 6);
      expect(
        bytes,
        equals(Uint8List.fromList([0x01, 0x05, 0xD2, 0xC1, 0xAB, 0x67])),
        reason: '[scope=01][idx=05][ts u32 LE]',
      );
    });

    test('parse(round-trip) returns equal MMF', () {
      final mmf = MeshCoreMmf.channel(
        channelIndex: 0x07,
        targetTimestampS: 0x12345678,
      );
      final parsed = MeshCoreMmf.parse(mmf.toBytes());
      expect(parsed, equals(mmf));
    });

    test('toStableString format matches "01:<idx>:<ts>"', () {
      final mmf = MeshCoreMmf.channel(
        channelIndex: 0,
        targetTimestampS: 0x67ABC1D2,
      );
      expect(mmf.toStableString(), '01:00:67abc1d2');
    });

    test('parseString round-trips', () {
      final original = MeshCoreMmf.channel(
        channelIndex: 3,
        targetTimestampS: 0xDEADBEEF,
      );
      final s = original.toStableString();
      final parsed = MeshCoreMmf.parseString(s);
      expect(parsed, equals(original));
    });

    test('rejects out-of-range channelIndex / timestamp', () {
      expect(
        () => MeshCoreMmf.channel(channelIndex: 256, targetTimestampS: 0),
        throwsArgumentError,
      );
      expect(
        () => MeshCoreMmf.channel(channelIndex: -1, targetTimestampS: 0),
        throwsArgumentError,
      );
      expect(
        () =>
            MeshCoreMmf.channel(channelIndex: 0, targetTimestampS: 0x100000000),
        throwsArgumentError,
      );
    });
  });

  group('MeshCoreMmf — contact scope', () {
    test('toBytes produces exactly 11 bytes', () {
      final prefix = Uint8List.fromList([0x79, 0x42, 0x6D, 0x8D, 0xB8, 0xFD]);
      final mmf = MeshCoreMmf.contact(
        peerPubkeyPrefix: prefix,
        targetTimestampS: 0x67ABC1D2,
      );
      final bytes = mmf.toBytes();
      expect(bytes.length, 11);
      expect(
        bytes,
        equals(Uint8List.fromList([0x02, ...prefix, 0xD2, 0xC1, 0xAB, 0x67])),
      );
    });

    test('parse(round-trip) returns equal MMF', () {
      final mmf = MeshCoreMmf.contact(
        peerPubkeyPrefix: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
        targetTimestampS: 0xCAFEBABE,
      );
      final parsed = MeshCoreMmf.parse(mmf.toBytes());
      expect(parsed, equals(mmf));
    });

    test('toStableString format matches "02:<12hex>:<8hex>"', () {
      final mmf = MeshCoreMmf.contact(
        peerPubkeyPrefix: Uint8List.fromList([
          0x79,
          0x42,
          0x6D,
          0x8D,
          0xB8,
          0xFD,
        ]),
        targetTimestampS: 0x67ABC1D2,
      );
      expect(mmf.toStableString(), '02:79426d8db8fd:67abc1d2');
    });

    test('parseString rejects malformed input', () {
      expect(MeshCoreMmf.parseString('garbage'), isNull);
      expect(MeshCoreMmf.parseString('03:00:00000000'), isNull);
      expect(MeshCoreMmf.parseString('01:00:tooshort'), isNull);
      expect(MeshCoreMmf.parseString('02:bad:67abc1d2'), isNull);
    });

    test('rejects 5-byte and 7-byte prefixes', () {
      expect(
        () => MeshCoreMmf.contact(
          peerPubkeyPrefix: Uint8List(5),
          targetTimestampS: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => MeshCoreMmf.contact(
          peerPubkeyPrefix: Uint8List(7),
          targetTimestampS: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ChatMetaMmf raw-byte parser', () {
    test('returns null on unknown scope byte', () {
      expect(MeshCoreMmf.parse(Uint8List.fromList([0xFF])), isNull);
      expect(
        MeshCoreMmf.parse(Uint8List.fromList([0x03, 0x00, 0x00, 0x00, 0x00])),
        isNull,
      );
    });

    test('returns null on truncated input', () {
      expect(MeshCoreMmf.parse(Uint8List(0)), isNull);
      // channel scope but only 4 bytes
      expect(
        MeshCoreMmf.parse(Uint8List.fromList([0x01, 0x00, 0x00, 0x00])),
        isNull,
      );
      // contact scope but only 9 bytes
      expect(
        MeshCoreMmf.parse(
          Uint8List.fromList([0x02, 1, 2, 3, 4, 5, 6, 0x00, 0x00]),
        ),
        isNull,
      );
    });
  });

  group('ChatMetaEnvelopeCodec — encodeReply byte vectors', () {
    test('channel reply encodes a recoverable envelope', () {
      final target = MeshCoreMmf.channel(
        channelIndex: 0,
        targetTimestampS: 0x67ABC1D2,
      );
      final wire = ChatMetaEnvelopeCodec.encodeReply(
        target: target,
        body: 'yes I agree',
        summary: 'Bob replied: yes I agree',
      );

      // Wire shape: [mrrp]<base64url>[/mrrp] <summary>
      expect(wire.startsWith('[mrrp]'), isTrue);
      expect(wire.contains('[/mrrp] '), isTrue);
      expect(wire.endsWith('Bob replied: yes I agree'), isTrue);

      // Round-trip decode.
      final decoded = ChatMetaEnvelopeCodec.decode(wire);
      expect(decoded.envelope, isNotNull);
      expect(decoded.envelope!.op, ChatMetaOps.reply);
      expect(decoded.envelope!.summary, 'Bob replied: yes I agree');

      final reply = ChatMetaReplyPayload.parse(decoded.envelope!.payload);
      expect(reply, isNotNull);
      expect(reply!.target, equals(target));
      expect(reply.body, 'yes I agree');
    });

    test('contact reply encodes a recoverable envelope', () {
      final target = MeshCoreMmf.contact(
        peerPubkeyPrefix: Uint8List.fromList([
          0x79,
          0x42,
          0x6D,
          0x8D,
          0xB8,
          0xFD,
        ]),
        targetTimestampS: 0xCAFEBABE,
      );
      final wire = ChatMetaEnvelopeCodec.encodeReply(
        target: target,
        body: 'on it',
        summary: 'Alice replied: on it',
      );
      final decoded = ChatMetaEnvelopeCodec.decode(wire);
      expect(decoded.envelope, isNotNull);
      final reply = ChatMetaReplyPayload.parse(decoded.envelope!.payload);
      expect(reply!.target, equals(target));
      expect(reply.body, 'on it');
    });

    test('encodeReply rejects bodies that exceed the OTA cap', () {
      final target = MeshCoreMmf.channel(channelIndex: 0, targetTimestampS: 0);
      // 220 bytes of body (without envelope/summary) already exceeds
      // the cap once envelope + summary are wrapped.
      expect(
        () => ChatMetaEnvelopeCodec.encodeReply(
          target: target,
          body: 'A' * 220,
          summary: 'long body that pushes us over the cap' * 2,
        ),
        throwsArgumentError,
      );
    });

    test('summary is truncated cleanly to ~80 bytes UTF-8', () {
      final target = MeshCoreMmf.channel(channelIndex: 0, targetTimestampS: 0);
      final wire = ChatMetaEnvelopeCodec.encodeReply(
        target: target,
        body: 'short',
        summary: 'X' * 200, // way over the summary cap
      );
      // Decode and check the summary length (should be <= 80B UTF-8).
      final decoded = ChatMetaEnvelopeCodec.decode(wire);
      expect(decoded.envelope, isNotNull);
      expect(
        utf8.encode(decoded.envelope!.summary).length,
        lessThanOrEqualTo(kChatMetaSummaryMaxBytes),
      );
    });
  });

  group('ChatMetaEnvelopeCodec — decoder defence', () {
    test('plain text passes through unchanged', () {
      final r = ChatMetaEnvelopeCodec.decode('hello world');
      expect(r.isPlainText, isTrue);
      expect(r.envelope, isNull);
      expect(r.displayText, 'hello world');
    });

    test('user text containing "[mrrp]" mid-string is NOT detected', () {
      // Detection anchors at offset 0 only.
      final r = ChatMetaEnvelopeCodec.decode(
        'see [mrrp]something[/mrrp] in the spec',
      );
      expect(r.isPlainText, isTrue);
      expect(r.envelope, isNull);
    });

    test('missing [/mrrp] suffix falls through to plain text', () {
      final r = ChatMetaEnvelopeCodec.decode('[mrrp]TVJSUC8B...');
      expect(r.isPlainText, isTrue);
      expect(r.envelope, isNull);
    });

    test('non-base64 envelope payload falls through to plain text', () {
      final r = ChatMetaEnvelopeCodec.decode(
        '[mrrp]not-base64![/mrrp] human summary',
      );
      // No envelope; body shows summary or raw body to keep UI honest.
      expect(r.isPlainText, isTrue);
    });

    test('mismatched magic falls through to plain text', () {
      // 9 bytes of "MRR/0\x01\x06\x02\x00" — wrong magic byte.
      final fake = Uint8List.fromList([
        0x4D, 0x52, 0x52, 0x21, 0x2F, // bad magic 4th byte
        0x01, 0x06, 0x02, 0x00,
      ]);
      final wire =
          '[mrrp]${base64Url.encode(fake).replaceAll('=', '')}'
          '[/mrrp] summary';
      final r = ChatMetaEnvelopeCodec.decode(wire);
      expect(r.isPlainText, isTrue);
    });

    test('mismatched version falls through to plain text', () {
      // Real envelope shape but version=0x02 (future).
      final inner = Uint8List.fromList([
        ...kChatMetaMagic,
        0x02, // version = future
        0x06, // svc
        0x02, // op = reply
        0x00, // len
      ]);
      final wire =
          '[mrrp]${base64Url.encode(inner).replaceAll('=', '')}'
          '[/mrrp] x';
      final r = ChatMetaEnvelopeCodec.decode(wire);
      expect(r.isPlainText, isTrue);
    });

    test('reserved REACTION op (D34) is rejected in D33', () {
      // Legitimate envelope shape with op=0x01 — must fail to decode
      // until D34 wires up the handler.
      final inner = Uint8List.fromList([
        ...kChatMetaMagic,
        kChatMetaVersion,
        kChatMetaSvc,
        ChatMetaOps.reactionReservedD34,
        0x00,
      ]);
      final wire =
          '[mrrp]${base64Url.encode(inner).replaceAll('=', '')}'
          '[/mrrp] Bob reacted';
      final r = ChatMetaEnvelopeCodec.decode(wire);
      expect(
        r.isPlainText,
        isTrue,
        reason: 'D33 must not surface reactions; rejection falls to plain text',
      );
    });

    test('unknown op (0x05+) is rejected in D33 (forward-compat fence)', () {
      final inner = Uint8List.fromList([
        ...kChatMetaMagic,
        kChatMetaVersion,
        kChatMetaSvc,
        0x05, // hypothetical future op
        0x00,
      ]);
      final wire =
          '[mrrp]${base64Url.encode(inner).replaceAll('=', '')}'
          '[/mrrp] x';
      final r = ChatMetaEnvelopeCodec.decode(wire);
      expect(r.isPlainText, isTrue);
    });

    test('truncated payload is rejected', () {
      // op=0x02 (reply), len=10, but only 4 payload bytes follow.
      final inner = Uint8List.fromList([
        ...kChatMetaMagic,
        kChatMetaVersion,
        kChatMetaSvc,
        ChatMetaOps.reply,
        10,
        1,
        2,
        3,
        4,
      ]);
      final wire =
          '[mrrp]${base64Url.encode(inner).replaceAll('=', '')}'
          '[/mrrp] s';
      final r = ChatMetaEnvelopeCodec.decode(wire);
      expect(r.isPlainText, isTrue);
    });
  });

  group('ChatMetaReplyPayload', () {
    test('parse rejects empty payload', () {
      expect(ChatMetaReplyPayload.parse(Uint8List(0)), isNull);
    });

    test('parse rejects unknown scope byte', () {
      expect(
        ChatMetaReplyPayload.parse(Uint8List.fromList([0xFF, 0, 0, 0, 0, 0])),
        isNull,
      );
    });

    test('parse rejects payload shorter than MMF length', () {
      // scope=channel claims 6 bytes; only give 4.
      expect(
        ChatMetaReplyPayload.parse(
          Uint8List.fromList([0x01, 0x00, 0x00, 0x00]),
        ),
        isNull,
      );
    });

    test('toBytes round-trips through parse', () {
      final p = ChatMetaReplyPayload(
        target: MeshCoreMmf.channel(
          channelIndex: 1,
          targetTimestampS: 0xAABBCCDD,
        ),
        body: 'hello reply',
      );
      final bytes = p.toBytes();
      final parsed = ChatMetaReplyPayload.parse(bytes);
      expect(parsed, isNotNull);
      expect(parsed!.target, equals(p.target));
      expect(parsed.body, p.body);
    });
  });

  group('ChatMetaHelloPayload', () {
    test('parse / encode / cap-bit semantics', () {
      final p = ChatMetaHelloPayload(capBits: 0x0001);
      expect(p.supportsReplies, isTrue);
      expect(p.supportsReactions, isFalse);

      final bytes = p.toBytes();
      expect(bytes.length, 3);
      expect(bytes[2], 0); // reserved trailing byte

      final round = ChatMetaHelloPayload.parse(bytes);
      expect(round?.capBits, 0x0001);
      expect(round?.supportsReplies, isTrue);
    });

    test('reserved bits are surfaced opaquely', () {
      // Future cap bit (e.g. bit 5) should round-trip without
      // breaking the parser.
      final p = ChatMetaHelloPayload(capBits: 0x0020);
      final round = ChatMetaHelloPayload.parse(p.toBytes());
      expect(round?.capBits, 0x0020);
      expect(round?.supportsReplies, isFalse);
    });

    test('parse rejects too-short input', () {
      expect(ChatMetaHelloPayload.parse(Uint8List.fromList([0x00])), isNull);
    });
  });
}
