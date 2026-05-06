// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D17.A regression pins for the conversations notifier's
// prefix-to-conversation routing.
//
// Background: pre-D17 the conversations provider had its own broken
// hand-parser that assumed a fictional 32-byte sender pubkey layout
// and silently dropped V3 frames at `<37`/`<38` length guards. The
// chat screen got a real parser via D12 but this provider did not.
//
// The new contact-message handler asks
// `meshCoreConversationIdForSenderPrefix` to map the firmware's
// 6-byte (12 hex char) sender prefix to a known conversation's full
// pubkey-hex id. The function below pins the rule shape so that
// rule cannot regress without an explicit test update.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';

void main() {
  MeshCoreConversation contactConversation({
    required String publicKeyHex,
    String name = 'TestPeer',
  }) {
    return MeshCoreConversation(
      id: publicKeyHex,
      name: name,
      isChannel: false,
      contact: MeshCoreContact(
        publicKey: Uint8List(32),
        name: name,
        type: MeshCoreAdvType.chat,
        pathLength: 0,
        path: Uint8List(0),
        lastSeen: DateTime(2026, 5, 6),
      ),
    );
  }

  MeshCoreConversation channelConversation({required int index}) {
    return MeshCoreConversation(
      id: 'channel_$index',
      name: 'Channel $index',
      isChannel: true,
      channelIndex: index,
    );
  }

  group('meshCoreConversationIdForSenderPrefix (D17.A)', () {
    test('returns the full pubkey id when a contact prefix matches', () {
      // Realistic case: firmware delivers a V3 contact frame with
      // sender_prefix = 79426d8dbb8f. The conversations list already
      // has the discovered contact under its full pubkey hex.
      final conversations = [
        contactConversation(
          publicKeyHex:
              '79426d8dbb8fd9371f1f52c13251ea07'
              'd797735af95832b934977f220831782b',
        ),
        channelConversation(index: 0),
      ];

      final id = meshCoreConversationIdForSenderPrefix(
        conversations,
        '79426d8dbb8f',
      );

      expect(
        id,
        equals(
          '79426d8dbb8fd9371f1f52c13251ea07'
          'd797735af95832b934977f220831782b',
        ),
      );
    });

    test('is case-insensitive on both sides', () {
      // The chat-screen path stores pubkey hex in lower case; some
      // legacy callers may still hand uppercase prefixes. Keep both
      // sides folded to lower for the comparison.
      final conversations = [
        contactConversation(
          publicKeyHex:
              '79426D8DBB8FD9371F1F52C13251EA07'
              'D797735AF95832B934977F220831782B',
        ),
      ];

      final id = meshCoreConversationIdForSenderPrefix(
        conversations,
        '79426D8DBB8F',
      );

      expect(id, isNotNull);
    });

    test('returns null when no contact starts with the prefix', () {
      final conversations = [
        contactConversation(
          publicKeyHex:
              '11111111111111111111111111111111'
              '11111111111111111111111111111111',
        ),
      ];

      final id = meshCoreConversationIdForSenderPrefix(
        conversations,
        '79426d8dbb8f',
      );

      expect(id, isNull);
    });

    test('skips channel conversations even if their id collides', () {
      // Defensive: a channel conversation with id 'channel_X' must
      // never match a contact prefix. Without this skip the prefix
      // search would trip on synthetic channel ids if their first
      // 12 chars happen to equal a sender prefix (extremely
      // unlikely but worth guarding against).
      final conversations = [
        channelConversation(index: 0),
        contactConversation(
          publicKeyHex:
              '79426d8dbb8fd9371f1f52c13251ea07'
              'd797735af95832b934977f220831782b',
        ),
      ];

      final id = meshCoreConversationIdForSenderPrefix(
        conversations,
        '79426d8dbb8f',
      );

      expect(id, equals(conversations[1].id));
    });

    test('rejects non-12-char inputs without scanning the list', () {
      // The parser surface guarantees 12 hex chars (6 bytes); if the
      // caller hands something else, treat it as a bug surfacing
      // and return null instead of producing an arbitrary partial
      // match.
      final conversations = [
        contactConversation(
          publicKeyHex:
              '79426d8dbb8fd9371f1f52c13251ea07'
              'd797735af95832b934977f220831782b',
        ),
      ];

      // Too short.
      expect(
        meshCoreConversationIdForSenderPrefix(conversations, '79426d8d'),
        isNull,
      );
      // Too long (e.g. caller passed full pubkey by mistake).
      expect(
        meshCoreConversationIdForSenderPrefix(
          conversations,
          '79426d8dbb8fd9371f1f52c13251ea07'
          'd797735af95832b934977f220831782b',
        ),
        isNull,
      );
      // Empty.
      expect(meshCoreConversationIdForSenderPrefix(conversations, ''), isNull);
    });

    test('returns the FIRST matching contact when prefixes collide', () {
      // Two contacts sharing the same 6-byte prefix is astronomically
      // unlikely but firmware-permissible (only the first 6 bytes are
      // sent on the wire). Pin the deterministic order: list order.
      final first = contactConversation(
        publicKeyHex:
            '79426d8dbb8fd9371f1f52c13251ea07'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        name: 'Alice',
      );
      final second = contactConversation(
        publicKeyHex:
            '79426d8dbb8fd9371f1f52c13251ea07'
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        name: 'Bob',
      );

      final id = meshCoreConversationIdForSenderPrefix([
        first,
        second,
      ], '79426d8dbb8f');

      expect(id, equals(first.id));
    });
  });

  // D19.A regression pins for the deterministic-id helpers.
  // Pre-D19 the conversations notifier used `DateTime.now()` in the
  // id, so re-receipt of the same firmware frame produced different
  // ids and the message store could not dedupe. The helpers below
  // give a stable id keyed on (chat-type, channel/sender, ts, text)
  // so the store's `add*Message`-by-id path acts as an automatic
  // duplicate guard.
  group('meshCoreFnv1a32Hex (D19.A)', () {
    test('FNV-1a empty string returns canonical offset basis', () {
      // Wire-spec FNV-1a 32-bit empty-input output is the offset
      // basis 0x811c9dc5. Pin so the constant or loop direction
      // cannot silently drift.
      expect(meshCoreFnv1a32Hex(''), equals('811c9dc5'));
    });

    test('FNV-1a is stable across calls for the same input', () {
      expect(
        meshCoreFnv1a32Hex('hello world'),
        equals(meshCoreFnv1a32Hex('hello world')),
      );
    });

    test('FNV-1a distinguishes single-byte differences', () {
      expect(
        meshCoreFnv1a32Hex('hello'),
        isNot(equals(meshCoreFnv1a32Hex('hellp'))),
      );
    });

    test('FNV-1a output is exactly 8 lowercase hex chars', () {
      // Several inputs to catch any leading-zero truncation.
      for (final input in ['', 'a', 'aa', 'meshcore', 'foo bar baz']) {
        final out = meshCoreFnv1a32Hex(input);
        expect(
          out.length,
          equals(8),
          reason: 'FNV output for "$input" was "$out"',
        );
        expect(
          RegExp(r'^[0-9a-f]{8}$').hasMatch(out),
          isTrue,
          reason: 'FNV output "$out" must be 8 lowercase hex chars',
        );
      }
    });

    test('FNV-1a is UTF-8 aware (multi-byte chars produce stable hash)', () {
      // 'hi' -> 2 bytes, 'hi👋' -> 6 bytes. Different inputs, must
      // differ deterministically.
      expect(
        meshCoreFnv1a32Hex('hi'),
        isNot(equals(meshCoreFnv1a32Hex('hi👋'))),
      );
    });
  });

  group('meshCoreInboundChannelMessageId (D19.A)', () {
    final ts = DateTime.fromMillisecondsSinceEpoch(1715000000000);

    test('id shape is stable for same (channel, ts, text)', () {
      final a = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: ts,
        text: 'hello',
      );
      final b = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: ts,
        text: 'hello',
      );
      expect(a, equals(b));
    });

    test('id differs for different channels', () {
      final a = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: ts,
        text: 'hello',
      );
      final b = meshCoreInboundChannelMessageId(
        channelIndex: 1,
        timestamp: ts,
        text: 'hello',
      );
      expect(a, isNot(equals(b)));
    });

    test('id differs for different text', () {
      final a = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: ts,
        text: 'hello',
      );
      final b = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: ts,
        text: 'world',
      );
      expect(a, isNot(equals(b)));
    });

    test('id differs across seconds (truncated to 1s granularity)', () {
      final a = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1715000000000),
        text: 'hi',
      );
      final b = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1715000001000),
        text: 'hi',
      );
      expect(a, isNot(equals(b)));
    });

    test('id collapses sub-second drift (same ts second => same id)', () {
      // Two timestamps in the same second produce the same id, which
      // is exactly the dedupe property we want for re-flooded
      // duplicates that arrive ~ms apart.
      final a = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1715000000123),
        text: 'hi',
      );
      final b = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1715000000789),
        text: 'hi',
      );
      expect(a, equals(b));
    });

    test('id has the documented prefix shape', () {
      final id = meshCoreInboundChannelMessageId(
        channelIndex: 7,
        timestamp: ts,
        text: 'public flood',
      );
      // Prefix carries chat-type + channel index so a quick log
      // scan can identify the source without parsing.
      expect(id, startsWith('mc_in_ch_7_'));
    });
  });

  group('meshCoreInboundContactMessageId (D19.A)', () {
    final ts = DateTime.fromMillisecondsSinceEpoch(1715000000000);

    test('id shape is stable for same (sender, ts, text)', () {
      final a = meshCoreInboundContactMessageId(
        senderPrefixHex: '96458be0b1c5',
        timestamp: ts,
        text: 'hi',
      );
      final b = meshCoreInboundContactMessageId(
        senderPrefixHex: '96458be0b1c5',
        timestamp: ts,
        text: 'hi',
      );
      expect(a, equals(b));
    });

    test('id is case-insensitive on sender prefix', () {
      final lower = meshCoreInboundContactMessageId(
        senderPrefixHex: '96458be0b1c5',
        timestamp: ts,
        text: 'hi',
      );
      final upper = meshCoreInboundContactMessageId(
        senderPrefixHex: '96458BE0B1C5',
        timestamp: ts,
        text: 'hi',
      );
      expect(lower, equals(upper));
    });

    test('id differs for different senders', () {
      final a = meshCoreInboundContactMessageId(
        senderPrefixHex: '96458be0b1c5',
        timestamp: ts,
        text: 'hi',
      );
      final b = meshCoreInboundContactMessageId(
        senderPrefixHex: 'aaaaaaaaaaaa',
        timestamp: ts,
        text: 'hi',
      );
      expect(a, isNot(equals(b)));
    });

    test('contact and channel ids never collide', () {
      // Defence-in-depth: namespace prefixes (`mc_in_ct_` vs
      // `mc_in_ch_`) must keep contact and channel ids distinct so
      // a contact msg never overwrites a channel msg in the store.
      final ch = meshCoreInboundChannelMessageId(
        channelIndex: 0,
        timestamp: ts,
        text: 'hi',
      );
      final ct = meshCoreInboundContactMessageId(
        senderPrefixHex: '000000000000',
        timestamp: ts,
        text: 'hi',
      );
      expect(ch, isNot(equals(ct)));
      expect(ch, startsWith('mc_in_ch_'));
      expect(ct, startsWith('mc_in_ct_'));
    });
  });
}
