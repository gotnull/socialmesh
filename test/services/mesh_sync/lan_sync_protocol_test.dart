// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mesh_sync/lan_sync_protocol.dart';

void main() {
  group('LanSyncHello', () {
    test('serializes and deserializes', () {
      const hello = LanSyncHello(
        protocolVersion: 1,
        peerId: '!12345678',
        nodeNum: 0x12345678,
        displayName: 'Test Node',
        maxBatchSize: 50,
      );

      final json = hello.toJson();
      expect(json['type'], equals('hello'));
      expect(json['protocolVersion'], equals(1));
      expect(json['peerId'], equals('!12345678'));
      expect(json['nodeNum'], equals(0x12345678));
      expect(json['displayName'], equals('Test Node'));
      expect(json['maxBatchSize'], equals(50));

      final parsed = LanSyncMessage.parse(json);
      expect(parsed, isA<LanSyncHello>());
      final h = parsed! as LanSyncHello;
      expect(h.protocolVersion, equals(1));
      expect(h.peerId, equals('!12345678'));
      expect(h.nodeNum, equals(0x12345678));
      expect(h.displayName, equals('Test Node'));
      expect(h.maxBatchSize, equals(50));
    });

    test('omits null displayName', () {
      const hello = LanSyncHello(
        protocolVersion: 1,
        peerId: '!aabbccdd',
        nodeNum: 0xaabbccdd,
      );

      final json = hello.toJson();
      expect(json.containsKey('displayName'), isFalse);
    });

    test('defaults on missing fields', () {
      final parsed = LanSyncHello.fromJson({'type': 'hello'});
      expect(parsed.protocolVersion, equals(1));
      expect(parsed.peerId, equals(''));
      expect(parsed.nodeNum, equals(0));
      expect(parsed.maxBatchSize, equals(50));
    });

    test('round-trips through JSON line encoding', () {
      const hello = LanSyncHello(
        protocolVersion: 1,
        peerId: '!deadbeef',
        nodeNum: 0xdeadbeef,
        displayName: 'Node Bravo',
      );

      final line = hello.toLine();
      final decoded = json.decode(line) as Map<String, dynamic>;
      final reparsed = LanSyncMessage.parse(decoded)! as LanSyncHello;
      expect(reparsed.peerId, equals('!deadbeef'));
      expect(reparsed.nodeNum, equals(0xdeadbeef));
    });
  });

  group('LanSyncRequest', () {
    test('serializes and deserializes', () {
      const req = LanSyncRequest(
        requesterPeerId: '!12345678',
        maxBatchSize: 25,
      );

      final json = req.toJson();
      expect(json['type'], equals('syncRequest'));
      expect(json['requesterPeerId'], equals('!12345678'));
      expect(json['maxBatchSize'], equals(25));

      final parsed = LanSyncMessage.parse(json)! as LanSyncRequest;
      expect(parsed.requesterPeerId, equals('!12345678'));
      expect(parsed.maxBatchSize, equals(25));
    });
  });

  group('LanSyncBatch', () {
    test('serializes empty batch', () {
      const batch = LanSyncBatch(
        posts: [],
        lastSeqInBatch: null,
        hasMore: false,
      );

      final json = batch.toJson();
      expect(json['type'], equals('syncBatch'));
      expect((json['posts'] as List).isEmpty, isTrue);
      expect(json['lastSeqInBatch'], isNull);
      expect(json['hasMore'], isFalse);
    });

    test('serializes batch with posts', () {
      final posts = [
        {'id': 'abc123', 'content': 'Hello mesh'},
        {'id': 'def456', 'content': 'World'},
      ];
      final batch = LanSyncBatch(
        posts: posts,
        lastSeqInBatch: 42,
        hasMore: true,
      );

      final json = batch.toJson();
      expect((json['posts'] as List).length, equals(2));
      expect(json['lastSeqInBatch'], equals(42));
      expect(json['hasMore'], isTrue);

      final parsed = LanSyncMessage.parse(json)! as LanSyncBatch;
      expect(parsed.posts.length, equals(2));
      expect(parsed.lastSeqInBatch, equals(42));
      expect(parsed.hasMore, isTrue);
    });
  });

  group('LanSyncAck', () {
    test('serializes and deserializes', () {
      const ack = LanSyncAck(ackedThroughSeq: 99);

      final json = ack.toJson();
      expect(json['type'], equals('syncAck'));
      expect(json['ackedThroughSeq'], equals(99));

      final parsed = LanSyncMessage.parse(json)! as LanSyncAck;
      expect(parsed.ackedThroughSeq, equals(99));
    });
  });

  group('LanSyncError', () {
    test('serializes with code', () {
      const err = LanSyncError(
        message: 'Version mismatch',
        code: 'version_mismatch',
      );

      final json = err.toJson();
      expect(json['type'], equals('error'));
      expect(json['message'], equals('Version mismatch'));
      expect(json['code'], equals('version_mismatch'));

      final parsed = LanSyncMessage.parse(json)! as LanSyncError;
      expect(parsed.message, equals('Version mismatch'));
      expect(parsed.code, equals('version_mismatch'));
    });

    test('serializes without code', () {
      const err = LanSyncError(message: 'Something broke');

      final json = err.toJson();
      expect(json.containsKey('code'), isFalse);
    });
  });

  group('LanSyncClose', () {
    test('serializes and deserializes', () {
      const close = LanSyncClose();

      final json = close.toJson();
      expect(json['type'], equals('close'));

      final parsed = LanSyncMessage.parse(json);
      expect(parsed, isA<LanSyncClose>());
    });
  });

  group('LanSyncMessage.parse()', () {
    test('returns null for unknown type', () {
      final msg = LanSyncMessage.parse({'type': 'unknown_future_type'});
      expect(msg, isNull);
    });

    test('returns null for missing type', () {
      final msg = LanSyncMessage.parse({'data': 'something'});
      expect(msg, isNull);
    });

    test('parses all known types', () {
      expect(LanSyncMessage.parse({'type': 'hello'}), isA<LanSyncHello>());
      expect(
        LanSyncMessage.parse({'type': 'syncRequest'}),
        isA<LanSyncRequest>(),
      );
      expect(
        LanSyncMessage.parse({'type': 'syncBatch', 'posts': []}),
        isA<LanSyncBatch>(),
      );
      expect(LanSyncMessage.parse({'type': 'syncAck'}), isA<LanSyncAck>());
      expect(LanSyncMessage.parse({'type': 'error'}), isA<LanSyncError>());
      expect(LanSyncMessage.parse({'type': 'close'}), isA<LanSyncClose>());
    });
  });

  group('buildLanSyncPeerId()', () {
    test('produces stable hex format', () {
      expect(buildLanSyncPeerId(0x12345678), equals('!12345678'));
      expect(buildLanSyncPeerId(0xdeadbeef), equals('!deadbeef'));
      expect(buildLanSyncPeerId(0), equals('!0'));
      expect(buildLanSyncPeerId(255), equals('!ff'));
    });

    test('same node always produces same ID', () {
      const nodeNum = 0xaabbccdd;
      expect(buildLanSyncPeerId(nodeNum), equals(buildLanSyncPeerId(nodeNum)));
    });
  });

  group('Protocol constants', () {
    test('version is 1', () {
      expect(lanSyncProtocolVersion, equals(1));
    });

    test('max rounds bounds session', () {
      expect(maxSessionRounds, greaterThan(0));
      expect(maxSessionRounds, lessThanOrEqualTo(100));
    });

    test('default port is 4480', () {
      expect(lanSyncDefaultPort, equals(4480));
    });

    test('service type matches convention', () {
      expect(lanSyncServiceType, equals('_socialmesh-sync._tcp'));
    });
  });
}
