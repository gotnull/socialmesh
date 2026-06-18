// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Global incident banner for Incident Mode.
///
/// A compact, calm banner intended to persist across shells (Map / Team /
/// Messages / Device / Settings) while a help request is active or the user is
/// responding. Pure presentation: takes a projection + role and a view tap.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../models/incident_mode_models.dart';

class IncidentGlobalBanner extends StatelessWidget {
  final IncidentProjection projection;

  /// Whether the local user is responding (vs. the requester).
  final bool asResponder;
  final VoidCallback? onView;

  const IncidentGlobalBanner({
    super.key,
    required this.projection,
    this.asResponder = false,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = asResponder
        ? l10n.helpModeBannerRespondingTitle
        : l10n.helpModeBannerActiveTitle;
    final subtitle = asResponder
        ? null
        : (projection.responderCount > 0
              ? l10n.helpModeResponderCount(projection.responderCount)
              : l10n.helpModeNoResponders);

    return StatusBanner.warning(
      title: title,
      subtitle: subtitle,
      icon: Icons.emergency_share,
      onTap: onView,
      trailing: onView == null
          ? null
          : TextButton(onPressed: onView, child: Text(l10n.helpModeBannerView)),
    );
  }
}
