// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mesh_models.dart';
import 'app_providers.dart';

// App-side display order for the Channels list, as radio slot indices.
// Purely presentational: the radio's slot assignment never changes, so
// message routing and channel identity are untouched by reordering.
class ChannelsDisplayOrderNotifier extends Notifier<List<int>> {
  @override
  List<int> build() {
    final settings = ref.watch(settingsServiceProvider).value;
    return settings?.channelsDisplayOrder ?? const [];
  }

  Future<void> setOrder(List<int> order) async {
    state = List.unmodifiable(order);
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setChannelsDisplayOrder(order);
  }
}

final channelsDisplayOrderProvider =
    NotifierProvider<ChannelsDisplayOrderNotifier, List<int>>(
      ChannelsDisplayOrderNotifier.new,
    );

/// Sorts [channels] by the saved display [order]. Slots not present in
/// the saved order (channels added after the last reorder) follow the
/// ordered ones, keeping their relative slot order. An empty order is a
/// passthrough, preserving the radio's slot ordering.
List<ChannelConfig> applyChannelDisplayOrder(
  List<ChannelConfig> channels,
  List<int> order,
) {
  if (order.isEmpty) return channels;
  final position = <int, int>{
    for (var i = 0; i < order.length; i++) order[i]: i,
  };
  final sorted = List<ChannelConfig>.from(channels);
  sorted.sort((a, b) {
    final pa = position[a.index] ?? order.length + a.index;
    final pb = position[b.index] ?? order.length + b.index;
    return pa.compareTo(pb);
  });
  return sorted;
}
