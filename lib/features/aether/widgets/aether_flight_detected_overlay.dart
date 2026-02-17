// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../data/airports.dart';
import '../providers/aether_flight_matcher_provider.dart';
import '../screens/aether_flight_detail_screen.dart';

/// Floating overlay card shown at the bottom of the screen when a mesh
/// node matches an active Aether flight. Uses a glass aesthetic with
/// blur and opacity. Sits flush at the bottom edge with no gap.
/// Dismissable via swipe-down or close button.
class AetherFlightDetectedOverlay extends ConsumerWidget {
  const AetherFlightDetectedOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayMatches = ref.watch(aetherOverlayMatchesProvider);
    if (overlayMatches.isEmpty) return const SizedBox.shrink();

    // Show the most recent match
    final match = overlayMatches.first;

    return Dismissible(
      key: ValueKey('aether_overlay_${match.flight.nodeId}'),
      direction: DismissDirection.down,
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        ref
            .read(aetherFlightMatcherProvider.notifier)
            .dismissOverlay(match.flight.nodeId);
      },
      child: _OverlayCard(
        match: match,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AetherFlightDetailScreen(flight: match.flight),
            ),
          );
        },
        onDismiss: () {
          HapticFeedback.lightImpact();
          ref
              .read(aetherFlightMatcherProvider.notifier)
              .dismissOverlay(match.flight.nodeId);
        },
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: _flightColor.withValues(alpha: 0.12),
              border: Border(
                top: BorderSide(color: _flightColor.withValues(alpha: 0.3)),
              ),
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
                          Builder(
                            builder: (context) {
                              final depCity = lookupAirport(
                                flight.departure,
                              )?.city;
                              final arrCity = lookupAirport(
                                flight.arrival,
                              )?.city;
                              final route = depCity != null && arrCity != null
                                  ? '${flight.departure} ($depCity) → ${flight.arrival} ($arrCity)'
                                  : '${flight.departure} → ${flight.arrival}';
                              return Text(
                                route,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                              );
                            },
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
    );
  }
}
