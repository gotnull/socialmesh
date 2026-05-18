// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/meshcore/meshcore_adapter.dart'
    show meshCoreThroughputCounter;
import '../services/meshcore/meshcore_throughput_counter.dart';

/// Row 50.b: stream the active MeshCore throughput snapshot at 1 Hz.
///
/// The counter itself is the source of truth (a singleton owned by the
/// transport adapter). This provider just polls it once per second for
/// the Transport screen. 1 Hz keeps the rolling-rate display readable
/// without thrashing rebuilds.
final meshCoreThroughputSnapshotProvider =
    StreamProvider<MeshCoreThroughputSnapshot>((ref) {
      // Emit the current snapshot immediately so the UI has a frame
      // ready without waiting for the first tick.
      final controller = StreamController<MeshCoreThroughputSnapshot>();
      controller.add(meshCoreThroughputCounter.snapshot());
      final ticker = Stream<void>.periodic(const Duration(seconds: 1));
      final sub = ticker.listen((_) {
        if (controller.isClosed) return;
        controller.add(meshCoreThroughputCounter.snapshot());
      });
      ref.onDispose(() {
        sub.cancel();
        controller.close();
      });
      return controller.stream;
    });
