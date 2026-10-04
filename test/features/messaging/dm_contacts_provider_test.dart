// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins computeDmContactInfo's derivation contract (moved verbatim from
// the messaging screen build method): newest message wins the preview,
// unread counts accumulate for received-unread peer messages, tapbacks
// and broadcasts are skipped, and peers absent from the node list still
// surface through their message-carried identity hints.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/dm_contacts_provider.dart';
import 'package:socialmesh/models/mesh_models.dart';

const _me = 0x1000;
const _peer = 0x2000;

Message _dm({
  required int from,
  required int to,
  required String text,
  required DateTime timestamp,
  bool sent = false,
  bool received = false,
  bool read = false,
  bool isEmoji = false,
  int? replyId,
  String? senderLongName,
}) {
  return Message(
    from: from,
    to: to,
    text: text,
    timestamp: timestamp,
    sent: sent,
    received: received,
    read: read,
    isEmoji: isEmoji,
    replyId: replyId,
    senderLongName: senderLongName,
  );
}

void main() {
  test('newest message wins the preview and unread counts accumulate', () {
    final info = computeDmContactInfo([
      _dm(
        from: _peer,
        to: _me,
        text: 'older unread',
        timestamp: DateTime(2026, 6, 1, 10),
        received: true,
      ),
      _dm(
        from: _peer,
        to: _me,
        text: 'newest unread',
        timestamp: DateTime(2026, 6, 1, 12),
        received: true,
      ),
      _dm(
        from: _me,
        to: _peer,
        text: 'my reply in between',
        timestamp: DateTime(2026, 6, 1, 11),
      ),
    ], _me);

    final peer = info[_peer]!;
    expect(peer.lastMessage, 'newest unread');
    expect(peer.lastMessageTime, DateTime(2026, 6, 1, 12));
    expect(peer.unreadCount, 2);
  });

  test('own outbound and read messages do not count as unread', () {
    final info = computeDmContactInfo([
      _dm(
        from: _me,
        to: _peer,
        text: 'outbound',
        timestamp: DateTime(2026, 6, 1, 10),
      ),
      _dm(
        from: _peer,
        to: _me,
        text: 'already read',
        timestamp: DateTime(2026, 6, 1, 11),
        received: true,
        read: true,
      ),
    ], _me);

    expect(info[_peer]!.unreadCount, 0);
    expect(info[_peer]!.lastMessage, 'already read');
  });

  test('tapback reactions and broadcasts are skipped', () {
    final info = computeDmContactInfo([
      _dm(
        from: _peer,
        to: _me,
        text: '👍',
        timestamp: DateTime(2026, 6, 1, 12),
        received: true,
        isEmoji: true,
        replyId: 42,
      ),
      _dm(
        from: _peer,
        to: 0xFFFFFFFF,
        text: 'channel broadcast',
        timestamp: DateTime(2026, 6, 1, 13),
        received: true,
      ),
    ], _me);

    expect(info, isEmpty);
  });

  test('an older unread message bumps the count without replacing the '
      'newer preview', () {
    final info = computeDmContactInfo([
      _dm(
        from: _peer,
        to: _me,
        text: 'newest',
        timestamp: DateTime(2026, 6, 1, 12),
        received: true,
        read: true,
      ),
      _dm(
        from: _peer,
        to: _me,
        text: 'older unread arriving late',
        timestamp: DateTime(2026, 6, 1, 9),
        received: true,
      ),
    ], _me);

    final peer = info[_peer]!;
    expect(peer.lastMessage, 'newest');
    expect(peer.unreadCount, 1);
  });

  test('identity hints survive for peers carried only by messages', () {
    final info = computeDmContactInfo([
      _dm(
        from: _peer,
        to: _me,
        text: 'hello',
        timestamp: DateTime(2026, 6, 1, 12),
        received: true,
        senderLongName: 'Departed Node',
      ),
    ], _me);

    expect(info[_peer]!.senderDisplayName, 'Departed Node');
  });

  test('identity hints come from the peer, not a newer outgoing message', () {
    // A shared dataset after a reflash: the node list is empty, the newest
    // DM to the peer went out through another of my radios and carries
    // that radio's name, and the peer's name lives only on its own reply.
    const otherRadio = 0x3000;
    final info = computeDmContactInfo([
      _dm(
        from: _peer,
        to: otherRadio,
        text: 'from the peer',
        timestamp: DateTime(2026, 6, 1, 10),
        received: true,
        read: true,
        senderLongName: 'Kappa',
      ),
      _dm(
        from: otherRadio,
        to: _peer,
        text: 'Ok?',
        timestamp: DateTime(2026, 6, 1, 11),
        sent: true,
        senderLongName: 'Rooftop Radio',
      ),
      _dm(
        from: _me,
        to: _peer,
        text: 'from the connected radio',
        timestamp: DateTime(2026, 6, 1, 9),
        sent: true,
        senderLongName: 'Connected Radio',
      ),
    ], _me);

    final peer = info[_peer]!;
    expect(peer.lastMessage, 'Ok?');
    expect(peer.senderDisplayName, 'Kappa');
  });

  test('a peer only ever messaged carries no identity hints', () {
    final info = computeDmContactInfo([
      _dm(
        from: _me,
        to: _peer,
        text: 'hello?',
        timestamp: DateTime(2026, 6, 1, 12),
        sent: true,
        senderLongName: 'Connected Radio',
      ),
    ], _me);

    final peer = info[_peer]!;
    expect(peer.lastMessage, 'hello?');
    expect(peer.senderDisplayName, isNull);
    expect(peer.senderShortName, isNull);
    expect(peer.senderAvatarColor, isNull);
  });

  test('messages sent through another of my radios list the peer, not '
      'the radio', () {
    // The dataset is shared with a second radio. Its outgoing messages
    // carry that radio's node number, and must not turn it into a contact.
    const otherRadio = 0x3000;
    final info = computeDmContactInfo([
      _dm(
        from: otherRadio,
        to: _peer,
        text: 'sent from the rooftop radio',
        timestamp: DateTime(2026, 6, 1, 10),
        sent: true,
      ),
      _dm(
        from: _peer,
        to: otherRadio,
        text: 'reply to the rooftop radio',
        timestamp: DateTime(2026, 6, 1, 11),
        received: true,
      ),
    ], _me);

    expect(info.containsKey(otherRadio), isFalse);
    expect(info[_peer]!.lastMessage, 'reply to the rooftop radio');
    expect(info[_peer]!.unreadCount, 1);
  });
}
