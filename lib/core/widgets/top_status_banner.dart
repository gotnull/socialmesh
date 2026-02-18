// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void _startDismissTimer() {
    _cancelDismissTimer();
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
      widget.onVisibilityChanged?.call(true);
    }
  }

  void _animateOut() {
    _cancelDismissTimer();
    // Freeze the current display props so the banner content doesn't
    // change to a stale state while the exit animation plays.
    _frozenReconnectState ??= widget.autoReconnectState;
    _frozenDeviceState ??= widget.deviceState;
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
  /// current widget properties.
  void _evaluateDismissState({
    required bool wasReconnecting,
    required bool isNowReconnecting,
    required bool wasVisible,
    required bool isNowVisible,
  }) {
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
    _animController.removeStatusListener(_onAnimationStatusChanged);
    _animController.dispose();
    super.dispose();
  }

  // ──────────────────────── build ────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

    final foregroundColor = isTerminalInvalidated
        ? AppTheme.errorRed
        : isReconnecting
        ? context.accentColor
        : (isFailed ? AppTheme.errorRed : Colors.orange);

    final icon = isTerminalInvalidated
        ? Icons.error_outline_rounded
        : isReconnecting
        ? Icons.bluetooth_searching_rounded
        : Icons.bluetooth_disabled_rounded;

    final invalidatedMessage =
        'Device was reset or replaced. Forget it from Bluetooth settings and set it up again.';
    final message = isTerminalInvalidated
        ? invalidatedMessage
        : isReconnecting
        ? (isScanning ? 'Searching for device...' : 'Reconnecting...')
        : isAuthFailed
        ? 'Authentication failed — re-pair in Scanner'
        : (isFailed ? 'Device not found' : 'Disconnected');
    // Don't show retry for auth failures — retrying background connect
    // hits the same PIN/auth issue. The user needs Scanner to manually
    // re-pair (which triggers the system PIN dialog).
    final showRetryButton = isFailed && !isTerminalInvalidated && !isAuthFailed;

    // Connect button is tappable whenever we're NOT actively reconnecting.
    final connectTappable = !isReconnecting && widget.onGoToScanner != null;

    final topPadding = MediaQuery.of(context).padding.top;
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
                  onTap: connectTappable ? widget.onGoToScanner : null,
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
                                if (isReconnecting)
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
                          const SizedBox(width: 12),
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
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: foregroundColor.withValues(alpha: 0.7),
                            ),
                          ] else if (isTerminalInvalidated) ...[
                            Text(
                              'Scan for Devices',
                              style: TextStyle(
                                color: foregroundColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
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
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: foregroundColor.withValues(alpha: 0.7),
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
