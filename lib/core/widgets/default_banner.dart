// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';

/// A default banner placeholder widget with a gradient based on accent color.
/// Used when a user hasn't set a profile banner.
class DefaultBanner extends StatelessWidget {
  const DefaultBanner({super.key, this.accentColor});

  /// The accent color to use for the gradient. If null, uses context.accentColor.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? context.accentColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.2),
          ],
        ),
      ),
    );
  }
}
