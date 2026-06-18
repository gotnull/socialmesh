// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_providers.dart';

/// A small, reusable top-of-screen connection status banner that matches
/// the blurred snack-bar styling and can be used in multiple places.
///
/// Animates in (slides down) when [visible] becomes true and animates out
/// (slides up) 2 seconds after the loading/reconnecting indicator stops.
class TopStatusBanner extends ConsumerStatefulWidget {
  final AutoReconnectState autoReconnectState;
  final bool autoReconnectEnabled;
  final VoidCallback onRetry;
  final VoidCallback? onGoToScanner;
  final DeviceConnectionState2 deviceState;

  /// Whether the parent wants the banner shown. The banner manages its own
  /// slide animation and may remain briefly visible after this becomes false.
  final bool visible;

  /// Called when the banner's *actual* on-screen visibility changes (i.e.
  /// after animations complete). Use this to keep [MediaQuery.removePadding]
  /// in sync with the banner's real footprint.
  final ValueChanged<bool>? onVisibilityChanged;

  const TopStatusBanner({
    super.key,
    required this.autoReconnectState,
    required this.autoReconnectEnabled,
    required this.onRetry,
    this.onGoToScanner,
    required this.deviceState,
    this.visible = true,
    this.onVisibilityChanged,
  });

  @override
  ConsumerState<TopStatusBanner> createState() => _TopStatusBannerState();
}

class _TopStatusBannerState extends ConsumerState<TopStatusBanner>
    with SingleTickerProviderStateMixin {
  bool _autoRetryTriggered = false;

  late final AnimationController _animController;
  late final Animation<double> _animation;
  Timer? _dismissTimer;

  /// Safety-net watchdog that fires after [_kReconnectTimeout] of
  /// continuous reconnecting state. When it fires, the auto-reconnect
  /// cycle is cancelled via [DeviceConnectionNotifier.cancelAutoReconnect]
  /// and the banner transitions to the "Device not found" state with
  /// actionable Retry / Connect options.
  Timer? _reconnectWatchdog;

  /// How long the banner tolerates a continuous reconnecting state before
  /// the watchdog forces a cancel.
  static const Duration _kReconnectTimeout = Duration(seconds: 90);

  /// Tracks whether the banner is taking up space on screen (animation > 0).
  bool _actuallyVisible = false;

  /// Cached display props frozen at the moment the banner starts animating
  /// out, so the content doesn't flash to a stale "Disconnected" state
  /// while the exit animation plays.
  AutoReconnectState? _frozenReconnectState;
  DeviceConnectionState2? _frozenDeviceState;

  // ──────────────────────── helpers ────────────────────────

  bool _isReconnecting(AutoReconnectState s) =>
      s == AutoReconnectState.scanning || s == AutoReconnectState.connecting;

  void _cancelDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  void _cancelReconnectWatchdog() {
    _reconnectWatchdog?.cancel();
    _reconnectWatchdog = null;
  }

  void _startReconnectWatchdog() {
    _cancelReconnectWatchdog();
    _reconnectWatchdog = Timer(_kReconnectTimeout, () {
      AppLogging.connection(
        '📡 TopStatusBanner: Reconnect watchdog fired after '
        '${_kReconnectTimeout.inSeconds}s — cancelling auto-reconnect',
      );
      _cancelReconnect();
    });
  }

  /// Cancel the active auto-reconnect cycle from the watchdog timer.
  /// Transitions the banner to the failed state with actionable
  /// options (Retry / Connect). For the user-tapped Cancel button see
  /// [_userCancelReconnect] which also blocks re-arm.
  void _cancelReconnect() {
    _cancelReconnectWatchdog();
    ref.read(deviceConnectionProvider.notifier).cancelAutoReconnect();
  }

  /// User-tapped authoritative cancel. Stops the retry cycle, blocks
  /// re-arm via `userDisconnected=true`, and clears the auto-reconnect
  /// state to `idle` (the Scanner becomes the next surface — no
  /// "Device not found" intermediate state). Tears down any in-flight
  /// transport link.
  void _userCancelReconnect() {
    _cancelReconnectWatchdog();
    _cancelDismissTimer();
    AppLogging.connection('RECONNECT_BANNER_CANCEL_TAPPED');
    // Fire-and-forget: the navigation to Scanner is dispatched
    // immediately by the caller; we don't want the user staring at the
    // banner while the transport disconnect awaits.
    unawaited(
      ref.read(deviceConnectionProvider.notifier).userCancelAutoReconnect(),
    );
  }

  void _startDismissTimer() {
    _cancelDismissTimer();
    // Suppress the 2 s auto-dismiss while the Meshtastic protocol is
    // not yet `ready`. Without this, the banner would vanish before
    // the two-phase handshake completes (regression visible to users
    // as "Unknown" parameters with no visible feedback). Configuring
    // and Recovering both keep the banner up.
    final bannerState = ref.read(meshtasticBannerStateProvider);
    if (bannerState != MeshtasticBannerState.passthrough) {
      AppLogging.connection(
        'RECONNECT_BANNER_DISMISS_SUPPRESSED bannerState=${bannerState.name}',
      );
      return;
    }
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _animateOut();
    });
  }

  void _animateIn() {
    _cancelDismissTimer();
    // Clear any frozen snapshot — we're showing live data again.
    _frozenReconnectState = null;
    _frozenDeviceState = null;
    _animController.forward();
    if (!_actuallyVisible) {
      _actuallyVisible = true;
      AppLogging.connection(
        'RECONNECT_BANNER_VISIBLE reason=animate_in '
        'autoReconnectState=${widget.autoReconnectState.name}',
      );
      // _animateIn() fires from didUpdateWidget. Any synchronous
      // onVisibilityChanged dispatch from here would call setState
      // on the parent while the parent is still building, which
      // Flutter rejects ("setState called during build"). Defer
      // via the shared _notifyVisibility post-frame helper.
      _notifyVisibility(true);
    }
  }

  void _animateOut() {
    _cancelDismissTimer();
    // Freeze the current display props so the banner content doesn't
    // change to a stale state while the exit animation plays.
    _frozenReconnectState ??= widget.autoReconnectState;
    _frozenDeviceState ??= widget.deviceState;
    AppLogging.connection(
      'RECONNECT_BANNER_HIDDEN reason=animate_out '
      'autoReconnectState=${widget.autoReconnectState.name}',
    );
    _animController.reverse();
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.reverse:
        // Notify at the START of reverse so the parent can begin its own
        // smooth padding transition in sync with our exit animation,
        // avoiding a sudden safe-area jump when the banner disappears.
        if (_actuallyVisible) {
          setState(() => _actuallyVisible = false);
          _notifyVisibility(false);
        }
      case AnimationStatus.dismissed:
        // Safety net: ensure we're marked hidden when animation completes.
        if (_actuallyVisible) {
          setState(() => _actuallyVisible = false);
          _notifyVisibility(false);
        }
      case AnimationStatus.forward:
        if (!_actuallyVisible) {
          setState(() => _actuallyVisible = true);
          _notifyVisibility(true);
        }
      case AnimationStatus.completed:
        break;
    }
  }

  /// Notify the parent of visibility changes via a post-frame callback
  /// to avoid calling setState on the parent during the build phase.
  void _notifyVisibility(bool visible) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisibilityChanged?.call(visible);
    });
  }

  /// Evaluate whether a dismiss timer should be running based on the
  /// current widget properties. Also manages the reconnect watchdog.
  void _evaluateDismissState({
    required bool wasReconnecting,
    required bool isNowReconnecting,
    required bool wasVisible,
    required bool isNowVisible,
  }) {
    // ── Reconnect watchdog management ──
    if (isNowReconnecting && !wasReconnecting) {
      // Reconnecting just started → arm the watchdog.
      _startReconnectWatchdog();
    } else if (!isNowReconnecting && wasReconnecting) {
      // Reconnecting just stopped → disarm the watchdog.
      _cancelReconnectWatchdog();
    }

    // ── Dismiss timer management (unchanged) ──

    // Reconnecting just started → cancel any pending dismiss, ensure visible
    if (isNowReconnecting && isNowVisible) {
      _cancelDismissTimer();
      if (!_animController.isForwardOrCompleted) _animateIn();
      return;
    }

    // Reconnecting just stopped while banner is (or should be) visible
    if (wasReconnecting && !isNowReconnecting && isNowVisible) {
      _startDismissTimer();
      return;
    }

    // Parent hid the banner (e.g. device connected) → animate out now.
    if (wasVisible && !isNowVisible) {
      _cancelDismissTimer();
      _animateOut();
      return;
    }
  }

  // ──────────────────────── lifecycle ────────────────────────

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _animController.addStatusListener(_onAnimationStatusChanged);

    if (widget.visible) {
      // Mark visible immediately so layout accounts for the banner,
      // but defer the animation start to avoid calling the parent's
      // onVisibilityChanged (which may setState) during the build phase.
      _actuallyVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _animController.forward();
          widget.onVisibilityChanged?.call(true);
        }
      });

      // If NOT reconnecting on first build, schedule dismiss.
      if (!_isReconnecting(widget.autoReconnectState)) {
        _startDismissTimer();
      } else {
        // Already reconnecting on first build — arm the watchdog.
        _startReconnectWatchdog();
      }
    }
  }

  @override
  void didUpdateWidget(covariant TopStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset the auto-retry flag when reconnect state changes so we
    // can trigger again on a new disconnect cycle.
    if (widget.autoReconnectState != oldWidget.autoReconnectState) {
      _autoRetryTriggered = false;
    }

    final wasReconnecting = _isReconnecting(oldWidget.autoReconnectState);
    final isNowReconnecting = _isReconnecting(widget.autoReconnectState);

    // Freeze the OLD widget's display state when visibility drops so the
    // exit animation keeps showing "Reconnecting..." (or whatever was on
    // screen) instead of flashing "Disconnected" for a frame.
    if (oldWidget.visible && !widget.visible) {
      _frozenReconnectState ??= oldWidget.autoReconnectState;
      _frozenDeviceState ??= oldWidget.deviceState;
    }

    // Banner just became visible → slide in
    if (widget.visible && !oldWidget.visible) {
      _animateIn();
      // If already reconnecting, no timer; otherwise start one.
      if (!isNowReconnecting) {
        _startDismissTimer();
      }
    }

    _evaluateDismissState(
      wasReconnecting: wasReconnecting,
      isNowReconnecting: isNowReconnecting,
      wasVisible: oldWidget.visible,
      isNowVisible: widget.visible,
    );
  }

  @override
  void dispose() {
    _cancelDismissTimer();
    _cancelReconnectWatchdog();
    _animController.removeStatusListener(_onAnimationStatusChanged);
    _animController.dispose();
    super.dispose();
  }

  // ──────────────────────── build ────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Meshtastic readiness banner state. Pure presentation — never
    // touches `unifiedConnectionStateProvider`. MeshCore sessions
    // resolve to `passthrough` so the existing banner logic below
    // remains the single source of truth for that protocol.
    final bannerState = ref.watch(meshtasticBannerStateProvider);
    final isConfiguring = bannerState == MeshtasticBannerState.configuring;
    final isDegraded = bannerState == MeshtasticBannerState.recovering;

    // Use frozen props during exit animation so content doesn't flash.
    final effectiveReconnectState =
        _frozenReconnectState ?? widget.autoReconnectState;
    final effectiveDeviceState = _frozenDeviceState ?? widget.deviceState;

    final isScanning = effectiveReconnectState == AutoReconnectState.scanning;
    final isConnecting =
        effectiveReconnectState == AutoReconnectState.connecting;
    final isReconnecting = isScanning || isConnecting;
    final isFailed = effectiveReconnectState == AutoReconnectState.failed;
    final isIdle = effectiveReconnectState == AutoReconnectState.idle;
    final isTerminalInvalidated = effectiveDeviceState.isTerminalInvalidated;
    final isUserDisconnected =
        effectiveDeviceState.reason == DisconnectReason.userDisconnected;
    final isAuthFailed =
        effectiveDeviceState.reason == DisconnectReason.authFailed;

    // Auto-trigger reconnect when the banner appears in idle+disconnected
    // state (unexpected disconnect where autoReconnectManager didn't kick
    // in). This gives the user immediate feedback instead of a dead
    // "Disconnected" banner. Skip if user manually disconnected — they
    // intentionally want to be disconnected (and with the /app route fix,
    // they should be on Scanner, not MainShell, anyway).
    // Also skip auth failures — auto-retry just hits the same PIN issue.
    if (widget.visible &&
        isIdle &&
        !isUserDisconnected &&
        !isTerminalInvalidated &&
        !isAuthFailed &&
        // Don't fire a parallel auto-reconnect while the readiness
        // restoreSession is doing its thing — the coordinator already
        // owns the recovery and a parallel scan would race it.
        !isConfiguring &&
        !isDegraded &&
        widget.autoReconnectEnabled &&
        !_autoRetryTriggered) {
      _autoRetryTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppLogging.connection(
            '📡 TopStatusBanner: Auto-triggering reconnect '
            '(idle + disconnected + not user-initiated)',
          );
          widget.onRetry();
        }
      });
    }

    // Meshtastic readiness override (presentation only). Wins over the
    // existing reconnect/disconnect text when the protocol is mid-
    // handshake or recovering, so the banner never shows "Connected"
    // while the protocol is wedged. MeshCore is unaffected (passthrough).
    final foregroundColor = isConfiguring
        ? context.accentColor
        : isDegraded
        ? AppTheme.errorRed
        : isTerminalInvalidated
        ? AppTheme.errorRed
        : isReconnecting
        ? context.accentColor
        : (isFailed ? AppTheme.errorRed : AccentColors.orange);

    final icon = isConfiguring
        ? Icons.bluetooth_searching_rounded
        : isDegraded
        ? Icons.bluetooth_disabled_rounded
        : isTerminalInvalidated
        ? Icons.error_outline_rounded
        : isReconnecting
        ? Icons.bluetooth_searching_rounded
        : Icons.bluetooth_disabled_rounded;

    final invalidatedMessage =
        'Device was reset or replaced. Forget it from Bluetooth settings and set it up again.'; // lint-allow: hardcoded-string
    final message = isConfiguring
        ? context.l10n.statusConfiguring
        : isDegraded
        ? context.l10n.statusDegraded
        : isTerminalInvalidated
        ? invalidatedMessage
        : isReconnecting
        ? (isScanning
              ? 'Searching for device...'
              : 'Reconnecting...') // lint-allow: hardcoded-string
        : isAuthFailed
        ? 'Authentication failed — re-pair in Scanner' // lint-allow: hardcoded-string
        : (isFailed
              ? 'Device not found'
              : 'Disconnected'); // lint-allow: hardcoded-string
    // Don't show retry for auth failures — retrying background connect
    // hits the same PIN/auth issue. The user needs Scanner to manually
    // re-pair (which triggers the system PIN dialog).
    final showRetryButton = isFailed && !isTerminalInvalidated && !isAuthFailed;

    // Connect button is tappable whenever we're NOT actively reconnecting,
    // OR when reconnecting (tapping cancel + navigates to scanner).
    final connectTappable = widget.onGoToScanner != null;

    final mq = MediaQuery.of(context);
    // Use viewPadding as a fallback: if an ancestor SafeArea / removePadding
    // has consumed padding.top (making it 0), viewPadding.top still carries the
    // real status-bar / dynamic-island inset so the banner never kisses the top.
    final safeTop = mq.padding.top > 0 ? mq.padding.top : mq.viewPadding.top;
    // Add a small breathing gap so content does not sit flush against the
    // dynamic island.
    final topPadding = safeTop + AppTheme.spacing8;
    const double kTopStatusContentHeight = kToolbarHeight;
    final bannerHeight = topPadding + kTopStatusContentHeight;

    return SizeTransition(
      sizeFactor: _animation,
      axisAlignment: -1.0, // anchor at top so it slides down
      child: ClipRect(
        child: SizedBox(
          height: bannerHeight,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.32),
                border: Border(
                  bottom: BorderSide(
                    color: foregroundColor.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: connectTappable
                      ? () {
                          if (isReconnecting) {
                            // User tapped during reconnecting — run the
                            // authoritative cancel (stops timers, sets
                            // userDisconnected, drives state to idle, tears
                            // down transport) before routing to Scanner.
                            _userCancelReconnect();
                          }
                          widget.onGoToScanner!();
                        }
                      : null,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: topPadding,
                      bottom: 12,
                    ),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(icon, size: 18, color: foregroundColor),
                                if (isReconnecting || isConfiguring)
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        foregroundColor,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Text(
                              message,
                              style: TextStyle(
                                color: foregroundColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (showRetryButton) ...[
                            TextButton.icon(
                              onPressed: () {
                                // User tapped retry — cancel dismiss timer
                                // so the banner stays while reconnecting.
                                _cancelDismissTimer();
                                widget.onRetry();
                              },
                              icon: Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: foregroundColor,
                              ),
                              label: Text(
                                'Retry',
                                style: TextStyle(
                                  color: foregroundColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: foregroundColor.withValues(alpha: 0.7),
                            ),
                          ] else if (isTerminalInvalidated) ...[
                            Text(
                              'Scan for Devices', // lint-allow: hardcoded-string
                              style: TextStyle(
                                color: foregroundColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: foregroundColor.withValues(alpha: 0.7),
                            ),
                          ] else if (!isReconnecting) ...[
                            Text(
                              'Connect',
                              style: TextStyle(
                                color: foregroundColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: foregroundColor.withValues(alpha: 0.7),
                            ),
                          ] else if (isReconnecting &&
                              widget.onGoToScanner != null) ...[
                            Text(
                              'Cancel',
                              style: TextStyle(
                                color: foregroundColor.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: foregroundColor.withValues(alpha: 0.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
