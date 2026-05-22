// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Snapshot composer. Combines every read facade into one
// [WatchCompanionSnapshot] for the Watch surface. Each slice is wrapped
// in defensive try/catch so a single broken facade degrades that section
// rather than throwing the whole snapshot.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';
import 'package:socialmesh/providers/locale_provider.dart';

import '../models/watch_companion_capabilities.dart';
import '../models/watch_companion_channel_preview.dart';
import '../models/watch_companion_connection_state.dart';
import '../models/watch_companion_inbox_preview.dart';
import '../models/watch_companion_node_preview.dart';
import '../models/watch_companion_snapshot.dart';
import 'watch_canned_messages_composer.dart';
import 'watch_capabilities_composer.dart';
import 'watch_channels_facade.dart';
import 'watch_inbox_facade.dart';
import 'watch_node_preview_composer.dart';
import 'watch_readiness_facade.dart';

/// The top-level Watch snapshot. Rebuilds whenever any of its slice
/// providers fires. Subscribers should consume this via a stream bridge
/// (see [ComposingWatchCompanionService]) rather than reading the raw
/// Provider, so each rebuild reaches the WatchConnectivity bridge.
///
/// Throw safety: every slice read is wrapped. If a slice fails the
/// composer logs via [AppLogging.watchCompanion] and substitutes a safe
/// empty value, so the Watch always renders something coherent.
///
/// Defence-in-depth caps: inbox previews and node previews are trimmed
/// to their max-rows constants here, even though the facades already
/// apply the same caps. Catches a regression in either facade without
/// crashing the Watch surface.
final watchSnapshotComposerProvider = Provider<WatchCompanionSnapshot>((ref) {
  final connection = _readSlice<WatchCompanionConnectionState>(
    () => ref.watch(watchReadinessFacadeProvider),
    label: 'readiness',
    fallback: () => const WatchCompanionConnectionState(
      status: WatchCompanionConnectionStatus.unsupported,
      readinessReason: 'readiness_facade_unavailable',
    ),
  );

  final inbox = _readSlice<WatchCompanionInboxPreview>(
    () => ref.watch(watchInboxFacadeProvider),
    label: 'inbox',
    fallback: () => const WatchCompanionInboxPreview(
      unreadCount: 0,
      previews: <WatchCompanionInboxMessage>[],
    ),
  );

  final nodes = _readSlice<List<WatchCompanionNodePreview>>(
    () => ref.watch(watchNodePreviewProvider),
    label: 'nodes',
    fallback: () => const <WatchCompanionNodePreview>[],
  );

  final channels = _readSlice<List<WatchCompanionChannelPreview>>(
    () => ref.watch(watchChannelsFacadeProvider),
    label: 'channels',
    fallback: () => const <WatchCompanionChannelPreview>[],
  );

  final cappedInbox = inbox.previews.length > kWatchInboxMaxRows
      ? WatchCompanionInboxPreview(
          unreadCount: inbox.unreadCount,
          previews: inbox.previews
              .take(kWatchInboxMaxRows)
              .toList(growable: false),
        )
      : inbox;
  final cappedNodes = nodes.length > kWatchNodesMaxRows
      ? nodes.take(kWatchNodesMaxRows).toList(growable: false)
      : nodes;

  final WatchCompanionCapabilities capabilities = deriveWatchCapabilities(
    connection: connection,
    inboxHasData:
        cappedInbox.previews.isNotEmpty || cappedInbox.unreadCount > 0,
    nodesHasData: cappedNodes.isNotEmpty,
  );

  // Watch the in-app locale picker so the snapshot rebuilds (and the
  // Watch receives fresh canned-message labels) whenever the user
  // changes the language in Appearance & Accessibility settings.
  ref.watch(localeProvider);

  return WatchCompanionSnapshot(
    generatedAt: DateTime.now().millisecondsSinceEpoch,
    connection: connection,
    inbox: cappedInbox,
    nodes: cappedNodes,
    channels: channels,
    cannedMessages: buildCannedMessages(safeL10n()),
    capabilities: capabilities,
  );
});

/// Reads one slice, returning [fallback] on any error and logging the
/// failure via the watch-companion logger. Keeps the snapshot composer
/// total: never throws because of one bad facade.
T _readSlice<T>(
  T Function() read, {
  required String label,
  required T Function() fallback,
}) {
  try {
    return read();
  } catch (e, st) {
    AppLogging.watchCompanion(
      'snapshot composer slice "$label" failed: $e\n$st',
    );
    return fallback();
  }
}
