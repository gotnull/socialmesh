import 'package:flutter/material.dart';
import '../theme.dart';
import '../../providers/splash_mesh_provider.dart';
import 'animated_tagline.dart';

/// Status information for the connecting screen
class ConnectionStatusInfo {
  final String text;
  final IconData icon;
  final Color color;
  final bool showSpinner;

  const ConnectionStatusInfo({
    required this.text,
    required this.icon,
    required this.color,
    required this.showSpinner,
  });

  /// Predefined status for initializing state
  static ConnectionStatusInfo initializing(Color accentColor) =>
      ConnectionStatusInfo(
        text: 'Initializing',
        icon: Icons.hourglass_empty_rounded,
        color: accentColor,
        showSpinner: true,
      );

  /// Predefined status for scanning state
  static ConnectionStatusInfo scanning(Color accentColor) =>
      ConnectionStatusInfo(
        text: 'Scanning for device',
        icon: Icons.bluetooth_searching_rounded,
        color: accentColor,
        showSpinner: true,
      );

  /// Predefined status for connecting state
  static ConnectionStatusInfo connecting(Color accentColor) =>
      ConnectionStatusInfo(
        text: 'Connecting',
        icon: Icons.bluetooth_connected_rounded,
        color: accentColor,
        showSpinner: true,
      );

  /// Predefined status for auto-reconnecting state
  static ConnectionStatusInfo autoReconnecting(Color accentColor) =>
      ConnectionStatusInfo(
        text: 'Auto-reconnecting',
        icon: Icons.bluetooth_connected_rounded,
        color: accentColor,
        showSpinner: true,
      );

  /// Predefined status for configuring state
  static ConnectionStatusInfo configuring(Color accentColor) =>
      ConnectionStatusInfo(
        text: 'Configuring device',
        icon: Icons.settings_rounded,
        color: accentColor,
        showSpinner: true,
      );

  /// Predefined status for connected state
  static ConnectionStatusInfo connected() => const ConnectionStatusInfo(
    text: 'Connected',
    icon: Icons.check_circle_rounded,
    color: AppTheme.successGreen,
    showSpinner: false,
  );

  /// Predefined status for failed state
  static ConnectionStatusInfo failed() => const ConnectionStatusInfo(
    text: 'Connection failed',
    icon: Icons.error_outline_rounded,
    color: AppTheme.errorRed,
    showSpinner: false,
  );
}

/// Shared connecting content widget used by both splash screen and scanner screen
class ConnectingContent extends StatelessWidget {
  final ConnectionStatusInfo statusInfo;
  final bool showMeshNode;
  final bool showCancel;
  final VoidCallback? onCancel;
  final Animation<double>? pulseAnimation;

  const ConnectingContent({
    super.key,
    required this.statusInfo,
    this.showMeshNode = true,
    this.showCancel = false,
    this.onCancel,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showMeshNode) ...[
          const ConfiguredSplashMeshNode(),
          const SizedBox(height: 32),
        ],
        const Text(
          'Socialmesh',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const AnimatedTagline(taglines: appTaglines),
        const SizedBox(height: 48),
        // Status indicator
        ConnectionStatusIndicator(
          statusInfo: statusInfo,
          pulseAnimation: pulseAnimation,
        ),
        if (showCancel) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 16),
            ),
          ),
        ],
      ],
    );
  }
}

/// Status indicator with spinner or icon and animated text
class ConnectionStatusIndicator extends StatelessWidget {
  final ConnectionStatusInfo statusInfo;
  final Animation<double>? pulseAnimation;

  const ConnectionStatusIndicator({
    super.key,
    required this.statusInfo,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    Widget indicator = _buildIndicator();

    // Wrap in animated builder if pulse animation provided
    if (pulseAnimation != null && !statusInfo.showSpinner) {
      indicator = AnimatedBuilder(
        animation: pulseAnimation!,
        builder: (context, child) {
          return Transform.scale(scale: pulseAnimation!.value, child: child);
        },
        child: indicator,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Spinner or icon
        SizedBox(width: 48, height: 48, child: Center(child: indicator)),
        const SizedBox(height: 16),
        // Animated text with dots
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Row(
            key: ValueKey(statusInfo.text),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                statusInfo.text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: statusInfo.color,
                  letterSpacing: 0.3,
                ),
              ),
              if (statusInfo.showSpinner) AnimatedDots(color: statusInfo.color),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator() {
    if (statusInfo.showSpinner) {
      return SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: statusInfo.color,
        ),
      );
    }
    return Icon(statusInfo.icon, color: statusInfo.color, size: 24);
  }
}

/// Animated dots that cycle through visibility
class AnimatedDots extends StatefulWidget {
  final Color color;

  const AnimatedDots({super.key, required this.color});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Stagger the animation for each dot
            final dotProgress = ((progress * 3) - index).clamp(0.0, 1.0);
            final opacity = dotProgress < 0.5
                ? dotProgress * 2
                : 2 - (dotProgress * 2);
            return Padding(
              padding: const EdgeInsets.only(left: 1),
              child: Text(
                '.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: widget.color.withValues(
                    alpha: opacity.clamp(0.3, 1.0),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
