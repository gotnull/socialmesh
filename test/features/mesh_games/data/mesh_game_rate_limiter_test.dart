// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_games/data/mesh_game_rate_limiter.dart';

void main() {
  test('allows first acquire', () {
    final l = MeshGameRateLimiter();
    expect(l.tryAcquire(0x1234), isTrue);
  });

  test('rejects a second acquire within the window', () {
    var now = DateTime(2026);
    final l = MeshGameRateLimiter(clock: () => now);
    expect(l.tryAcquire(0xAA), isTrue);
    now = now.add(const Duration(milliseconds: 500));
    expect(l.tryAcquire(0xAA), isFalse);
  });

  test('allows again once the window elapses', () {
    var now = DateTime(2026);
    final l = MeshGameRateLimiter(
      minInterval: const Duration(seconds: 2),
      clock: () => now,
    );
    expect(l.tryAcquire(0xBB), isTrue);
    now = now.add(const Duration(seconds: 2, milliseconds: 1));
    expect(l.tryAcquire(0xBB), isTrue);
  });

  test('different peers have independent budgets', () {
    var now = DateTime(2026);
    final l = MeshGameRateLimiter(clock: () => now);
    expect(l.tryAcquire(1), isTrue);
    expect(l.tryAcquire(2), isTrue);
    // Peer 1 is throttled, peer 2 is not.
    expect(l.tryAcquire(1), isFalse);
  });
}
