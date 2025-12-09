import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Shared zoom controls widget for all map implementations.
/// Provides consistent zoom in, zoom out, and fit-all functionality.
class MapZoomControls extends StatelessWidget {
  /// Current zoom level
  final double currentZoom;

  /// Minimum allowed zoom
  final double minZoom;

  /// Maximum allowed zoom
  final double maxZoom;

  /// Callback when zoom in is pressed
  final VoidCallback onZoomIn;

  /// Callback when zoom out is pressed
  final VoidCallback onZoomOut;

  /// Callback when fit all is pressed (optional)
  final VoidCallback? onFitAll;

  /// Whether to show the fit all button
  final bool showFitAll;

  const MapZoomControls({
    super.key,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    this.onFitAll,
    this.showFitAll = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom in
          _ZoomButton(
            icon: Icons.add,
            onPressed: currentZoom < maxZoom
                ? () {
                    HapticFeedback.selectionClick();
                    onZoomIn();
                  }
                : null,
            isTop: true,
          ),
          _Divider(),
          // Zoom out
          _ZoomButton(
            icon: Icons.remove,
            onPressed: currentZoom > minZoom
                ? () {
                    HapticFeedback.selectionClick();
                    onZoomOut();
                  }
                : null,
          ),
          if (showFitAll && onFitAll != null) ...[
            _Divider(),
            // Fit all
            _ZoomButton(
              icon: Icons.fit_screen,
              onPressed: () {
                HapticFeedback.selectionClick();
                onFitAll!();
              },
              isBottom: true,
              tooltip: 'Fit all',
            ),
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: 32,
      color: AppTheme.darkBorder.withValues(alpha: 0.3),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isTop;
  final bool isBottom;
  final String? tooltip;

  const _ZoomButton({
    required this.icon,
    required this.onPressed,
    this.isTop = false,
    this.isBottom = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.vertical(
          top: isTop ? const Radius.circular(12) : Radius.zero,
          bottom: isBottom ? const Radius.circular(12) : Radius.zero,
        ),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null
                ? AppTheme.textSecondary
                : AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Navigation controls for maps (center on me, reset north)
class MapNavigationControls extends StatelessWidget {
  final VoidCallback onCenterOnMe;
  final VoidCallback? onResetNorth;
  final bool hasLocation;

  const MapNavigationControls({
    super.key,
    required this.onCenterOnMe,
    this.onResetNorth,
    this.hasLocation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Center on my location
          _ZoomButton(
            icon: Icons.my_location,
            onPressed: hasLocation
                ? () {
                    HapticFeedback.selectionClick();
                    onCenterOnMe();
                  }
                : null,
            isTop: onResetNorth == null,
            isBottom: onResetNorth == null,
            tooltip: 'Center on me',
          ),
          if (onResetNorth != null) ...[
            _Divider(),
            _ZoomButton(
              icon: Icons.explore,
              onPressed: () {
                HapticFeedback.selectionClick();
                onResetNorth!();
              },
              isBottom: true,
              tooltip: 'Reset north',
            ),
          ],
        ],
      ),
    );
  }
}
