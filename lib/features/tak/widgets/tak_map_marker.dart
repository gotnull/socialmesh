// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../models/tak_event.dart';
import '../utils/cot_affiliation.dart';

/// Individual map marker for a TAK/CoT entity.
///
/// Renders a 36×36 rounded-rectangle container with MIL-STD-2525 affiliation
/// coloring, a center icon, and a callsign label beneath. Stale entities
/// are drawn at 40 % opacity.
class TakMapMarker extends StatelessWidget {
  /// The TAK event to render.
  final TakEvent event;

  /// Called when the marker is tapped.
  final VoidCallback? onTap;

  /// Called when the marker is long-pressed (e.g. to track the entity).
  final VoidCallback? onLongPress;

  /// Whether this entity is currently being tracked.
  final bool isTracked;

  /// Marker container size.
  static const double markerSize = 36;

  /// Total height including the callsign label.
  static const double totalHeight = 56;

  /// Maximum characters for the callsign label.
  static const int maxCallsignLength = 12;

  const TakMapMarker({
    super.key,
    required this.event,
    this.onTap,
    this.onLongPress,
    this.isTracked = false,
  });

  @override
  Widget build(BuildContext context) {
    final affiliation = parseAffiliation(event.type);
    final color = affiliation.color;
    final isStale = event.isStale;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(
        opacity: isStale ? 0.4 : 1.0,
        child: SizedBox(
          width: markerSize + 20, // Extra width for callsign label
          height: totalHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Marker container
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: markerSize,
                    height: markerSize,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      cotTypeIcon(event.type),
                      color: color,
                      size: 18,
                    ),
                  ),
                  // Tracking pin indicator
                  if (isTracked)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(
                          Icons.push_pin,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              // Callsign label
              Text(
                _truncatedCallsign,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(blurRadius: 3, color: Colors.black),
                    Shadow(blurRadius: 6, color: Colors.black),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _truncatedCallsign {
    final name = event.displayName;
    if (name.length <= maxCallsignLength) return name;
    return '${name.substring(0, maxCallsignLength - 1)}\u2026';
  }
}
