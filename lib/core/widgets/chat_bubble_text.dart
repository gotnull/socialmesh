// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

// Canonical body-text style for chat bubbles. Each surface picks its own
// baseline (SIP DM + Meshtastic outgoing use 14, incoming uses 15); using
// one helper keeps incoming and outgoing bubbles symmetrical.
//
// The user's accessibility text-size preference is applied app-wide via
// MediaQuery.textScaler (see main.dart), so the size passed here is the
// unscaled baseline; the render layer scales it for every Text uniformly.
// Multiplying here again would double-scale.
//
// This is purely a render-time helper: it does NOT affect message
// payloads, wire format, persistence, or anything visible to the peer.
TextStyle chatBubbleBodyStyle({
  required double baseFontSize,
  Color? color,
  FontWeight? fontWeight,
}) {
  return TextStyle(
    fontSize: baseFontSize,
    color: color,
    fontWeight: fontWeight,
  );
}
