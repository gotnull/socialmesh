// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/transport_path.dart';
import '../../../utils/time_format.dart';
import '../../../models/mesh_models.dart';
import 'hop_count_chip.dart';

/// Always-visible metadata line inside a received bubble: timestamp plus,
/// when the packet carried them, transport path, hop count and SNR.
/// Inbound-only - outbound messages reach the radio over BLE/USB and never
/// carry receive metadata. A single wrapping Text keeps a long line from
/// overflowing a bubble whose width was set by short message text.
///
/// The delivery path comes exclusively from the packet's via_mqtt flag
/// (see [TransportPath]). Unknown is omitted from this compact line -
/// historical rows without the flag must not be mislabelled RF; the
/// expanded surfaces state "Unknown" explicitly.
class InboundMessageMetaLine extends StatelessWidget {
  final Message message;
  final bool isEncrypted;

  const InboundMessageMetaLine({
    super.key,
    required this.message,
    this.isEncrypted = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final timeFormat = AppTimeFormat.timeOnly(context);
    final transport = classifyTransport(message.viaMqtt);
    final parts = <String>[
      timeFormat.format(message.timestamp),
      if (transport != TransportPath.unknown) transport.localizedLabel(l10n),
      if (message.hopCount != null) hopCountLabel(l10n, message.hopCount!),
      if (message.rxSnr != null)
        l10n.messagingTechInfoSnr(message.rxSnr!.toStringAsFixed(1)),
    ];
    final semanticParts = <String>[
      if (transport != TransportPath.unknown)
        l10n.messagingSemanticsReceivedVia(transport.localizedLabel(l10n)),
      if (message.hopCount != null) hopCountLabel(l10n, message.hopCount!),
      if (message.rxSnr != null)
        l10n.messagingTechInfoSnr(message.rxSnr!.toStringAsFixed(1)),
      timeFormat.format(message.timestamp),
    ];
    return Semantics(
      label: semanticParts.join(', '),
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (isEncrypted) ...[
            Icon(Icons.lock, size: 10, color: context.textTertiary),
            SizedBox(width: AppTheme.spacing3),
          ],
          Text(
            parts.join(' · '),
            style: TextStyle(fontSize: 11, color: context.textTertiary),
          ),
        ],
      ),
    );
  }
}
