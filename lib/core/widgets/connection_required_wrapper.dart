// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'top_status_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/navigation/main_shell.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_providers.dart' as conn;
import '../theme.dart';
import '../transport.dart';

/// A wrapper widget that shows a "No Device Connected" screen when disconnected.
///
/// Use this widget to wrap screen content that requires an active device connection.
/// It automatically shows the disconnected UI when the device is not connected,
/// including options to scan for devices.
///
/// When disconnected, this widget renders a full Scaffold with its own AppBar
/// to completely replace the wrapped content.
///
/// Example usage:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return ConnectionRequiredWrapper(
///     screenTitle: 'Channels',
///     child: ChannelsScreen(),
///   );
/// }
/// ```
class ConnectionRequiredWrapper extends ConsumerWidget {
  /// The child widget to display when connected.
  final Widget child;

  /// The title to show in the AppBar when disconnected.
  /// If null, shows "Disconnected". (Kept for backward compatibility but
  /// we no longer replace the entire screen.)
  final String? screenTitle;

  /// Optional custom message to display when disconnected.
  final String? disconnectedMessage;

  /// Whether to show a reconnecting state animation.
  /// Defaults to true. (Used for banner message when enabled.)
  final bool showReconnectingState;

  /// Optional callback when user taps "Scan for Devices".
  /// If null, navigates to /scanner.
  final VoidCallback? onScanPressed;

  /// When true the wrapper will render a small, non-modal inline status banner
  /// instead of replacing the entire screen. Keep default false so MainShell's
  /// global banner is used by default.
  final bool showInlineBanner;

  const ConnectionRequiredWrapper({
    super.key,
    required this.child,
    this.screenTitle,
    this.disconnectedMessage,
    this.showReconnectingState = true,
    this.onScanPressed,
    this.showInlineBanner = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final autoReconnectState = ref.watch(autoReconnectStateProvider);
    final userDisconnected = ref.watch(userDisconnectedProvider);
    final settingsAsync = ref.watch(settingsServiceProvider);

    final isConnected = connectionStateAsync.when(
      data: (state) => state == DeviceConnectionState.connected,
      loading: () => false,
      error: (_, _) => false,
    );

    // Always show the underlying content so the UI remains interactive.
    if (isConnected) return child;

    // Only show the full-screen scan wrapper if the user manually disconnected
    // or if it's the first launch (never paired, auto-reconnect disabled)
    final hasEverPaired =
        settingsAsync.whenOrNull(
          data: (settings) => settings.lastDeviceId != null,
        ) ??
        false;
    final autoReconnectEnabled =
        settingsAsync.whenOrNull(data: (settings) => settings.autoReconnect) ??
        true;

    final isFirstLaunch = !hasEverPaired && !autoReconnectEnabled;

    if (userDisconnected || isFirstLaunch) {
      return _buildDisconnectedScreen(context, ref, autoReconnectState);
    }

    // Otherwise, show only the reconnection banner and keep main content visible
    if (showInlineBanner) {
      return _wrapWithInlineBanner(context, ref, child, autoReconnectState);
    }
    // Default: show main content (with banner handled by MainShell)
    return child;
  }

  // Kept for backward-compatibility (previously returned full-screen disconnected UI)
  Widget _buildDisconnectedScreen(
    BuildContext context,
    WidgetRef ref,
    AutoReconnectState autoReconnectState,
  ) {
    // Check if device was not found (may be connected elsewhere)
    final deviceState = ref.watch(conn.deviceConnectionProvider);
    final settingsAsync = ref.watch(settingsServiceProvider);
    final isDeviceNotFound =
        autoReconnectState == AutoReconnectState.failed &&
        deviceState.reason == conn.DisconnectReason.deviceNotFound;
    final savedDeviceName =
        settingsAsync.whenOrNull(data: (settings) => settings.lastDeviceName) ??
        'Your saved device';
    final isInvalidated = deviceState.isTerminalInvalidated;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        leading: const HamburgerMenuButton(),
        centerTitle: true,
        title: Text(
          screenTitle ?? 'Disconnected',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.textSecondary),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Show helpful banner when device not found
              if (isDeviceNotFound) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$savedDeviceName not found',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'If another app is connected to this device, disconnect from it first. Only one app can use Bluetooth at a time.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Icon(
                  isInvalidated
                      ? Icons.error_outline
                      : autoReconnectState == AutoReconnectState.failed
                          ? Icons.wifi_off
                          : Icons.bluetooth_disabled,
                  size: 64,
                  color: context.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  isInvalidated
                      ? 'Device Reset'
                      : autoReconnectState == AutoReconnectState.failed
                          ? 'Connection Failed'
                          : 'No Device Connected',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  disconnectedMessage ??
                      (isInvalidated
                          ? 'Device was reset or replaced. Set it up again.'
                          : (autoReconnectState == AutoReconnectState.failed
                              ? 'Could not find saved device'
                              : 'Connect to a Meshtastic device to get started')),
                  style: TextStyle(fontSize: 14, color: context.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
              ],
              ElevatedButton.icon(
                onPressed:
                    onScanPressed ??
                    () => Navigator.of(context).pushNamed('/scanner'),
                icon: const Icon(Icons.bluetooth_searching, size: 20),
                label: const Text('Scan for Devices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapWithInlineBanner(
    BuildContext context,
    WidgetRef ref,
    Widget child,
    AutoReconnectState autoReconnectState,
  ) {
    // Inline reconnection state variables replaced by `TopStatusBanner`.

    // Inline banner variables replaced by `TopStatusBanner`.

    final deviceState = ref.watch(conn.deviceConnectionProvider);

    return Stack(
      children: [
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: TopStatusBanner(
            autoReconnectState: autoReconnectState,
            autoReconnectEnabled: true,
            onRetry: () {
              ref
                  .read(conn.deviceConnectionProvider.notifier)
                  .startBackgroundConnection();
            },
            onGoToScanner: () => Navigator.of(context).pushNamed('/scanner'),
            deviceState: deviceState,
          ),
        ),
        // (replaced inline banner by TopStatusBanner)
      ],
    );
  }
}
