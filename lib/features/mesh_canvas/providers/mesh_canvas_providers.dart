// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Riverpod scaffolding for the MeshCanvas feature.
//
// Spec anchor: docs/canvas/CANVAS_V0_1.md §S0 product invariants.
// S7.A scope: only the providers needed to drive the viewer over the
// Local Device Canvas. Mesh Canvas send path (S7-final), digest /
// sync (S9), and the full provider graph land in later slices.
//
// Riverpod conventions in this codebase (lib/providers/CLAUDE.md):
//   - Riverpod 3.x only; no StateNotifier / StateProvider /
//     ChangeNotifierProvider.
//   - No business logic inside Notifier.build(); delegate to the
//     repository or codec.
//   - `ref.onDispose` on every provider that creates an owning
//     resource (CanvasDatabase here).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/canvas/canvas_palette.dart';
import '../../../services/canvas/canvas_database.dart';
import '../../../services/canvas/canvas_models.dart';
import '../../../services/canvas/canvas_repository.dart';

/// Owns the `canvas.db` connection for the app's lifetime.
final canvasDatabaseProvider = FutureProvider<CanvasDatabase>((ref) async {
  final db = CanvasDatabase();
  await db.init();
  ref.onDispose(() {
    // Close is fire-and-forget; provider teardown can't await.
    db.close();
  });
  return db;
});

/// Typed CRUD layer over [canvasDatabaseProvider].
final canvasRepositoryProvider = FutureProvider<CanvasRepository>((ref) async {
  final db = await ref.watch(canvasDatabaseProvider.future);
  return CanvasRepository(db);
});

/// The auto-created Local Device Canvas (`scope = 'local'`). Always
/// returns a row — created on first read, returned thereafter. Mesh
/// canvas list lookups land in S7.C.
final localDeviceCanvasProvider = FutureProvider<CanvasSummary>((ref) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  return repo.getOrCreateLocalCanvas();
});

/// Painted cells for a specific canvas. The S7.A viewer reads this for
/// the Local Device Canvas. Re-fetched whenever `ref.invalidate` is
/// called on the family entry (the painter callback does this after
/// every accepted paint).
final canvasCellsProvider = FutureProvider.family<List<CanvasCell>, int>((
  ref,
  canvasLocalId,
) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  return repo.getCanvasCells(canvasLocalId);
});

/// User's currently-selected palette index. Defaults to palette index
/// 8 (black) — a sensible "any colour but the erase sentinel" start.
/// In S7.A, only [SocialMeshPalette.quickStripIndices] values flow
/// through here from the bottom strip; the full sheet in S7.B can
/// emit any index in 0..63.
final selectedColorProvider = NotifierProvider<SelectedColorNotifier, int>(
  SelectedColorNotifier.new,
);

class SelectedColorNotifier extends Notifier<int> {
  /// Default starting colour. Black is high-contrast on the dark
  /// canvas background and is in the quick strip.
  static const int _initialIndex = 8;

  @override
  int build() => _initialIndex;

  /// Set the active palette index. Out-of-range inputs are rejected
  /// silently so the UI can't accidentally pick a reserved or
  /// unknown index — the wire codec would drop the resulting paint
  /// anyway, but this keeps the state honest.
  ///
  /// Also pushes the chosen index into [recentColorsProvider] so the
  /// palette sheet's "recent" rail reflects what the user actually
  /// painted with, not just what they hovered.
  void select(int paletteIndex) {
    if (paletteIndex < 0 || paletteIndex > SocialMeshPalette.maxIndex) return;
    state = paletteIndex;
    ref.read(recentColorsProvider.notifier).push(paletteIndex);
  }
}

/// Most-recently-used palette indices, newest first. Capped at
/// [RecentColorsNotifier.maxRecents] entries. In-session only in S7.B
/// — no SharedPreferences yet because the value of "recents survive
/// app restart" is small and the persistence glue would dominate the
/// slice. A later slice can add disk-backed recall without changing
/// any caller.
final recentColorsProvider = NotifierProvider<RecentColorsNotifier, List<int>>(
  RecentColorsNotifier.new,
);

class RecentColorsNotifier extends Notifier<List<int>> {
  /// Soft cap — picked to fit comfortably as a single pinned row at
  /// the top of the palette sheet at any phone width without
  /// horizontal scroll on a 360pt screen.
  static const int maxRecents = 8;

  @override
  List<int> build() => const <int>[];

  /// Insert [paletteIndex] at the head of the recents list. If it
  /// already exists, move-to-front rather than duplicate. Out-of-range
  /// indices are ignored (defence in depth — [SelectedColorNotifier]
  /// already validates).
  void push(int paletteIndex) {
    if (paletteIndex < 0 || paletteIndex > SocialMeshPalette.maxIndex) return;
    final next = <int>[paletteIndex];
    for (final existing in state) {
      if (existing == paletteIndex) continue;
      next.add(existing);
      if (next.length >= maxRecents) break;
    }
    state = next;
  }
}

/// Monotonic per-author op_seq counter for local paints. Local Device
/// Canvas paints never broadcast, so the value doesn't need to
/// survive process death; an in-memory u8 counter is enough for the
/// 6-field dedupe key (CANVAS_V0_1.md §9) to keep two same-second
/// paints distinguishable.
final localCanvasOpSeqProvider =
    NotifierProvider<LocalCanvasOpSeqNotifier, int>(
      LocalCanvasOpSeqNotifier.new,
    );

class LocalCanvasOpSeqNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Return the next op_seq value (mod 256) and advance.
  int takeNext() {
    final next = state;
    state = (state + 1) & 0xFF;
    return next;
  }
}
