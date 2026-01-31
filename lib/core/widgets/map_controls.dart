// SPDX-License-Identifier: GPL-3.0-or-later
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
        color: context.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
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
      color: context.border.withValues(alpha: 0.3),
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
                ? context.textSecondary
                : context.textTertiary.withValues(alpha: 0.5),
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
        color: context.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
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

/// Layout constants for consistent map control spacing
class MapControlLayout {
  static const double padding = 16.0;
  static const double controlSpacing = 8.0;
  static const double controlSize = 44.0;
  static const double zoomControlsHeight = 136.0; // 3 buttons × 44 + 2 dividers
}

/// Compass widget showing map rotation - shared across all map screens
class MapCompass extends StatelessWidget {
  final double rotation;
  final VoidCallback onPressed;

  const MapCompass({
    super.key,
    required this.rotation,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: -rotation * (3.14159 / 180),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // North indicator (red)
              Positioned(
                top: 6,
                child: Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // South indicator (white)
              Positioned(
                bottom: 6,
                child: Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Center dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: context.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A complete map controls column positioned on the right side of the map
/// Use this for consistent control layout across all map screens
class MapControlsOverlay extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final double mapRotation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback? onFitAll;
  final VoidCallback? onCenterOnMe;
  final VoidCallback onResetNorth;
  final bool hasMyLocation;
  final bool showFitAll;
  final bool showNavigation;
  final bool showCompass;
  final double topOffset;
  final double rightOffset;

  const MapControlsOverlay({
    super.key,
    required this.currentZoom,
    this.minZoom = 2.0,
    this.maxZoom = 18.0,
    this.mapRotation = 0.0,
    required this.onZoomIn,
    required this.onZoomOut,
    this.onFitAll,
    this.onCenterOnMe,
    required this.onResetNorth,
    this.hasMyLocation = true,
    this.showFitAll = true,
    this.showNavigation = true,
    this.showCompass = true,
    this.topOffset = MapControlLayout.padding,
    this.rightOffset = MapControlLayout.padding,
  });

  @override
  Widget build(BuildContext context) {
    const spacing = MapControlLayout.controlSpacing;

    return Positioned(
      right: rightOffset,
      top: topOffset,
      child: Column(
        children: [
          // Compass
          if (showCompass) ...[
            MapCompass(rotation: mapRotation, onPressed: onResetNorth),
            SizedBox(height: spacing),
          ],
          // Zoom controls
          MapZoomControls(
            currentZoom: currentZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onFitAll: onFitAll,
            showFitAll: showFitAll,
          ),
          // Navigation controls
          if (showNavigation && onCenterOnMe != null) ...[
            SizedBox(height: spacing),
            MapNavigationControls(
              onCenterOnMe: onCenterOnMe!,
              onResetNorth: showCompass ? null : onResetNorth,
              hasLocation: hasMyLocation,
            ),
          ],
        ],
      ),
    );
  }
}
