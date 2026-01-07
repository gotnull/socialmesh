import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_providers.dart';

/// Mixin for screens that require device connection.
/// Automatically shows a blocking overlay when device is disconnected.
mixin DeviceRequiredScreen<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// Override to provide custom message when disconnected
  String get disconnectedMessage => 'Connect device to use this feature';

  /// Override to provide custom action when disconnected
  VoidCallback? get onReconnectPressed => null;

  /// Override to return true if screen should pop when disconnected
  bool get popOnDisconnect => false;

  /// Override to provide custom disconnected widget
  Widget? buildDisconnectedOverlay(BuildContext context) => null;

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceConnectionProvider);
    final isConnected = deviceState.isConnected;

    // Handle pop on disconnect
    if (popOnDisconnect && !isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    return Stack(
      children: [
        // Main content - always build to maintain state
        buildContent(context),

        // Disconnected overlay
        if (!isConnected)
          Positioned.fill(
            child:
                buildDisconnectedOverlay(context) ??
                _DefaultDisconnectedOverlay(
                  message: disconnectedMessage,
                  onReconnect:
                      onReconnectPressed ??
                      () {
                        Navigator.of(context).pushNamed('/scanner');
                      },
                ),
          ),
      ],
    );
  }

  /// Build the main screen content
  Widget buildContent(BuildContext context);
}

/// Default overlay shown when device is disconnected
class _DefaultDisconnectedOverlay extends StatelessWidget {
  final String message;
  final VoidCallback onReconnect;

  const _DefaultDisconnectedOverlay({
    required this.message,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bluetooth_disabled,
                    size: 40,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Device Not Connected',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onReconnect,
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Connect Device'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget wrapper that blocks interaction when device is not connected.
/// Use this to wrap interactive elements that require device connection.
class DeviceRequiredInteraction extends ConsumerWidget {
  final Widget child;
  final String? blockedMessage;
  final bool showDisabled;
  final double disabledOpacity;

  const DeviceRequiredInteraction({
    super.key,
    required this.child,
    this.blockedMessage,
    this.showDisabled = true,
    this.disabledOpacity = 0.5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isDeviceConnectedProvider);

    if (isConnected) {
      return child;
    }

    if (showDisabled) {
      return GestureDetector(
        onTap: () => _showBlockedMessage(context),
        behavior: HitTestBehavior.opaque,
        child: IgnorePointer(
          child: Opacity(opacity: disabledOpacity, child: child),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showBlockedMessage(BuildContext context) {
    final message = blockedMessage ?? 'Connect device to use this feature';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bluetooth_disabled, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Builder widget that provides device connection state
class DeviceConnectionBuilder extends ConsumerWidget {
  final Widget Function(BuildContext context, bool isConnected) builder;

  const DeviceConnectionBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isDeviceConnectedProvider);
    return builder(context, isConnected);
  }
}

/// A button that is automatically disabled when device is not connected
class DeviceRequiredButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final String? blockedMessage;

  const DeviceRequiredButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.blockedMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isDeviceConnectedProvider);

    return FilledButton(
      onPressed: isConnected
          ? onPressed
          : () {
              _showBlockedMessage(context);
            },
      style:
          style ??
          (isConnected
              ? null
              : FilledButton.styleFrom(backgroundColor: Colors.grey.shade600)),
      child: child,
    );
  }

  void _showBlockedMessage(BuildContext context) {
    final message = blockedMessage ?? 'Connect device to use this feature';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bluetooth_disabled, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Icon button that is automatically disabled when device is not connected
class DeviceRequiredIconButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final String? blockedMessage;

  const DeviceRequiredIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.blockedMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isDeviceConnectedProvider);
    final theme = Theme.of(context);

    return IconButton(
      onPressed: isConnected
          ? onPressed
          : () {
              _showBlockedMessage(context);
            },
      icon: isConnected ? icon : Opacity(opacity: 0.5, child: icon),
      tooltip: tooltip,
      color: isConnected ? null : theme.disabledColor,
    );
  }

  void _showBlockedMessage(BuildContext context) {
    final message = blockedMessage ?? 'Connect device to use this feature';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bluetooth_disabled, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
