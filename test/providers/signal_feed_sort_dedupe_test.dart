import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/social.dart';
import 'package:socialmesh/providers/signal_providers.dart';

Post _signal({
  required String id,
  required DateTime createdAt,
  DateTime? expiresAt,
  int? meshNodeId,
  int? hopCount,
}) {
  return Post(
    id: id,
    authorId: 'author_$id',
    content: 'signal $id',
    createdAt: createdAt,
    postMode: PostMode.signal,
    origin: SignalOrigin.mesh,
    expiresAt: expiresAt,
    meshNodeId: meshNodeId,
    hopCount: hopCount,
  );
}

void main() {
  test(
    'sortSignalsForFeed prioritizes my node, then hopCount, expiry, createdAt',
    () {
      final now = DateTime(2024, 1, 1, 12, 0, 0);
      final myNodeNum = 42;

      final mine = _signal(
        id: 'mine',
        createdAt: now.subtract(const Duration(minutes: 1)),
        expiresAt: now.add(const Duration(minutes: 10)),
        meshNodeId: myNodeNum,
        hopCount: 2,
      );
      final close = _signal(
        id: 'close',
        createdAt: now.subtract(const Duration(minutes: 2)),
        expiresAt: now.add(const Duration(minutes: 5)),
        meshNodeId: 7,
        hopCount: 0,
      );
      final far = _signal(
        id: 'far',
        createdAt: now.subtract(const Duration(minutes: 3)),
        expiresAt: now.add(const Duration(minutes: 1)),
        meshNodeId: 9,
        hopCount: 3,
      );

      final sorted = sortSignalsForFeed([far, close, mine], myNodeNum);
      expect(sorted.first.id, 'mine');
      expect(sorted[1].id, 'close');
      expect(sorted[2].id, 'far');
    },
  );

  test('sortSignalsForFeed uses expiry then createdAt when hopCount ties', () {
    final now = DateTime(2024, 1, 1, 12, 0, 0);

    final soon = _signal(
      id: 'soon',
      createdAt: now.subtract(const Duration(minutes: 1)),
      expiresAt: now.add(const Duration(minutes: 1)),
      meshNodeId: 1,
      hopCount: 1,
    );
    final later = _signal(
      id: 'later',
      createdAt: now.subtract(const Duration(minutes: 10)),
      expiresAt: now.add(const Duration(minutes: 5)),
      meshNodeId: 2,
      hopCount: 1,
    );
    final newest = _signal(
      id: 'newest',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      meshNodeId: 3,
      hopCount: 1,
    );

    final sorted = sortSignalsForFeed([later, newest, soon], null);
    expect(sorted.first.id, 'soon');
    expect(sorted[1].id, 'newest');
    expect(sorted[2].id, 'later');
  });

  test('SignalFeedState.withSignals deduplicates by id', () {
    final now = DateTime(2024, 1, 1, 12, 0, 0);
    final original = _signal(id: 'dup', createdAt: now);
    final updated = _signal(
      id: 'dup',
      createdAt: now,
    ).copyWith(content: 'updated');

    final state = SignalFeedState().withSignals([original, updated]);
    expect(state.signals.length, 1);
    expect(state.signals.first.content, 'updated');
  });
}
