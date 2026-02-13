// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../providers/aether_flight_matcher_provider.dart';
import '../screens/aether_flight_detail_screen.dart';

/// Floating overlay card shown at the bottom of the screen when a mesh
/// node matches an active Aether flight. Uses a glass aesthetic with
/// blur and opacity. Dismissable via swipe-down or close button. Hides
/// on scroll and reappears when scrolling stops.
class AetherFlightDetectedOverlay extends ConsumerStatefulWidget {
  /// Whether the overlay should be temporarily hidden (e.g. during scroll).
  final bool hidden;

  const AetherFlightDetectedOverlay({super.key, this.hidden = false});

  @override
  ConsumerState<AetherFlightDetectedOverlay> createState() =>
      _AetherFlightDetectedOverlayState();
}

class _AetherFlightDetectedOverlayState
    extends ConsumerState<AetherFlightDetectedOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _slideController.forward();
  }

  @override
  void didUpdateWidget(AetherFlightDetectedOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hidden != oldWidget.hidden) {
      if (widget.hidden) {
        _slideController.reverse();
      } else {
        _slideController.forward();
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _dismiss(AetherFlightMatch match) {
    HapticFeedback.lightImpact();
    ref
        .read(aetherFlightMatcherProvider.notifier)
        .dismissOverlay(match.flight.nodeId);
  }

  void _openFlight(AetherFlightMatch match) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AetherFlightDetailScreen(flight: match.flight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlayMatches = ref.watch(aetherOverlayMatchesProvider);
    if (overlayMatches.isEmpty) return const SizedBox.shrink();

    // Show the most recent match
    final match = overlayMatches.first;

    return SlideTransition(
      position: _slideAnimation,
      child: Dismissible(
        key: ValueKey('aether_overlay_${match.flight.nodeId}'),
        direction: DismissDirection.down,
        onDismissed: (_) => _dismiss(match),
        child: _OverlayCard(
          match: match,
          onTap: () => _openFlight(match),
          onDismiss: () => _dismiss(match),
        ),
      ),
    );
  }
}

/// The actual card content with glass aesthetic.
class _OverlayCard extends StatelessWidget {
  final AetherFlightMatch match;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _OverlayCard({
    required this.match,
    required this.onTap,
    required this.onDismiss,
  });

  static const _flightColor = Color(0xFF29B6F6);

  @override
  Widget build(BuildContext context) {
    final flight = match.flight;
    final node = match.node;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: _flightColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _flightColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  // Flight icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _flightColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.flight,
                      color: _flightColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Flight info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              flight.flightNumber,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _flightColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DETECTED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${flight.departure} → ${flight.arrival}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                            if (node.rssi != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.signal_cellular_alt,
                                size: 11,
                                color: context.textTertiary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${node.rssi} dBm',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Report button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _flightColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Report',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _flightColor,
                      ),
                    ),
                  ),
                  // Dismiss button
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: context.textTertiary,
                    ),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
