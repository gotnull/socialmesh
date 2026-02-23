// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/mutation_queue.dart';

void main() {
  late MutationQueue queue;
  late List<String> logs;

  setUp(() {
    queue = MutationQueue();
    logs = [];
    queue.log = logs.add;
  });

  group('MutationQueue - basic behavior', () {
    test('single mutation executes and commits', () async {
      var optimisticCalled = false;
      var commitCalled = false;

      final result = await queue.enqueue<String>(
        key: 'test:1',
        execute: () async => 'server-result',
        optimisticApply: () => optimisticCalled = true,
        commitApply: (r) {
          expect(r, 'server-result');
          commitCalled = true;
        },
        rollbackApply: () => fail('rollback should not be called'),
      );

      expect(result, 'server-result');
      expect(optimisticCalled, isTrue);
      expect(commitCalled, isTrue);
      expect(queue.hasPending('test:1'), isFalse);
    });

    test(
      'optimistic apply runs synchronously before future completes',
      () async {
        var state = 'initial';
        final completer = Completer<String>();

        // Fire off enqueue but do not await yet.
        final future = queue.enqueue<String>(
          key: 'test:1',
          execute: () => completer.future,
          optimisticApply: () => state = 'optimistic',
          commitApply: (r) => state = r,
          rollbackApply: () => state = 'initial',
        );

        // Optimistic should have applied immediately.
        expect(state, 'optimistic');
        expect(queue.hasPending('test:1'), isTrue);

        completer.complete('committed');
        await future;

        expect(state, 'committed');
        expect(queue.hasPending('test:1'), isFalse);
      },
    );

    test('failed mutation triggers rollback', () async {
      var state = 'initial';

      try {
        await queue.enqueue<void>(
          key: 'test:1',
          execute: () async => throw Exception('network error'),
          optimisticApply: () => state = 'optimistic',
          commitApply: (_) => fail('commit should not be called'),
          rollbackApply: () => state = 'rolled-back',
        );
        fail('should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }

      expect(state, 'rolled-back');
      expect(queue.hasPending('test:1'), isFalse);
    });

    test('pendingCount tracks all keys', () async {
      final c1 = Completer<void>();
      final c2 = Completer<void>();

      final f1 = queue.enqueue<void>(
        key: 'key-a',
        execute: () => c1.future,
        optimisticApply: () {},
        commitApply: (_) {},
        rollbackApply: () {},
      );

      final f2 = queue.enqueue<void>(
        key: 'key-b',
        execute: () => c2.future,
        optimisticApply: () {},
        commitApply: (_) {},
        rollbackApply: () {},
      );

      // One processing per key = 2 total.
      expect(queue.pendingCount, 2);

      c1.complete();
      await f1;
      expect(queue.pendingCount, 1);

      c2.complete();
      await f2;
      expect(queue.pendingCount, 0);
    });
  });

  group('MutationQueue - per-key serialization', () {
    test('mutations for the same key execute sequentially', () async {
      final executionOrder = <int>[];
      final completers = [
        Completer<void>(),
        Completer<void>(),
        Completer<void>(),
      ];

      final futures = <Future<void>>[];

      for (var i = 0; i < 3; i++) {
        futures.add(
          queue.enqueue<void>(
            key: 'same-key',
            execute: () async {
              executionOrder.add(i);
              await completers[i].future;
            },
            optimisticApply: () {},
            commitApply: (_) {},
            rollbackApply: () {},
          ),
        );
      }

      // Only the first should be executing.
      await Future<void>.delayed(Duration.zero);
      expect(executionOrder, [0]);

      // Complete first, second starts.
      completers[0].complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(executionOrder, [0, 1]);

      // Complete second, third starts.
      completers[1].complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(executionOrder, [0, 1, 2]);

      completers[2].complete();
      await Future.wait(futures);
    });

    test('mutations for different keys execute concurrently', () async {
      final executionOrder = <String>[];
      final c1 = Completer<void>();
      final c2 = Completer<void>();

      final f1 = queue.enqueue<void>(
        key: 'key-a',
        execute: () async {
          executionOrder.add('a-start');
          await c1.future;
          executionOrder.add('a-end');
        },
        optimisticApply: () {},
        commitApply: (_) {},
        rollbackApply: () {},
      );

      final f2 = queue.enqueue<void>(
        key: 'key-b',
        execute: () async {
          executionOrder.add('b-start');
          await c2.future;
          executionOrder.add('b-end');
        },
        optimisticApply: () {},
        commitApply: (_) {},
        rollbackApply: () {},
      );

      await Future<void>.delayed(Duration.zero);

      // Both should have started (different keys = concurrent).
      expect(executionOrder, contains('a-start'));
      expect(executionOrder, contains('b-start'));

      c1.complete();
      c2.complete();
      await Future.wait([f1, f2]);
    });
  });

  group('MutationQueue - out-of-order response bug reproduction', () {
    test('rapid toggle taps produce correct final state '
        'even if server would respond out of order', () async {
      // Simulates: initial=false, tap1=true, tap2=false, tap3=true.
      // Without queue, if server responds tap3, tap1, tap2 the final
      // state would be false (tap2's response). With queue, each mutation
      // executes in order so final state is true (tap3's response).

      var localState = false; // initial: not liked
      final serverCompleters = <Completer<bool>>[];

      // Each execute simulates a server call that returns the value
      // that was sent. We control when they complete to simulate
      // out-of-order responses.
      Future<bool> simulateServerToggle(bool newValue) {
        final c = Completer<bool>();
        serverCompleters.add(c);
        return c.future;
      }

      // Tap 1: like (true)
      final f1 = queue.enqueue<bool>(
        key: 'like:post1',
        execute: () => simulateServerToggle(true),
        optimisticApply: () => localState = true,
        commitApply: (result) => localState = result,
        rollbackApply: () => localState = false,
      );

      expect(localState, true, reason: 'optimistic: tap1 sets true');

      // Tap 2: unlike (false)
      final f2 = queue.enqueue<bool>(
        key: 'like:post1',
        execute: () => simulateServerToggle(false),
        optimisticApply: () => localState = false,
        commitApply: (result) => localState = result,
        rollbackApply: () => localState = true,
      );

      expect(localState, false, reason: 'optimistic: tap2 sets false');

      // Tap 3: like (true)
      final f3 = queue.enqueue<bool>(
        key: 'like:post1',
        execute: () => simulateServerToggle(true),
        optimisticApply: () => localState = true,
        commitApply: (result) => localState = result,
        rollbackApply: () => localState = false,
      );

      expect(localState, true, reason: 'optimistic: tap3 sets true');

      // Queue serializes: only tap1's execute has started.
      await Future<void>.delayed(Duration.zero);
      expect(serverCompleters.length, 1, reason: 'only tap1 started');

      // Complete tap1's server call (returns true).
      serverCompleters[0].complete(true);
      await Future<void>.delayed(Duration.zero);
      await f1;

      // Tap2 should now start.
      await Future<void>.delayed(Duration.zero);
      expect(serverCompleters.length, 2, reason: 'tap2 started');

      // Complete tap2 (returns false).
      serverCompleters[1].complete(false);
      await f2;

      // Tap3 should now start.
      await Future<void>.delayed(Duration.zero);
      expect(serverCompleters.length, 3, reason: 'tap3 started');

      // Complete tap3 (returns true).
      serverCompleters[2].complete(true);
      await f3;

      expect(localState, true, reason: 'final state matches tap3 intent');
    });

    test(
      'without queue simulation: out-of-order responses corrupt state',
      () async {
        // This test demonstrates the bug the queue solves.
        // Simulating fire-and-forget with out-of-order completion.
        var localState = false;

        final c1 = Completer<bool>();
        final c2 = Completer<bool>();
        final c3 = Completer<bool>();

        // Fire all three "requests" simultaneously (no queue).
        // Each applies optimistic + commit on complete.
        localState = true; // optimistic tap1
        final f1 = c1.future.then((v) => localState = v);

        localState = false; // optimistic tap2
        final f2 = c2.future.then((v) => localState = v);

        localState = true; // optimistic tap3
        final f3 = c3.future.then((v) => localState = v);

        // Simulate out-of-order: tap3 responds first, then tap1, then tap2.
        c3.complete(true); // tap3 response arrives first
        await f3;
        expect(localState, true);

        c1.complete(true); // tap1 response arrives second
        await f1;
        expect(localState, true); // still true by luck

        c2.complete(false); // tap2 response arrives last, OVERWRITES!
        await f2;
        expect(
          localState,
          false,
          reason:
              'BUG: final state is false (tap2 response) '
              'even though user intended true (tap3)',
        );
      },
    );
  });

  group('MutationQueue - failure handling', () {
    test('failed mutation rolls back, subsequent mutations continue', () async {
      var state = 0;

      // Mutation 1: succeeds, sets state to 1.
      final f1 = queue.enqueue<int>(
        key: 'counter',
        execute: () async => 1,
        optimisticApply: () => state = 1,
        commitApply: (r) => state = r,
        rollbackApply: () => state = 0,
      );

      // Mutation 2: fails, should rollback to previous committed state.
      final f2 = queue.enqueue<int>(
        key: 'counter',
        execute: () async => throw Exception('fail'),
        optimisticApply: () => state = 2,
        commitApply: (r) => state = r,
        rollbackApply: () => state = 1, // rollback to last known good
      );

      // Mutation 3: succeeds, sets state to 3.
      final f3 = queue.enqueue<int>(
        key: 'counter',
        execute: () async => 3,
        optimisticApply: () => state = 3,
        commitApply: (r) => state = r,
        rollbackApply: () => state = 1,
      );

      await f1;
      expect(state, 1);

      try {
        await f2;
      } catch (_) {
        // Expected.
      }
      // After rollback, state should be 1. But optimistic for f3 already
      // set it to 3. The rollback of f2 sets it to 1, then f3's execute
      // runs and commits to 3.

      await f3;
      expect(state, 3);
      expect(queue.hasPending('counter'), isFalse);
    });

    test('rollback failure does not block queue', () async {
      var commitCount = 0;

      final f1 = queue.enqueue<void>(
        key: 'test',
        execute: () async => throw Exception('fail'),
        optimisticApply: () {},
        commitApply: (_) {},
        rollbackApply: () => throw Exception('rollback also fails'),
      );

      final f2 = queue.enqueue<void>(
        key: 'test',
        execute: () async {},
        optimisticApply: () {},
        commitApply: (_) => commitCount++,
        rollbackApply: () {},
      );

      try {
        await f1;
      } catch (_) {}

      await f2;
      expect(commitCount, 1, reason: 'queue continues after rollback failure');
    });

    test('optimistic apply failure prevents enqueue', () async {
      try {
        await queue.enqueue<void>(
          key: 'test',
          execute: () async {},
          optimisticApply: () => throw Exception('optimistic failed'),
          commitApply: (_) {},
          rollbackApply: () {},
        );
        fail('should have thrown');
      } catch (e) {
        expect(e, isA<Exception>());
      }

      expect(queue.hasPending('test'), isFalse);
    });
  });

  group('MutationQueue - logging', () {
    test('logs lifecycle events', () async {
      await queue.enqueue<void>(
        key: 'log-test',
        execute: () async {},
        optimisticApply: () {},
        commitApply: (_) {},
        rollbackApply: () {},
      );

      expect(logs, contains(contains('enqueue key=log-test id=0')));
      expect(logs, contains(contains('optimistic key=log-test id=0')));
      expect(logs, contains(contains('start key=log-test id=0')));
      expect(logs, contains(contains('commit key=log-test id=0')));
      expect(logs, contains(contains('queue-empty key=log-test')));
    });

    test('logs rollback on failure', () async {
      try {
        await queue.enqueue<void>(
          key: 'fail-test',
          execute: () async => throw Exception('oops'),
          optimisticApply: () {},
          commitApply: (_) {},
          rollbackApply: () {},
        );
      } catch (_) {}

      expect(logs, contains(contains('rollback key=fail-test id=0')));
    });
  });

  group('MutationQueue - edge cases', () {
    test('multiple keys process independently', () async {
      var stateA = 'initial';
      var stateB = 'initial';

      final cA = Completer<String>();
      final cB = Completer<String>();

      final fA = queue.enqueue<String>(
        key: 'key-a',
        execute: () => cA.future,
        optimisticApply: () => stateA = 'optimistic-a',
        commitApply: (r) => stateA = r,
        rollbackApply: () => stateA = 'initial',
      );

      final fB = queue.enqueue<String>(
        key: 'key-b',
        execute: () => cB.future,
        optimisticApply: () => stateB = 'optimistic-b',
        commitApply: (r) => stateB = r,
        rollbackApply: () => stateB = 'initial',
      );

      // Complete B before A (out of global order, but each key is independent).
      cB.complete('committed-b');
      await fB;
      expect(stateB, 'committed-b');
      expect(stateA, 'optimistic-a'); // A still pending.

      cA.complete('committed-a');
      await fA;
      expect(stateA, 'committed-a');
    });

    test('empty queue returns correct pendingCount', () {
      expect(queue.pendingCount, 0);
      expect(queue.hasPending('nonexistent'), isFalse);
    });
  });
}
