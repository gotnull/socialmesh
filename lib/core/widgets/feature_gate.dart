import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/connection_providers.dart';
import '../command/commands.dart';

/// A widget that gates access to features based on their requirements.
///
/// When the feature is available, renders [child].
/// When unavailable, shows [placeholder] or a default unavailability message.
///
/// Usage:
/// ```dart
/// FeatureGate(
///   feature: FeatureId.sendMessage,
///   child: SendMessageButton(),
///   placeholder: DisabledSendButton(),
/// )
/// ```
class FeatureGate extends ConsumerWidget {
  /// The feature ID to check availability for
  final FeatureId feature;

  /// The widget to show when the feature is available
  final Widget child;

  /// Optional custom placeholder when feature is unavailable.
  /// If null, a default message will be shown.
  final Widget? placeholder;

  /// If true, shows a disabled/grayed out version of [child] instead of placeholder
  /// when unavailable. The child will be wrapped in an IgnorePointer + Opacity.
  final bool showDisabled;

  /// Opacity for the disabled state when [showDisabled] is true. Default 0.5.
  final double disabledOpacity;

  /// Optional callback when tapped while unavailable.
  /// Useful for showing a snackbar or dialog explaining why feature is unavailable.
  final VoidCallback? onUnavailableTap;

  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.placeholder,
    this.showDisabled = false,
    this.disabledOpacity = 0.5,
    this.onUnavailableTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable = ref.watch(featureAvailableProvider(feature));

    if (isAvailable) {
      return child;
    }

    // Feature is unavailable - show feedback on tap
    final onTap =
        onUnavailableTap ?? () => _showUnavailableMessage(context, ref);

    if (showDisabled) {
      // Show disabled version of the child
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: IgnorePointer(
          child: Opacity(opacity: disabledOpacity, child: child),
        ),
      );
    }

    // Show placeholder or default message
    if (placeholder != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: placeholder,
      );
    }

    // Default unavailability message
    final reason =
        ref.watch(featureUnavailabilityReasonProvider(feature)) ??
        'This feature is currently unavailable';

    return _DefaultUnavailablePlaceholder(reason: reason, onTap: onTap);
  }

  void _showUnavailableMessage(BuildContext context, WidgetRef ref) {
    final reason =
        ref.read(featureUnavailabilityReasonProvider(feature)) ??
        'This feature is currently unavailable';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(reason)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Connect',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).pushNamed('/scanner');
          },
        ),
      ),
    );
  }
}

/// Default placeholder widget shown when feature is unavailable and no custom
/// placeholder is provided.
class _DefaultUnavailablePlaceholder extends StatelessWidget {
  final String reason;
  final VoidCallback? onTap;

  const _DefaultUnavailablePlaceholder({required this.reason, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                reason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simpler feature gate that completely hides the child when unavailable.
/// Use this for features that should be invisible when unavailable,
/// rather than showing a placeholder.
class FeatureGateHidden extends ConsumerWidget {
  final FeatureId feature;
  final Widget child;

  const FeatureGateHidden({
    super.key,
    required this.feature,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable = ref.watch(featureAvailableProvider(feature));
    return isAvailable ? child : const SizedBox.shrink();
  }
}

/// Extension to easily wrap any widget in a feature gate.
extension FeatureGateExtension on Widget {
  /// Wraps this widget in a FeatureGate.
  Widget gated(FeatureId feature, {Widget? placeholder}) {
    return FeatureGate(feature: feature, placeholder: placeholder, child: this);
  }

  /// Wraps this widget in a FeatureGate that shows a disabled version
  /// when the feature is unavailable.
  Widget gatedDisabled(FeatureId feature, {double opacity = 0.5}) {
    return FeatureGate(
      feature: feature,
      showDisabled: true,
      disabledOpacity: opacity,
      child: this,
    );
  }

  /// Wraps this widget in a FeatureGateHidden that hides it completely
  /// when the feature is unavailable.
  Widget gatedHidden(FeatureId feature) {
    return FeatureGateHidden(feature: feature, child: this);
  }
}

/// Button that executes a command through the dispatcher with proper error handling
class CommandButton extends ConsumerWidget {
  final DeviceCommand<dynamic> Function() commandBuilder;
  final Widget child;
  final ButtonStyle? style;
  final bool showLoadingIndicator;

  const CommandButton({
    super.key,
    required this.commandBuilder,
    required this.child,
    this.style,
    this.showLoadingIndicator = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if device is connected to determine button state
    final isConnected = ref.watch(isDeviceConnectedProvider);

    return FilledButton(
      onPressed: isConnected
          ? () => _executeCommand(context, ref)
          : () => _showDisconnectedMessage(context),
      style:
          style ??
          (isConnected
              ? null
              : FilledButton.styleFrom(backgroundColor: Colors.grey.shade600)),
      child: child,
    );
  }

  Future<void> _executeCommand(BuildContext context, WidgetRef ref) async {
    final command = commandBuilder();
    final result = await ref.dispatch(command);

    if (!context.mounted) return;

    result.fold(
      onSuccess: (_) {
        // Command succeeded - UI can handle success state
      },
      onFailure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(error.userMessage ?? error.message)),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _showDisconnectedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Connect device to use this feature'),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Connect',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).pushNamed('/scanner');
          },
        ),
      ),
    );
  }
}

/// Icon button that executes a command through the dispatcher
class CommandIconButton extends ConsumerWidget {
  final DeviceCommand<dynamic> Function() commandBuilder;
  final Widget icon;
  final String? tooltip;

  const CommandIconButton({
    super.key,
    required this.commandBuilder,
    required this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isDeviceConnectedProvider);

    return IconButton(
      onPressed: isConnected
          ? () => _executeCommand(context, ref)
          : () => _showDisconnectedMessage(context),
      icon: isConnected ? icon : Opacity(opacity: 0.5, child: icon),
      tooltip: tooltip,
    );
  }

  Future<void> _executeCommand(BuildContext context, WidgetRef ref) async {
    final command = commandBuilder();
    final result = await ref.dispatch(command);

    if (!context.mounted) return;

    result.fold(
      onSuccess: (_) {},
      onFailure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.userMessage ?? error.message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _showDisconnectedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Connect device to use this feature'),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Convenience function to execute a command and handle errors
Future<T?> executeCommand<T>(
  BuildContext context,
  WidgetRef ref,
  DeviceCommand<T> command, {
  VoidCallback? onSuccess,
  void Function(CommandError error)? onError,
}) async {
  final result = await ref.dispatch(command);

  if (!context.mounted) return null;

  return result.fold(
    onSuccess: (value) {
      onSuccess?.call();
      return value;
    },
    onFailure: (error) {
      if (onError != null) {
        onError(error);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.userMessage ?? error.message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    },
  );
}
