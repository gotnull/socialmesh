// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/nodes/stale_node_cleanup.dart';
import 'package:socialmesh/services/protocol/admin_ack_tracker.dart';
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

    Future<AdminAckResult?> remove(int nodeNum) =>
        protocol.removeNode(nodeNum, ackTimeout: any(named: 'ackTimeout'));

    void answer(int nodeNum, Future<AdminAckResult?> Function() reply) =>
        when(() => remove(nodeNum)).thenAnswer((_) => reply());

    setUp(() {
      protocol = _MockProtocolService();
      connected = true;
      when(() => protocol.isConnected).thenAnswer((_) => connected);
      when(() => remove(any()))
          .thenAnswer((_) async => const AdminAckResult.acked());
    });

    void radioHas(List<int> nodeNums) {
      when(() => protocol.nodes)
          .thenReturn({for (final n in nodeNums) n: MeshNode(nodeNum: n)});
    }

    test('sends one confirmed removal per radio node, in order, and reports '
        'progress for every node', () async {
      radioHas([1, 2, 3]);
      final progress = <int>[];

      final result = await removeStaleNodesFromRadio(protocol, [
        1,
        2,
        3,
      ], onProgress: progress.add);

      verifyInOrder([
        () => protocol.removeNode(1, ackTimeout: kStaleNodeRemovalAckTimeout),
        () => protocol.removeNode(2, ackTimeout: kStaleNodeRemovalAckTimeout),
        () => protocol.removeNode(3, ackTimeout: kStaleNodeRemovalAckTimeout),
      ]);
      expect(result.removed, [1, 2, 3]);
      expect(result.failed, 0);
      expect(result.stoppedOnDisconnect, isFalse);
      expect(progress, [1, 2, 3]);
    });

    test('nodes the radio never reported are removed without a radio '
        'write', () async {
      radioHas([2]);

      final result = await removeStaleNodesFromRadio(protocol, [1, 2, 3]);

      verify(() => remove(2)).called(1);
      verifyNever(() => remove(1));
      verifyNever(() => remove(3));
      expect(result.removed, [1, 2, 3]);
    });

    test(
      'sends the next write only once the radio confirms the last',
      () async {
        radioHas([1, 2]);
        final first = Completer<AdminAckResult?>();
        answer(1, () => first.future);

        final run = removeStaleNodesFromRadio(protocol, [1, 2]);
        await Future<void>.delayed(Duration.zero);
        verifyNever(() => remove(2));

        first.complete(const AdminAckResult.acked());
        final result = await run;
        verify(() => remove(2)).called(1);
        expect(result.removed, [1, 2]);
      },
    );

    test('stops at the first radio node after the link drops', () async {
      radioHas([1, 2, 3]);
      answer(1, () async {
        connected = false;
        return const AdminAckResult.acked();
      });

      final result = await removeStaleNodesFromRadio(protocol, [1, 2, 3]);

      verify(() => remove(1)).called(1);
      verifyNever(() => remove(2));
      expect(result.removed, [1]);
      expect(result.stoppedOnDisconnect, isTrue);
    });

    test('a wait cancelled by a disconnect stops the run and does not count '
        'the node as removed', () async {
      radioHas([1, 2]);
      answer(1, () async => const AdminAckResult.cancelled());

      final result = await removeStaleNodesFromRadio(protocol, [1, 2]);

      expect(result.removed, isEmpty);
      expect(result.failed, 0);
      expect(result.stoppedOnDisconnect, isTrue);
      verifyNever(() => remove(2));
    });

    test(
      'a removal the radio refuses is counted and the run carries on',
      () async {
        radioHas([1, 2]);
        answer(
          1,
          () async => const AdminAckResult.failed(RoutingError.badRequest),
        );

        final result = await removeStaleNodesFromRadio(protocol, [1, 2]);

        expect(result.removed, [2]);
        expect(result.failed, 1);
        expect(result.stoppedOnDisconnect, isFalse);
      },
    );

    test('an unanswered removal stops further writes; the remaining radio '
        'nodes count as failed and app-only nodes are still removed', () async {
      radioHas([1, 2, 3]);
      answer(1, () async => const AdminAckResult.timedOut());
      final progress = <int>[];

      final result = await removeStaleNodesFromRadio(protocol, [
        1,
        2,
        4,
        3,
      ], onProgress: progress.add);

      verify(() => remove(1)).called(1);
      verifyNever(() => remove(2));
      verifyNever(() => remove(3));
      expect(result.removed, [4]);
      expect(result.failed, 3);
      expect(result.stoppedOnDisconnect, isFalse);
      expect(progress, [1, 2, 3, 4]);
    });

    test('an unanswered removal after the link dropped counts as a '
        'disconnect', () async {
      radioHas([1, 2]);
      answer(1, () async {
        connected = false;
        return const AdminAckResult.timedOut();
      });

      final result = await removeStaleNodesFromRadio(protocol, [1, 2]);

      expect(result.removed, isEmpty);
      expect(result.failed, 0);
      expect(result.stoppedOnDisconnect, isTrue);
    });

    test('a send that fails because the link dropped stops the run and '
        'does not count the node as removed', () async {
      radioHas([1, 2]);
      answer(1, () async {
        connected = false;
        throw StateError('Cannot remove node: not connected');
      });

      final result = await removeStaleNodesFromRadio(protocol, [1, 2]);

      expect(result.removed, isEmpty);
      expect(result.failed, 0);
      expect(result.stoppedOnDisconnect, isTrue);
      verifyNever(() => remove(2));
    });

    test('a send that fails while still connected is counted and the run '
        'carries on', () async {
      radioHas([1, 2]);
      when(() => remove(1)).thenThrow(Exception('write failed'));

      final result = await removeStaleNodesFromRadio(protocol, [1, 2]);

      expect(result.removed, [2]);
      expect(result.failed, 1);
      expect(result.stoppedOnDisconnect, isFalse);
    });
  });
}
