// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../../../core/widgets/animated_empty_state.dart';

/// Animated empty state for the signals screen.
/// Uses the reusable AnimatedEmptyState widget for consistency across Social screens.
class SignalsEmptyState extends StatelessWidget {
  const SignalsEmptyState({
    super.key,
    required this.canGoActive,
    required this.blockedReason,
    required this.onGoActive,
  });

  final bool canGoActive;
  final String? blockedReason;
  final VoidCallback onGoActive;

  static const _taglines = [
    'Nothing active here right now.\nSignals appear when someone nearby goes active.',
    'Signals are mesh-first and ephemeral.\nThey dissolve when their timer ends.',
    'Share a quick status or photo.\nNearby nodes will see it in real time.',
    'Go active to broadcast your presence.\nOff-grid, device to device.',
  ];

  static const _icons = [
    Icons.sensors_off,
    Icons.near_me,
    Icons.router,
    Icons.image,
    Icons.location_on,
    Icons.chat_bubble_outline,
    Icons.schedule,
    Icons.bookmark_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: _icons,
        taglines: _taglines,
        titlePrefix: 'No active ',
        titleKeyword: 'signals',
        titleSuffix: ' nearby',
        actionLabel: 'Go Active',
        actionIcon: Icons.sensors,
        onAction: onGoActive,
        actionEnabled: canGoActive,
        actionDisabledReason: blockedReason,
      ),
    );
  }
}
