// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// One-line traceroute result summary shared by every "Traceroute
// complete" surface. Takes AppLocalizations directly (not a
// BuildContext) so the global completion banner can format a summary
// without a widget in the tree.

import '../../l10n/app_localizations.dart';
import '../../models/telemetry_log.dart';

/// Formats a one-line traceroute summary: transport + hops + SNR.
String formatTracerouteSummary(AppLocalizations l10n, TraceRouteLog log) {
  final hops = log.hopsTowards;
  final snr = log.snr;
  final mqtt = log.viaMqtt ?? false;
  final isDirect = hops == 0;

  if (mqtt) {
    if (isDirect && snr != null) {
      return l10n.nodeDetailTracerouteSummaryMqttDirect(snr.toStringAsFixed(1));
    }
    if (!isDirect && snr != null) {
      return l10n.nodeDetailTracerouteSummaryMqtt(hops, snr.toStringAsFixed(1));
    }
  } else {
    if (isDirect && snr != null) {
      return l10n.nodeDetailTracerouteSummaryRfDirect(snr.toStringAsFixed(1));
    }
    if (!isDirect && snr != null) {
      return l10n.nodeDetailTracerouteSummaryRf(hops, snr.toStringAsFixed(1));
    }
  }

  // Fallback: no SNR available
  if (isDirect) return l10n.nodeDetailTracerouteSummaryDirectNoSnr;
  return l10n.nodeDetailTracerouteSummaryHopsOnly(hops);
}
