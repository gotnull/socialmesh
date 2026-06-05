// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/carplay/carplay_drain_processor.dart';

void main() {
  Map<String, dynamic> sendItem(String id, String peerId, String text) => {
    'id': id,
    'kind': 'send',
    'peerId': peerId,
    'text': text,
  };

  group('CarPlayDrainProcessor.process', () {
    test('sends each fresh item and returns all ids for removal', () async {
      final sent = <String>[];
      final drained = await CarPlayDrainProcessor.process(
        items: [sendItem('a', '100', 'hi'), sendItem('b', '200', 'yo')],
        alreadyDrained: {},
        send: (peerId, text, id) async => sent.add('$id:$peerId:$text'),
      );

      expect(sent, ['a:100:hi', 'b:200:yo']);
      expect(drained, ['a', 'b']);
    });

    test('keeps an item queued when the send throws (radio down)', () async {
      final drained = await CarPlayDrainProcessor.process(
        items: [sendItem('a', '100', 'hi')],
        alreadyDrained: {},
        send: (_, _, _) async => throw StateError('not connected'),
      );

      // Not added to drained -> stays in the container for the next trigger.
      expect(drained, isEmpty);
    });

    test(
      'does not re-send already-drained ids but still removes them',
      () async {
        final sent = <String>[];
        final drained = await CarPlayDrainProcessor.process(
          items: [sendItem('a', '100', 'hi')],
          alreadyDrained: {'a'},
          send: (peerId, text, id) async => sent.add(id),
        );

        expect(sent, isEmpty); // skipped — already sent in a prior pass
        expect(drained, ['a']); // still scheduled for removal
      },
    );

    test('drops malformed items so they cannot wedge the queue', () async {
      final sent = <String>[];
      final drained = await CarPlayDrainProcessor.process(
        items: [
          {'id': 'bad1', 'kind': 'send', 'peerId': 'notanumber', 'text': 'x'},
          {'id': 'bad2', 'kind': 'send', 'peerId': '100', 'text': ''},
        ],
        alreadyDrained: {},
        send: (peerId, text, id) async => sent.add(id),
      );

      expect(sent, isEmpty);
      // Both dropped (returned for removal) without sending.
      expect(drained, ['bad1', 'bad2']);
    });

    test(
      'leaves non-send kinds queued (markRead has no producer in v0.1)',
      () async {
        final sent = <String>[];
        final drained = await CarPlayDrainProcessor.process(
          items: [
            {
              'id': 'r1',
              'kind': 'markRead',
              'peerId': '100',
              'messageId': 'm1',
            },
          ],
          alreadyDrained: {},
          send: (peerId, text, id) async => sent.add(id),
        );

        expect(sent, isEmpty);
        expect(drained, isEmpty); // left in place, not silently dropped
      },
    );

    test('skips items missing an idempotency id', () async {
      final drained = await CarPlayDrainProcessor.process(
        items: [
          {'kind': 'send', 'peerId': '100', 'text': 'hi'},
        ],
        alreadyDrained: {},
        send: (_, _, _) async {},
      );

      expect(drained, isEmpty);
    });
  });
}
