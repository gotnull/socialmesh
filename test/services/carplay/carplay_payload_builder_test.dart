// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/carplay/carplay_payload_builder.dart';

void main() {
  const me = 0x1111;
  const alice = 0x2222;
  const bob = 0x3333;
  const broadcast = 0xFFFFFFFF;

  Message msg(
    int from,
    int to,
    String text, {
    required int tsMs,
    bool read = false,
  }) {
    return Message(
      from: from,
      to: to,
      text: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(tsMs),
      read: read,
    );
  }

  final nodes = <int, MeshNode>{
    me: MeshNode(nodeNum: me, longName: 'Me', shortName: 'ME'),
    alice: MeshNode(nodeNum: alice, longName: 'Alice', shortName: 'AL'),
    bob: MeshNode(nodeNum: bob, shortName: 'BO'),
  };

  group('buildRecentMessages', () {
    test('groups DMs by peer and excludes broadcast', () {
      final messages = [
        msg(alice, me, 'hi from alice', tsMs: 1000),
        msg(me, alice, 'hi back', tsMs: 2000),
        msg(me, broadcast, 'broadcast to all', tsMs: 3000),
        msg(bob, me, 'hi from bob', tsMs: 1500),
      ];

      final payload = CarPlayPayloadBuilder.buildRecentMessages(
        messages: messages,
        nodes: nodes,
        myNodeNum: me,
        nowMs: 9999,
      );

      expect(payload['version'], 1);
      expect(payload['updatedAtMs'], 9999);

      final convos = payload['conversations'] as List;
      // Two DM peers (alice, bob); broadcast excluded.
      expect(convos.length, 2);

      final peerIds = convos.map((c) => c['peerId']).toSet();
      expect(peerIds, {alice.toString(), bob.toString()});
    });

    test('orders conversations by most recent message, newest first', () {
      final messages = [
        msg(alice, me, 'old', tsMs: 1000),
        msg(bob, me, 'newer', tsMs: 5000),
      ];

      final payload = CarPlayPayloadBuilder.buildRecentMessages(
        messages: messages,
        nodes: nodes,
        myNodeNum: me,
        nowMs: 9999,
      );

      final convos = payload['conversations'] as List;
      expect(convos.first['peerId'], bob.toString());
      expect(convos.last['peerId'], alice.toString());
    });

    test('sets sentByMe and read correctly', () {
      final messages = [
        msg(alice, me, 'unread inbound', tsMs: 1000),
        msg(alice, me, 'read inbound', tsMs: 1100, read: true),
        msg(me, alice, 'my send', tsMs: 1200),
      ];

      final payload = CarPlayPayloadBuilder.buildRecentMessages(
        messages: messages,
        nodes: nodes,
        myNodeNum: me,
        nowMs: 9999,
      );

      final convo = (payload['conversations'] as List).single;
      final msgs = convo['messages'] as List;
      // Chronological order preserved.
      expect(msgs.map((m) => m['text']), [
        'unread inbound',
        'read inbound',
        'my send',
      ]);

      expect(msgs[0]['sentByMe'], false);
      expect(msgs[0]['read'], false);
      expect(msgs[1]['read'], true);
      expect(msgs[2]['sentByMe'], true);
      // Our own sends count as read.
      expect(msgs[2]['read'], true);
    });

    test('caps messages per conversation to the newest window', () {
      final messages = [
        for (var i = 0; i < CarPlayPayloadBuilder.maxPerConversation + 5; i++)
          msg(alice, me, 'm$i', tsMs: 1000 + i),
      ];

      final payload = CarPlayPayloadBuilder.buildRecentMessages(
        messages: messages,
        nodes: nodes,
        myNodeNum: me,
        nowMs: 9999,
      );

      final msgs =
          (payload['conversations'] as List).single['messages'] as List;
      expect(msgs.length, CarPlayPayloadBuilder.maxPerConversation);
      // Newest window kept: last message is the most recent.
      expect(
        msgs.last['text'],
        'm${CarPlayPayloadBuilder.maxPerConversation + 4}',
      );
      // Oldest 5 dropped: first kept is m5.
      expect(msgs.first['text'], 'm5');
    });

    test('falls back to hex name when peer node is unknown', () {
      const stranger = 0xABCDEF01;
      final messages = [msg(stranger, me, 'who am i', tsMs: 1000)];

      final payload = CarPlayPayloadBuilder.buildRecentMessages(
        messages: messages,
        nodes: nodes,
        myNodeNum: me,
        nowMs: 9999,
      );

      final convo = (payload['conversations'] as List).single;
      expect(convo['displayName'], 'Node !abcdef01');
    });
  });

  group('buildPeers', () {
    test('excludes self and unnamed nodes, includes named', () {
      final unnamed = <int, MeshNode>{
        ...nodes,
        0x4444: MeshNode(nodeNum: 0x4444), // no name -> excluded
      };

      final payload = CarPlayPayloadBuilder.buildPeers(
        nodes: unnamed,
        myNodeNum: me,
      );

      final peers = payload['peers'] as List;
      final ids = peers.map((p) => p['peerId']).toSet();
      // me excluded; 0x4444 excluded (no name); alice + bob present.
      expect(ids, {alice.toString(), bob.toString()});

      final alicePeer = peers.firstWhere(
        (p) => p['peerId'] == alice.toString(),
      );
      expect(alicePeer['displayName'], 'Alice');
      // bob has only a shortName -> used as fallback.
      final bobPeer = peers.firstWhere((p) => p['peerId'] == bob.toString());
      expect(bobPeer['displayName'], 'BO');
    });
  });
}
