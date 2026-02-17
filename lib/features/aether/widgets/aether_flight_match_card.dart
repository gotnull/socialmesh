// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../data/airports.dart';
import '../providers/aether_flight_matcher_provider.dart';
import '../screens/aether_flight_detail_screen.dart';

/// A card displayed in the Nodes screen when a mesh node matches an
/// active Aether flight. Visually distinct from regular node cards with
/// a flight-themed accent and clear call-to-action.
class AetherFlightMatchCard extends StatelessWidget {
  final AetherFlightMatch match;

  const AetherFlightMatchCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final flight = match.flight;
    final node = match.node;
    const flightColor = Color(0xFF29B6F6); // lightBlue.shade400

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AetherFlightDetailScreen(flight: flight),
            ),
          );
        },
        child: GradientBorderContainer(
          borderRadius: 12,
          borderWidth: 2,
          accentColor: flightColor,
          accentOpacity: 1.0,
          backgroundColor: flightColor.withValues(alpha: 0.06),
          enableDepthBlend: true,
          depthBlendOpacity: 0.4,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Flight icon badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: flightColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.flight, color: flightColor, size: 28),
              ),
              const SizedBox(width: 16),
              // Flight info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Flight number + "IN FLIGHT" badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            flight.flightNumber,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: flightColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.flight_takeoff,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'IN FLIGHT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Route
                    Builder(
                      builder: (context) {
                        final depAirport = lookupAirport(flight.departure);
                        final arrAirport = lookupAirport(flight.arrival);
                        return Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  flight.departure,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                                if (depAirport != null)
                                  Text(
                                    depAirport.city,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: context.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: context.textTertiary,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  flight.arrival,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                                if (arrAirport != null)
                                  Text(
                                    arrAirport.city,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: context.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    // Node name
                    Row(
                      children: [
                        Icon(
                          Icons.sensors,
                          size: 13,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            node.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Signal metrics if available
                        if (node.rssi != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.signal_cellular_alt,
                            size: 12,
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
                        if (node.snr != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            'SNR ${node.snr}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // CTA
                    Row(
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 14,
                          color: flightColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to report your reception',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: flightColor,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: flightColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
