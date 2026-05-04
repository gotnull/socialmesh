// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/accessibility_providers.dart';

// Canonical body-text size for chat bubbles. Each surface picks its own
// baseline (SIP DM uses 14, Meshtastic + MeshCore use 15 for incoming /
// 14 for outgoing via the theme bodyMedium); this helper applies the
// user's chosen accessibility text-scale on top so the same setting
// reaches both incoming and outgoing bubbles symmetrically.
//
// This is purely a render-time helper — it does NOT affect message
// payloads, wire format, persistence, or anything visible to the peer.
TextStyle chatBubbleBodyStyle(
  WidgetRef ref, {
  required double baseFontSize,
  Color? color,
  FontWeight? fontWeight,
}) {
  final scale = ref.watch(effectiveTextScaleProvider);
  return TextStyle(
    fontSize: baseFontSize * scale,
    color: color,
    fontWeight: fontWeight,
  );
}
