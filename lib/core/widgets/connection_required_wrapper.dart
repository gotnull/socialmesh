import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/navigation/main_shell.dart';
import '../../providers/app_providers.dart';
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
      return _buildReconnectingScreen(context, autoReconnectState);
    }

    // Otherwise show disconnected state with full screen replacement
    return _buildDisconnectedScreen(context, ref, autoReconnectState);
  }

  Widget _buildDisconnectedScreen(
    BuildContext context,
    WidgetRef ref,
    AutoReconnectState autoReconnectState,
  ) {
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
    AutoReconnectState autoReconnectState,
  ) {
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
      body: Center(
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
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
