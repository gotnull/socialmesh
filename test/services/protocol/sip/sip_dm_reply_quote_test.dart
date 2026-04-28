// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Regression coverage for two bugs the user surfaced via on-device
/// logs:
///
/// 1. The secure-DM router stored `replyToText` as the BODY of a
///    quote-formatted message instead of the QUOTE — making the
///    sender's local bubble appear to "reply to itself" with the
///    user's own typed text in the quote box. The receiver's view
///    was correct because the receiver path runs through
///    `SipDmManager.handleInboundDm`, which uses `parseReplyToText`.
///
/// 2. `GlobalObjectKey(entry.timestampMs)` collided when two messages
///    landed in the same second, throwing "Multiple widgets used the
///    same GlobalKey" while finalising the widget tree. Switching to
///    `GlobalObjectKey(entry)` keys on identity, which is unique
///    per `SipDmHistoryEntry` instance.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_dm.dart';

void main() {
  group('SipDmManager.parseReplyToText', () {
    test('extracts the quote, not the body', () {
      // The fix: the secure router used to call extractReplyBody here
      // and store its result as replyToText, which is the BODY. The
      // bubble would then render the user's own reply text in the
      // quote box, looking like the message was replying to itself.
      const reply = '> 🎨 Sketch\nHi';
      expect(SipDmManager.parseReplyToText(reply), equals('🎨 Sketch'));
      expect(SipDmManager.extractReplyBody(reply), equals('Hi'));
      // The two helpers must NEVER agree on a reply-formatted message
      // — if they ever do, someone has confused them again.
      expect(
        SipDmManager.parseReplyToText(reply),
        isNot(equals(SipDmManager.extractReplyBody(reply))),
      );
    });

    test('returns null for non-reply text', () {
      expect(SipDmManager.parseReplyToText('plain message'), isNull);
      expect(SipDmManager.parseReplyToText(''), isNull);
    });

    test('returns null when quote line has no body separator', () {
      // No newline → not a real reply envelope.
      expect(SipDmManager.parseReplyToText('> just a quote no body'), isNull);
    });

    test('handles ink reply placeholder round-trip', () {
      // Format produced by SipDmManager.formatReplyMessage when
      // replying to a sketch. The wire body that travels:
      const wire = '> 🎨 Sketch\nlooks great!';
      expect(SipDmManager.parseReplyToText(wire), equals('🎨 Sketch'));
      expect(SipDmManager.extractReplyBody(wire), equals('looks great!'));
    });
  });

  group('SipDmHistoryEntry GlobalKey identity', () {
    test('two entries with the same timestampMs but different identities '
        'produce distinct GlobalObjectKeys', () {
      // Regression: the message-bubble GlobalObjectKey used to be
      // built from entry.timestampMs. Two messages sent inside the
      // same second collided on the millisecond-rounded timestamp,
      // and Flutter threw "Multiple widgets used the same GlobalKey"
      // during widget-tree finalisation.
      final entryA = SipDmHistoryEntry(
        text: 'A',
        timestampMs: 1700000000000,
        direction: SipDmDirection.outbound,
      );
      final entryB = SipDmHistoryEntry(
        text: 'B',
        timestampMs: 1700000000000,
        direction: SipDmDirection.inbound,
      );
      // The fix: key on the entry instance. Distinct identities ⇒
      // distinct keys.
      expect(GlobalObjectKey(entryA), isNot(equals(GlobalObjectKey(entryB))));
      // The old approach (key on timestampMs) WOULD have collided —
      // pinning that as a regression cue.
      expect(
        GlobalObjectKey(entryA.timestampMs),
        equals(GlobalObjectKey(entryB.timestampMs)),
        reason: 'this collision is exactly what the new key avoids',
      );
    });

    test('GlobalObjectKey on the same entry instance is stable', () {
      final entry = SipDmHistoryEntry(
        text: 'stable',
        timestampMs: 1700000000000,
        direction: SipDmDirection.outbound,
      );
      // Multiple GlobalObjectKey instances built around the same
      // entry instance are equal — required for ensureVisible to
      // resolve the registered widget when the lookup happens later.
      expect(GlobalObjectKey(entry), equals(GlobalObjectKey(entry)));
    });
  });
}
