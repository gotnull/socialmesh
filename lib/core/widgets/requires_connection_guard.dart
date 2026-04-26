// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// RequiresConnectionGuard — wraps a node-required screen so that an
// in-session disconnect kicks the user back to the previous route with
// a snackbar.
//
// The drawer's `requiresConnection: true` flag prevents *entry* into a
// node-required screen while disconnected. This widget is the symmetric
// piece: once the user is inside (e.g. SIP Hub, Presence, Mesh
// Explorer) and the device drops, we shouldn't leave them poking at
// stale UI that can't honour any of its actions. Watch the connection
// stream, and on the transition from connected → not-connected pop
// back so they end up where they came from with a clear notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../utils/snackbar.dart';
import '../l10n/l10n_extension.dart';
import '../transport.dart';

/// Wrap a screen pushed from a `requiresConnection: true` drawer item
/// so it pops itself when the underlying mesh node disconnects.
///
/// The guard listens to [connectionStateProvider] and reacts only on
/// the *transition* from connected → not-connected. A screen that
/// opens while the device is already in a transitional state (e.g.
/// reconnecting) doesn't get popped immediately — only an actual loss
/// of an established connection triggers the redirect.
class RequiresConnectionGuard extends ConsumerStatefulWidget {
  const RequiresConnectionGuard({super.key, required this.child});

  /// The node-required screen to wrap.
  final Widget child;

  @override
  ConsumerState<RequiresConnectionGuard> createState() =>
      _RequiresConnectionGuardState();
}

class _RequiresConnectionGuardState
    extends ConsumerState<RequiresConnectionGuard> {
  /// Whether we observed an established connection at any point during
  /// this widget's lifetime. The pop-on-disconnect rule only fires
  /// after we've actually been connected — opening the screen during
  /// a reconnect loop shouldn't trigger an immediate redirect.
  bool _wasConnected = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
      previous,
      next,
    ) {
      final isConnectedNow =
          next.asData?.value == DeviceConnectionState.connected;
      if (isConnectedNow) {
        _wasConnected = true;
        return;
      }
      // Only pop after the user has actually been connected at least
      // once on this screen. Otherwise an in-flight reconnect would
      // bounce them out of a screen they just opened.
      if (!_wasConnected) return;
      if (!mounted) return;

      // Capture the navigator/messenger before any awaits — defensive
      // pattern from CLAUDE.md async-safety rules.
      final navigator = Navigator.of(context);
      final l10n = context.l10n;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (navigator.canPop()) {
          navigator.pop();
        }
        showWarningSnackBar(context, l10n.requiresConnectionGuardDisconnected);
      });
    });

    return widget.child;
  }
}
