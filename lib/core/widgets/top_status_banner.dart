import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_providers.dart';

/// A small, reusable top-of-screen connection status banner that matches
/// the blurred snack-bar styling and can be used in multiple places.
class TopStatusBanner extends ConsumerWidget {
  final AutoReconnectState autoReconnectState;
  final bool autoReconnectEnabled;
  final VoidCallback onRetry;
  final VoidCallback? onGoToScanner;
  final DeviceConnectionState2 deviceState;

  const TopStatusBanner({
    super.key,
    required this.autoReconnectState,
    required this.autoReconnectEnabled,
    required this.onRetry,
    this.onGoToScanner,
    required this.deviceState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final isScanning = autoReconnectState == AutoReconnectState.scanning;
    final isConnecting = autoReconnectState == AutoReconnectState.connecting;
    final isReconnecting = isScanning || isConnecting;
    final isFailed = autoReconnectState == AutoReconnectState.failed;
    final isTerminalInvalidated = deviceState.isTerminalInvalidated;

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
        : (isFailed ? 'Device not found' : 'Disconnected');
    final showRetryButton = isFailed && !isTerminalInvalidated;

    final topPadding = MediaQuery.of(context).padding.top;
    // Use kToolbarHeight as a single source of truth for common top bar sizes
    const double kTopStatusContentHeight = kToolbarHeight;
    final bannerHeight = topPadding + kTopStatusContentHeight;

    // The banner is tappable for navigation but does NOT block interactions below
    return SizedBox(
      height: bannerHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.32),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(
                color: foregroundColor.withValues(alpha: 0.25),
                width: 1,
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
                onTap:
                    ((isTerminalInvalidated ||
                            isFailed ||
                            (!isReconnecting && !autoReconnectEnabled)) &&
                        onGoToScanner != null)
                    ? onGoToScanner
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
                            onPressed: onRetry,
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
    );
  }
}
