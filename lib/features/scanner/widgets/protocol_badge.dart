// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../models/mesh_device.dart';

/// Protocol pill shown next to the transport label on a device card.
///
/// Same shape and color treatment used by every device-card surface
/// (BLE scan results, mDNS Wi-Fi radios, etc.) so identical protocols
/// render identical chips regardless of transport.
class ProtocolBadge extends StatelessWidget {
  final MeshProtocolType protocolType;

  const ProtocolBadge({super.key, required this.protocolType});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (protocolType) {
      MeshProtocolType.meshtastic => (
        context.l10n.scannerProtocolMeshtastic,
        AppTheme.successGreen,
      ),
      MeshProtocolType.meshcore => (
        context.l10n.scannerProtocolMeshCore,
        AccentColors.cyan,
      ),
      MeshProtocolType.unknown => (
        context.l10n.scannerProtocolUnknown,
        AccentColors.orange,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radius4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
