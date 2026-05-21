// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Protocol-neutral node-preview composer. Public watch_companion files
// MUST NOT import this file outside the snapshot composer.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart'
    show nodeDexSortedEntriesProvider;

import '../models/watch_companion_node_preview.dart';

/// Maximum number of node rows surfaced to the Watch. The composer
/// re-applies this cap as defence-in-depth.
const int kWatchNodesMaxRows = 5;

/// Compose the recent-nodes preview from the NodeDex (which is already
/// protocol-neutral on the phone). Sorting is delegated to the upstream
/// provider, which orders by `node.lastHeard` desc with fallback to
/// `entry.lastSeen` (matches the NodeDex screen's default sort).
///
/// `hops` is always null in v1 because MeshNode does not expose a hop
/// count; the field is reserved on the wire for a future protocol
/// extension. MeshCore entries surface only when their nodes have been
/// ingested into the NodeDex, which is the same NodeDex behavior the
/// phone UI shows.
final watchNodePreviewProvider = Provider<List<WatchCompanionNodePreview>>((
  ref,
) {
  final entries = ref.watch(nodeDexSortedEntriesProvider);

  return entries
      .take(kWatchNodesMaxRows)
      .map((tuple) {
        final (entry, node) = tuple;
        final lastHeard =
            (node?.lastHeard ?? entry.lastSeen).millisecondsSinceEpoch;

        return WatchCompanionNodePreview(
          nodeId: entry.nodeNum.toString(),
          shortName: node?.shortName,
          longName: node?.longName,
          lastHeardMs: lastHeard,
          rssi: node?.rssi,
          hops: null,
        );
      })
      .toList(growable: false);
});
