// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:collection';

import 'logging.dart';

/// A lightweight per-key FIFO mutation queue that guarantees:
/// - Optimistic UI updates happen immediately on enqueue
/// - Network mutations execute sequentially per key
/// - Responses are processed in enqueue order (no out-of-order bugs)
/// - Failures trigger rollback of the optimistic change
///
/// Usage:
/// ```dart
/// final queue = MutationQueue();
/// await queue.enqueue<bool>(
///   key: 'like:$postId',
///   execute: () => service.likePost(postId),
///   optimisticApply: () => notifier.setLiked(postId, true),
///   commitApply: (_) {}, // server confirmed, nothing extra needed
///   rollbackApply: () => notifier.setLiked(postId, false),
/// );
/// ```
class MutationQueue {
  MutationQueue();

  /// Per-key queues of pending task closures.
  final Map<String, _KeyQueue> _queues = {};

  /// Global monotonically increasing sequence number.
  int _nextId = 0;

  /// Logger function, replaceable for testing.
  void Function(String message) log = AppLogging.social;

  /// Enqueue a mutation for a given [key].
  ///
  /// - [optimisticApply] runs synchronously and immediately.
  /// - [execute] is the async network call, deferred until this entry
  ///   reaches the head of its key's queue.
  /// - [commitApply] runs on successful [execute] completion.
  /// - [rollbackApply] runs if [execute] throws.
  ///
  /// Returns a [Future] that completes with the result of [execute],
  /// or throws if [execute] fails (after rollback).
  Future<T> enqueue<T>({
    required String key,
    required Future<T> Function() execute,
    required void Function() optimisticApply,
    required void Function(T result) commitApply,
    required void Function() rollbackApply,
  }) {
    final id = _nextId++;

    log('MutationQueue: enqueue key=$key id=$id');

    // Apply optimistic update immediately (synchronous).
    try {
      optimisticApply();
      log('MutationQueue: optimistic key=$key id=$id');
    } catch (e) {
      log('MutationQueue: optimistic-failed key=$key id=$id error=$e');
      return Future.error(e);
    }

    final completer = Completer<T>();

    // Wrap the entire execution in a closure that captures type-safe
    // references. The queue stores these as Future<void> Function() so
    // generic type information is preserved inside the closure, avoiding
    // covariant casting issues with Queue<_MutationEntry<dynamic>>.
    Future<void> task() async {
      log('MutationQueue: start key=$key id=$id');
      try {
        final result = await execute();
        try {
          commitApply(result);
          log('MutationQueue: commit key=$key id=$id');
        } catch (e) {
          log('MutationQueue: commit-failed key=$key id=$id error=$e');
        }
        completer.complete(result);
      } catch (e, st) {
        log('MutationQueue: rollback key=$key id=$id error=$e');
        try {
          rollbackApply();
        } catch (rollbackError) {
          log(
            'MutationQueue: rollback-failed key=$key '
            'id=$id error=$rollbackError',
          );
        }
        completer.completeError(e, st);
      }
    }

    final queue = _queues.putIfAbsent(key, _KeyQueue.new);
    queue.entries.add(task);

    // If no task is currently executing for this key, start processing.
    if (!queue.isProcessing) {
      unawaited(_processQueue(key));
    }

    return completer.future;
  }

  /// Whether there are any pending mutations for [key].
  bool hasPending(String key) {
    final queue = _queues[key];
    return queue != null && (queue.isProcessing || queue.entries.isNotEmpty);
  }

  /// Total number of pending mutations across all keys.
  int get pendingCount {
    var count = 0;
    for (final queue in _queues.values) {
      count += queue.entries.length;
      if (queue.isProcessing) count++;
    }
    return count;
  }

  /// Process task closures for [key] sequentially.
  Future<void> _processQueue(String key) async {
    final queue = _queues[key];
    if (queue == null) return;
    if (queue.isProcessing) return;

    queue.isProcessing = true;

    while (queue.entries.isNotEmpty) {
      final task = queue.entries.removeFirst();
      await task();
    }

    queue.isProcessing = false;
    _queues.remove(key);
    log('MutationQueue: queue-empty key=$key');
  }
}

/// Internal queue state for a single key.
class _KeyQueue {
  final Queue<Future<void> Function()> entries =
      Queue<Future<void> Function()>();
  bool isProcessing = false;
}
