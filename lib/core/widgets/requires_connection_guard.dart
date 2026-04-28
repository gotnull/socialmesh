// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// RequiresConnectionGuard — wraps a node-required screen with a
// debounced disconnect handler. Brief transport blips (BLE/USB/TCP)
// during an active session show an inline "reconnecting…" banner and
// stay on the screen. Persistent disconnects past a grace window pop
// the user back to the parent route with the existing snackbar — same
// safety net we had before, just with a cushion for the common iOS BLE
// hiccup.
//
// The drawer's `requiresConnection: true` flag still prevents *entry*
// into a node-required screen while disconnected. This widget covers
// the symmetric case: once inside (e.g. SIP DM thread, Mesh Explorer),
// we don't kick the user off mid-activity for a 2-second blip.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../utils/snackbar.dart';
import '../l10n/l10n_extension.dart';
import '../theme.dart';
import '../transport.dart';
import 'status_banner.dart';

/// Grace period between observing a `connected → disconnected`
/// transition and acting on it. Covers the typical iOS BLE blip
/// (~1-3 s) plus the first auto-reconnect attempt
/// (`BackgroundReconnectManager` first backoff is 5 s, then connect
/// time). Anything past this is treated as a persistent disconnect.
const Duration kRequiresConnectionGuardGraceWindow = Duration(seconds: 10);

/// Wrap a screen pushed from a `requiresConnection: true` drawer item
/// so it survives brief disconnects and pops itself only when the
/// underlying mesh node stays disconnected past the grace window.
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

  /// Whether the inline "reconnecting…" banner is currently rendered.
  bool _showBanner = false;

  /// Countdown for the grace window. Cancelled on recovery, on dispose,
  /// and reset on every fresh `connected → disconnected` transition.
  Timer? _graceTimer;

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  void _onReconnected() {
    _wasConnected = true;
    _graceTimer?.cancel();
    _graceTimer = null;
    if (_showBanner) {
      setState(() => _showBanner = false);
    }
  }

  void _onDisconnected() {
    if (!_wasConnected) return;
    if (_graceTimer?.isActive == true) return;

    setState(() => _showBanner = true);

    // Capture navigator/messenger references before the async gap —
    // defensive pattern from CLAUDE.md async-safety rules.
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    _graceTimer = Timer(kRequiresConnectionGuardGraceWindow, () {
      if (!mounted) return;
      // Recovery may have flipped this off between schedule and fire.
      if (!_showBanner) return;
      setState(() => _showBanner = false);
      if (navigator.canPop()) {
        navigator.pop();
      }
      showWarningSnackBar(context, l10n.requiresConnectionGuardDisconnected);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DeviceConnectionState>>(connectionStateProvider, (
      previous,
      next,
    ) {
      final isConnectedNow =
          next.asData?.value == DeviceConnectionState.connected;
      if (isConnectedNow) {
        _onReconnected();
      } else {
        _onDisconnected();
      }
    });

    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: StatusBanner.warning(
                  title: context.l10n.requiresConnectionGuardReconnectingBanner,
                  isLoading: true,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
