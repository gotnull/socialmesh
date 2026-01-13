import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/navigation/main_shell.dart';
import '../../providers/app_providers.dart';
import '../../providers/connection_providers.dart' as conn;
import '../theme.dart';
import '../transport.dart';
import 'loading_indicator.dart';

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
  /// If null, shows "Disconnected".
  final String? screenTitle;

  /// Optional custom message to display when disconnected.
  final String? disconnectedMessage;

  /// Whether to show a reconnecting state animation.
  /// Defaults to true.
  final bool showReconnectingState;

  /// Optional callback when user taps "Scan for Devices".
  /// If null, navigates to /scanner.
  final VoidCallback? onScanPressed;

  const ConnectionRequiredWrapper({
    super.key,
    required this.child,
    this.screenTitle,
    this.disconnectedMessage,
    this.showReconnectingState = true,
    this.onScanPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final autoReconnectState = ref.watch(autoReconnectStateProvider);

    final isConnected = connectionStateAsync.when(
      data: (state) => state == DeviceConnectionState.connected,
      loading: () => false,
      error: (_, _) => false,
    );

    final isReconnecting =
        autoReconnectState == AutoReconnectState.scanning ||
        autoReconnectState == AutoReconnectState.connecting;

    // If connected, show the child content
    if (isConnected) {
      return child;
    }

    // If reconnecting and we want to show that state
    if (isReconnecting && showReconnectingState) {
      return _buildReconnectingScreen(context, ref, autoReconnectState);
    }

    // Otherwise show disconnected state with full screen replacement
    return _buildDisconnectedScreen(context, ref, autoReconnectState);
  }

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
                  autoReconnectState == AutoReconnectState.failed
                      ? Icons.wifi_off
                      : Icons.bluetooth_disabled,
                  size: 64,
                  color: context.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  autoReconnectState == AutoReconnectState.failed
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
                      (autoReconnectState == AutoReconnectState.failed
                          ? 'Could not find saved device'
                          : 'Connect to a Meshtastic device to get started'),
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

  Widget _buildReconnectingScreen(
    BuildContext context,
    WidgetRef ref,
    AutoReconnectState autoReconnectState,
  ) {
    // Get saved device name to show in info banner
    final settingsAsync = ref.watch(settingsServiceProvider);
    final savedDeviceName =
        settingsAsync.whenOrNull(data: (settings) => settings.lastDeviceName) ??
        'Your saved device';

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        leading: const HamburgerMenuButton(),
        centerTitle: true,
        title: Text(
          screenTitle ?? 'Reconnecting...',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Info banner about device possibly being connected elsewhere
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
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
                          'Looking for $savedDeviceName',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'If another app is connected to this device, please disconnect from it first. Only one app can use Bluetooth at a time.',
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
            // Center content
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LoadingIndicator(size: 48),
                    const SizedBox(height: 24),
                    Text(
                      autoReconnectState == AutoReconnectState.scanning
                          ? 'Scanning for device...'
                          : 'Connecting...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait...',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Cancel button to stop auto-reconnect and scan for other devices
                    TextButton.icon(
                      onPressed: () {
                        // Cancel the auto-reconnect
                        ref
                            .read(autoReconnectStateProvider.notifier)
                            .setState(AutoReconnectState.idle);
                        // Mark as user disconnected to prevent further auto-reconnect
                        ref
                            .read(userDisconnectedProvider.notifier)
                            .setUserDisconnected(true);
                        // Navigate to scanner
                        if (onScanPressed != null) {
                          onScanPressed!();
                        } else {
                          Navigator.of(context).pushNamed('/scanner');
                        }
                      },
                      icon: Icon(
                        Icons.bluetooth_searching,
                        size: 18,
                        color: context.textSecondary,
                      ),
                      label: Text(
                        'Scan for Other Devices',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
