// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/nodes/stale_node_cleanup.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _MockProtocolService extends Mock implements ProtocolService {}

final _now = DateTime(2026, 11, 17, 9, 30);

MeshNode _node(
  int nodeNum, {
  int? daysAgo,
  bool favourite = false,
  bool ignored = false,
  bool publicKey = false,
}) => MeshNode(
  nodeNum: nodeNum,
  lastHeard: daysAgo == null ? null : _now.subtract(Duration(days: daysAgo)),
  isFavorite: favourite,
  isIgnored: ignored,
  hasPublicKey: publicKey,
);

void main() {
  group('selectStaleNodeNums', () {
    List<int> select(List<MeshNode> nodes, int days, {int? local}) =>
        selectStaleNodeNums(nodes, days: days, now: _now, localNodeNum: local);

    test('selects nodes last heard longer ago than the threshold', () {
      final nodes = [_node(1, daysAgo: 10), _node(2, daysAgo: 3)];
      expect(select(nodes, 7), [1]);
    });

    test('a node heard exactly at the threshold is kept', () {
      final nodes = [_node(1, daysAgo: 7)];
      expect(select(nodes, 7), isEmpty);
    });

    test('keeps favourites, ignored nodes and the local node', () {
      final nodes = [
        _node(1, daysAgo: 30, favourite: true),
        _node(2, daysAgo: 30, ignored: true),
        _node(3, daysAgo: 30),
        _node(4, daysAgo: 30),
      ];
      expect(select(nodes, 7, local: 3), [4]);
    });

    test('never treats a node with no last-heard time as stale', () {
      expect(select([_node(1)], 1), isEmpty);
    });

    test('nodes with a public key are kept for at least seven days', () {
      final nodes = [
        _node(1, daysAgo: 3, publicKey: true),
        _node(2, daysAgo: 8, publicKey: true),
        _node(3, daysAgo: 3),
      ];
      expect(select(nodes, 1), [2, 3]);
      // Above the floor the user's threshold applies to keyed nodes too.
      expect(select([_node(4, daysAgo: 20, publicKey: true)], 14), [4]);
    });

    test('zero days selects nothing', () {
      expect(select([_node(1, daysAgo: 400)], 0), isEmpty);
    });
  });

  group('removeStaleNodesFromRadio', () {
    late _MockProtocolService protocol;
    late bool connected;

    setUp(() {
      protocol = _MockProtocolService();
      connected = true;
      when(() => protocol.isConnected).thenAnswer((_) => connected);
      when(() => protocol.removeNode(any())).thenAnswer((_) async {});
    });

    void radioHas(List<int> nodeNums) {
      when(() => protocol.nodes)
          .thenReturn({for (final n in nodeNums) n: MeshNode(nodeNum: n)});
    }

    test('sends one removal per radio node, in order, and reports progress '
        'for every node', () async {
      radioHas([1, 2, 3]);
      final progress = <int>[];

      final result = await removeStaleNodesFromRadio(
        protocol,
        [1, 2, 3],
        pause: Duration.zero,
        onProgress: progress.add,
      );

      verifyInOrder([
        () => protocol.removeNode(1),
        () => protocol.removeNode(2),
        () => protocol.removeNode(3),
      ]);
      expect(result.removed, [1, 2, 3]);
      expect(result.failed, 0);
      expect(result.stoppedOnDisconnect, isFalse);
      expect(progress, [1, 2, 3]);
    });

    test('nodes the radio never reported are removed without a radio '
        'write', () async {
      radioHas([2]);

      final result = await removeStaleNodesFromRadio(protocol, [
        1,
        2,
        3,
      ], pause: Duration.zero);

      verify(() => protocol.removeNode(2)).called(1);
      verifyNever(() => protocol.removeNode(1));
      verifyNever(() => protocol.removeNode(3));
      expect(result.removed, [1, 2, 3]);
    });

    test(
      'waits the pause between radio writes, not before the first',
      () async {
        radioHas([1, 2, 3]);
        final stopwatch = Stopwatch()..start();

        await removeStaleNodesFromRadio(protocol, [
          1,
          2,
          3,
        ], pause: const Duration(milliseconds: 40));

        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(80));
      },
    );

    test('stops at the first radio node after the link drops', () async {
      radioHas([1, 2, 3]);
      when(() => protocol.removeNode(1)).thenAnswer((_) async {
        connected = false;
      });

      final result = await removeStaleNodesFromRadio(protocol, [
        1,
        2,
        3,
      ], pause: Duration.zero);

      verify(() => protocol.removeNode(1)).called(1);
      verifyNever(() => protocol.removeNode(2));
      expect(result.removed, [1]);
      expect(result.stoppedOnDisconnect, isTrue);
    });

    test('a send that fails because the link dropped stops the run and '
        'does not count the node as removed', () async {
      radioHas([1, 2]);
      when(() => protocol.removeNode(1)).thenAnswer((_) async {
        connected = false;
        throw StateError('Cannot remove node: not connected');
      });

      final result = await removeStaleNodesFromRadio(protocol, [
        1,
        2,
      ], pause: Duration.zero);

      expect(result.removed, isEmpty);
      expect(result.failed, 0);
      expect(result.stoppedOnDisconnect, isTrue);
      verifyNever(() => protocol.removeNode(2));
    });

    test('a send that fails while still connected is counted and the run '
        'carries on', () async {
      radioHas([1, 2]);
      when(() => protocol.removeNode(1)).thenThrow(Exception('write failed'));

      final result = await removeStaleNodesFromRadio(protocol, [
        1,
        2,
      ], pause: Duration.zero);

      expect(result.removed, [2]);
      expect(result.failed, 1);
      expect(result.stoppedOnDisconnect, isFalse);
    });
  });
}
