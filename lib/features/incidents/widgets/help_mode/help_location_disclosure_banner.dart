// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Honest, centralized location-sharing disclosure for Help Mode.
///
/// Driven by [HelpLocationPolicy] so the copy is decided in one place. While
/// precise location sending is unsupported it shows the "location off" copy and
/// never implies that coordinates are shared. The future "shared" branch is
/// kept compiling for when a sealed transport lands.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../services/help_location_policy.dart';

class HelpLocationDisclosureBanner extends StatelessWidget {
  const HelpLocationDisclosureBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (HelpLocationPolicy.canSendPreciseLocation) {
      return StatusBanner.info(
        title: l10n.helpModeLocationSharedTitle,
        subtitle: l10n.helpModeLocationSharedBody,
        icon: Icons.my_location,
      );
    }
    return StatusBanner.info(
      title: l10n.helpModeLocationOffTitle,
      subtitle: l10n.helpModeLocationOffBody,
      icon: Icons.location_off,
    );
  }
}
